#Requires AutoHotkey v2.0
#Include OCR.ahk
#Include utils.ahk

class TraderBot {
    __New(settings_obj) {
        this.settings_obj := settings_obj
        this.wtitle := settings_obj.wtitle
        this.coords := settings_obj.coords
        this.colors := settings_obj.colors
        this.ps := Map()
        this.amount_arr := []
        ; this.amounts_tresholds := [[20000, 3],[4350, 2], [0, 1]]
        this.amounts_tresholds := []

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
            this.amounts_tresholds.InsertAt(1, [_tresh, _index])
        }
        ; var := ''
        ; for v in this.amounts_tresholds {
        ;     var .= v[2] ' = ' v[1] '`n'
        ; }

        ; MsgBox next_bal '`nTresholds value:`n' var
        this.start_time := A_TickCount
        this.log_file := 'log.csv'
        this.trade_opened := [false, A_TickCount]
        this.crossovers_arr := []
        this.current_color := '?'
        this.last_trade := ''
        this.active_trade := ''
        this.executed_trades := ['', '']
        this.countdown_close := 0
        this.countdown_close_str := ''
        this.win_rate := ''
        this.debug_str := ''
        this.stats := {streak: 0, win: 0, loss: 0, draw: 0, reset_date: 0}
        this.balance := {current: 0, min: 999999999, max: 0, last_trade: 0}
        this.balance := this.check_balance(this.balance)
        this.candle_data := [{color: '?', colors: [], colors_12: [], color_changes: ['?'], timeframe: Utils.get_timeframe()}]
        
        this.lose_streak := {max: this.stats.streak, repeat: Map()}
        this.paused := false
        this.blockers := Map()
        this.state := {coin_change_streak: false, 5loss: false}
        this.min_x := this.coords.area.x - 50
        this.amount := this.get_amount(this.balance.current)
        this._time := 15
        this._time += 4
        this.payout := 92
        this.datetime := A_Now
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
        this.date := FormatTime(this.datetime, 'MM/dd')
        this.time := FormatTime(this.datetime, 'HH:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
        this.coin_name := OCR.FromRect(this.coords.coin.x - 15, this.coords.coin.y - 15, 130, 40).Text
        this.marked_time_refresh := A_TickCount

        if !FileExist(this.log_file) {
            FileAppend('date,time,active_trade,next_target,last_trade,balance,amount,payout,Streak (W|D|L|win_rate),Streaks,OHLC,debug`n', this.log_file)
        }
    }

    start_loop(*) {
        ToolTip('Running...', 5, 5, 1)
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
        }
        WinMove(-8, -8, 1040, 744, this.wtitle)
        this.set_amount(this.amount)
        MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,1,2)
        SetTimer(this.main.Bind(this), 100)
    }

    main() {
        if A_TickCount > this.marked_time_refresh + 2*60*60*1000 {
            this.marked_time_refresh := A_TickCount
            this.reload_website()
            ; reload
        }    
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)
            sleep 100
        }
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 1)
        sleep 100

        this.balance := this.check_balance(this.balance)
        this.checker_payout()
        if not this.pixels_search()
            return
        this.check_trade_closed()
        
        this.datetime := A_Now
        if this.stats.reset_date != SubStr(this.datetime, 1, -6) {
            this.stats.win := 0
            this.stats.loss := 0
            this.stats.draw := 0
            this.lose_streak := {max: 0, repeat: Map()}
        }
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
        
        if this.ps.blue.state and this.ps.orange.state {
            this.both_lines_detected()
        }
    
        this.update_log()
        sleep 100
    
    }
    
    check_paused() {
        key := '2cr'
        if not this.blockers.Has(key)
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.crossovers_arr.Length >= 2 and A_TickCount - this.crossovers_arr[-2].time <= 30000) {
            this.blockers[key] := {state: true, tick_count: A_TickCount}
        }
        if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 45000 {
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        }

        ; key := 'not_3G3R'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if (candle_data.Length >=3 and candle_data[1].color = candle_data[2].color and candle_data[1].color = candle_data [3].color) {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else if candle_data.Length < 3 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; }

        key := 'GRRG'
        if not this.blockers.Has(key)
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=4 and this.candle_data[4].color = 'G' and this.candle_data[3].color = 'R' and this.candle_data[2].color = 'R' and this.candle_data[1].color = 'G') {
            this.blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        }

        key := 'RGGR'
        if not this.blockers.Has(key)
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=4 and this.candle_data[4].color = 'R' and this.candle_data[3].color = 'G' and this.candle_data[2].color = 'G' and this.candle_data[1].color = 'R') {
            this.blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        }

        key := 'GRG'
        if not this.blockers.Has(key)
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=3 and this.candle_data[3].color = 'G' and this.candle_data[2].color = 'R' and this.candle_data[1].color = 'G') {
            this.blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        }

        key := 'RGR'
        if not this.blockers.Has(key)
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        if (this.candle_data.Length >=3 and this.candle_data[3].color = 'R' and this.candle_data[2].color = 'G' and this.candle_data[1].color = 'R') {
            this.blockers[key] := {state: true, tick_count: A_TickCount}
        } else {
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        }

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
        ; if candle_data.Length >= 3 and candle_data[2].color != candle_data[3].color and this.ps.orange.y < min(candle_data[1].H, candle_data[1].L) and this.ps.blue.y > max(candle_data[1].H, candle_data[1].L) {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 30000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        ; key := 'small_body'
        ; if not this.blockers.Has(key)
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; if candle_data.Length >= 3 and abs(candle_data[3].O - candle_data[3].C)/abs(candle_data[3].H - candle_data[3].L) <= 0.1 and abs(candle_data[2].O - candle_data[2].C)/abs(candle_data[2].H - candle_data[2].L) <= 0.1 {
        ;     this.blockers[key] := {state: true, tick_count: A_TickCount}
        ; } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 15000 {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; } else {
        ;     this.blockers[key] := {state: false, tick_count: A_TickCount}
        ; }

        
        key := '4losses'
        coin_change_streak := -4
        if this.state.5loss and this.stats.streak != coin_change_streak
            this.state.5loss := false
        if not this.blockers.Has(key)
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        if this.stats.streak = coin_change_streak and not this.state.5loss {
            this.state.5loss := true
            this.blockers[key] := {state: true, tick_count: A_TickCount}
        } else if this.blockers[key].state and A_TickCount > this.blockers[key].tick_count + 45000 and this.candle_data.Length >= 4 and this.candle_data[1].color = this.candle_data[2].color and this.candle_data[2].color = this.candle_data[3].color and this.candle_data[3].color = this.candle_data[4].color {
            this.state.5loss := true
            this.blockers[key] := {state: false, tick_count: A_TickCount}
        }

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
    scenario1() {
        _pheight := 3.75
        condition_both := this.crossovers_arr.Length >= 2 and not this.trade_opened[1]
        if this.stats.streak <= -4 {
            _pheight := 5.5
            condition_both := condition_both and Utils.is_all_same(this.candle_data[1].colors) and this.candle_data[1].size >= 50 and Mod(A_Sec, 15) >= 10 
        }
        condition_buy  := this.ps.orange.y > this.ps.blue.y + _pheight and this.ps.g_touch_blue.state and this.ps.g_touch_orange.state and condition_both
        condition_sell := this.ps.blue.y > this.ps.orange.y + _pheight and this.ps.r_touch_blue.state and this.ps.r_touch_orange.state and condition_both
        condition_buy  :=  condition_buy and this.candle_data.Length >= 2 and this.current_color = 'G' and this.candle_data[1].color = 'G' and this.candle_data[2].color = 'R'
        condition_sell := condition_sell and this.candle_data.Length >= 2 and this.current_color = 'R' and this.candle_data[1].color = 'R' and this.candle_data[2].color = 'G'

        if this.paused
            return false
        if (condition_buy) {
            this.last_trade := 'BUY'
            this.trade_opened := [true, A_TickCount]
            this.execute_trade('BUY', '1')
        } else if (condition_sell) {
            this.last_trade := 'SELL'
            this.trade_opened := [true, A_TickCount]
            this.execute_trade('SELL', '1')
        }
    }
    scenario2() {
        _pheight := 3.75
        condition_both := this.crossovers_arr.Length >= 2 and A_TickCount - this.crossovers_arr[-1].time <= 32000 and A_TickCount - this.crossovers_arr[-1].time >= 15000 and not this.trade_opened[1]
        if this.stats.streak <= -4 {
            _pheight := 5.5
            condition_both := condition_both and Utils.is_all_same(this.candle_data[1].colors) and this.candle_data[1].size >= 50
        }
        condition_buy  := this.ps.orange.y - this.ps.blue.y > _pheight and this.current_color = 'G' and condition_both
        condition_sell := this.ps.blue.y - this.ps.orange.y > _pheight and this.current_color = 'R' and condition_both
        condition_buy  :=  condition_buy and this.candle_data.Length >= 2 and this.current_color = 'G' and this.candle_data[1].color = 'G' and this.candle_data[2].color = 'R'
        condition_sell := condition_sell and this.candle_data.Length >= 2 and this.current_color = 'R' and this.candle_data[1].color = 'R' and this.candle_data[2].color = 'G'

        if this.paused
            return false
        if (condition_buy) {
            this.last_trade := 'BUY'
            this.trade_opened := [true, A_TickCount]
            this.execute_trade('BUY', '2')
        } else if (condition_sell) {
            this.last_trade := 'SELL'
            this.trade_opened := [true, A_TickCount]
            this.execute_trade('SELL', '2')
        }
    }

    checker_payout() {
        coin_change_streak := -4
        if not this.state.coin_change_streak and this.stats.streak != coin_change_streak
            this.state.coin_change_streak := true
        Loop {
            if (this.stats.streak != coin_change_streak or not this.state.coin_change_streak) and ImageSearch(&outx, &outy, this.coords.Payout.x, this.coords.Payout.y, this.coords.Payout.x+this.coords.Payout.w, this.coords.Payout.y+this.coords.Payout.h, '*10 payout.png') {
                this.payout := 92
                break
            } else {
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
                    Loop {
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
                Send '{Escape}'
                sleep 1000
            }
        }
    }
    check_trade_closed() {
        if (this.trade_opened[1]) {
            MouseClick('L', this.coords.trades_opened.x + Random(-2, 2), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
            sleep 50 
            loop 3 {
                if PixelSearch(&x, &y, this.coords.detect_trade_open1.x, this.coords.detect_trade_open1.y, this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, this.colors.green2, 30) {
                    return
                }
                sleep 50
            }
            this.active_trade := ''
            this.trade_opened[1] := false
            MouseClick('L', this.coords.trades_closed.x + Random(-2, 2), this.coords.trades_closed.y + Random(-1, 1), 5, 2)
            sleep 300
            draw := {x1:this.coords.detect_trade_close1.x , x2:(this.coords.detect_trade_close2.x+this.coords.detect_trade_close1.x)/2, y1:this.coords.detect_trade_close1.y, y2: this.coords.detect_trade_close2.y}
            win :=  {x2:this.coords.detect_trade_close2.x , x1:(this.coords.detect_trade_close2.x+this.coords.detect_trade_close1.x)/2, y1:this.coords.detect_trade_close1.y, y2: this.coords.detect_trade_close2.y}
            win.ps := PixelSearch(&x, &y, win.x1, win.y1, win.x2, win.y2, this.colors.green2, 35)
            draw.ps := PixelSearch(&x, &y, draw.x1, draw.y1, draw.x2, draw.y2, this.colors.green2, 30)
            MouseClick('L', this.coords.trades_opened.x + Random(-2, 2), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
            if not win.ps and not draw.ps {
                if this.stats.streak > 4
                    this.stats.streak := 0
                else if this.stats.streak > 0
                    this.stats.streak := -Abs(this.stats.streak)+1
                this.stats.streak--

                if not this.lose_streak.repeat.Has(this.stats.streak)
                    this.lose_streak.repeat[this.stats.streak] := 0

                if (this.stats.streak = this.lose_streak.max)
                    this.lose_streak.repeat[this.stats.streak]++
                else if (this.stats.streak < this.lose_streak.max) {
                    this.lose_streak.max := this.stats.streak
                    this.lose_streak.repeat[this.stats.streak] := 1
                } else {
                    this.lose_streak.repeat[this.stats.streak]++
                }
                this.amount := this.amount_arr[this.get_amount(this.balance.current+this.amount*2.2)][-this.stats.streak+1] ; (default_amount + Floor(balance.current/1000)) * (-stats.streak) + (-stats.streak-1) * 1.5
                ; if (Mod(stats.streak, -2)=0)
                ;     amount := default_amount + Floor(balance.current/1000)
                this.set_amount(this.amount)
                this.stats.loss++
            } else if win.ps {
                if this.stats.streak < 4 and this.stats.streak > 0
                    this.amount := this.amount_arr[this.get_amount(this.balance.current+this.amount*2.2)][this.stats.streak+1]
                else
                    this.amount := this.get_amount(this.balance.current)
                if this.stats.streak < 0
                    this.stats.streak := 0
                this.stats.streak++
                this.set_amount(this.amount)
                this.stats.win++
            } else if draw.ps {
                this.stats.draw++
            } 
        }
    }

    both_lines_detected() {
        ToolTip('blue', this.ps.blue.x-200, this.ps.blue.y, 2)
        ToolTip('orange', this.ps.orange.x-200, this.ps.orange.y, 3)
        ToolTip('blue', this.ps.blue.x, this.ps.blue.y-200, 4)
        ToolTip('orange', this.ps.orange.x, this.ps.orange.y-200, 5)
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

        this.current_color := this.ps.close_green.state ? 'G' : this.ps.close_red.state ? 'R' : '?'    
        this.candle_data[1].colors.Push(this.current_color)
        if Mod(A_Sec, 15) >= 12 {
            this.candle_data[1].colors_12.Push(this.current_color)
        }
        if this.current_color != this.candle_data[1].color_changes[-1]
            this.candle_data[1].color_changes.Push(this.current_color)

        if (Mod(A_Sec, 15) >= 13) {
            _timeframe := Utils.get_timeframe()
            if _timeframe != this.candle_data[1].timeframe {
                this.candle_data.InsertAt(1, {color: this.current_color, timeframe: _timeframe, colors: [this.current_color], color_changes: [this.current_color], H: this.candle_data[1].C, L: this.candle_data[1].C})
                while this.candle_data.Length > 7
                    this.candle_data.Pop()
            }
        }

        if (Mod(A_Sec, 15) = 14 and A_MSec >= 100) {
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
        this.paused := this.check_paused()
        this.scenario1()
        this.scenario2()
    }
    update_log() {
        global

        str_ohlc := ''
            
        str_ohlc .= this.candle_data[1].HasOwnProp('O') ? this.candle_data[1].O ' | ' : '? | '
        str_ohlc .= this.candle_data[1].HasOwnProp('H') ? this.candle_data[1].H ' | ' : '? | '
        str_ohlc .= this.candle_data[1].HasOwnProp('L') ? this.candle_data[1].L ' | ' : '? | '
        str_ohlc .= this.candle_data[1].HasOwnProp('C') ? this.candle_data[1].C ' | ' : '? | '

        date := FormatTime(this.datetime, 'MM/dd')
        time := FormatTime(this.datetime, 'hh:mm:ss') '.' substr(Round(A_MSec/100), 1, 1)
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
            streaks_str .= k '[' v '] '
        }
        
        this.debug_str := 'ps: ' this.ps.blue.state ' ' this.ps.orange.state ' | diff: ' (this.ps.blue.state and this.ps.orange.state ? this.ps.orange.y - this.ps.blue.y : 0) ' | '
        ; this.debug_str := 'G: ' (this.ps.orange.state and this.ps.close_green.state ? this.ps.close_green.y - this.ps.orange.y : 0) ' | R: ' (this.ps.orange.state and this.ps.close_red.state ? this.ps.orange.y - this.ps.close_green.y : 0) ' | ' this.debug_str
        _a := this.ps.g_touch_blue.state and this.ps.g_touch_orange.state ? '2lines: BUY' : this.ps.r_touch_blue.state and this.ps.r_touch_orange.state ? '2lines: SELL' : ''
        this.debug_str := _a ' | ' this.debug_str
        this.debug_str := this.crossovers_arr.Length > 0 ? 'last CO: ' this.crossovers_arr[-1].direction '(' Format('{:.1f}', (A_TickCount - this.crossovers_arr[-1].time)/1000) ')' ' | ' this.debug_str : this.debug_str
        _ := ''
        for val in this.candle_data {
            if A_Index > 3 {
                _ := RTrim(_, '|')
                break
            }
            _ .= val.color '(' SubStr(val.timeframe, -2) ')|'
        }
        if this.crossovers_arr.Length > 1 {
            this.debug_str := this.current_color ' (' A_TickCount - this.crossovers_arr[-1].time ') | ' _ ' | ' this.debug_str
        } else {
            this.debug_str := _ ' | ' this.debug_str
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
            str.next_bal := '$' v[2]+1 ': ' v[1]
        }

    
        loop {
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
                    '(' this.stats.streak ') ' this.active_trade countdown_close_str ' | ' paused_str ',' 
                    format('{:.2f}', this.amount) ',' 
                    this.balance.current ' (' this.balance.max ' | ' this.balance.min ')' ',' 
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
    execute_trade(action, reason) {
        global
        this.active_trade := ''
        this.balance.last_trade := this.balance.current - this.amount
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)
            sleep 100
        }
        if this.balance.current < 1 {
            MsgBox('0 Balance.')
            exitapp
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
        ; this.balance := this.check_balance(this.balance)
    }     

    pixels_search() {
        this.ps.blue :=     {state: false}
        this.ps.orange :=     {state: false}
        this.ps.close_green :=     {state: false}
        this.ps.close_red :=     {state: false}
        this.ps.open :=     {state: false}
        this.ps.g_touch_blue :=     {state: false}
        this.ps.g_touch_orange :=   {state: false}
        this.ps.r_touch_blue :=     {state: false}
        this.ps.r_touch_orange :=   {state: false}

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
            Loop {
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
                this.reload_website()
            }
            this.coords.area.x2 := this.coords.area.x - 2
            ; this.debug_str := 'ps: ' this.ps.blue.state ' ' this.ps.orange.state ' | diff: ' (this.ps.blue.state and this.ps.orange.state ? this.ps.orange.y - this.ps.blue.y : 0) ' | '
            ; ToolTip('(' A_Sec '.' A_MSec ')' this.debug_str '`nCurrent this.last_trade: ' this.last_trade '`nCurrent balance: ' format('{:.2f}', balance.current), 5, 5, 11)
            return false
        }

        if this.ps.blue.state and this.ps.orange.state {
            this.ps.g_touch_blue := {state: PixelSearch(&x, &y, this.ps.blue.x+4, this.ps.blue.y+4, this.ps.blue.x+2, this.ps.blue.y-4, this.colors.green, 5), x:x, y:y}
            this.ps.g_touch_orange := {state: PixelSearch(&x, &y, this.ps.orange.x+4, this.ps.orange.y+4, this.ps.orange.x+2, this.ps.orange.y-4, this.colors.green, 5), x:x, y:y}
            this.ps.r_touch_blue := {state: PixelSearch(&x, &y, this.ps.blue.x+4, this.ps.blue.y+4, this.ps.blue.x+2, this.ps.blue.y-4, this.colors.red, 5), x:x, y:y}
            this.ps.r_touch_orange := {state: PixelSearch(&x, &y, this.ps.orange.x+4, this.ps.orange.y+4, this.ps.orange.x+2, this.ps.orange.y-4, this.colors.red, 5), x:x, y:y}
        }

        ToolTip(,,, 12)
        return true
    }

    get_amount(val) {
        for tresh in this.amounts_tresholds {
            if val >= tresh[1]
                return tresh[2]
        }
        return 1
    }

    reload_website() {
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 100
        }
        sleep 80
        Send('^r')
        sleep 5000
        this.check_balance(this.balance)
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
            if !ClipWait(0.5) {
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
            if cur_bal > _balance.last_trade + 0.5 and this.stats.streak < 0 and not this.trade_opened[1] {
                if cur_bal < _balance.last_trade + this.amount*1.4 {
                    sleep 10
                    ; this.stats.streak++
                    ; this.stats.draw++
                } else {
                    this.stats.streak := 1
                    this.stats.win++
                    this.stats.loss--
                    this.amount := this.get_amount(cur_bal)
                    if this.stats.streak <= 3
                        this.amount := this.amount_arr[this.get_amount(this.balance.current+this.amount*2.2)][this.stats.streak+1]
                }
                this.set_amount(this.amount)
                _balance.last_trade := cur_bal
            }
            _balnew := {current: cur_bal, last_trade: _balance.last_trade, max: Format('{:.2f}', max(cur_bal, _balance.max)), min: Format('{:.2f}', min(cur_bal, _balance.min))}
            return _balnew
        }
    }
}

