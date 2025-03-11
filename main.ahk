#Requires AutoHotkey v2.0
CoordMode('Mouse', 'Screen')
CoordMode('Pixel', 'Screen')
CoordMode('ToolTip', 'Screen')
SendMode('Event')
#Include OCR.ahk

settings_obj := Settings()
obj_trader := TraderBot(settings_obj)

Hotkey('F1', obj_trader.start_loop.Bind(), 'On')
ToolTip('Ready. Press F1 to start', 5, 5, 1)
return

class TraderBot {
    __New(settings_obj) {
        this.settings_obj := settings_obj
        this.wtitle := settings_obj.wtitle
        this.coords := settings_obj.coords
        this.colors := settings_obj.colors
        this.ps := Map()
        this.amount_arr := []
        this.amount_arr.Push([1,3,7,15,31,66,135,281,586,1223])
        this.amount_arr.Push([2, 6, 14, 30, 62, 132, 270, 562, 1172, 2000])
        Loop 10 {
            _index := A_Index
            if this.amount_arr.Length < A_Index
                this.amount_arr.Push([A_Index])
            while this.amount_arr[_index].Length < 20 {
                this.amount_arr[_index].Push(this.amount_arr[_index][-1]*2+1)
            }
        }
        this.start_time := A_TickCount
        this.log_file := 'log.csv'
        this.trade_opened := [false, A_TickCount]
        this.crossovers_arr := []
        this.last_trade := ''
        this.active_trade := ''
        this.countdown_close := 0
        this.countdown_close_str := ''
        this.win_rate := ''
        this.debug_str := ''
        this.balance := {current: 0, min: 999999999, max: 0}
        this.balance := this.check_balance(balance)
        this.candle_data := [{color: '?', colors: [], color_changes: ['?'], timeframe: Utils.get_timeframe()}]
        this.stats := {streak: 0, win: 0, loss: 0, draw: 0, reset_date: 0}
        this.lose_streak := {max: this.stats.streak, repeat: Map()}
        this.paused := false
        this.blockers := Map()
        this.amounts_tresholds := [[4350, 2], [3060, 1]]
        this.state := {coin_change_streak: false, 5loss: false}
        this.min_x := this.coords.area.x - 50
        this.amount := this.get_amount(balance.current)
        this._time := 15
        this._time += 2
        this.payout := 92
        this.datetime := A_Now
        this.stats.reset_date := SubStr(datetime, 1, -6)
        this.date := FormatTime(datetime, 'MM/dd')
        this.time := FormatTime(datetime, 'HH:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
        this.coin_name := OCR.FromRect(this.coords.coin.x - 15, this.coords.coin.y - 15, 130, 40).Text
        this.marked_time_refresh := A_TickCount

        if !FileExist(this.log_file) {
            FileAppend('date,time,active_trade,last_trade,balance,amount,payout,Streak (W|D|L|win_rate),Streaks,OHLC,debug`n', this.log_file)
        }
        MsgBox 'done'
    }

    start_loop(*) {
        ToolTip('Running...', 5, 5, 1)
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 500
        }
        this.set_amount(this.amount)
        MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,1,2)
        SetTimer(this.main, 100)
    }

    main() {
        if A_TickCount > marked_time_refresh + 2*60*60*1000 {
            marked_time_refresh := A_TickCount
            this.reload_website()
            ; reload
        }    
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)
            sleep 100
        }
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 1)
        sleep 100

        this.checker_payout()
        this.pixels_search()
        this.check_trade_closed()
        
        this.datetime := A_Now
        if this.stats.reset_date != SubStr(this.datetime, 1, -6) {
            this.stats.win := 0
            this.stats.loss := 0
            this.stats.draw := 0
            this.lose_streak := {max: 0, repeat: Map()}
        }
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
    
        ps_gtouchblue   := ''
        ps_gtouchorange := ''
        ps_rtouchblue   := ''
        ps_rtouchorange := ''
    
        if ps1 and ps2 {
            both_lines_detected()
        }
    
        update_log()
        sleep 100
    
    }
    
    check_paused() {
        key := '2cr'
        if not blockers.Has(key)
            blockers[key] := {state: false, tick_count: A_TickCount}
        if (crossovers_arr.Length >= 2 and A_TickCount - crossovers_arr[-2].time <= 30000) {
            blockers[key] := {state: true, tick_count: A_TickCount}
        }
        if blockers[key].state and A_TickCount > blockers[key].tick_count + 45000 {
            blockers[key] := {state: false, tick_count: A_TickCount}
        }

        ; key := 'not_3G3R'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if (candle_data.Length >=3 and candle_data[1].color = candle_data[2].color and candle_data[1].color = candle_data [3].color) {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else if candle_data.Length < 3 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; }

        key := 'GRRG'
        if not blockers.Has(key)
            blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=4 and this.candle_data[4].color = 'G' and this.candle_data[3].color = 'R' and this.candle_data[2].color = 'R' and this.candle_data[1].color = 'G') {
            blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            blockers[key] := {state: false, tick_count: A_TickCount}
        }

        key := 'RGGR'
        if not blockers.Has(key)
            blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=4 and this.candle_data[4].color = 'R' and this.candle_data[3].color = 'G' and this.candle_data[2].color = 'G' and this.candle_data[1].color = 'R') {
            blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            blockers[key] := {state: false, tick_count: A_TickCount}
        }

        key := 'GRG'
        if not blockers.Has(key)
            blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=3 and this.candle_data[3].color = 'G' and this.candle_data[2].color = 'R' and this.candle_data[1].color = 'G') {
            blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            blockers[key] := {state: false, tick_count: A_TickCount}
        }

        key := 'RGR'
        if not blockers.Has(key)
            blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=3 and this.candle_data[3].color = 'R' and this.candle_data[2].color = 'G' and this.candle_data[1].color = 'R') {
            blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            blockers[key] := {state: false, tick_count: A_TickCount}
        }

        ; key := '3sCc'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if not Utils.is_all_same(candle_data[1].colors) {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and A_TickCount > blockers[key].tick_count + 15000 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := '2px'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if ps1 and ps2 and Abs(outy2 - outy1) <= 2 {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and A_TickCount > blockers[key].tick_count + 45000 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'candle_engulfed'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data.Length >= 3 and candle_data[2].H > candle_data[3].H and candle_data[2].L < candle_data[3].L {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and A_TickCount > blockers[key].tick_count + 15000 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := '2candle_diff'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data.Length >= 3 and candle_data[2].color != candle_data[3].color and outy2 < min(candle_data[1].H, candle_data[1].L) and outy1 > max(candle_data[1].H, candle_data[1].L) {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and A_TickCount > blockers[key].tick_count + 30000 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'small_body'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data.Length >= 3 and abs(candle_data[3].O - candle_data[3].C)/abs(candle_data[3].H - candle_data[3].L) <= 0.1 and abs(candle_data[2].O - candle_data[2].C)/abs(candle_data[2].H - candle_data[2].L) <= 0.1 {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and A_TickCount > blockers[key].tick_count + 15000 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; if this.state.5loss and this.stats.streak != -5
        ;     this.state.5loss := false

        ; key := '5losses'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if this.stats.streak = -5 and not this.state.5loss {
        ;     this.state.5loss := true
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and this.candle_data.Length >= 3 and this.candle_data[2].color = this.candle_data[3].color and this.candle_data[1].color = this.candle_data[4].color {
        ;     this.state.5loss := true
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'color_ch3'
        ; if not blockers.Has(key)
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data[1].color_changes.Length > 3 {
        ;     blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if blockers[key].state and A_TickCount > blockers[key].tick_count + 45000 {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        for k, v in blockers {
            if v.state
                return true
        }
        return false
    }
    scenario1() {
        if this.stats.streak <= -4 {
            _pheight := 4
        } else {
            _pheight := 4
        }
        condition_buy  := outy2 > outy1 + _pheight and ps_gtouchblue and ps_gtouchorange and crossovers_arr.Length >= 2 and last_trade != 'BUY'  and not trade_opened[1]
        condition_sell := outy1 > outy2 + _pheight and ps_rtouchblue and ps_rtouchorange and crossovers_arr.Length >= 2 and last_trade != 'SELL' and not trade_opened[1]

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
    scenario3() {
        condition_buy  := psGc and outyc < outy1 - 1 and Mod(A_Sec, 15) >= 12 and this.candle_data.Length >=4 and this.candle_data[4] = 'R' and this.candle_data[3] = 'R' and this.candle_data[2] = 'R' and this.candle_data[1] = 'G' and not trade_opened[1]
        condition_sell := psRc and outyc > outy1 + 1 and Mod(A_Sec, 15) >= 12 and this.candle_data.Length >=4 and this.candle_data[4] = 'G' and this.candle_data[3] = 'G' and this.candle_data[2] = 'G' and this.candle_data[1] = 'R' and not trade_opened[1]

        if paused
            return false
        if (condition_buy) {
            ; last_trade := 'BUY'
            trade_opened := [true, A_TickCount]
            main_sub1(last_trade)
        } else if (condition_sell) {
            ; last_trade := 'SELL'
            trade_opened := [true, A_TickCount]
            main_sub1(last_trade)
        }
    }
    scenario2() {
        condition_buy := ps_gtouchblue 
        condition_sell := ps_rtouchblue 

        if trade_opened[1] and paused
            return false
        if (psGc and outy2 < outy1 and outyc > outy2 and condition_buy) {
            trade_opened := [true, A_TickCount]
            last_trade := 'BUY'
            main_sub1(last_trade)
        } else if (psRc and outy2 > outy1 and outyc < outy2 and condition_sell) {
            trade_opened := [true, A_TickCount]
            last_trade := 'SELL'
            main_sub1(last_trade)
        }
    }

    checker_payout() {
        coin_change_streak := -4
        Loop {
            if not this.state.coin_change_streak and this.stats.streak != coin_change_streak
                this.state.coin_change_streak := true

            if (this.stats.streak != coin_change_streak or not this.state.coin_change_streak) and ImageSearch(&outx, &outy, this.coords.Payout.x, this.coords.Payout.y, this.coords.Payout.x+this.coords.Payout.w, this.coords.Payout.y+this.coords.Payout.h, '*10 payout.png') {
                payout := 92
                break
            } else {
                if this.state.coin_change_streak and this.stats.streak = coin_change_streak
                    this.state.coin_change_streak := false
                Loop 19 {
                    ToolTip(,,,A_Index+1)
                }
                last_trade := ''
                ToolTip('Waiting for payout to be 92 or higher...', 500, 5, 12)
                MouseClick('L', this.coords.coin.x + Random(-2, 2), this.coords.coin.y + Random(-2, 2), 1, 2)
                sleep 300
                MouseClick('L', this.coords.cryptocurrencies.x + Random(-2, 2), this.coords.cryptocurrencies.y + Random(-2, 2), 1, 2)
                sleep 300
                if this.stats.streak = coin_change_streak
                    MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(-2, 2), 1, 2)
                else
                    MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(1, 2)*28, 1, 2)
                sleep 500
                Send '{Escape}'
                sleep 1000

            }
        }
    }
    check_trade_closed() {
        if (trade_opened[1] and countdown_close < 0) {
            active_trade := ''
            trade_opened[1] := false
            new_balance := this.check_balance(balance)
            if (new_balance.current <= balance.current + 0.5) {
                balance := new_balance
                if this.stats.streak > 0
                    this.stats.streak := 0
                this.stats.streak--
                if (this.stats.streak = lose_streak.max)
                    lose_streak.repeat[this.stats.streak]++
                else if (this.stats.streak < lose_streak.max) {
                    lose_streak.max := this.stats.streak
                    lose_streak.repeat[this.stats.streak] := 1
                } else {
                    lose_streak.repeat[this.stats.streak]++
                }
                this.amount := this.amount_arr[this.get_amount(balance.current+this.amount*2.2)][-this.stats.streak+1] ; (default_amount + Floor(balance.current/1000)) * (-stats.streak) + (-stats.streak-1) * 1.5
                ; if (Mod(stats.streak, -2)=0)
                ;     amount := default_amount + Floor(balance.current/1000)
                this.set_amount(this.amount)
                this.stats.loss++
            } else if (new_balance.current > balance.current + this.amount*1.2) {
                balance := new_balance
                if this.stats.streak < 0
                    this.stats.streak := 0
                this.amount := this.get_amount(balance.current)
                this.set_amount(this.amount)
                this.stats.streak++
                this.stats.win++
            } else {
                balance := new_balance
                this.stats.draw++
            } 
        }
    }
    both_lines_detected() {
        ToolTip('blue', outx1-200, outy1, 2)
        ToolTip('orange', outx2-200, outy2, 3)
        ToolTip('blue', outx1, outy1-200, 4)
        ToolTip('orange', outx2, outy2-200, 5)
        if psGc
            ToolTip('CLOSE-green', outxc-250, outyc, 6)
        if psRc
            ToolTip('CLOSE-red', outxc-250, outyc, 6)
        if this.candle_data[1].HasOwnProp('O') and this.candle_data[1].HasOwnProp('H') and this.candle_data[1].HasOwnProp('L') and this.candle_data[1].HasOwnProp('C') {
            if this.candle_data[1].O
                ToolTip('OPEN', outx1-250, this.candle_data[1].O, 7)
            ToolTip('HIGH', outx1-200, this.candle_data[1].H, 8)
            ToolTip('LOW ', outx1-200, this.candle_data[1].L, 9)
        }

        ToolTip(A_Sec '.' A_MSec ' ||Mod 14?|| ' Mod(A_Sec, 15), 1205, 5, 19)
        ps_gtouchblue := PixelSearch(&outx5, &outy5, outx1+4, outy1+4, outx1+2, outy1-4, this.colors.green, 5)
        ps_gtouchorange := PixelSearch(&outx6, &outy6, outx2+4, outy2+4, outx2+2, outy2-4, this.colors.green, 5)
        ps_rtouchblue := PixelSearch(&outx7, &outy7, outx1+4, outy1+4, outx1+2, outy1-4, this.colors.red, 5)
        ps_rtouchorange := PixelSearch(&outx8, &outy8, outx2+4, outy2+4, outx2+2, outy2-4, this.colors.red, 5)

        _color := psGc ? 'G' : psRc ? 'R' : '?'    
        if Mod(A_Sec, 15) >= 12 {
            this.candle_data[1].colors.Push(_color)
        }
        if _color != this.candle_data[1].color_changes[-1]
            this.candle_data[1].color_changes.Push(_color)

        if (Mod(A_Sec, 15) = 14 and A_MSec >= 100) {
            _timeframe := Utils.get_timeframe()
            if _timeframe != this.candle_data[1].timeframe and (psGc or psRc) {
                this.candle_data.InsertAt(1, {color: _color, timeframe: _timeframe, colors: [_color], color_changes: [_color], H: this.candle_data[1].C, L: this.candle_data[1].C})
                while this.candle_data.Length > 5
                    this.candle_data.Pop()
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
            try 
                coin_name := OCR.FromRect(this.coords.coin.x - 25, this.coords.coin.y - 25, 150, 50,, 3).Text
            catch  
                coin_name := '???'
        }
        paused := check_paused()
        scenario1()
        scenario3()
    }
    update_log() {
        global

        str_ohlc := ''
            
        str_ohlc .= this.candle_data[1].HasOwnProp('O') ? this.candle_data[1].O ' | ' : '? | '
        str_ohlc .= this.candle_data[1].HasOwnProp('H') ? this.candle_data[1].H ' | ' : '? | '
        str_ohlc .= this.candle_data[1].HasOwnProp('L') ? this.candle_data[1].L ' | ' : '? | '
        str_ohlc .= this.candle_data[1].HasOwnProp('C') ? this.candle_data[1].C ' | ' : '? | '

        date := FormatTime(datetime, 'MM/dd')
        time := FormatTime(datetime, 'hh:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
        if trade_opened[1] {
            countdown_close := (trade_opened[2] + _time*1000 - A_TickCount)/1000
            countdown_close_str := ' (' format('{:.2f}', countdown_close) ')'
        } else {
            countdown_close_str := ''
        }
    
        streaks_str := ''
        if lose_streak.repeat.Count > 0
            lose_streak_str := lose_streak.max '(' lose_streak.repeat[lose_streak.max] ')'
        else
            lose_streak_str := 0 '(' 0 ')'
        for k, v in lose_streak.repeat {
            streaks_str .= k '[' v '] '
        }
        
        debug_str := 'ps: ' ps1 ' ' ps2 ' | diff: ' (ps1 and ps2 ? outy2 - outy1 : 0) ' | '
        ; debug_str := 'G: ' (ps2 and psGc ? outyc - outy2 : 0) ' | R: ' (ps2 and psRc ? outy2 - outyc : 0) ' | ' debug_str
        _a := ps_gtouchblue and ps_gtouchorange ? '2lines: BUY' : ps_rtouchblue and ps_rtouchorange ? '2lines: SELL' : ''
        debug_str := _a ' | ' debug_str
        debug_str := crossovers_arr.Length > 0 ? 'last CO: ' crossovers_arr[-1].direction '(' Format('{:.1f}', (A_TickCount - crossovers_arr[-1].time)/1000) ')' ' | ' debug_str : debug_str
        _ := ''
        for val in this.candle_data {
            if A_Index > 3 {
                _ := RTrim(_, '|')
                break
            }
            _ .= val.color '(' SubStr(val.timeframe, -2) ')|'
        }
        debug_str := _ ' | ' debug_str
        
        _pauser := ''
        for k, v in blockers {
            if v.state
                _pauser .= k ':' v.state '|'
        }
        paused_str := paused ? 'Paused (' _pauser ')' : '()'
        err := 0
        win_rate := this.stats.win > 0 ? this.stats.win/(this.stats.win+this.stats.loss+this.stats.draw)*100 : 0
        win_rate := Format('{:.1f}', win_rate)
    
        loop {
            try {
                file_size := FileGetSize(this.log_file)
                max_size := 5 * 1024 * 1024 ; 5 MB
                if file_size > max_size
                    FileDelete(this.log_file)
    
                FileAppend(
                    date ',' 
                    time ',' 
                    active_trade countdown_close_str ' | ' paused_str ',' 
                    format('{:.2f}', this.amount) ',' 
                    balance.current ' (' balance.max ' | ' balance.min ')' ',' 
                    last_trade ',' 
                    ' | ' payout '%=' format('{:.2f}', this.amount*1.92) ' (' coin_name ')' ',' 
                    this.stats.streak ' (' this.stats.win '|' this.stats.draw '|' this.stats.loss '|' win_rate '%)' ',' 
                    streaks_str ',' 
                    str_ohlc ',' 
                    debug_str '`n',
                    this.log_file
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
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)
            sleep 100
        }
        sleep 50
        MouseClick('L', this.coords[action][1] + Random(-5, 5), this.coords[action][2] + Random(-5, 5), 1, 2)
        sleep 500
        while this.check_balance(balance).current = balance.current {
            ToolTip('Waiting balance change...', 500, 5, 12)
            sleep 50
            if (a_index>100) {
                last_trade := action
                ToolTip(,,, 12)
                return 
            }
        }
        ToolTip(,,, 12)
        balance := this.check_balance(balance)
        active_trade := action
    }     

    pixels_search() {
        this.ps.red := false
        try
            this.ps.blue := PixelSearch(&outx1, &outy1, this.coords.area.x, this.coords.area.y, this.coords.area.x2, this.coords.area.y2, this.colors.blue, 5)
        catch as e {
            ToolTip('Error: PixelSearch failed`n' e.Message, 500, 5, 15)
            this.coords.area.x := max(this.coords.area.x - 1, 100)
            this.coords.area.x2 := this.coords.area.x - 2
            ToolTip(,,, 15)
            return
        }
        psGc := ''
        psRc := ''
        if this.ps.blue {
            this.ps.red := PixelSearch(&outx2, &outy2, outx1+1, this.coords.area.y, outx1-1, this.coords.area.y2, this.colors.orange, 5)
            psGc := PixelSearch(&outxc, &outyc, outx1+4, this.coords.area.y, outx1+1, this.coords.area.y2, this.colors.green, 5)
            if not psGc
                psRc := PixelSearch(&outxc, &outyc, outx1+4, this.coords.area.y2, outx1+1, this.coords.area.y, this.colors.red, 5)
            if psGc {
                Loop {
                    pso := PixelSearch(&outxo, &outyo, outx1+4, this.coords.area.y2, outx1+1, this.coords.area.y, this.colors.green, 15)
                    if pso
                        break
                }
            } else if psRc {
                Loop {
                    pso := PixelSearch(&outxo, &outyo, outx1+4, this.coords.area.y, outx1+1, this.coords.area.y2, this.colors.red, 15)
                    if pso
                        break
                }
            }
            if psGc or psRc {
                this.candle_data[1].O := outyo
                this.candle_data[1].C := outyc
                this.candle_data[1].H := this.candle_data[1].HasOwnProp('H') ? min(outyc, this.candle_data[1].H, this.candle_data[1].O) : psGc ? outyc : outyo
                this.candle_data[1].L := this.candle_data[1].HasOwnProp('L') ? max(outyc, this.candle_data[1].L, this.candle_data[1].O) : psRc ? outyc : outyo
                if outyc and outyo
                    this.candle_data[1].size := Abs(outyc - outyo)
            }

            this.coords.area.x := min(this.coords.area.x + 1, A_ScreenWidth*0.95)
            this.coords.area.x2 := this.coords.area.x - 2
            ToolTip('(' A_Sec '.' A_MSec ')' debug_str '`nCurrent last_trade: ' last_trade '`nCurrent balance: ' format('{:.2f}', balance.current), 5, 5, 11)
        } else {
            this.coords.area.x := max(this.coords.area.x - 1, 100)
            if this.coords.area.x < this.min_x {
                this.coords.area.x := this.min_x
                this.reload_website()
            }
            this.coords.area.x2 := this.coords.area.x - 2
            ; debug_str := 'ps: ' ps1 ' ' ps2 ' | diff: ' (ps1 and ps2 ? outy2 - outy1 : 0) ' | '
            ; ToolTip('(' A_Sec '.' A_MSec ')' debug_str '`nCurrent last_trade: ' last_trade '`nCurrent balance: ' format('{:.2f}', balance.current), 5, 5, 11)
            return
        }
        ToolTip(,,, 12)
    }

    get_amount(val) {
        for tresh in this.amounts_tresholds {
            if val >= tresh[1]
                return tresh[2]
            return 1
        }
    }

    reload_website() {
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 100
        }
        sleep 80
        Send('^r')
        sleep 5000
        this.check_balance(balance)
        sleep 2000
        return
    }
    
    set_amount(amount) {
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
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
    
    check_balance(_balance) {
        Loop {
            A_Clipboard := ''
            if !WinActive(this.wtitle) {
                WinActivate(this.wtitle)  
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
            _balnew := {current: cur_bal, max: Format('{:.2f}', max(cur_bal, _balance.max)), min: Format('{:.2f}', min(cur_bal, _balance.min))}
            return _balnew
        }
    }
}

class Settings {
    __New() {
        this.settings_file := 'settings.ini'
        this.wtitle := IniRead(this.settings_file, 'General', 'wtitle')
        this.coords := this.read_settings(['area', 'BUY', 'SELL', 'Payout', 'coin', 'cryptocurrencies', 'stocks', 'coin_top', 'empty_area'], 'coords')
        this.colors := this.read_settings(['blue', 'orange', 'green', 'red'], 'colors')
    }

    read_settings(arr, section) {
        _map := Map()
        for v in arr {
            if section != 'coords' {
                _map.%v% := IniRead(this.settings_file, section, v)
                continue
            }
            _split := StrSplit(IniRead(this.settings_file, section, v), ',', ' ')
            _map.%v% := {x: _split[1], y: _split[2]}
            if _split.Length = 4 {
                _map.%v%.w := _split[3]
                _map.%v%.h := _split[4]
                _map.%v%.x2 := _split[3]
                _map.%v%.y2 := _split[4]
            }
        }
        return _map
    }
}

class Utils {
    static is_all_same(arr) {
        for i, v in arr
            if (v != arr[1])  ; Compare each value with the first element
                return false
        return true
    }
    
    static get_timeframe(interval := 15) {
        datetime := A_Now
        ; datetime := DateAdd(A_NowUTC, -5, 'h')
        seconds := SubStr(datetime, -2)
        rounded_seconds := Floor(seconds / interval) * interval
        rounded_time := SubStr(datetime, 1, -2) Format("{:02}", rounded_seconds)
        return rounded_time
    }    
}

$^Esc::ExitApp
$+Esc::Reload
$Esc::Pause -1