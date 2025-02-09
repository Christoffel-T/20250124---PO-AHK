#Requires AutoHotkey v2.0
CoordMode('Mouse', 'Screen')
CoordMode('Pixel', 'Screen')
CoordMode('ToolTip', 'Screen')
SendMode('Event')
#Include OCR.ahk

settings_file := 'settings.ini'

wtitle := IniRead(settings_file, 'General', 'wtitle')

coords_area := StrSplit(IniRead(settings_file, 'General', 'coords_area'), ',', ' ')
coords := Map()
coords['BUY']  := StrSplit(IniRead(settings_file, 'General', "coords['BUY']"), ',', ' ')
coords['SELL'] := StrSplit(IniRead(settings_file, 'General', "coords['SELL']"), ',', ' ')

coords['Payout']  := StrSplit(IniRead(settings_file, 'General', "coords['Payout']"), ',', ' ')
coords['coin']  := StrSplit(IniRead(settings_file, 'General', "coords['coin']"), ',', ' ')
coords['coin_top']  := StrSplit(IniRead(settings_file, 'General', "coords['coin_top']"), ',', ' ')
coords['empty_area']  := StrSplit(IniRead(settings_file, 'General', "coords['empty_area']"), ',', ' ')

colors := Map()
colors['green'] := IniRead(settings_file, 'General', 'colors[green]')
colors['red'] := IniRead(settings_file, 'General', 'colors[red]')

Hotkey('F1', main.Bind(), 'On')
ToolTip('Ready. Press F1 to start', 5, 5, 1)
start_time := A_TickCount
main()

main(hk:='') {
    global
    ToolTip('Running...', 5, 5, 1)
    if !WinActive(wtitle) {
        WinActivate(wtitle)  
        sleep 500
    }

    log_file := 'log.csv'
    tickcount_last_reverse := [false, A_TickCount]
    direction := ''
    active_trade := ''
    countdown_close := 0
    countdown_close_str := ''
    win_rate := ''
    debug_str := ''
    current_balance := check_balance()
    count_p_or_l := 0
    wins := 0
    losses := 0

    default_amount := 2
    amount := default_amount + Floor(current_balance/1000)
    _time := 15
    _time += 2
    payout := 1.92
    datetime := A_NowUTC
    datetime := DateAdd(datetime, -5, 'h')
    date := FormatTime(datetime, 'MM/dd')
    time := FormatTime(datetime, 'HH:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
    coin_name := OCR.FromRect(coords['coin'][1] - 15, coords['coin'][2] - 15, 130, 30).Text
    marked_time_refresh := A_TickCount

    if !FileExist(log_file) {
        FileAppend('date,time,active_trade,direction,balance,amount,payout,P/L (win_rate),debug`n', log_file)
    }
    set_amount(amount)
    MouseClick('l', coords['empty_area'][1], coords['empty_area'][2],1,2)
    SetTimer(start, 100)
}

start() {
    global

    if A_TickCount > marked_time_refresh + 2*60*60*1000 {
        marked_time_refresh := A_TickCount
        reload_website()
        reload
    }

    Loop {
        if !WinActive(wtitle) {
            WinActivate(wtitle)
            sleep 100
        }
        MouseClick('L', coords['empty_area'][1], coords['empty_area'][2], 1, 1)
        sleep 100
        if ImageSearch(&outx, &outx, coords['Payout'][1], coords['Payout'][2], coords['Payout'][3], coords['Payout'][4], '*50 payout.png') {
            ocr1 := OCR.FromRect(coords['Payout'][1], coords['Payout'][2], coords['Payout'][3], coords['Payout'][4], , 10)
            payout := 92
            break
        } else {
            direction := ''
            ToolTip('Waiting for payout to be 92 or higher...', 500, 5, 12)
            MouseClick('L', coords['coin'][1] + Random(-2, 2), coords['coin'][2] + Random(-2, 2), 1, 2)
            sleep 500
            MouseClick('L', coords['coin_top'][1] + Random(-2, 2), coords['coin_top'][2] + Random(-2, 2), 1, 2)
            sleep 500
            Send '{Escape}'
            sleep 1000
            coin_name := OCR.FromRect(coords['coin'][1] - 15, coords['coin'][2] - 15, 130, 30).Text
        }
    }

    MsgBox payout

    ps2 := false
    try
        ps1 := PixelSearch(&outx1, &outy1, coords_area[1], coords_area[2], coords_area[3], coords_area[4], colors['green'], 5)
    catch as e {
        ToolTip('Error: PixelSearch failed`n' e.Message, 500, 5, 15)
        coords_area[1] := max(coords_area[1] - 1, 100)
        coords_area[3] := coords_area[1] - 2
        ToolTip(,,, 15)
        return
    }

    if ps1 {
        ps2 := PixelSearch(&outx2, &outy2, outx1+1, coords_area[2], outx1-1, coords_area[4], colors['red'], 5)
        coords_area[1] := min(coords_area[1] + 1, A_ScreenWidth*0.95)
        coords_area[3] := coords_area[1] - 2
        debug_str := 'ps: ' ps1 ' ' ps2 ' | diff: ' (ps1 and ps2 ? outy2 - outy1 : 0) ' | '
        ToolTip('(' A_Sec '.' A_MSec ')' debug_str '`nCurrent direction: ' direction '`nCurrent balance: ' format('{:.2f}', current_balance), 5, 5, 11)
    } else {
        coords_area[1] := max(coords_area[1] - 1, 100)
        coords_area[3] := coords_area[1] - 2
        debug_str := 'ps: ' ps1 ' ' ps2 ' | diff: ' (ps1 and ps2 ? outy2 - outy1 : 0) ' | '
        ToolTip('(' A_Sec '.' A_MSec ')' debug_str '`nCurrent direction: ' direction '`nCurrent balance: ' format('{:.2f}', current_balance), 5, 5, 11)
        return
    }
    
    win_rate := wins+losses > 0 ? wins/(wins+losses)*100 : 0
    win_rate := Format('{:.1f}', win_rate)

    ToolTip(,,, 12)

    if (tickcount_last_reverse[1] and countdown_close < 0) {
        active_trade := ''
        tickcount_last_reverse[1] := false
        new_balance := check_balance()
        if (new_balance <= current_balance + 0.5) {
            current_balance := new_balance
            amount := 2*amount + 1
            if Mod(count_p_or_l, -5)=0
                amount := default_amount + Floor(current_balance/1000)
            set_amount(amount)
            if count_p_or_l > 0
                count_p_or_l := 0
            count_p_or_l--
            losses++
        } else if (new_balance > current_balance) {
            current_balance := new_balance
            amount := default_amount
            set_amount(amount)
            if count_p_or_l < 0
                count_p_or_l := 0
            count_p_or_l++
            wins++
        }
    }

    datetime := A_NowUTC
    datetime := DateAdd(datetime, -5, 'h')
    date := FormatTime(datetime, 'MM/dd')
    time := FormatTime(datetime, 'hh:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
    if ps1 and ps2 {
        ToolTip('Green', outx1+100, outy1, 2)
        ToolTip('Red', outx2+100, outy2, 3)
        ToolTip('Green', outx1, outy1-200, 4)
        ToolTip('Red', outx2, outy2-200, 5)
        if (direction='') {
            direction := outy2 < outy1 ? 'SELL' : 'BUY'
        }

        ToolTip(A_Sec '.' A_MSec ' ||Mod 14?|| ' Mod(A_Sec, 15), 1205, 5, 19)
        if Mod(A_Sec, 15) = 14 {
            ToolTip(A_Sec '.' A_MSec ' ||MOD 14!!!!!!!!!!!!|| ' Mod(A_Sec, 15), 1205, 5, 19)
            if (direction='SELL' and outy2 > outy1) {
                direction := 'BUY'
                main_sub1(direction)
            } else if (direction='BUY' and outy2 < outy1) {
                direction := 'SELL'
                main_sub1(direction)
            }
        }

    }

    update_log()
    sleep 100
}

update_log() {
    global
    if tickcount_last_reverse[1] {
        countdown_close := (tickcount_last_reverse[2] + _time*1000 - A_TickCount)/1000
        countdown_close_str := ' (' format('{:.2f}', countdown_close) ')'
    } else {
        countdown_close_str := ''
    }
    err := 0
    loop {
        ToolTip('Appending new row. Errors: ' err, 500, 5, 12)
        try {
            FileAppend(
                date ',' 
                time ',' 
                active_trade countdown_close_str ',' 
                direction ',' 
                current_balance ',' 
                format('{:.2f}', amount) ',' 
                format('{:.2f}', payout) ' (' coin_name ')' ',' 
                count_p_or_l ' (' wins '|' losses '|' win_rate '%)' ',' 
                debug_str '`n',
                log_file
            )
            if current_balance < 1 {
                MsgBox('0 Balance.')
                exitapp
            }
            break
        } catch {
            err++
            sleep 100
            continue
        }
    }
}

main_sub1(action) {
    global

    condition := count_p_or_l <= -2 ? true : (not tickcount_last_reverse[1])

    ; if true {
    if condition {
        tickcount_last_reverse := [false, A_TickCount]
        if !WinActive(wtitle) {
            WinActivate(wtitle)
            sleep 100
        }
        sleep 50
        MouseClick('L', coords[action][1] + Random(-5, 5), coords[action][2] + Random(-5, 5), 1, 2)
        sleep 30
        while check_balance() = current_balance {
            ToolTip('Waiting balance change...', 500, 5, 12)
            sleep 50
            if (a_index>100) {
                direction := action
                ToolTip(,,, 12)
                return 
            }
        }
        ToolTip(,,, 12)
        tickcount_last_reverse[1] := true
        current_balance := check_balance()
        active_trade := action
    }
    direction := action
}

reload_website() {
    if !WinActive(wtitle) {
        WinActivate(wtitle)  
        sleep 100
    }
    sleep 80
    Send('^r')
    sleep 5000
    check_balance()
    sleep 2000
    return
}

set_amount(amount) {
    if !WinActive(wtitle) {
        WinActivate(wtitle)  
        sleep 100
    }
    sleep 80
    Send('^f')
    sleep 80
    Send('^a{BS}')
    sleep 80
    Send('amount')
    sleep 80
    Send('{enter}')
    sleep 80
    Send('{esc}')
    sleep 80
    Send('{tab}')
    sleep 80
    A_Clipboard := amount
    sleep 100
    Send('^v')
    sleep 100
    Send('{tab 2}')
    sleep 50
    MouseMove(Random(-20, 20), Random(-20, 20), 4, 'R')
    return
}

check_balance() {
    Loop {
        A_Clipboard := ''
        if !WinActive(wtitle) {
            WinActivate(wtitle)  
            sleep 100
        }
        sleep 50
        Send('^a^c')
        sleep 50
        if !ClipWait(2) {
            ToolTip('Copy failed')
            sleep 30
            continue
        }
        sleep 100
        if !RegExMatch(A_Clipboard, 'm)^\d{1,3}(,\d{3})*(\.\d{2})*$', &match) {
            tooltip('Error: No balance found`n' A_Clipboard)
            sleep 100
            continue
        }
        ToolTip
        balance := StrReplace(match[], ',', '')
        return balance
    }
}

$^Esc::ExitApp
$+Esc::Reload
$Esc::Pause -1