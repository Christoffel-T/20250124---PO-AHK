#Requires AutoHotkey v2.0
#Include OCR.ahk
#Include utils.ahk

class TraderBot {
    __New(settings_obj) {
        this.settings_obj := settings_obj
        this.wtitle := WinExist(settings_obj.wtitle)
        this.coords := settings_obj.coords
        this.colors := settings_obj.colors
        this.ps := Map()
        this.amount_arr := []
        ; this.amounts_tresholds := [[20000, 3],[4350, 2], [0, 1]]
        this.amounts_tresholds := [[0, 1]]
        this.qualifiers := {}
        this.qualifiers.streak_sc := -4000

        Loop 10 {
            _index := A_Index
            if this.amount_arr.Length < A_Index
                this.amount_arr.Push([A_Index])
            while this.amount_arr[_index].Length < 20 {
                total := 0
                ; for v in this.amount_arr[_index] {
                ;     total += v
                ; }
                ; val := min(20000, Ceil(total/0.92)+_index)
                val := min(20000, Floor(this.amount_arr[_index][-1]*2.1)+_index)
                this.amount_arr[_index].Push(val)
            }
            _tresh := A_Index = 1 ? this.amount_arr[_index][9]*10 : this.amount_arr[_index][10]*10
            this.amounts_tresholds.InsertAt(1, [_tresh, _index+1])
        }
        this.start_time := A_TickCount
        this.log_file := 'log.csv'
        this.trade_opened := [false, A_TickCount]
        this.crossovers_arr := []
        this.last_trade := ''
        this.active_trade := ''
        this.executed_trades := [['', '']]
        this.countdown_close := 0
        this.countdown_close_str := ''
        this.win_rate := ''
        this.debug_str := ''
        this.stats := {bal_win: 0, bal_lose: 0, streak: 0, streak2: 0, win: 0, loss: 0, draw: 0, reset_date: 0}
        this.balance := {starting: 750, reset_max: 1500, current: 0, min: 999999999, max: 0, last_trade: 0}
        this.candle_data := [{both_lines_touch: false, blue_line_y: [], color: '?', colors: [], colors_12: [], color_changes: ['?'], timeframe: Utils.get_timeframe(), moving_prices: [0]}]
        
        this.lose_streak := {max: this.stats.streak, repeat: Map(), end_by_win_count: 0}
        this.paused := false
        this.blockers := Map()
        this.state := {coin_change_streak: false, 5loss: false, 32:false}
        this.min_x := this.coords.area.x - 50
        this.amount := this.GetAmount(this.balance.current)
        this._time := 15
        this._time += 4
        this.payout := 92
        this.datetime := A_Now
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
        this.coin_name := OCR.FromRect(this.coords.coin.x - 15, this.coords.coin.y - 15, 130, 40).Text
        this.marked_time_refresh := A_TickCount

        this.pause_based_on_timeframe := ''

        if !FileExist(this.log_file) {
            FileAppend('date,time,active_trade,next_target,last_trade,balance,amount,payout,Streak (W|D|L|win_rate),Streaks,OHLC,debug`n', this.log_file)
        }
    } 

    StartLoop(*) {
        ToolTip('Running...', 5, 5, 1)
        this.ReloadWebsite()
        this.CheckBalance()
        
        if this.balance.current != this.balance.starting {
            if this.balance.current < this.balance.starting {
                this.AddBalance(this.balance.starting-this.balance.current)
            }
            sleep 2000
            this.CheckBalance()
        }

        this.SetTradeAmount()
        sleep 100
        MouseClick('L', this.coords.time1.x + Random(-2, 2), this.coords.time1.y + Random(-2, 2), 1, 2)
        sleep 100
        MouseClick('L', this.coords.time_choice.x + Random(-2, 2), this.coords.time_choice.y + Random(-2, 2), 1, 2)
        sleep 100
        MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,1,2)
        sleep 100
        this.CheckPayout(true)
        SetTimer(this.Main.Bind(this), 100)
    }

    Main() {
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)
            sleep 100
        }
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 1)
        sleep 100

        this.CheckBalance()
        this.CheckPayout()
        if not this.PSearch()
            return
        this.CheckTradeClosed()
        
        this.datetime := A_Now
        if this.stats.reset_date != SubStr(this.datetime, 1, -6) {
            this.stats.win := 0
            this.stats.loss := 0
            this.stats.draw := 0
            this.lose_streak := {max: 0, repeat: Map(), end_by_win_count: 0}
        }
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
        
        if this.ps.blue.state and this.ps.orange.state {
            this.BothLinesDetected()
            this.RunScenarios()
        }
    
        this.UpdateLog()
        sleep 100
    
    }
    
    CheckPaused() {

        ; key := 'pause-3'

        ; _bottom := 0
        ; _top := 99999999

        ; if this.candle_data.Length >= 2 {
        ;     for v in this.candle_data[2].blue_line_y {
        ;         _bottom := max(_bottom, v)
        ;         _top := min(_top, v)
        ;     }
        ; }

        ; if this.stats.streak <= -3 and Mod(A_Sec, 15) >= 1 and Mod(A_Sec, 15) <= 3
        ; and (this.ps.blue.y > _top and this.candle_data[1].color = 'G' or this.ps.blue.y < _top and this.candle_data[1].color = 'R')
        ;     this.pause_based_on_timeframe := Utils.get_timeframe(15,0)

        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if this.pause_based_on_timeframe = this.candle_data[1].timeframe {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'PAUSE_blue_touch_top/bottom'

        ; if (this.ps.blue.y >= this.candle_data[1].O - 10 and this.ps.blue.y <= this.candle_data[1].O + 10)
        ; or (this.ps.blue.y >= this.candle_data[1].C - 10 and this.ps.blue.y <= this.candle_data[1].C + 10)
        ;     this.pause_based_on_timeframe := Utils.get_timeframe(15,0)

        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if this.pause_based_on_timeframe = this.candle_data[1].timeframe {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }
        ; if this.blockers[key].state and 

        ; key := 'PAUSE'
        ; pause_buy  := Mod(A_Sec, 15) >= 13 and this.ps.moving_price.y > this.candle_data[1].O - (this.candle_data[1].size/2) and this.candle_data[1].color = 'G'
        ; pause_sell := Mod(A_Sec, 15) >= 13 and this.ps.moving_price.y < this.candle_data[1].O + (this.candle_data[1].size/2) and this.candle_data[1].color = 'R'

        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if this.candle_data.Length >= 2 and pause_buy or pause_sell {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; }
        ; if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 15000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := '2cr'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if (this.crossovers_arr.Length >= 2 and A_TickCount - this.crossovers_arr[-2].time <= 30000) {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; }
        ; if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 45000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'not_3G3R'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and (candle_data.Length >=3 and candle_data[1].color = candle_data[2].color and candle_data[1].color = candle_data [3].color) {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else if candle_data.Length < 3 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; }

        ; key := 'GRRG'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and (this.candle_data.Length >=4 and this.candle_data[4].color = 'G' and this.candle_data[3].color = 'R' and this.candle_data[2].color = 'R' and this.candle_data[1].color = 'G') {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'RGGR'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and (this.candle_data.Length >=4 and this.candle_data[4].color = 'R' and this.candle_data[3].color = 'G' and this.candle_data[2].color = 'G' and this.candle_data[1].color = 'R') {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'GRG'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and (this.candle_data.Length >=3 and this.candle_data[3].color = 'G' and this.candle_data[2].color = 'R' and this.candle_data[1].color = 'G') {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'RGR'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and (this.candle_data.Length >=3 and this.candle_data[3].color = 'R' and this.candle_data[2].color = 'G' and this.candle_data[1].color = 'R') {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := '3sCc'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if not Utils.is_all_same(candle_data[1].colors_12) {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 15000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := '2px'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if this.ps.blue.state and this.ps.orange.state and Abs(this.ps.orange.y - this.ps.blue.y) <= 2 {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 45000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'candle_engulfed'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data.Length >= 3 and candle_data[2].H > candle_data[3].H and candle_data[2].L < candle_data[3].L {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 15000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := '2candle_diff'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and candle_data.Length >= 3 and candle_data[2].color != candle_data[3].color and this.ps.orange.y < min(candle_data[1].H, candle_data[1].L) and this.ps.blue.y > max(candle_data[1].H, candle_data[1].L) {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 30000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'small_body'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if Mod(A_Sec, 15) >= 13 and candle_data.Length >= 3 and abs(candle_data[3].O - candle_data[3].C)/abs(candle_data[3].H - candle_data[3].L) <= 0.1 and abs(candle_data[2].O - candle_data[2].C)/abs(candle_data[2].H - candle_data[2].L) <= 0.1 {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 15000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        
        ; key := '4losses'
        ; coin_change_streak := -4
        ; if this.state.5loss and this.stats.streak != coin_change_streak
        ;     this.state.5loss := false
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if this.stats.streak = coin_change_streak and not this.state.5loss {
        ;     this.state.5loss := true
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if Mod(A_Sec, 15) >= 13 and this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 45000 and this.candle_data.Length >= 4 and this.candle_data[1].color = this.candle_data[2].color and this.candle_data[2].color = this.candle_data[3].color and this.candle_data[3].color = this.candle_data[4].color {
        ;     this.state.5loss := true
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'color_ch3'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data[1].color_changes.Length > 3 {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 45000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        for k, v in this.blockers {
            if v.state
                return true
        }
        return false
    }
    Scenario1() {
        if this.paused or this.candle_data.Length < 2
            return false
        bad_condition := false
        ; try
        ;     bad_condition := this.candle_data[2].color = 'R' and this.ps.blue.y < this.candle_data[2].blue_line_y[-1] or this.candle_data[2].color = 'G' and this.ps.blue.y > this.candle_data[2].blue_line_y[-1]
        _pheight := 20
        _candle_size := 20
        condition_both := Mod(A_Sec-1, 15) <= 2 and this.crossovers_arr.Length >= 2 and not this.trade_opened[1] and this.candle_data[2].size >= _candle_size
        ; if this.stats.streak <= -3
        ;     condition_both := condition_both and Mod(A_Sec-1, 15) >= 1 and Mod(A_Sec-1, 15) <= 3
        if condition_both and this.ps.orange.y > this.ps.blue.y + _pheight and this.candle_data[2].both_lines_touch and condition_both
            this.qualifiers.sc1B := {state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[-1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}
        if condition_both and this.ps.blue.y > this.ps.orange.y + _pheight and this.candle_data[2].both_lines_touch and condition_both
            this.qualifiers.sc1S := {state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[-1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}
        
        condition_buy := false
        condition_sell := false
        
        if this.qualifiers.HasOwnProp('sc1B') {
            if this.qualifiers.sc1B.state = 1 and A_Now > this.qualifiers.sc1B.timeframe + 15 {
                this.qualifiers.sc1B.state := false
            } else if this.qualifiers.sc1B.state = 1 and A_TickCount > this.qualifiers.sc1B.time + 3000 {
                this.qualifiers.sc1B.state := false
            } 

            if this.qualifiers.sc1B.state = 1 {
                condition_buy := true
            } 
        }
        if this.qualifiers.HasOwnProp('sc1S') {
            if this.qualifiers.sc1S.state = 1 and A_Now > this.qualifiers.sc1S.timeframe + 15 {
                this.qualifiers.sc1S.state := false
            } else if this.qualifiers.sc1S.state = 1 and A_TickCount > this.qualifiers.sc1S.time + 3000 {
                this.qualifiers.sc1S.state := false
            } 

            if this.qualifiers.sc1S.state = 1 {
                condition_sell := true
            } 
        }

        if (condition_buy and this.candle_data[1].color = 'G') {
            try
                this.qualifiers.sc1B.state := false
            this.last_trade := 'BUY'
            this.ExecuteTrade('BUY', '1')
        } else if (condition_sell and this.candle_data[1].color = 'R') {
            try 
                this.qualifiers.sc1S.state := false
            this.last_trade := 'SELL'
            this.ExecuteTrade('SELL', '1')
        }
    }

    Scenario2() {
        if this.paused or this.candle_data.Length < 2
            return false
        bad_condition := false
        ; try
        ;     bad_condition := this.candle_data[2].color = 'R' and this.ps.blue.y < this.candle_data[2].blue_line_y[-1] or this.candle_data[2].color = 'G' and this.ps.blue.y > this.candle_data[2].blue_line_y[-1]
        _pheight := 20
        _candle_size := 20
        condition_both := Mod(A_Sec-1, 15) >= 13 and this.crossovers_arr.Length >= 2 and not this.trade_opened[1] and this.candle_data[2].size >= _candle_size
        
        condition_buy  := this.candle_data[2].color = 'G' and this.candle_data[1].moving_prices[-1] < this.candle_data[1].C and this.candle_data[1].C < this.candle_data[2].C
        condition_sell := this.candle_data[2].color = 'R' and this.candle_data[1].moving_prices[-1] > this.candle_data[1].C and this.candle_data[1].C > this.candle_data[2].C

        if condition_both and condition_buy  and this.ps.orange.y > this.ps.blue.y + _pheight and this.candle_data[2].both_lines_touch
            this.qualifiers.sc2B := {timeframe: Utils.get_timeframe(), state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[-1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}
        if condition_both and condition_sell and this.ps.blue.y > this.ps.orange.y + _pheight and this.candle_data[2].both_lines_touch
            this.qualifiers.sc2S := {timeframe: Utils.get_timeframe(), state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[-1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}

        condition_buy := false
        condition_sell := false
        
        if this.qualifiers.HasOwnProp('sc2B') {
            if this.qualifiers.sc2B.state = 1 and A_Now > this.qualifiers.sc2B.timeframe + 30 {
                this.qualifiers.sc2B.state := false
            } else if this.qualifiers.sc2B.state = 1 and A_TickCount > this.qualifiers.sc2B.time + 3000 {
                this.qualifiers.sc2B.state := false
            } 
            if this.qualifiers.sc2B.state = 1 {
                condition_buy := true
            } 
        }
        if this.qualifiers.HasOwnProp('sc2S') {
            if this.qualifiers.sc2S.state = 1 and A_Now > this.qualifiers.sc2S.timeframe + 30 {
                this.qualifiers.sc2S.state := false
            } else if this.qualifiers.sc2S.state = 1 and A_TickCount > this.qualifiers.sc2S.time + 3000 {
                this.qualifiers.sc2S.state := false
            } 
            if this.qualifiers.sc2S.state = 1 {
                condition_sell := true
            } 
        }

        if (condition_buy and this.candle_data[1].color = 'G') {
            this.qualifiers.sc2B.state := false
            this.last_trade := 'BUY'
            this.ExecuteTrade('BUY', '2')
        } else if (condition_sell and this.candle_data[1].color = 'R') {
            this.qualifiers.sc2S.state := false
            this.last_trade := 'SELL'
            this.ExecuteTrade('SELL', '2')
        }
    }
    Scenario3() {
        if this.paused or this.candle_data.Length < 2 or this.trade_opened[1] 
            return false

        condition_both := Mod(A_Sec-1, 15) >= 12
        
        if condition_both and this.candle_data[1].color = 'R' and this.candle_data[1].moving_prices[-1] < this.candle_data[1].O 
            this.qualifiers.sc3B := {state: true, price_line: this.candle_data[1].moving_prices[-1], timeframe: Utils.get_timeframe()}
        if condition_both and this.candle_data[1].color = 'G' and this.candle_data[1].moving_prices[-1] > this.candle_data[1].O
            this.qualifiers.sc3S := {state: true, price_line: this.candle_data[1].moving_prices[-1], timeframe: Utils.get_timeframe()}

        condition_buy  := this.qualifiers.HasOwnProp('sc3B') and this.qualifiers.sc3B.state
        condition_sell := this.qualifiers.HasOwnProp('sc3S') and this.qualifiers.sc3S.state

        for v in ['sc3B', 'sc3S'] {
            if this.qualifiers.HasOwnProp(v) and this.qualifiers.%v%.state and Utils.get_timeframe() != this.qualifiers.%v%.timeframe
                this.qualifiers.%v%.state := false
        }

        if (condition_buy) {
            this.qualifiers.sc3B.state := false
            this.ExecuteTrade('BUY', '3')
        } else if (condition_sell) {
            this.qualifiers.sc3S.state := false
            this.ExecuteTrade('SELL', '3')
        }
    }

    Scenario3a() {
        if this.paused or this.candle_data.Length < 2 or this.trade_opened[1] 
            return false

        condition_both := Mod(A_Sec-1, 15) >= 14
        
        if condition_both and this.candle_data[1].color = 'R' and this.candle_data[1].moving_prices[-1] < this.candle_data[1].O 
            this.qualifiers.sc3aB := {state: true, price_line: this.candle_data[1].moving_prices[-1], timeframe: Utils.get_timeframe()+15}
        if condition_both and this.candle_data[1].color = 'G' and this.candle_data[1].moving_prices[-1] > this.candle_data[1].O
            this.qualifiers.sc3aS := {state: true, price_line: this.candle_data[1].moving_prices[-1], timeframe: Utils.get_timeframe()+15}

        condition_buy  := this.candle_data[1].color = 'G' and this.candle_data[1].size > 2 and this.qualifiers.HasOwnProp('sc3aB') and this.qualifiers.sc3aB.state and this.qualifiers.sc3aB.timeframe = Utils.get_timeframe()
        condition_sell := this.candle_data[1].color = 'R' and this.candle_data[1].size > 2 and this.qualifiers.HasOwnProp('sc3aS') and this.qualifiers.sc3aS.state and this.qualifiers.sc3aS.timeframe = Utils.get_timeframe()

        for v in ['sc3aB', 'sc3aS'] {
            if this.qualifiers.HasOwnProp(v) and this.qualifiers.%v%.state and Utils.get_timeframe() > this.qualifiers.%v%.timeframe
                this.qualifiers.%v%.state := false
        }

        if (condition_buy) {
            this.qualifiers.sc3aB.state := false
            this.ExecuteTrade('BUY', '3a')
        } else if (condition_sell) {
            this.qualifiers.sc3aS.state := false
            this.ExecuteTrade('SELL', '3a')
        }
    }
    Scenario4() {
        if this.candle_data.Length < 2
            return false
        if this.paused
            return false
        condition_both := Mod(A_Sec, 15) >= 13 and Abs(this.ps.orange.y - this.ps.blue.y) >= 40 and not this.trade_opened[1] and this.candle_data[1].size >= 30
        if this.stats.streak <= -3
            condition_both := Mod(A_Sec, 15) >= 1 and Abs(this.ps.orange.y - this.ps.blue.y) >= 40 and not this.trade_opened[1] and this.candle_data[1].size >= 30
        condition_buy  := condition_both and this.ps.orange.y > this.ps.blue.y and (+this.ps.orange.y - this.ps.blue.y > -this.candle_data[1].C + this.candle_data[2].C) and this.candle_data[1].color = 'G'
        condition_sell := condition_both and this.ps.orange.y < this.ps.blue.y and (-this.ps.orange.y + this.ps.blue.y > +this.candle_data[1].C - this.candle_data[2].C) and this.candle_data[1].color = 'R'

        condition_buy  := condition_buy  and this.ps.moving_price.y < this.candle_data[1].O - (this.candle_data[1].size/2)
        condition_sell := condition_sell and this.ps.moving_price.y > this.candle_data[1].O + (this.candle_data[1].size/2)

        if (condition_buy) {
            this.last_trade := 'BUY'
            this.ExecuteTrade('BUY', '4')
        } else if (condition_sell) {
            this.last_trade := 'SELL'
            this.ExecuteTrade('SELL', '4')
        }
    }
    Scenario5() {
        if this.candle_data.Length < 2 or this.trade_opened[1]
            return false
        condition_both := Mod(A_Sec, 15) >= 1 and Mod(A_Sec, 15) <= 3 and Abs(this.ps.orange.y - this.ps.blue.y) >= 40 and this.candle_data[1].size >= 30
        condition_buy  := condition_both and this.candle_data[2].color = 'R' and this.candle_data[2].moving_prices[-1] < this.candle_data[2].O
        condition_sell := condition_both and this.candle_data[2].color = 'G' and this.candle_data[2].moving_prices[-1] > this.candle_data[2].O

        condition_buy  := condition_buy  and this.candle_data[1].color = 'G' and this.candle_data[1].C < this.ps.blue.y
        condition_sell := condition_sell and this.candle_data[1].color = 'R' and this.candle_data[1].C > this.ps.blue.y

        if (condition_buy) {
            this.last_trade := 'BUY'
            this.ExecuteTrade('BUY', '5')
        } else if (condition_sell) {
            this.last_trade := 'SELL'
            this.ExecuteTrade('SELL' , '5')
        }
    }

    CheckPayout(change_anyway := false) {
        coin_change_streak := -4
        this.marked_time_refresh := A_TickCount
        if not this.state.coin_change_streak and this.stats.streak != coin_change_streak
            this.state.coin_change_streak := true
        _count_reload := 0
        Loop {
            _count_reload++
            if _count_reload > 100 {
                _count_reload := 0
                this.ReloadWebsite()
            }
            if A_TickCount > this.marked_time_refresh + 2*60*1000 {
                this.marked_time_refresh := A_TickCount
                this.ReloadWebsite()
                ; reload
            }    
            if not change_anyway and (this.stats.streak != coin_change_streak or not this.state.coin_change_streak) and ImageSearch(&outx, &outy, this.coords.Payout.x, this.coords.Payout.y, this.coords.Payout.x+this.coords.Payout.w, this.coords.Payout.y+this.coords.Payout.h, '*10 payout.png') {
                this.payout := 92
                break
            } else {
                change_anyway := false
                Loop 19 {
                    ToolTip(,,,A_Index+1)
                }
                this.last_trade := ''
                ToolTip('Waiting for payout to be 92 or higher... ' A_Index, 500, 5, 12)
                MouseClick('L', this.coords.coin.x + Random(-2, 2), this.coords.coin.y + Random(-2, 2), 1, 2)
                sleep 100
                MouseClick('L', this.coords.cryptocurrencies.x + Random(-2, 2), this.coords.cryptocurrencies.y + Random(-2, 2), 1, 2)
                sleep 100
                if this.state.coin_change_streak and this.stats.streak = coin_change_streak {
                    this.state.coin_change_streak := false
                    _count_reload := 0
                    Loop {
                        _count_reload++
                        if _count_reload > 20 {
                            _count_reload := 0
                            this.ReloadWebsite()
                        }
                        MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(0, 2)*28, 1, 2)
                        sleep 300
                        new_cname := OCR.FromRect(this.coords.coin.x - 25, this.coords.coin.y - 25, 150, 50,, 3).Text
                        ToolTip('Waiting coin name change (' this.coin_name ' vs ' new_cname ') ' A_Index, 500, 5, 12)
                        if this.coin_name != new_cname {
                            this.coin_name := new_cname
                            break
                        }
                    }
                } else {
                    MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(-2, 2), 1, 2)
                }
                sleep 100
                MouseClick('L', this.coords.time1.x + Random(-2, 2), this.coords.time1.y + Random(-2, 2), 1, 2)
                sleep 100
                MouseClick('L', this.coords.time_choice.x + Random(-2, 2), this.coords.time_choice.y + Random(-2, 2), 1, 2)
                sleep 100
                Send '{Escape}'
                sleep 1000
            }
        }
    }
    CheckTradeClosed() {
        if (this.trade_opened[1]) {
            MouseClick('L', this.coords.trades_opened.x + Random(-2, 2), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
            sleep 50 
            loop 3 {
                if PixelSearch(&x, &y, this.coords.detect_trade_open1.x, this.coords.detect_trade_open1.y, this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, this.colors.green2, 30) {
                    return
                }
                sleep 50
            }
            sleep 500
            this.active_trade := ''
            this.trade_opened[1] := false
            MouseClick('L', this.coords.trades_closed.x + Random(-2, 2), this.coords.trades_closed.y + Random(-1, 1), 5, 2)
            sleep 300
            draw := {x1:this.coords.detect_trade_close1.x , x2:(this.coords.detect_trade_close2.x+this.coords.detect_trade_close1.x)/2, y1:this.coords.detect_trade_close1.y, y2: this.coords.detect_trade_close2.y}
            win :=  {x2:this.coords.detect_trade_close2.x , x1:(this.coords.detect_trade_close2.x+this.coords.detect_trade_close1.x)/2, y1:this.coords.detect_trade_close1.y, y2: this.coords.detect_trade_close2.y}
            win.ps := PixelSearch(&x, &y, win.x1, win.y1, win.x2, win.y2, this.colors.green2, 37)
            draw.ps := PixelSearch(&x, &y, draw.x1, draw.y1, draw.x2, draw.y2, this.colors.green2, 32)
            MouseClick('L', this.coords.trades_opened.x + Random(-2, 2), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
            if not win.ps and not draw.ps {
                if this.stats.streak > 0
                    this.stats.streak := 0
                ; else if this.stats.streak > 0
                ;     this.stats.streak := -Abs(this.stats.streak)+1
                this.stats.streak--

                if this.state.32
                    this.stats.streak2--
                if this.stats.streak <= -4 and not this.state.32 {
                    this.stats.streak2--
                    this.state.32 := true
                }
                this.amount := this.amount_arr[this.GetAmount(this.balance.current+this.amount*2.2)][-this.stats.streak+1] ; (default_amount + Floor(balance.current/1000)) * (-stats.streak) + (-stats.streak-1) * 1.5
                
                if this.stats.streak <= -3 {
                    ToolTip('CHANGING COIN... ' A_Index, 500, 5, 12)
                    MouseClick('L', this.coords.coin.x + Random(-2, 2), this.coords.coin.y + Random(-2, 2), 1, 2)
                    sleep 100
                    MouseClick('L', this.coords.cryptocurrencies.x + Random(-2, 2), this.coords.cryptocurrencies.y + Random(-2, 2), 1, 2)
                    sleep 100
                    _count_reload := 0
                    Loop {
                        _count_reload++
                        if _count_reload > 50 {
                            _count_reload := 0
                            this.ReloadWebsite()
                        }
                        MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(0, 2)*28, 1, 2)
                        sleep 200
                        new_cname := OCR.FromRect(this.coords.coin.x - 25, this.coords.coin.y - 25, 150, 50,, 3).Text
                        ToolTip('Waiting coin name change (' this.coin_name ' vs ' new_cname ') ' A_Index, 500, 5, 12)
                        if this.coin_name != new_cname {
                            this.coin_name := new_cname
                            break
                        }
                    }
                    sleep 100
                    MouseClick('L', this.coords.time1.x + Random(-2, 2), this.coords.time1.y + Random(-2, 2), 1, 2)
                    sleep 100
                    MouseClick('L', this.coords.time_choice.x + Random(-2, 2), this.coords.time_choice.y + Random(-2, 2), 1, 2)
                    sleep 100
                    Send '{Escape}'
                    sleep 200
                }

                this.SetTradeAmount()
                this.stats.loss++
            } else if win.ps {
                this.amount := this.GetAmount(this.balance.current)
                if this.stats.streak < 0 {
                    if this.stats.streak = -4
                        this.lose_streak.end_by_win_count++
                    if not this.lose_streak.repeat.Has(this.stats.streak)
                        this.lose_streak.repeat[this.stats.streak] := 0
                    if this.stats.streak < this.lose_streak.max
                        this.lose_streak.max := this.stats.streak
                    this.lose_streak.repeat[this.stats.streak]++
                    this.stats.streak := 0
                }
                this.stats.streak++
                if this.state.32 {
                    this.stats.streak2++
                }
                this.SetTradeAmount()
                this.stats.win++
            } else if draw.ps {
                this.stats.draw++
            }
        }
    }

    BothLinesDetected() {
        ToolTip('blue', this.ps.blue.x-200, this.ps.blue.y, 2)
        ToolTip('orange', this.ps.orange.x-200, this.ps.orange.y, 3)
        ToolTip('blue', this.ps.blue.x, A_ScreenHeight-100, 4)
        ToolTip('orange', this.ps.orange.x, A_ScreenHeight-50, 5)
        if this.ps.close_green.state 
            ToolTip('CLOSE-green', this.ps.close_green.x-250, this.ps.close_green.y, 6)
        if this.ps.close_red.state 
            ToolTip('CLOSE-red', this.ps.close_red.x-250, this.ps.close_red.y, 6)
        if this.candle_data[1].HasOwnProp('O') and this.candle_data[1].HasOwnProp('H') and this.candle_data[1].HasOwnProp('L') and this.candle_data[1].HasOwnProp('C') {
            if this.candle_data[1].O
                ToolTip('OPEN', this.ps.blue.x-250, this.candle_data[1].O, 7)
            ToolTip('HIGH', this.ps.blue.x-200, this.candle_data[1].H, 8)
            ToolTip('LOW ', this.ps.blue.x-200, this.candle_data[1].L, 9)
        }

        ToolTip(A_Sec '.' A_MSec ' ||Mod 14?|| ' Mod(A_Sec, 15), 1205, 5, 19)

        this.candle_data[1].color := this.ps.close_green.state ? 'G' : this.ps.close_red.state ? 'R' : '?'
        this.candle_data[1].colors.Push(this.candle_data[1].color)
        if Mod(A_Sec, 15) >= 12 {
            this.candle_data[1].colors_12.Push(this.candle_data[1].color)
        }
        if this.candle_data[1].color != this.candle_data[1].color_changes[-1]
            this.candle_data[1].color_changes.Push(this.candle_data[1].color)

        ; if (Mod(A_Sec, 15) >= 13) {
        _timeframe := Utils.get_timeframe()
        if _timeframe != this.candle_data[1].timeframe {
            this.candle_data.InsertAt(1, {moving_prices: [], blue_line_y: [], color: this.candle_data[1].color, size: 0, timeframe: _timeframe, colors: [this.candle_data[1].color], colors_12: [this.candle_data[1].color], color_changes: [this.candle_data[1].color], O: this.candle_data[1].O, H: this.candle_data[1].H, L: this.candle_data[1].L, C: this.candle_data[1].C})
            while this.candle_data.Length > 7
                this.candle_data.Pop()
        }
        this.candle_data[1].both_lines_touch := this.ps.r_touch_blue.state and this.ps.r_touch_orange.state or this.ps.g_touch_blue.state and this.ps.g_touch_orange.state
        this.candle_data[1].blue_line_y.Push(this.ps.blue.y)
        this.candle_data[1].moving_prices.Push(this.ps.moving_price.y)
        ; }

        if (Mod(A_Sec, 15) = 13 and A_MSec >= 500 or Mod(A_Sec, 15) = 14) {
            ToolTip(A_Sec '.' A_MSec ' ||MOD 14!!!!!!!!!!!!|| ' Mod(A_Sec, 15), 1205, 5, 19)
            if ((this.crossovers_arr.Length = 0 || this.crossovers_arr[-1].direction != 'BUY') and this.ps.orange.y > this.ps.blue.y) {
                if this.last_trade=''
                    this.last_trade := 'BUY'
                this.crossovers_arr.Push({direction: 'BUY', time: A_TickCount})
            } else if ((this.crossovers_arr.Length = 0 || this.crossovers_arr[-1].direction != 'SELL') and this.ps.orange.y < this.ps.blue.y) {
                if this.last_trade=''
                    this.last_trade := 'SELL'
                this.crossovers_arr.Push({direction: 'SELL', time: A_TickCount})
            }
            if this.crossovers_arr.Length > 10
                this.crossovers_arr.RemoveAt(1)
            try 
                this.coin_name := OCR.FromRect(this.coords.coin.x - 25, this.coords.coin.y - 25, 150, 50,, 3).Text
            catch  
                this.coin_name := '???'
        }
    }

    RunScenarios() {
        this.paused := this.CheckPaused()
        ; if this.stats.streak <= -3 {
        ;     qualifier_buy  := this.candle_data[1].moving_prices[-1] < this.candle_data[2].C and this.candle_data[1].color = 'G' and this.candle_data[2].color = 'G'
        ;     qualifier_sell := this.candle_data[1].moving_prices[-1] > this.candle_data[2].C and this.candle_data[1].color = 'R' and this.candle_data[2].color = 'R'
        ;     if not qualifier_buy and not qualifier_sell
        ;         return
        ; }
        ; if this.stats.streak <= -4
        this.Scenario3()
        ; this.Scenario2()
        ; this.Scenario1()
    }

    UpdateLog() {
        global

        str_ohlc := '<' this.ps.moving_price.y '> '
        
        if this.candle_data.Length > 1 {
            str_ohlc .= this.candle_data[2].HasOwnProp('O') ? this.candle_data[1].O ' (' this.candle_data[2].O ') | ' : '? | '
            str_ohlc .= this.candle_data[2].HasOwnProp('H') ? this.candle_data[1].H ' (' this.candle_data[2].H ') | ' : '? | '
            str_ohlc .= this.candle_data[2].HasOwnProp('L') ? this.candle_data[1].L ' (' this.candle_data[2].L ') | ' : '? | '
            str_ohlc .= this.candle_data[2].HasOwnProp('C') ? this.candle_data[1].C ' (' this.candle_data[2].C ') | ' : '? | '
        }

        date := FormatTime(A_Now, 'MM/dd')
        time := FormatTime(A_Now, 'HH:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
        if this.trade_opened[1] {
            countdown_close := (this.trade_opened[2] - A_TickCount)/1000
            countdown_close_str :=  this.executed_trades[1][2] ' (' format('{:.2f}', countdown_close) ')'
        } else {
            countdown_close_str := ''
        }
    
        streaks_str := ''
        if this.lose_streak.repeat.Count > 0
            lose_streak_str := this.lose_streak.max '(' this.lose_streak.repeat[this.lose_streak.max] ')'
        else
            lose_streak_str := 0 '(' 0 ')'
        for k, v in this.lose_streak.repeat {
            streaks_str .= k '<' v '> '
        }

        try {    
            this.debug_str := 'qualifiers: ' this.candle_data[1].color ' | '
            if not this.paused
                this.debug_str .= ' NP | '
            this.debug_str .= ' line_diff: ' this.ps.orange.y - this.ps.blue.y ' | '
            this.debug_str .= ' cnd_diff: ' this.candle_data[2].C - this.candle_data[1].C ' | '
            this.debug_str .= ' mv_price: ' this.ps.moving_price.y ' <? ' this.candle_data[1].O - (this.candle_data[1].size/2) ' | ' this.ps.moving_price.y ' +? ' this.candle_data[1].O + (this.candle_data[1].size/2) ' | '
        }
        
        _pauser := ''
        for k, v in this.blockers {
            if v.state
                _pauser .= k ':' v.state '|'
        }
        paused_str := this.paused ? 'Paused (' _pauser ')' : '()'
        err := 0
        win_rate := this.stats.win > 0 ? this.stats.win/(this.stats.win+this.stats.loss+this.stats.draw)*100 : 0
        win_rate := Format('{:.1f}', win_rate)

        str := Map()
        str.next_bal := '$1000: $99999999999999'

        for v in this.amounts_tresholds {
            if this.balance.current > v[1] {
                break
            }
            str.next_bal := '$' v[2] ': ' v[1]
        }

        str_c := ''
        for k, v in this.qualifiers.OwnProps() {
            if not Type(v) = 'Object' or not v.HasOwnProp('state')
                continue
            if v.state {
                str_c .= k '_' v.state ' | '
            }
        }
        try
            str_c .= SubStr(this.crossovers_arr[-1].direction, 1, 1) Format('{:.1f}', (A_TickCount - this.crossovers_arr[-1].time)/1000) ' | '
        str_c .= 'g' this.ps.g_touch_blue.state this.ps.g_touch_orange.state ' | '
        str_c .= 'r' this.ps.r_touch_blue.state this.ps.r_touch_orange.state ' | '
        try
            str_c .= 'LD: ' this.ps.orange.y - this.ps.blue.y ' | '
        
        _count_reload := 0
        loop {
            _count_reload++
            if _count_reload > 1000 {
                _count_reload := 0
                MsgBox 'Too many errors while trying to append new row to log file.'
            }

            try {
                if FileExist(this.log_file) {
                    file_size := FileGetSize(this.log_file)
                    max_size := 5 * 1024 * 1024 ; 5 MB
                    if file_size > max_size
                        FileDelete(this.log_file)
                }
    
                FileAppend(
                    date ',' 
                    time ',' 
                    str_c '(' this.candle_data[1].size ' | ' this.coin_name ') (' this.stats.streak ') ' this.active_trade countdown_close_str ' | ' paused_str ',' 
                    format('{:.2f}', this.amount) ',' 
                    this.balance.current ' (W:' this.stats.bal_win ' | L:' this.stats.bal_lose ') (' this.balance.max ' | ' this.balance.min ')' ',' 
                    str.next_bal ',' 
                    this.last_trade ',' 
                    ' | ' this.payout '%=' format('{:.2f}', this.amount*1.92) ' (' this.coin_name ')' ',' 
                    this.stats.streak ' (' this.stats.win '|' this.stats.draw '|' this.stats.loss '|' win_rate '%)' ',' 
                    streaks_str ',' 
                    str_ohlc ',' 
                    this.debug_str '`n',
                    this.log_file
                )
                break
            } catch as e {
                if !InStr(e.Message, 'being used by another process')
                    throw e
                err++
                ToolTip('Appending new row. Errors: ' err '`n' e.Message, 500, 5, 12)
                sleep 100
                continue
            }
        }
    }
    ExecuteTrade(action, reason) {
        global
        this.last_trade := action
        if this.trade_opened[1]
            return false
        this.trade_opened := [true, A_TickCount]
        this.active_trade := ''
        this.balance.last_trade := this.balance.current
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)
            sleep 100
        }
        if this.balance.current < 1 {
            return
        }
        sleep 50
        MouseClick('L', this.coords.%action%.x + Random(-5, 5), this.coords.%action%.y + Random(-1, 1), 1, 2)
        sleep 200
        MouseClick('L', this.coords.trades_opened.x + Random(-5, 5), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
        sleep 50
        loop {
            MouseMove(this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, 0)
            sleep 50
            ToolTip('waiting for trade to be opened', , , 12)
            if PixelSearch(&x, &y, this.coords.detect_trade_open1.x, this.coords.detect_trade_open1.y, this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, this.colors.green2, 20) {
                break
            }
            if A_Index > 400 {
                this.trade_opened[1] := false
                this.active_trade := ''
                return
            }

            ; if (a_index>100) {
            ;     this.last_trade := action
            ;     ToolTip(,,, 12)
            ;     return 
            ; }
        }
        ToolTip(,,, 12)
        this.executed_trades.InsertAt(1, [action, reason])
        while this.executed_trades.Length > 10
            this.executed_trades.Pop()
        this.active_trade := action
    }     

    PSearch() {
        this.ps.blue := {state: false}
        this.ps.orange := {state: false}
        this.ps.close_green := {state: false}
        this.ps.close_red := {state: false}
        this.ps.open := {state: false}
        this.ps.g_touch_blue := {state: false}
        this.ps.g_touch_orange := {state: false}
        this.ps.r_touch_blue := {state: false}
        this.ps.r_touch_orange := {state: false}
        _count_reload := 0
        loop {
            _count_reload++
            if _count_reload > 1000 {
                _count_reload := 0
                this.ReloadWebsite()
            }
            try {
                this.ps.moving_price := {state: PixelSearch(&x1, &y1, this.coords.area_price.x, this.coords.area_price.y, this.coords.area_price.x2, this.coords.area_price.y2, this.colors.moving_price, 5)}
                PixelSearch(&x2, &y2, x1+5, this.coords.area_price.y2, x1-5, y1, this.colors.moving_price, 5)
                this.ps.moving_price.y := (y1+y2)/2
                break
            }
        }
        try {
            this.ps.blue := {state: PixelSearch(&x, &y, this.coords.area.x, this.coords.area.y, this.coords.area.x2, this.coords.area.y2, this.colors.blue, 5), x:x, y:y}
        } catch as e {
            ToolTip('Error: PixelSearch failed`n' e.Message, 500, 5, 15)
            this.coords.area.x := max(this.coords.area.x - 1, 100)
            this.coords.area.x2 := this.coords.area.x - 2
            ToolTip(,,, 15)
            return false
        }
        if this.ps.blue.state {
            this.ps.orange := {state: PixelSearch(&x, &y, this.ps.blue.x+1, this.coords.area.y, this.ps.blue.x-1, this.coords.area.y2, this.colors.orange, 5), x:x, y:y}
            _count_reload := 0
            Loop {
                _count_reload++
                if _count_reload > 20000 {
                    _count_reload := 0
                    this.ReloadWebsite()
                }
                this.ps.close_green := {state: PixelSearch(&x, &y, this.ps.blue.x+4, this.coords.area.y, this.ps.blue.x+1, this.coords.area.y2, this.colors.green, 10), x:x, y:y}
                if not this.ps.close_green.state 
                    this.ps.close_red := {state: PixelSearch(&x, &y, this.ps.blue.x+4, this.coords.area.y2, this.ps.blue.x+1, this.coords.area.y, this.colors.red, 10), x:x, y:y}
                if this.ps.close_green.state {
                        this.ps.open := {state: PixelSearch(&x, &y, this.ps.blue.x+4, this.coords.area.y2, this.ps.blue.x+1, this.coords.area.y, this.colors.green, 15), x:x, y:y}
                        if this.ps.open.state
                            break
                } else if this.ps.close_red.state {
                        this.ps.open := {state: PixelSearch(&x, &y, this.ps.blue.x+4, this.coords.area.y, this.ps.blue.x+1, this.coords.area.y2, this.colors.red, 15), x:x, y:y}
                        if this.ps.open.state
                            break
                }
            }
            if this.ps.close_red.state {
                this.candle_data[1].O := this.ps.open.y
                this.candle_data[1].C := this.ps.close_red.y
                this.candle_data[1].H := this.candle_data[1].HasOwnProp('H') ? max(this.ps.close_red.y, this.candle_data[1].H, this.candle_data[1].O) : this.ps.open.y
                this.candle_data[1].L := this.candle_data[1].HasOwnProp('L') ? min(this.ps.close_red.y, this.candle_data[1].L, this.candle_data[1].O) : this.ps.close_red.y
                if this.ps.close_red.y and this.ps.open.y
                    this.candle_data[1].size := Abs(this.ps.close_red.y - this.ps.open.y)
            } else if this.ps.close_green.state {
                this.candle_data[1].O := this.ps.open.y
                this.candle_data[1].C := this.ps.close_green.y
                this.candle_data[1].H := this.candle_data[1].HasOwnProp('H') ? min(this.ps.close_green.y, this.candle_data[1].H, this.candle_data[1].O) : this.ps.close_green.y
                this.candle_data[1].L := this.candle_data[1].HasOwnProp('L') ? max(this.ps.close_green.y, this.candle_data[1].L, this.candle_data[1].O) : this.ps.open.y
                if this.ps.close_green.y and this.ps.open.y
                    this.candle_data[1].size := Abs(this.ps.close_green.y - this.ps.open.y)
            }

            this.coords.area.x := min(this.coords.area.x + 1, A_ScreenWidth*0.95)
            this.coords.area.x2 := this.coords.area.x - 2
            ToolTip('(' A_Sec '.' A_MSec ')' this.debug_str '`nCurrent this.last_trade: ' this.last_trade '`nCurrent balance: ' format('{:.2f}', this.balance.current), 5, 5, 11)
        } else {
            this.coords.area.x := max(this.coords.area.x - 1, 100)
            if this.coords.area.x < this.min_x {
                this.coords.area.x := this.min_x
                this.ReloadWebsite()
            }
            this.coords.area.x2 := this.coords.area.x - 2
            ; this.debug_str := 'ps: ' this.ps.blue.state ' ' this.ps.orange.state ' | diff: ' (this.ps.blue.state and this.ps.orange.state ? this.ps.orange.y - this.ps.blue.y : 0) ' | '
            ; ToolTip('(' A_Sec '.' A_MSec ')' this.debug_str '`nCurrent this.last_trade: ' this.last_trade '`nCurrent balance: ' format('{:.2f}', balance.current), 5, 5, 11)
            return false
        }
        threshold := [10, 8]
        if this.ps.blue.state and this.ps.orange.state {
            this.ps.g_touch_blue := {state: PixelSearch(&x, &y, this.ps.blue.x+threshold[1], this.ps.blue.y+threshold[1], this.ps.blue.x+threshold[2], this.ps.blue.y-threshold[1], this.colors.green, 5), x:x, y:y}
            this.ps.g_touch_orange := {state: PixelSearch(&x, &y, this.ps.orange.x+threshold[1], this.ps.orange.y+threshold[1], this.ps.orange.x+threshold[2], this.ps.orange.y-threshold[1], this.colors.green, 5), x:x, y:y}
            this.ps.r_touch_blue := {state: PixelSearch(&x, &y, this.ps.blue.x+threshold[1], this.ps.blue.y+threshold[1], this.ps.blue.x+threshold[2], this.ps.blue.y-threshold[1], this.colors.red, 5), x:x, y:y}
            this.ps.r_touch_orange := {state: PixelSearch(&x, &y, this.ps.orange.x+threshold[1], this.ps.orange.y+threshold[1], this.ps.orange.x+threshold[2], this.ps.orange.y-threshold[1], this.colors.red, 5), x:x, y:y}
        }

        ToolTip(,,, 12)
        return true
    }

    GetAmount(val) {
        for tresh in this.amounts_tresholds {
            _index := A_Index
            if val >= tresh[1] {
                while this.amounts_tresholds.Length > _index
                    this.amounts_tresholds.Pop()        
                return tresh[2]
            }
        }
        return this.amounts_tresholds[-1][2]
    }

    ReloadWebsite() {
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 100
        }
        sleep 80
        Send('!d')
        sleep 80
        Utils.PasteText('https://pocketoption.com/en/cabinet/demo-quick-high-low/')
        sleep 80
        Send('{Enter}')
        sleep 80
        WinMove(-8, -8, 1040, 744, this.wtitle)
        sleep 5000
        return
    }
    
    SetTradeAmount() {
        _count_reload := 0
        Loop {
            _count_reload++
            if _count_reload > 1000 {
                _count_reload := 0
                this.ReloadWebsite()
            }
            this.CheckBalance()
            if this.balance.current < 1 {
                this.stats.bal_lose++
                this.AddBalance(this.balance.starting-this.balance.current)
            } else if this.balance.current >= this.balance.reset_max {
                this.stats.bal_win++
                this.AddBalance(this.balance.reset_max + this.balance.starting - this.balance.current)
            }
            this.amount := Min(this.amount, this.balance.current)

            if !WinActive(this.wtitle) {
                WinActivate(this.wtitle)  
                sleep 100
            }
            ; if this.state.32 {
            ;     this.amount := this.amount_arr[this.GetAmount(this.balance.current)][4+1]
            ; }
            ; if this.balance.current >= this.balance.max and this.state.32 {
            ;     this.state.32 := false
            ;     this.stats.streak2 := 0
            ;     this.stats.streak := 1
            ;     this.amount := this.amount_arr[this.GetAmount(this.balance.current)][this.stats.streak]
            ; }
            sleep 80
            Send('^f')
            sleep 80
            Send('^a{BS}')
            sleep 80
            Utils.PasteText('amount')
            sleep 80
            Send('{enter}{Escape}')
            sleep 80
            Send('{tab}')
            sleep 80
            Utils.PasteText(this.amount)
            sleep 80
            A_Clipboard := ''
            sleep 50
            Send('^a^c')
            sleep 50
            ClipWait(0.5)
            try {
                if Format('{:.0f}', RegExReplace(A_Clipboard, '[^\d.]')) != Format('{:.0f}', RegExReplace(this.amount, '[^\d.]')) {
                    continue
                }
            } catch {
                continue
            }
            sleep 80
            A_Clipboard := ''
            Send('{Tab}^f')
            sleep 80
            Send('USD{enter}{Escape}')
            sleep 50
            MouseMove(Random(-20, 20), Random(-20, 20), 4, 'R')
            return
        }
    }
    
    SetTradeTime() {
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 100
        }
        sleep 80
        Send('^f')
        sleep 80
        Send('^a{BS}')
        sleep 80
        
        sleep 80
        A_Clipboard := this.amount
        sleep 100
        Send('^v')
        sleep 100
        Send('{tab 2}')
        sleep 50
        MouseMove(Random(-20, 20), Random(-20, 20), 4, 'R')
        return
    }
    
    CheckBalance() {
        _count_reload := 0
        Loop {
            _count_reload++
            if _count_reload > 1000 {
                _count_reload := 0
                this.ReloadWebsite()
            }
            A_Clipboard := ''
            if !WinActive(this.wtitle) {
                WinActivate(this.wtitle)  
                sleep 100
            }
            MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,1,2)
            sleep 50
            Send('^a^c')
            sleep 50
            if !ClipWait(0.5) {
                ToolTip('Copy failed')
                sleep 30
                if A_Index > 20 {
                    this.ReloadWebsite()
                }
                continue
            }
            sleep 100
            if !RegExMatch(A_Clipboard, 'USD') {
                tooltip('Error: No balance found`n' A_Clipboard)
                sleep 80
                Send('^f')
                sleep 80
                Send('USD{enter}{Escape}')
                sleep 50
                continue
            }
            if !RegExMatch(A_Clipboard, 'm)^\d{1,3}(,\d{3})*(\.\d{2})*$', &match) {
                tooltip('Error: No balance found`n' A_Clipboard)
                sleep 80
                Send('^f')
                sleep 80
                Send('USD{enter}{Escape}')
                sleep 50
                continue
            }
            ToolTip
            cur_bal := StrReplace(match[], ',', '')
            if cur_bal >= 50000 {
                MsgBox 'Balance too high.'
            }
            cur_bal := Format('{:.2f}', cur_bal - (this.stats.bal_win) * (this.balance.reset_max))
            if cur_bal > this.balance.last_trade and this.stats.streak < 0 and not this.trade_opened[1] {
                if cur_bal > this.balance.last_trade + 0.5 {
                    ; this.stats.streak++
                    ; this.stats.draw++
                    this.stats.streak++
                    if this.stats.streak < 0 {
                        if this.stats.streak = -4
                            this.lose_streak.end_by_win_count++
                        if not this.lose_streak.repeat.Has(this.stats.streak)
                            this.lose_streak.repeat[this.stats.streak] := 0
                        if this.stats.streak < this.lose_streak.max
                            this.lose_streak.max := this.stats.streak
                        this.lose_streak.repeat[this.stats.streak]++
                        this.stats.streak := 0
                    }
    
                    this.stats.streak := 1
                    if this.state.32
                        this.stats.streak2 += 2
                    this.stats.win++
                    this.stats.loss--
                    this.amount := this.GetAmount(cur_bal)
                } else {
                    sleep 10
                    this.stats.loss--
                    this.stats.draw++
                }
                this.balance.last_trade := cur_bal
            }
            this.balance.current := cur_bal
            this.balance.max := Format('{:.2f}', max(cur_bal, this.balance.max))
            this.balance.min := Format('{:.2f}', min(cur_bal, this.balance.min))
            return
        }
    }

    AddBalance(bal_amount) {
        bal_amount := format('{:.2f}', bal_amount)
        A_Clipboard := ''
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 100
        }
        MouseClick('L', this.coords.balance.x + Random(-2, 2), this.coords.balance.y + Random(-2, 2), 1, 2)
        sleep 1000
        MouseClick('L', this.coords.top_up.x + Random(-2, 2), this.coords.top_up.y + Random(-2, 2), 1, 2)
        sleep 1000
        Send '{tab}'
        sleep 500
        Utils.PasteText(bal_amount)
        sleep 500
        Send '{Enter}'
        sleep 1000
        MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,1,2)
        this.balance.max := 0
        this.balance.min := 9**10
        sleep 1000
        this.CheckBalance()
        return
    }
}

