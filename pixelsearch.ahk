#Requires AutoHotkey v2.0
CoordMode('Mouse', 'Screen')
CoordMode('Pixel', 'Screen')
CoordMode('ToolTip', 'Screen')
SendMode('Event')
#Include OCR.ahk

settings_file := 'settings.ini'

wtitle := IniRead(settings_file, 'General', 'wtitle')

coords_area := StrSplit(IniRead(settings_file, 'General', 'coords_area'), ',', ' ')
min_x := coords_area[1] - 50
coords := Map()
coords['BUY']  := StrSplit(IniRead(settings_file, 'General', "coords['BUY']"), ',', ' ')
coords['SELL'] := StrSplit(IniRead(settings_file, 'General', "coords['SELL']"), ',', ' ')

coords['Payout']  := StrSplit(IniRead(settings_file, 'General', "coords['Payout']"), ',', ' ')
coords['coin']  := StrSplit(IniRead(settings_file, 'General', "coords['coin']"), ',', ' ')
coords['coin_top']  := StrSplit(IniRead(settings_file, 'General', "coords['coin_top']"), ',', ' ')
coords['empty_area']  := StrSplit(IniRead(settings_file, 'General', "coords['empty_area']"), ',', ' ')

colors := Map()
colors['blue'] := IniRead(settings_file, 'General', "colors['blue']")
colors['orange'] := IniRead(settings_file, 'General', "colors['orange']")
colors['green'] := IniRead(settings_file, 'General', "colors['green']")
colors['red'] := IniRead(settings_file, 'General', "colors['red']")

Hotkey('F1', main.Bind(), 'On')
ToolTip('Ready. Press F1 to start', 5, 5, 1)
start_time := A_TickCount
main()

get_timeframe(interval := 15) {
    datetime := A_NowUTC
    datetime := DateAdd(datetime, -5, 'h')
    seconds := SubStr(datetime, -2)
    rounded_seconds := Floor(seconds / interval) * interval
    rounded_time := SubStr(datetime, 1, -2) Format("{:02}", rounded_seconds)
    return rounded_time
}

main(hk:='') {
    global
    ToolTip('Running...', 5, 5, 1)
    if !WinActive(wtitle) {
        WinActivate(wtitle)  
        sleep 500
    }

    log_file := 'log.csv'
    trade_opened := [false, A_TickCount]
    crossovers_arr := []
    last_trade := ''
    active_trade := ''
    countdown_close := 0
    countdown_close_str := ''
    win_rate := ''
    debug_str := ''
    balance := {current: 0, min: 999999999, max: 0}
    balance := check_balance(balance)
    candle_colors := [{color: '?', timeframe: get_timeframe()}]
    
    count_p_or_l := 0
    lose_streak := {max: count_p_or_l, repeat: 1}
    stats := {win: 0, loss: 0, draw: 0}
    paused := false
    blockers := Map()

    amounts_tresholds := [[4000, 2], [3060, 1]]

    amount := get_amount(balance.current)
    _time := 15
    _time += 2
    payout := 92
    datetime := A_NowUTC
    datetime := DateAdd(datetime, -5, 'h')
    date := FormatTime(datetime, 'MM/dd')
    time := FormatTime(datetime, 'HH:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
    coin_name := OCR.FromRect(coords['coin'][1] - 15, coords['coin'][2] - 15, 130, 40).Text
    marked_time_refresh := A_TickCount

    if !FileExist(log_file) {
        FileAppend('date,time,active_trade,last_trade,balance,amount,payout,Streak (W|D|L|win_rate),debug`n', log_file)
    }
    set_amount(amount)
    MouseClick('l', coords['empty_area'][1], coords['empty_area'][2],1,2)
    SetTimer(start, 100)
}

get_amount(val) {
    for tresh in amounts_tresholds {
        if val >= tresh[1]
            return tresh[2]
        return 1
    }
}

start() {
    global

    if A_TickCount > marked_time_refresh + 2*60*60*1000 {
        marked_time_refresh := A_TickCount
        reload_website()
        ; reload
    }

    Loop {
        if !WinActive(wtitle) {
            WinActivate(wtitle)
            sleep 100
        }
        MouseClick('L', coords['empty_area'][1], coords['empty_area'][2], 1, 1)
        sleep 100
        if ImageSearch(&outx, &outy, coords['Payout'][1], coords['Payout'][2], coords['Payout'][3]+coords['Payout'][1], coords['Payout'][4]+coords['Payout'][2], '*10 payout.png') {
            payout := 92
            break
        } else {
            last_trade := ''
            ToolTip('Waiting for payout to be 92 or higher...', 500, 5, 12)
            MouseClick('L', coords['coin'][1] + Random(-2, 2), coords['coin'][2] + Random(-2, 2), 1, 2)
            sleep 500
            MouseClick('L', coords['coin_top'][1] + Random(-2, 2), coords['coin_top'][2] + Random(-2, 2), 1, 2)
            sleep 500
            Send '{Escape}'
            sleep 1000
        }
    }

    ps2 := false
    try
        ps1 := PixelSearch(&outx1, &outy1, coords_area[1], coords_area[2], coords_area[3], coords_area[4], colors['blue'], 5)
    catch as e {
        ToolTip('Error: PixelSearch failed`n' e.Message, 500, 5, 15)
        coords_area[1] := max(coords_area[1] - 1, 100)
        coords_area[3] := coords_area[1] - 2
        ToolTip(,,, 15)
        return
    }

    if ps1 {
        ps2 := PixelSearch(&outx2, &outy2, outx1+1, coords_area[2], outx1-1, coords_area[4], colors['orange'], 5)
        ps3 := PixelSearch(&outx3, &outy3, outx1+4, coords_area[2], outx1+1, coords_area[4], colors['green'], 5)
        ps4 := PixelSearch(&outx4, &outy4, outx1+4, coords_area[4], outx1+1, coords_area[2], colors['red'], 5)
        coords_area[1] := min(coords_area[1] + 1, A_ScreenWidth*0.95)
        coords_area[3] := coords_area[1] - 2
        ToolTip('(' A_Sec '.' A_MSec ')' debug_str '`nCurrent last_trade: ' last_trade '`nCurrent balance: ' format('{:.2f}', balance.current), 5, 5, 11)
    } else {
        coords_area[1] := max(coords_area[1] - 1, 100)
        if coords_area[1] < min_x {
            coords_area[1] := min_x
            reload_website()
        }
        coords_area[3] := coords_area[1] - 2
        debug_str := 'ps: ' ps1 ' ' ps2 ' | diff: ' (ps1 and ps2 ? outy2 - outy1 : 0) ' | '
        ToolTip('(' A_Sec '.' A_MSec ')' debug_str '`nCurrent last_trade: ' last_trade '`nCurrent balance: ' format('{:.2f}', balance.current), 5, 5, 11)
        return
    }
    
    win_rate := stats.win > 0 ? stats.win/(stats.win+stats.loss+stats.draw)*100 : 0
    win_rate := Format('{:.1f}', win_rate)

    ToolTip(,,, 12)

    if (trade_opened[1] and countdown_close < 0) {
        active_trade := ''
        trade_opened[1] := false
        new_balance := check_balance(balance)
        if (new_balance.current <= balance.current + 0.5) {
            balance := new_balance
            if count_p_or_l > 0
                count_p_or_l := 0
            count_p_or_l--
            if (count_p_or_l = lose_streak.max)
                lose_streak.repeat++
            else if (count_p_or_l < lose_streak.max) {
                lose_streak.max := count_p_or_l
                lose_streak.repeat := 1
            }
            amount := 2*(amount) + 1 ; (default_amount + Floor(balance.current/1000)) * (-count_p_or_l) + (-count_p_or_l-1) * 1.5
            ; if (Mod(count_p_or_l, -2)=0)
            ;     amount := default_amount + Floor(balance.current/1000)
            set_amount(amount)
            stats.loss++
        } else if (new_balance.current > balance.current + amount*1.2) {
            balance := new_balance
            if count_p_or_l < 0
                count_p_or_l := 0
            amount := get_amount(balance.current)
            set_amount(amount)
            count_p_or_l++
            stats.win++
        } else {
            balance := new_balance
            stats.draw++
        } 
    }

    datetime := A_NowUTC
    datetime := DateAdd(datetime, -5, 'h')
    date := FormatTime(datetime, 'MM/dd')
    time := FormatTime(datetime, 'hh:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
    if ps1 and ps2 {
        ToolTip('blue', outx1+100, outy1, 2)
        ToolTip('orange', outx2+100, outy2, 3)
        ToolTip('blue', outx1, outy1-200, 4)
        ToolTip('orange', outx2, outy2-200, 5)
        if ps3
            ToolTip('green', outx3+150, outy3, 6)
        if ps4
            ToolTip('red', outx4+150, outy4, 6)

        ToolTip(A_Sec '.' A_MSec ' ||Mod 14?|| ' Mod(A_Sec, 15), 1205, 5, 19)
        ps5 := PixelSearch(&outx5, &outy5, outx1+4, outy1+4, outx1+2, outy1-4, colors['green'], 5)
        ps6 := PixelSearch(&outx6, &outy6, outx2+4, outy2+4, outx1+2, outy1-4, colors['green'], 5)
        ps7 := PixelSearch(&outx7, &outy7, outx1+4, outy1+4, outx1+2, outy1-4, colors['red'], 5)
        ps8 := PixelSearch(&outx8, &outy8, outx2+4, outy2+4, outx1+2, outy1-4, colors['red'], 5)
        
        paused := check_paused()
        scenario1()
        if (Mod(A_Sec, 15) = 14 and A_MSec >= 100) {
            _timeframe := get_timeframe()
            if _timeframe != candle_colors[-1].time {
                _color := ps3 ? 'G' : ps4 ? 'R' : '?'
                candle_colors.InsertAt(1, {color: _color, timeframe: _timeframe})
                while candle_colors.Length > 5
                    candle_colors.Pop()
            }
            ToolTip(A_Sec '.' A_MSec ' ||MOD 14!!!!!!!!!!!!|| ' Mod(A_Sec, 15), 1205, 5, 19)
            if ((crossovers_arr.Length = 0 || crossovers_arr[-1].direction != 'BUY') and outy2 > outy1) {
                if last_trade=''
                    last_trade := 'BUY'
                crossovers_arr.Push({direction: 'BUY', time: A_TickCount})
            } else if ((crossovers_arr.Length = 0 || crossovers_arr[-1].direction != 'SELL') and outy2 < outy1) {
                if last_trade=''
                    last_trade := 'SELL'
                crossovers_arr.Push({direction: 'SELL', time: A_TickCount})
            }
            if crossovers_arr.Length > 10
                crossovers_arr.RemoveAt(1)
            coin_name := OCR.FromRect(coords['coin'][1] - 25, coords['coin'][2] - 25, 150, 50,, 3).Text
        }
    }

    update_log()
    sleep 100

    check_paused() {
        if (crossovers_arr.Length >= 2 and A_TickCount - crossovers_arr[-2].time <= 45000) {
            blockers['2cr'] := {state: true, tick_count: A_TickCount}
        }
        if blockers['2cr'].state and A_TickCount > blockers['2cr'].tick_count + 45000 {
            blockers['2cr'] := {state: false, tick_count: A_TickCount}
        }

        if (candle_colors[1].color = candle_colors[2].color and candle_colors[1].color = candle_colors [3].color) {
            blockers['3G3R'] := {state: false, tick_count: A_TickCount}
        } else {
            blockers['3G3R'] := {state: true, tick_count: A_TickCount}
        }

        for k, v in blockers {
            if v.state
                return true
        }
        return false
    }

    scenario1() {
        condition_buy  := outy2 > outy1 + 5 and ps5 and ps6 and crossovers_arr.Length >= 2 and crossovers_arr[-1].direction = 'BUY'  and A_TickCount < crossovers_arr[-1].time + 30000 and last_trade != crossovers_arr[-1].direction 
        condition_sell := outy1 > outy2 + 5 and ps7 and ps8 and crossovers_arr.Length >= 2 and crossovers_arr[-1].direction = 'SELL' and A_TickCount < crossovers_arr[-1].time + 30000 and last_trade != crossovers_arr[-1].direction 

        if paused
            return false
        if (condition_buy) {
            last_trade := 'BUY'
            trade_opened := [true, A_TickCount]
            main_sub1(last_trade)
        } else if (condition_sell) {
            last_trade := 'SELL'
            trade_opened := [true, A_TickCount]
            main_sub1(last_trade)
        }
    }
    scenario2() {
        condition_buy := ps5 
        condition_sell := ps7 

        if trade_opened[1] and paused
            return false
        if (ps3 and outy2 < outy1 and outy3 > outy2 and condition_buy) {
            trade_opened := [true, A_TickCount]
            last_trade := 'BUY'
            main_sub1(last_trade)
        } else if (ps4 and outy2 > outy1 and outy4 < outy2 and condition_sell) {
            trade_opened := [true, A_TickCount]
            last_trade := 'SELL'
            main_sub1(last_trade)
        }
    }
}

update_log() {
    global
    if trade_opened[1] {
        countdown_close := (trade_opened[2] + _time*1000 - A_TickCount)/1000
        countdown_close_str := ' (' format('{:.2f}', countdown_close) ')'
    } else {
        countdown_close_str := ''
    }
    
    debug_str := 'ps: ' ps1 ' ' ps2 ' | diff: ' (ps1 and ps2 ? outy2 - outy1 : 0) ' | '
    ; debug_str := 'G: ' (ps2 and ps3 ? outy3 - outy2 : 0) ' | R: ' (ps2 and ps4 ? outy2 - outy4 : 0) ' | ' debug_str
    _a := ps5 and ps6 ? '2lines: BUY' : ps7 and ps8 ? '2lines: SELL' : ''
    debug_str := _a ' | ' debug_str
    debug_str := crossovers_arr.Length > 0 ? 'last CO: ' crossovers_arr[-1].direction '(' Format('{:.1f}', (A_TickCount - crossovers_arr[-1].time)/1000) ')' ' | ' debug_str : debug_str
    _ := ''
    for val in candle_colors {
        if A_Index > 3 {
            _ := RTrim(_, '|')
            break
        }
        _ .= val.color '(' SubStr(val.timeframe, -2) ')|'
    }
    debug_str := _ ' | ' debug_str
    
    _pauser := ''
    for k, v in blockers {
        _pauser .= k ':' v.state '|'
    }
    paused_str := paused ? 'Paused (' _pauser ')' : '()'
    err := 0
    loop {
        try {
            file_size := FileGetSize(log_file)
            max_size := 5 * 1024 * 1024 ; 5 MB
            if file_size > max_size
                FileDelete(log_file)

            FileAppend(
                date ',' 
                time ',' 
                active_trade countdown_close_str ' | ' paused_str ',' 
                last_trade ',' 
                balance.current ' (' balance.min ' | ' balance.max ')' ',' 
                format('{:.2f}', amount) ',' 
                lose_streak.max '(' lose_streak.repeat ') | ' payout '%=' format('{:.2f}', amount*1.92) ' (' coin_name ')' ',' 
                count_p_or_l ' (' stats.win '|' stats.draw '|' stats.loss '|' win_rate '%)' ',' 
                debug_str '`n',
                log_file
            )
            if balance.current < 1 {
                MsgBox('0 Balance.')
                exitapp
            }
            break
        } catch as e {
            err++
            ToolTip('Appending new row. Errors: ' err '`n' e.Message, 500, 5, 12)
            sleep 100
            continue
        }
    }
}

main_sub1(action) {
    global
    if !WinActive(wtitle) {
        WinActivate(wtitle)
        sleep 100
    }
    sleep 50
    MouseClick('L', coords[action][1] + Random(-5, 5), coords[action][2] + Random(-5, 5), 1, 2)
    sleep 30
    while check_balance(balance).current = balance.current {
        ToolTip('Waiting balance change...', 500, 5, 12)
        sleep 50
        if (a_index>100) {
            last_trade := action
            ToolTip(,,, 12)
            return 
        }
    }
    ToolTip(,,, 12)
    balance := check_balance(balance)
    active_trade := action
}

reload_website() {
    if !WinActive(wtitle) {
        WinActivate(wtitle)  
        sleep 100
    }
    sleep 80
    Send('^r')
    sleep 5000
    check_balance(balance)
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

check_balance(balance) {
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
        cur_bal := StrReplace(match[], ',', '')
        balance.current := cur_bal
        if cur_bal < balance.min 
            balance.min := cur_bal
        if cur_bal > balance.max
            balance.max := cur_bal
        return balance
    }
}

$^Esc::ExitApp
$+Esc::Reload
$Esc::Pause -1