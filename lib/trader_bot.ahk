#Requires AutoHotkey v2.0
#Include OCR.ahk
#Include utils.ahk
;{
scriptPath := A_LineFile
modTime := FileGetTime(scriptPath, "M")
formatted := FormatTime(modTime, "yyyy-MM-dd HH:mm:ss")
traymenu := A_TrayMenu
traymenu.Add("Last Modified: " formatted, (*) => '')
/*
tester(tst) {
    static inst := {streak: 1, amt: 1, level: 3}
    static streak_prev_list := [1]
    if tst = 1 {
        if inst.streak < 0
            inst.streak := 0
        inst.streak++
    }
    if tst = 0 {
        if inst.streak > 0
            inst.streak := 0
        inst.streak--
    }
    streak := inst.streak
    
    if true {
        if inst.streak = 1 {
            inst.amt := Helper0811_4Loss.Tier3CustomAt2('resetidx', 3)
            inst.level := 3
        } else {
            if streak = streak_prev_list[1]
                inst.amt := Helper0811_4Loss.Tier3CustomAt2('draw')
            else if streak < 0
                inst.amt := Helper0811_4Loss.Tier3CustomAt2()
        }
    }
    streak_prev_list.InsertAt(1, streak)
    tooltip inst.streak ' = ' inst.amt
}

F1:: {
    tester(1)
}

F2:: {
    tester(0)
}

F3:: {
    tester(2)
}
*/

;}

Helper_Skip(streak, only_read:=false, just_check:=false) {
    static last_streak := 0
    static streak_skipped := 0
    static repeat_flag := 0
    
    if only_read {
        if streak = last_streak and repeat_flag > 0 {
            return 1
        }
        return 0
    }

    if streak > 0 {
        last_streak := 0
        streak_skipped := 0
    }

    if streak <= -3 and Mod(-streak, 2) = 1 {
        if streak = streak_skipped {
            return 0
        }
        if just_check {
            if repeat_flag
                return 1
            return 0
        }
        repeat_flag++
        last_streak := streak
        if repeat_flag > 1 {
            repeat_flag := 0
            streak_skipped := last_streak
            return 0
        }
        return 1
    }

    return 0
}

ClickOnPage(text, press_enter:=true, tabs:=0) {
    default_delay1 := 200
    default_delay2 := 300
    SendEvent('^f')
    sleep default_delay1
    SendEvent('^a{Delete}')
    sleep default_delay1
    SendEvent(text)
    sleep default_delay2
    SendEvent('{Enter}{Escape}')
    sleep default_delay1
    if press_enter {
        SendEvent('{Enter}')
        sleep default_delay1
    }
    if tabs > 0 {
        SendEvent('{Tab ' tabs '}')
        sleep default_delay1
    }
}

class Helper0811_4Loss {
    static _inst := {amt:1, streak:0, level:1, wins:0, idx_loss:0, state_tier3:0}

    static Update(streak, streak_prev_list, max_bal_diff) {
        inst := Helper0811_4Loss._inst
        inst.amt := 1
        inst.streak := streak

        amts := [[1.40, 2.02, 4.39, 9.26],
                 [20.05, 30.66, 64.10, 133.88],
                 [279.51, 583.44, 1217.72, 2541.44],
                 [60.0, 120.0, 240.0, 500],
                 [23.95, 51.06, 108.0, 748.0],
                 [51.06, 108.0, 226.0, 1890.0],
                 [108, 226, 473, 5000]]
        
        ; if max_bal_diff <= 40 and inst.level > 1 {
        ;     return Helper0811_4Loss.Reset()
        ; }
        ; if max_bal_diff <= 20 and inst.level = 4 {
        ;     inst.level := 1
        ;     Helper0811_4Loss.Tier3CustomAt2('reset')
        ;     return inst
        ; }
        if streak = 1 and streak != streak_prev_list[1] and inst.level > 1 {
            Helper0811_4Loss.Tier3CustomAt2('resetidx')
            inst.wins++
            inst.idx_loss := 0
        }

        if (streak_prev_list[1] = -4 and streak != streak_prev_list[1]) {
            if inst.streak < -4 {
                inst.streak := -1
                inst.level := Min(amts.Length, inst.level + 1)
                inst.wins := 0
            } else if inst.level = 2 {
                if max_bal_diff <= 0 {
                    inst.level := 1
                    inst.wins := 0
                } else {
                    inst.level := 2
                }
            } else if inst.level = 3 {
                inst.level := Min(amts.Length, inst.level + 1)
                inst.wins := 0
            } else if inst.streak = 1 {
                ; inst.level := 1
                inst.wins := 0
                inst.idx_loss := 0
            }
        }

        if (inst.streak < 0)
            inst.amt := amts[inst.level][-inst.streak]
        
        if inst.wins = 0 {
            if inst.level = 3 and inst.streak = -1 {
                inst.idx_loss := 1
                ; inst.amt := (max_bal_diff + 5*inst.idx_loss)/0.92
            } else if inst.level >= 3 and streak != streak_prev_list[1] and streak < 0 {
                inst.amt := (max_bal_diff + 5*inst.idx_loss)/0.92
                inst.idx_loss++
            }
        }

        ; if inst.state_tier3 = 0 and inst.streak = -1 and inst.level = 3 {
        ;     inst.state_tier3 := 1
        ; }

        ; if inst.state_tier3 = 1 {
        ;     if inst.streak = 1 {
        ;         inst.amt := Helper0811_4Loss.Tier3CustomAt2('resetidx', 1)
        ;         inst.level := 3
        ;     } else {
        ;         if streak = streak_prev_list[1]
        ;             inst.amt := Helper0811_4Loss.Tier3CustomAt2('draw')
        ;         ; else if streak < 0 and streak_prev_list[2] > 0
        ;         ;     inst.amt := Helper0811_4Loss.Tier3CustomAt2(, 'tier3loss')
        ;         else if streak < 0
        ;             inst.amt := Helper0811_4Loss.Tier3CustomAt2()
        ;     }
        ; }
        
        return inst
    }

    static Tier3CustomAt2(state:='', state2:=0) {
        static idx := 0
        static count_loss_at_tier3 := 0
        static amts := []

        if amts.Length < 10 {
            amts := [1.3]
            amts.Push(2)
            Loop 100 {
                amts.Push(amts[-1]*2.2)
            }
        }
         
        if state2 {
            if state2 = 'tier3loss' {
                count_loss_at_tier3++
            }
            amts := [1.25, 2.20, 4.55, 10.10, 22.00]
            Loop 5 {
                amts[A_Index] := amts[A_Index]*count_loss_at_tier3+1
            }
            amts.Push(2)
            Loop 100 {
                amts.Push(amts[-1]*2.2)
            }
        }

        if state != 'draw' {
            idx++
        }

        if state = 'resetidx' {
            idx := 0
        } else if state = 'reset' {
            idx := 0
            count_loss_at_tier3 := 0
            amts := []
            return 1
        }

        return amts[Max(idx, 1)]
    }

    static Get() {
        return Helper0811_4Loss._inst
    }

    static SetLevel(level) {
        Helper0811_4Loss._inst.level := level
        return Helper0811_4Loss._inst
    }

    static Reset() {
        Helper0811_4Loss._inst := {amt:1, streak:0, level:1, wins:0, idx_loss:0, state_tier3:0}
        Helper0811_4Loss.count_loss_at_tier3 := 0
        Helper0811_4Loss.Tier3CustomAt2('reset')
        return Helper0811_4Loss._inst
    }
}

class TraderBot {
    __New(settings_obj) {
        this.settings_obj := settings_obj
        this.wtitle := WinExist(settings_obj.wtitle)
        this.coords := settings_obj.coords
        this.colors := settings_obj.colors
        this.ps := Map()

        this.balance := {current: 0, min: 999999999, max: 0, last_trade: 0}
        this.balance.starting := 1200
        this.balance.reset_max := this.balance.starting + 500
        ; this.balance.reset_max := this.balance.starting*2
        this.amount_arr := []
        this.amount_arr.Push([1, 1.80, 3.80, 8, 16.7, 35, 73, 153, 316, 670, 1350])
        
        this.win_amounts := [[1.1, 2.25, 1.5, 1.5, 1.1, 2.25, 1.5, 1.5, 1.1, 2.25, 1.5]]
        for v in this.win_amounts[1].Clone()
            this.win_amounts[1].Push(v)
        for v in this.win_amounts[1].Clone()
            this.win_amounts[1].Push(v)

        this.amounts_tresholds := [[0, 1]]

        Loop 10 {
            _index := A_Index
            if this.amount_arr.Length < A_Index
                this.amount_arr.Push([A_Index])
            while this.amount_arr[_index].Length < 20 {
                total := 0
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
        this.executed_trades := ['']
        this.countdown_close := 0
        this.countdown_close_str := ''
        this.win_rate := ''
        this.debug_str := ''
        this.stats := {trade_history: [''], bal_mark: 0, bal_win: 0, bal_lose: 0, streak: 0, streak2: 0, win: 0, loss: 0, draw: 0, win_rate: 0, reset_date: 0}
        this.stats.bal_win := 0
        this.stats.max_bal_diff := 0
        this.candle_data := [{both_lines_touch: false, blue_line_y: [], color: '?', colors: [], colors_12: [], color_changes: ['?'], timeframe: Utils.get_timeframe(), moving_prices: [0]}]
        
        this.lose_streak := {max: 0, repeat: Map()}
        this.paused := false
        this.blockers := Map()
        this.state := {coin_change_streak: false, 5loss: false, 32:false}
        this.min_x := this.coords.area.x - 50
        this._time := 15
        this._time += 4
        this.payout := 92
        this.datetime := A_Now
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
        this.coin_name := OCR.FromRect(this.coords.coin.x - 15, this.coords.coin.y - 15, 130, 40).Text
        this.marked_time_refresh := A_TickCount
        
        this.pause_based_on_timeframe := ''
        this.qualifiers := {}
        this.streak_prev := []
        this.QualifiersReset()
        this.amount := this.GetAmount(this.balance.current)

        if !FileExist(this.log_file) {
            FileAppend('date,time,active_trade,max_diff,side_bal,balance,next_target,last_trade,amount,payout,Streak (W|D|L|win_rate),Streaks,OHLC,debug`n', this.log_file)
        }
    }

    AmountOverride(amt_prev) {
        CUSTOM_LOSS_STREAK_START := -5
        streak := this.stats.streak
        ; if streak <= -5 {
        ;     this.qualifiers.random_trade.state := false
        ; }

        if this.stats.max_bal_diff >= 100 {
            this.amount_override.win2.state := 1
        }
        if this.stats.max_bal_diff <= 0 {
            this.amount_override.win2.state := 0
        }

        ; if this.amount_override.win2.state = 1 {
        ;     for helper in [_helper_4_175, _helper_1, _helper_A] {
        ;         if amt := helper()
        ;             return amt
        ;     }
        ;     return 1
        ; }
        
        for helper in [_helper0811_4Loss] {
            if return_val := helper() {
                return return_val
            }
        }
        
        return 0

        _helper0811_4Loss() {
            Helper0811_4Loss.Update(streak, this.streak_prev, this.stats.max_bal_diff)
            this.stats.streak := Helper0811_4Loss.Get().streak

            inst := Helper0811_4Loss.Get()
            if inst.level >= 2 {
                if (inst.level = 2 and streak = -4) {
                    this.qualifiers.flip_trade.state := false
                    this.qualifiers.random_trade.state := false
                } else if (inst.level = 2 and streak <= -2) {
                    this.qualifiers.flip_trade.state := true
                } else {
                    if not this.qualifiers.random_trade.state and streak >= 1 {
                        this.qualifiers.random_trade.state := true
                        this.qualifiers.flip_trade.state := true
                    }
                }
            }

            if Helper0811_4Loss.Get().level = 2 {
                if streak = 1 and streak != this.streak_prev[1] {
                    this.ChangeCoin()
                }
                if streak = -2 {
                    this.qualifiers.flip_trade.state := true
                    this.qualifiers.flip_trade.marked_winrate := this.stats.win_rate
                }
                if this.stats.max_bal_diff <= 0 {
                    Helper0811_4Loss.Reset()
                }
            }
            
            if this.qualifiers.flip_trade.state = 1 and this.stats.win_rate >= this.qualifiers.flip_trade.marked_winrate + 0.8 {
                ; this.qualifiers.flip_trade.state := false
                this.qualifiers.flip_trade.marked_winrate := 0
            }
            ; if streak <= -9 and streak >= -11 {
            ;     if this.qualifiers.flip_trade.state = 1
            ;         this.qualifiers.flip_trade.state := 'temp'
            ;     this.qualifiers.random_trade.state := false
            ;     return Helper0811_4Loss.Get().amt/2
            ; } else {
            ;     if this.qualifiers.flip_trade.state = 'temp'
            ;         this.qualifiers.flip_trade.state := false
            ; }
            if not this.qualifiers.custom_switch.state and inst.level >= 2 and inst.streak <= -2 {
                this.qualifiers.custom_switch.state := true
            }
            switch {
                case inst.level = 1 and inst.streak = -2:
                    return (this.stats.max_bal_diff+0.40)/0.92
                case inst.level = 1 and inst.streak = -3:
                    return (this.stats.max_bal_diff+1)/0.92
                case inst.level = 1 and inst.streak = -4:
                    return (this.stats.max_bal_diff+2.5)/0.92
                case inst.level = 2 and inst.streak = -1:
                    return (this.stats.max_bal_diff+6.25)/0.92
            }
            if inst.level >= 2 and this.qualifiers.custom_switch.state {
                if (inst.level = 2 and inst.streak = -3) {
                    return this.stats.max_bal_diff*0.25
                }
                if (inst.streak < 0) {
                    if Mod(inst.streak, 2) = 0 {
                        return this.stats.max_bal_diff*0.05
                    } else {
                        return (this.stats.max_bal_diff+5)/0.92
                    }
                }
            }
            return Helper0811_4Loss.Get().amt
        }

        _helper_2610() {
            streak := this.stats.streak
            if streak < 0 {
                amts := [1.35, 1.79, 3.85, 8.14, 17.10, 35.80, 74.82, 156.25, 326.20, 680.87, 1421.05, 2966.00]
                if Helper_Skip(streak) {
                    return 1
                }
                return amts[Min(-streak, amts.Length)]
            }
            return 1
        }

        _helper_4_175() {
            streak := this.stats.streak
            streak_prev := this.streak_prev[1]
            qual := this.amount_override.helper4

            if (this.stats.max_bal_diff >= 175) and !qual.state {
                qual.state := 1
            }
            if !qual.state
                return 0

            amts_lose := [1]
            loop 20 {
                amts_lose.Push(amts_lose[-1]*3)
            }
            
            if streak = 1 {
                if streak_prev = -1 and this.streak_prev[2] > 0 {
                    return 100
                }
            }
            if streak < 0 {
                return amts_lose[-streak]
            }
            return 1
        }

        _helper_3_175() {
            streak := this.stats.streak
            qual := this.amount_override.helper3
            streak_prev := this.streak_prev[1]

            amts_win := [7, 30, 62, 130]
            amts_win := [1]
            amts_lose := [8,31,63,131]
            
            if (this.stats.max_bal_diff >= 175) and !qual.state {
                qual.state := 1
            }
            if !qual.state
                return 0
            ; if qual.countWin1 > 4 or qual.countLose1 > 4 {
            if qual.countLose1 > 4 {
                qual.state := 'pause'
                qual.countWin1 := 1
                qual.amtWin1 := amts_win[1]
                qual.countLose1 := 1
                qual.amtLose1 := amts_lose[1]
            }
            if qual.state = 'pause' {
                if streak = 1 and streak_prev = -1 and this.streak_prev[2] = 1 {
                    qual.state := 1
                }
                return 1
            }

            if streak = 2 and streak_prev = 1 {
                qual.countWin1 := 1
                qual.amtWin1 := amts_win[1]
                return 1
            }
            if streak = -2 and streak_prev = -1 {
                qual.countLose1++
                qual.amtLose1 := amts_lose[Min(qual.countLose1, amts_lose.Length)]
                return 1
            }
            if streak = 1 {
                if streak_prev = -1 {
                    qual.countLose1 := 1
                    qual.amtLose1 := amts_lose[1]
                }
                return qual.amtWin1
            }
            if streak = -1 {
                if streak_prev = 1 {
                    qual.countWin1++
                    qual.amtWin1 := amts_win[Min(qual.countWin1, amts_win.Length)]
                }
                return qual.amtLose1
            }
            return 1
        }

        _helper_B_amt70() {
            if this.amount_override.lastAmount70 > 0 {
                if this.stats.streak = -1 {
                    if this.amount_override.lastAmount70 >= 70 {
                        this.amount_override.lastAmount70 := this.amount_override.lastAmount70*0.15
                    }
                    return this.amount_override.lastAmount70
                }
                if this.stats.streak = 1 {
                    return this.amount_override.lastAmount70*0.25
                }
                if this.stats.streak <= -2 and this.stats.streak > CUSTOM_LOSS_STREAK_START {
                    if this.stats.streak = -2 {
                        this.amount_override.lastAmount70 := this.amount_override.lastAmount70*2.5
                    }
                    return 1
                }
                if this.stats.streak = 2 {
                    this.amount_override.lastAmount70 := 0
                }
            }
            return 0
        }

        _helper_C() {
            if this.stats.streak = -1 or this.stats.streak = 1 {            
                if this.streak_prev[1] = -this.stats.streak {
                    this.amount_override.amountAt1 := this.amount_override.amountAt1*2.5
                } else if this.streak_prev[1] = this.stats.streak {
                    ; IGNORED: Same streak value
                } else if this.streak_prev[1] < 0 {
                    if amt_prev > 100
                        this.amount_override.amountAt1 := amt_prev*0.3
                    else if amt_prev > 1
                        this.amount_override.amountAt1 := amt_prev*0.5
                } else if this.streak_prev[1] > 0 {
                    this.amount_override.amountAt1 := amt_prev*2.5
                }

                if this.amount_override.amountAt1 >= 70 and this.stats.streak = -1 {
                    this.amount_override.lastAmount70 := this.amount_override.amountAt1
                    return this.amount_override.lastAmount70*0.15
                }
                return this.amount_override.amountAt1
            ; } else if this.stats.streak <= CUSTOM_LOSS_STREAK_START {
            ;     if this.stats.streak < -8 {
            ;         return 1
            ;     }
            ;     amts := [4.5, 25, 50, 150, 25]
            ;     loop 20 {
            ;         amts.Push(amts[-1]*2.5)
            ;     }
            ;     return amts[1 + (-this.stats.streak ) - (-CUSTOM_LOSS_STREAK_START)]
            } else {
                if this.stats.streak = 2 {
                    this.amount_override.amountAt1 := 2
                }
                if this.stats.streak >= 2 {
                    list := [7, 3, 1.5]
                    return list[Mod(this.stats.streak-1-1, list.Length)+1]
                }
                return 1
            }
            return 0
        }

        _helper_A() {
            if this.stats.streak = -1 and this.streak_prev[1] = 2 {
                this.amount_override.win2.count_loss++
            }
            if this.stats.streak = 3 {
                if this.streak_prev[1] != this.stats.streak
                    this.amount_override.win2.count_win++
                this.amount_override.win2.count_loss := 0
                if this.amount_override.win2.count_win >= 5 {
                    this.amount_override.win2.count_win := 0
                    this.amount_override.win2.count := 0
                    this.amount_override.win2.multiplier := 2.25
                }
                return 1
            }
            if this.stats.streak = 2 {
                if this.amount_override.win2.count_loss >= 2 {
                    this.amount_override.win2.multiplier := 2.65
                    return 1
                }
                if this.streak_prev[1] != this.stats.streak
                    this.amount_override.win2.count++
                amts := [2.25]
                loop 30 {
                    if A_Index >= this.amount_override.win2.count
                        amts.Push(amts[-1]*this.amount_override.win2.multiplier)
                    else
                        amts.Push(amts[-1]*2.25)
                }
                return amts[this.amount_override.win2.count]
            }
            ; if this.stats.streak > CUSTOM_LOSS_STREAK_START {
                return 1
            ; }
        }

        _helper_1() {
            streak := this.stats.streak
            qual := this.amount_override.lose12
            if streak = -1 or streak = -2 {
                if qual.losses_ina_row >= 2
                    return 1
                return qual.%-streak%
            }
            if streak = -2 and this.streak_prev[1] != streak {
                qual.1 := qual.1*2.5
            }
            if streak = -3 and this.streak_prev[1] != streak {
                qual.losses_ina_row++
                qual.2 := qual.2*2.5
            }
            if streak = 2 {
                if qual.losses_ina_row < 2
                    qual := Constants.GetAmounts3()
                else
                    qual.losses_ina_row := 0
            }
            return 0
        }

        _helper_2_8lose_225() {
            streak := this.stats.streak
            qual := this.amount_override.lose8
            if (streak = -8 and this.streak_prev[1] != streak) or (this.stats.max_bal_diff >= 225) {
                qual.state := 1
            }

            if !qual.state
                return 0

            if streak = -1 or streak = -2 {
                if qual.losses_ina_row.%-streak% >= 2
                    return 1
                return qual.%-streak%
            }
            if streak = -3 {
                qual.losses_ina_row.1++
                qual.losses_ina_row.2++
            }
            if streak = 2 {
                qual.losses_ina_row.1 := 0
                qual.losses_ina_row.2 := 0
            }
            if qual.losses_ina_row.1 = 0 and qual.losses_ina_row.2 = 0 {
                qual := Constants.GetAmounts4()
            }
            return 1
        }

    }

    CheckTradeClosed(just_check:=false) {
        if not this.trade_opened[1] and not just_check {
            return false
        }
        
        MouseClick('L', this.coords.trades_opened.x + Random(-2, 2), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
        sleep 50
        loop 3 {
            if PixelSearch(&x, &y, this.coords.detect_trade_open1.x, this.coords.detect_trade_open1.y, this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, this.colors.green2, 30) {
                return false
            }
            sleep 50
        }
        sleep 500
        
        if just_check
            return true
        
        this.active_trade := ''
        this.trade_opened[1] := false
        this.CheckBalance()
        if this.balance.current > this.balance.last_trade + 0.5 {
            win := {ps:true}
            draw := {ps:true}
        } else if this.balance.current < this.balance.last_trade - 0.5 {
            win := {ps:false}
            draw := {ps:false}
        } else {
            win := {ps:false}
            draw := {ps:true}
        }
        this.balance.last_trade := this.balance.current 

        this.streak_prev.InsertAt(1, this.stats.streak)
        while this.streak_prev.Length >= 10 {
            this.streak_prev.Pop()
        }
        amt_prev := this.amount
        if not win.ps and not draw.ps {
            if Helper_Skip(this.stats.streak,, true) {
                TradeLose(false)
            } else {
                TradeLose()
            }
        } else if win.ps {
            if Helper_Skip(this.stats.streak,, true) {
                TradeWin(false)
            } else {
                TradeWin()
            }
        } else if draw.ps {
            TradeDraw()
        }
        this.stats.win_rate := this.stats.win > 0 ? this.stats.win/(this.stats.win+this.stats.loss+this.stats.draw)*100 : 0

        if amt := this.AmountOverride(amt_prev)
            this.amount := amt
        
        ; if draw.ps and not win.ps {
        ;     this.amount := amt_prev
        ; }
        this.SetTradeAmount()
        this.stats.%this.executed_trades[1]%.win_rate := Round(this.stats.%this.executed_trades[1]%.win / max(this.stats.%this.executed_trades[1]%.win + this.stats.%this.executed_trades[1]%.lose, 1) * 100, 1)
        RankScenarios()

        RankScenarios() {
            sortableArray := ''
            For key, value in this.stats.OwnProps() {
                if !InStr(key, 'BUY') and !InStr(key, 'SELL')
                    continue
                if !this.stats.%key%.HasOwnProp('rank')
                    this.stats.%key%.rank := 0
                sortableArray .= Format('{:.1f}', value.win_rate) ',' value.rank ',' key '`n'
            }
            sortableArray := Sort(sortableArray, 'R')

            for v in StrSplit(sortableArray, '`n') {
                try
                    key := StrSplit(v,',')[3]
                this.stats.%key%.rank := A_Index
            }
        }

        TradeLose(streak_change:=true) {
            if this.stats.G_balance.state {
                this.stats.G_balance.val += this.amount
            }
            this.stats.%this.executed_trades[1]%.lose++
            this.stats.trade_history.InsertAt(1, 'lose')
            if this.stats.streak > 0 and this.qualifiers.win_amount_modifier.state = 1 {
                _num := Mod(this.stats.streak - 1, 4) + 1
                this.qualifiers.win_amount_modifier.amounts[_num] := this.qualifiers.win_amount_modifier.amounts[_num]*2+1
            }

            while this.stats.trade_history.Length > 10
                this.stats.trade_history.Pop()
            
            if this.stats.streak < 0 {
                if not this.lose_streak.repeat.Has(this.stats.streak) {
                    this.lose_streak.repeat[this.stats.streak] := {win: 0, lose: 0}
                }
                this.lose_streak.repeat[this.stats.streak].lose++
            }

            if streak_change {
                if this.stats.streak >= 0
                    this.stats.streak := 0
                this.stats.streak--
            }

            if this.balance.current <= this.qualifiers.loss_amount_modifier.balance - 1000 {
                this.qualifiers.loss_amount_modifier.balance -= 1000
                this.qualifiers.loss_amount_modifier.streak := Min(this.qualifiers.loss_amount_modifier.streak + 1, -3)
            }

            if this.stats.streak < 0
                this.amount := LossModifier()

            this.stats.loss++

            LossModifier() {
                qual := this.qualifiers.loss_amount_modifier
                if this.stats.streak >= -3 {
                    if qual.state1 = 0 {
                        if this.stats.streak = -3 {
                            qual.amounts[1] := qual.amounts[1]*2+1
                            qual.amounts[2] := qual.amounts[2]*2+1
                            qual.state_2ndloss[1]++
                            qual.state_2ndloss[2]++
                        }
                        if qual.state_2ndloss[2] >= 2 and this.stats.streak = -3 {
                            qual.state1 := 1
                        }
                        return qual.amounts[-this.stats.streak]
                    } else if qual.state1 = 1 {
                        amts := Constants.GetAmounts2()
                        if this.stats.streak = -3 {
                            qual.idx[2]++
                            return qual.amounts[-this.stats.streak]
                        } else {
                            return amts[-this.stats.streak][Min(qual.idx[2], amts[-this.stats.streak].Length)]
                        }
                    }
                } else {
                    amts := [qual.amounts[3]*2+2, qual.amounts[3]*2+2]
                    loop 15 {
                        amts.Push(amts[-1]*2+2)
                    }
                    return amts[-this.stats.streak-3]
                }
            }
        }

        TradeWin(streak_change:=true) {
            if this.stats.G_balance.state {
                this.stats.G_balance.val -= this.amount*0.92
            }
            qual := this.qualifiers.loss_amount_modifier
            if this.stats.streak = -1 or this.stats.streak = -2 {
                if qual.state_2ndloss[-this.stats.streak] < 2
                    qual.state_2ndloss[-this.stats.streak] := 0
                
                if this.stats.streak = -2 and qual.state1 = 1 {
                    qual.idx[2] := Max(qual.idx[2]-1, 1)
                }
            }
            if this.stats.streak < 0 and this.stats.streak >= -3 {
                qual.amounts[-this.stats.streak] := Constants.GetAmounts1()[-this.stats.streak]
            }

            if this.balance.current >= this.qualifiers.loss_amount_modifier.balance + 1000 {
                this.qualifiers.loss_amount_modifier.balance += 1000
                this.qualifiers.loss_amount_modifier.streak--
            }
            if this.stats.streak = -1 {
                this.qualifiers.loss_amount_modifier.amount_1 := (0.10*(this.stats.max_bal_diff)) / 0.92
            }
            if this.stats.streak = -2 {
                this.qualifiers.loss_amount_modifier.amount_2 := (0.10*(this.stats.max_bal_diff)) / 0.92
            }
            
            this.stats.trade_history.InsertAt(1, 'win')
            while this.stats.trade_history.Length > 10
                this.stats.trade_history.Pop()
            if this.balance.current >= this.qualifiers.balance_mark.mark + 100 and this.balance.current < this.qualifiers.balance_mark.mark_starting + 1750 {
                this.qualifiers.balance_mark.mark += 100
                ; this.qualifiers.balance_mark.count := 0
                this.qualifiers.streak_reset.val := -4
            }
            this.stats.%this.executed_trades[1]%.win++
 
            if this.stats.streak = this.qualifiers.streak_reset.val {
                if this.qualifiers.streak_reset.val = -2 {
                    this.qualifiers.streak_reset.trade_history.InsertAt(1, 'win')
                    while this.qualifiers.streak_reset.trade_history.Length > 10
                        this.qualifiers.streak_reset.trade_history.Pop()
                    if this.qualifiers.streak_reset.count2 < 0
                        this.qualifiers.streak_reset.count2 := 0
                    this.qualifiers.streak_reset.count2++
                }
            }

            if this.stats.G_balance.state and this.stats.G_balance.val <= 0 {
                ; this.amount_arr[1].RemoveAt(1, 4)
                this.stats.G_balance.state := false
                this.stats.G_balance.val := 0
                this.stats.G_balance.count := 0
            }

            if this.stats.max_bal_diff <= this.qualifiers.pause_temp.reset_F {
                this.qualifiers.win_after_31 := false
                this.QualifiersReset()
            }

            if this.amount >= 31 and this.stats.max_bal_diff <= 100 {
                this.qualifiers.win_after_31 := true
                this.qualifiers.pause_temp.amount := this.stats.max_bal_diff
            }

            list := [1, 10, 7, 3]
            _num := Mod(this.stats.streak - 1, list.Length) + 1
            if this.stats.streak > 0 {
                this.qualifiers.win_amount_modifier.amounts[_num] := list[_num]
            }

            if streak_change {
                if this.stats.streak < 0 {
                    if not this.lose_streak.repeat.Has(this.stats.streak) {
                        this.lose_streak.repeat[this.stats.streak] := {win: 0, lose: 0}
                    }
                    this.lose_streak.repeat[this.stats.streak].win++
                    this.stats.streak := 0
                }
                this.stats.streak++
            }
            this.stats.win++

            if this.stats.streak > 0 {
                _num := Mod(this.stats.streak - 1, list.Length) + 1
                
                if this.stats.max_bal_diff < 150 and this.qualifiers.custom_amount_modifier.state = 150
                    this.qualifiers.custom_amount_modifier.state := 130
                
                this.amount := this.win_amounts[1][this.stats.streak]
                if this.qualifiers.win_amount_modifier.state = 1 {
                    this.amount := this.qualifiers.win_amount_modifier.amounts[_num]
                }
            }
        }

        TradeDraw() {
            this.stats.trade_history.InsertAt(1, 'draw')
            while this.stats.trade_history.Length   > 10
                this.stats.trade_history.Pop()
            this.stats.%this.executed_trades[1]%.draw++
            this.stats.draw++
        }
    }

    ChangeCoin(_random:=true) {
        ToolTip('CHANGING COIN... ' A_Index, 500, 5, 12)
        MouseClick('L', this.coords.coin.x + Random(-2, 2), this.coords.coin.y + Random(-2, 2), 1, 2)
        sleep 100
        MouseClick('L', this.coords.cryptocurrencies.x + Random(-2, 2), this.coords.cryptocurrencies.y + Random(-2, 2), 1, 2)
        sleep 100
        _count_reload := 0
        Loop {
            _count_reload++
            if _count_reload > 20 {
                _count_reload := 0
                this.ReloadWebsite()
            }
            if _random {
                MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(0, 2)*28, 1, 2)
            } else {
                MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + Random(-2, 2), 1, 2)
            }
            sleep 300
            new_cname := OCR.FromRect(this.coords.coin.x - 25, this.coords.coin.y - 25, 150, 50,, 3).Text
            ToolTip('Waiting coin name change (' this.coin_name ' vs ' new_cname ') ' A_Index, 500, 5, 12)
            if this.coin_name != new_cname {
                this.coin_name := new_cname
                break
            }
        }
        sleep 100
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 2)
        sleep 500
        MouseClick('L', this.coords.time1.x + Random(-2, 2), this.coords.time1.y + Random(-2, 2), 1, 2)
        sleep 100
        MouseClick('L', this.coords.time_choice.x + Random(-2, 2), this.coords.time_choice.y + Random(-2, 2), 1, 2)
        sleep 100
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 2)
        sleep 100
        Send '{Escape}'
        sleep 500
    }

    SetTradeAmount(bal_mark:=true) {
        _count_reload := 0

        Loop {
            Send '{LCtrl up}{RCtrl up}{LShift up}{RShift up}{Alt up}{LWin up}{RWin up}'
            _count_reload++
            if _count_reload > 1000 {
                _count_reload := 0
                this.ReloadWebsite()
            }
            this.CheckBalance()
            if this.balance.current < 1 and bal_mark {
                this.stats.bal_lose++
                this.AddBalance(this.balance.starting-this.balance.current)
                BalanceReset()
            } else if this.balance.current >= this.balance.reset_max and bal_mark {
                this.stats.bal_win++
                this.stats.bal_mark += floor(this.balance.current/this.balance.starting)*this.balance.starting
                this.AddBalance(Ceil(this.balance.current/this.balance.starting)*this.balance.starting - this.balance.current)
                BalanceReset()
            }

            sleep 300
            this.amount := this.amount < 1 ? 1.25 : this.amount
            this.amount := Min(this.amount, this.balance.current)

            if !WinActive(this.wtitle) {
                WinActivate(this.wtitle)  
                sleep 100
            }
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
                _compare1 := Floor(RegExReplace(A_Clipboard, '[^\d.]'))
                _compare2 := Floor(RegExReplace(this.amount, '[^\d.]'))
                if _compare1 != _compare2 {
                    tooltip(_compare1 ' != ' _compare2)
                    sleep 300
                    continue
                }
            } catch as e {
                ToolTip(e.Message)
                sleep 300
                continue
            }
            tooltip
            sleep 80
            A_Clipboard := ''
            Send('{Tab}^f')
            sleep 80
            Send('USD{enter}{Escape}')
            sleep 50
            MouseMove(Random(-20, 20), Random(-20, 20), 4, 'R')
            return
        }

        BalanceReset() {
            this.QualifiersReset()
            this.amount := 1
            this.stats.streak := 0
            this.stats.max_bal_diff := 0
            this.SetTradeAmount()
        }

    }

    QualifiersReset() {
        Helper0811_4Loss.Reset()
        this.amount_override := {lastAmount70: 0, amountAt1: 2, win2: {count:0, count_win:0, count_loss:0, state:0, multiplier:2.25}, lose12: Constants.GetAmounts3(), lose8: Constants.GetAmounts4()}
        this.amount_override.helper3 := {state:0, amtWin1:7, amtLose1:8, countWin1:1, countLose1:1}
        this.amount_override.helper4 := {state:0}
        this.stats.G_balance := {val: 0, state: false, count: 0, mark: 0}

        this.qualifiers := {
            custom_switch: {
                state: false
            },
            random_trade: {
                state: true
            },
            streak_sc: -4000,
            streak_reset: {
                trade_history: [''],
                val: -4,           ; Consolidated from later update
                count: 0,          ; Consolidated from later update
                count2: 0          ; Consolidated from later update
            },
            1020: {
                mark: 0,           ; Consolidated from later update
                val: 10            ; Consolidated from later update
            },
            flip_trade: {
                state: false,
                marked_winrate: 0,
                count: 0
            },
            pause_temp: {
                state: false,
                count: 0,
                amount: 1,         ; Consolidated from later update
                reset_F: 10        ; Consolidated from later update
            },
            double_trade: {
                state: false,
                count: 0,
                WW: 0,
                WL: 0,
                LL: 0
            },
            win_after_31: false,
            custom_amount_modifier: {
                state: 0,          ; Consolidated from later update (from `this.qualifiers.custom_amount_modifier.state := 0`)
                count: 5
            },
            ; Note: For loss_amount_modifier and win_amount_modifier, the later lines 
            ; were setting the object keys again (state, amounts, etc.) but the object 
            ; structure was already mostly defined in the first pass. I've kept the 
            ; most complete definition and removed the duplicates.
            loss_amount_modifier: {
                idx: Map(1, 1, 2, 1),
                state_2ndloss: Map(1, 0, 2, 0), ; Map() should be a function call
                balance: this.balance.starting,
                streak: -3,
                state1: 0,
                amount_1: 1,
                amount_2: 1,
                amount_3: 20,
                amounts: Constants.GetAmounts1()
            },
            win_amount_modifier: {
                state: 0,          ; Consolidated from later update
                amounts: [1, 10, 7, 3] ; Consolidated from later update
            },
            balance_mark : {
                mark_starting:this.balance.starting, mark: this.balance.starting, count: 0
            },
        }

    }
    
    StartLoop(*) {
        ToolTip('Running...', 5, 5, 1)
        this.ReloadWebsite()
        this.CheckBalance()
        
        MsgBox("WARNING! The script will zero your balance. Make sure you're using a demo!",, "0x30 T3")
        ; MouseClick('L', this.coords.coin.x + Random(-2, 2), this.coords.coin.y + Random(-2, 2), 1, 2)
        ; sleep 100
        ; MouseClick('L', this.coords.cryptocurrencies.x + Random(-2, 2), this.coords.cryptocurrencies.y + Random(-2, 2), 1, 2)
        ; sleep 100
        ; MouseClick('L', this.coords.coin_top.x*1.8 + Random(-2, 2), this.coords.coin_top.y - 1*28, 1, 2)
        ; sleep 1000
        ; MouseClick('L', this.coords.coin_top.x + Random(-2, 2), this.coords.coin_top.y + 0*28, 1, 2)
        ; sleep 1000
        ; MouseClick('L', this.coords.coin_top.x*1.8 + Random(-2, 2), this.coords.coin_top.y + 1*28, 1, 2)
        ; sleep 1000
        MouseClick('L', this.coords.empty_area.x + Random(-2, 2), this.coords.empty_area.y, 1, 2)
        sleep 300


        while this.balance.current > this.balance.starting {
            this.amount := 20000
            this.SetTradeAmount(false)
            sleep 200
            MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,3,2)
            sleep 600
            this.ExecuteTrade(['SELL', 'BUY'][Random(1,2)], 'STARTING')
            start_time := A_TickCount
            while !this.CheckTradeClosed(true) or A_TickCount - start_time <= 6500
                sleep 100
            this.CheckBalance()
        }
        
        this.CheckBalance()
        while this.balance.current < this.balance.starting {
            this.AddBalance(this.balance.starting-this.balance.current)
            sleep 2000
            this.CheckBalance()
        }
        
        this.amount := this.GetAmount(this.balance.current)
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
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 2)
        sleep 100
        Send('{Escape 2}')

        this.CheckStuck()
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
            this.lose_streak := {max: 0, repeat: Map()}
        }
        this.stats.reset_date := SubStr(this.datetime, 1, -6)
        
        if this.ps.blue.state and this.ps.orange.state {
            this.BothLinesDetected()
            this.RunScenarios()
        }
    
        this.UpdateLog()
        sleep 100
    
    }

    CheckStuck() {
        if this.candle_data.Length > 3 {
            _reload := true
            Loop 3 {
                if not Utils.is_all_same(this.candle_data[A_Index].moving_prices) {
                    _reload := false
                    break
                }
            }
            if _reload {
                this.ReloadWebsite()
            }
        }
    }
    
    CheckPaused() {
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

        for k, v in this.blockers {
            if v.state
                return true
        }
        return false
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
                if this.state.coin_change_streak and this.stats.streak = coin_change_streak {
                    this.state.coin_change_streak := false
                    this.ChangeCoin()
                } else {
                    this.ChangeCoin(false)
                }
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
        this.candle_data[1].moving_prices.InsertAt(1, this.ps.moving_price.y)
            
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

        ScenarioRandom(15)

        Scenario3b()
        Scenario3a()
        if this.stats.streak != -3 {
            Scenario3()
        }
        Scenario2()
        Scenario1()

        ScenarioRandom(delay) {
            if !this.qualifiers.random_trade.state
                return false
            if this.paused or this.candle_data.Length < 2 or this.trade_opened[1] 
                return false

            _name := StrReplace(A_ThisFunc, 'Scenario', '')
            _name_buy := 'sc' _name 'B'
            _name_sell := 'sc' _name 'S'
            condition_both := (A_TickCount - this.trade_opened[2])/1000 > delay

            rand := Random(1, 2)
            
            condition_buy  := false
            condition_sell  := false
            if condition_both and this.candle_data[1].color = 'G' and rand = 1
                condition_buy  := true
            if condition_both and this.candle_data[1].color = 'R' and rand = 2
                condition_sell  := true
            
            if (condition_buy) {
                this.ExecuteTrade('BUY', _name)
            } else if (condition_sell) {
                this.ExecuteTrade('SELL', _name)
            }
        }

        Scenario1() {
            if this.paused or this.candle_data.Length < 2
                return false
            _name := StrReplace(A_ThisFunc, 'Scenario', '')
            bad_condition := false
            ; try
            ;     bad_condition := this.candle_data[2].color = 'R' and this.ps.blue.y < this.candle_data[2].blue_line_y[-1] or this.candle_data[2].color = 'G' and this.ps.blue.y > this.candle_data[2].blue_line_y[-1]
            _pheight := 20
            _candle_size := 20
            condition_both := Mod(A_Sec-1, 15) <= 2 and this.crossovers_arr.Length >= 2 and not this.trade_opened[1] and this.candle_data[2].size >= _candle_size
            ; if this.stats.streak <= -3
            ;     condition_both := condition_both and Mod(A_Sec-1, 15) >= 1 and Mod(A_Sec-1, 15) <= 3
            if condition_both and this.ps.orange.y > this.ps.blue.y + _pheight and this.candle_data[2].both_lines_touch and condition_both
                this.qualifiers.sc1B := {state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}
            if condition_both and this.ps.blue.y > this.ps.orange.y + _pheight and this.candle_data[2].both_lines_touch and condition_both
                this.qualifiers.sc1S := {state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}
            
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
                this.ExecuteTrade('BUY', _name)
            } else if (condition_sell and this.candle_data[1].color = 'R') {
                try 
                    this.qualifiers.sc1S.state := false
                this.last_trade := 'SELL'
                this.ExecuteTrade('SELL', _name)
            }
        }
        Scenario2() {
            if this.paused or this.candle_data.Length < 2
                return false
            _name := StrReplace(A_ThisFunc, 'Scenario', '')
            bad_condition := false
            ; try
            ;     bad_condition := this.candle_data[2].color = 'R' and this.ps.blue.y < this.candle_data[2].blue_line_y[-1] or this.candle_data[2].color = 'G' and this.ps.blue.y > this.candle_data[2].blue_line_y[-1]
            _pheight := 20
            _candle_size := 20
            condition_both := Mod(A_Sec-1, 15) >= 13 and this.crossovers_arr.Length >= 2 and not this.trade_opened[1] and this.candle_data[2].size >= _candle_size
            
            condition_buy  := this.candle_data[2].color = 'G' and this.candle_data[1].moving_prices[1] < this.candle_data[1].C and this.candle_data[1].C < this.candle_data[2].C
            condition_sell := this.candle_data[2].color = 'R' and this.candle_data[1].moving_prices[1] > this.candle_data[1].C and this.candle_data[1].C > this.candle_data[2].C

            if condition_both and condition_buy  and this.ps.orange.y > this.ps.blue.y + _pheight and this.candle_data[2].both_lines_touch
                this.qualifiers.sc2B := {timeframe: Utils.get_timeframe(), state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}
            if condition_both and condition_sell and this.ps.blue.y > this.ps.orange.y + _pheight and this.candle_data[2].both_lines_touch
                this.qualifiers.sc2S := {timeframe: Utils.get_timeframe(), state: true, time: A_TickCount, price_line: this.candle_data[1].moving_prices[1], candle_size: this.candle_data[1].size, timeframe: Utils.get_timeframe()}

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
                this.ExecuteTrade('BUY', _name)
            } else if (condition_sell and this.candle_data[1].color = 'R') {
                this.qualifiers.sc2S.state := false
                this.last_trade := 'SELL'
                this.ExecuteTrade('SELL', _name)
            }
        }
        Scenario3() {
            if this.paused or this.candle_data.Length < 2 or this.trade_opened[1] 
                return false

            _name := StrReplace(A_ThisFunc, 'Scenario', '')
            condition_both := Mod(A_Sec-1, 15) >= 12
            
            if condition_both and this.candle_data[1].color = 'R' and this.candle_data[1].moving_prices[1] < this.candle_data[1].O 
                this.qualifiers.sc3B := {state: true, price_line: this.candle_data[1].moving_prices[1], timeframe: Utils.get_timeframe()}
            if condition_both and this.candle_data[1].color = 'G' and this.candle_data[1].moving_prices[1] > this.candle_data[1].O
                this.qualifiers.sc3S := {state: true, price_line: this.candle_data[1].moving_prices[1], timeframe: Utils.get_timeframe()}

            condition_buy  := this.qualifiers.HasOwnProp('sc3B') and this.qualifiers.sc3B.state
            condition_sell := this.qualifiers.HasOwnProp('sc3S') and this.qualifiers.sc3S.state

            for v in ['sc3B', 'sc3S'] {
                if this.qualifiers.HasOwnProp(v) and this.qualifiers.%v%.state and Utils.get_timeframe() != this.qualifiers.%v%.timeframe
                    this.qualifiers.%v%.state := false
            }

            if (condition_buy) {
                this.qualifiers.sc3B.state := false
                this.ExecuteTrade('BUY', _name)
            } else if (condition_sell) {
                this.qualifiers.sc3S.state := false
                this.ExecuteTrade('SELL', _name)
            }
        }
        Scenario3a() {
            if this.paused or this.candle_data.Length < 2 or this.trade_opened[1] 
                return false

            _name := StrReplace(A_ThisFunc, 'Scenario', '')
            condition_both := Mod(A_Sec-1, 15) >= 14
            
            if condition_both and this.candle_data[1].color = 'R' and this.candle_data[1].moving_prices[1] < this.candle_data[1].O - this.candle_data[1].size/2
                this.qualifiers.sc3aB := {state: true, price_line: this.candle_data[1].moving_prices[1], timeframe: Utils.get_timeframe()+15}
            if condition_both and this.candle_data[1].color = 'G' and this.candle_data[1].moving_prices[1] > this.candle_data[1].O + this.candle_data[1].size/2
                this.qualifiers.sc3aS := {state: true, price_line: this.candle_data[1].moving_prices[1], timeframe: Utils.get_timeframe()+15}

            condition_buy  := this.candle_data[1].color = 'G' and this.candle_data[1].moving_prices[1] < this.candle_data[1].C and this.candle_data[1].size > 2 and this.qualifiers.HasOwnProp('sc3aB') and this.qualifiers.sc3aB.state and this.qualifiers.sc3aB.timeframe = Utils.get_timeframe()
            condition_sell := this.candle_data[1].color = 'R' and this.candle_data[1].moving_prices[1] > this.candle_data[1].C and this.candle_data[1].size > 2 and this.qualifiers.HasOwnProp('sc3aS') and this.qualifiers.sc3aS.state and this.qualifiers.sc3aS.timeframe = Utils.get_timeframe()

            for v in ['sc3aB', 'sc3aS'] {
                if this.qualifiers.HasOwnProp(v) and this.qualifiers.%v%.state and Utils.get_timeframe() > this.qualifiers.%v%.timeframe
                    this.qualifiers.%v%.state := false
            }

            if (condition_buy) {
                this.qualifiers.sc3aB.state := false
                this.ExecuteTrade('BUY', _name)
            } else if (condition_sell) {
                this.qualifiers.sc3aS.state := false
                this.ExecuteTrade('SELL', _name)
            }
        }
        Scenario3b() {
            if this.paused or this.candle_data.Length < 2 or this.trade_opened[1] 
                return false

            _name := StrReplace(A_ThisFunc, 'Scenario', '')
            _name_buy := 'sc' _name 'B'
            _name_sell := 'sc' _name 'S'
            condition_both := Mod(A_Sec-1, 15) >= 10
            
            if condition_both and this.candle_data[1].color = 'G' and this.candle_data[1].moving_prices[1] < this.candle_data[1].C 
                this.qualifiers.%_name_buy% := {state: true, price_line: this.candle_data[1].moving_prices[1], timeframe: Utils.get_timeframe()+15}
            if condition_both and this.candle_data[1].color = 'R' and this.candle_data[1].moving_prices[1] > this.candle_data[1].C and this.candle_data[1].moving_prices[1] > this.candle_data[2].O and this.candle_data[2].color = 'G'
                this.qualifiers.%_name_sell% := {state: true, price_line: this.candle_data[1].moving_prices[1], timeframe: Utils.get_timeframe()+15}

            condition_buy  := false
            condition_sell := false

            for v in [_name_buy, _name_sell] {
                if this.qualifiers.HasOwnProp(v) and this.qualifiers.%v%.state {
                    if Utils.get_timeframe() > this.qualifiers.%v%.timeframe {
                        this.qualifiers.%v%.state := false
                    } else {
                        if v = _name_buy and this.candle_data[1].moving_prices[1] < this.qualifiers.%v%.price_line - 1
                            condition_buy := true
                        if v = _name_sell and this.candle_data[1].moving_prices[1] > this.qualifiers.%v%.price_line + 1
                            condition_sell := true
                    }
                }
            }
            
            if (condition_buy and this.stats.streak != -3) {
                this.qualifiers.%_name_buy%.state := false
                this.ExecuteTrade('BUY', _name)
            } else if (condition_sell) {
                this.qualifiers.%_name_sell%.state := false
                this.ExecuteTrade('SELL', _name)
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
            condition_buy  := condition_both and this.candle_data[2].color = 'R' and this.candle_data[2].moving_prices[1] < this.candle_data[2].O
            condition_sell := condition_both and this.candle_data[2].color = 'G' and this.candle_data[2].moving_prices[1] > this.candle_data[2].O

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
            if !this.stats.%this.executed_trades[1]%.HasOwnProp('win_rate')
                this.stats.%this.executed_trades[1]%.win_rate := 100
            if !this.stats.%this.executed_trades[1]%.HasOwnProp('rank')
                this.stats.%this.executed_trades[1]%.rank := 1
            countdown_close_str :=  this.executed_trades[1] ' [' this.stats.%this.executed_trades[1]%.win '|' this.stats.%this.executed_trades[1]%.draw '|' this.stats.%this.executed_trades[1]%.lose '] [' this.stats.%this.executed_trades[1]%.win_rate '% ' this.stats.%this.executed_trades[1]%.rank '/' 10 ']' ' (' format('{:.2f}', countdown_close) ')'
        } else {
            countdown_close_str := ''
        }
    
        str_l := ''
        for k, v in this.lose_streak.repeat {
            str_l .= k '<' v.win '|' v.lose '> '
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
        win_rate := Format('{:.1f}', this.stats.win_rate)

        str := Map()
        str.next_bal := '$1000: $99999999999999'

        for v in this.amounts_tresholds {
            if this.balance.current > v[1] {
                break
            }
            str.next_bal := '$' v[2] ': ' v[1]
        }

        str_c := '(130: ' this.qualifiers.custom_amount_modifier.count ') '
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
        
        str_c := str_c '(' this.candle_data[1].size ' | ' RegExReplace(this.coin_name, '[^\w]', ' ') ') (' this.stats.streak ') ' countdown_close_str ' | ' paused_str
        str_d := '(' Helper0811_4Loss.Get().level ') ' format('{:.2f}', this.amount)
        if this.qualifiers.flip_trade.state = 1 {
            str_d := 'FLIP ' str_d
        }
        if Helper_Skip(this.stats.streak, true) {
            str_d := 'S ' str_d
        }
        str_e := this.stats.streak ' (' this.stats.win '|' this.stats.draw '|' this.stats.loss '|' win_rate '%)'
        if this.stats.streak = -1 or this.stats.streak = -2
            str_e := '(' this.qualifiers.loss_amount_modifier.state_2ndloss[-this.stats.streak] ') ' str_e
        str_f := format('{:.2f}', this.stats.max_bal_diff) ' (' this.qualifiers.streak_reset.count '|' this.qualifiers.streak_reset.count2 ')'
        str_g := format('{:.2f}', this.stats.G_balance.val) ' (' this.stats.G_balance.count ')'
        str_m := 'WW:' this.qualifiers.double_trade.WW ' | LL:' this.qualifiers.double_trade.LL ' | WL:' this.qualifiers.double_trade.WL
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
                    str_c ',' 
                    str_d ',' 
                    str_e ',' 
                    str_f ',' 
                    str_g ',' 
                    '(' this.qualifiers.balance_mark.mark ') ' this.balance.current ' (W:' this.stats.bal_win ' | L:' this.stats.bal_lose ') (' this.balance.max ' | ' this.balance.min ')' ',' 
                    str.next_bal ',' 
                    this.last_trade ',' 
                    ' | ' this.payout '%=' format('{:.2f}', this.amount*1.92) ' (' this.coin_name ')' ',' 
                    str_l ',' 
									
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
        if reason = 'STARTING' {
            MouseClick('L', this.coords.%action%.x + Random(-5, 5), this.coords.%action%.y + Random(-1, 1), 1, 2)
            return
        }

        if this.qualifiers.flip_trade.state = 1 {
            action := (action = "buy") ? "sell" : "buy"
        }

        this.last_trade := action
        if this.trade_opened[1]
            return false
        _name := action reason
        if this.stats.HasOwnProp(_name) and this.stats.%_name%.rank > 4 and this.qualifiers.streak_reset.val = this.stats.streak and this.qualifiers.streak_reset.val = -2
            return false
        if this.qualifiers.pause_temp.state {
            this.qualifiers.pause_temp.count++
            if this.qualifiers.pause_temp.count > 5 {
                this.qualifiers.pause_temp.state := false
                this.qualifiers.pause_temp.count := 0
            } else {
                return false
            }
        }
        this.qualifiers.custom_amount_modifier.count++

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

        if not this.qualifiers.double_trade.state {
            MouseClick('L', this.coords.%action%.x + Random(-5, 5), this.coords.%action%.y + Random(-1, 1), 1, 2)
        } else {
            MouseClick('L', this.coords.%action%.x + Random(-5, 5), this.coords.%action%.y + Random(-1, 1), 1, 2)
            ; sleep Random(800, 1200)
            ; _act2 := action = 'BUY' ? 'SELL' : 'BUY'
            ; MouseClick('L', this.coords.%_act2%.x + Random(-5, 5), this.coords.%_act2%.y + Random(-1, 1), 1, 2)
        }
        
        sleep 200
        MouseClick('L', this.coords.trades_opened.x + Random(-5, 5), this.coords.trades_opened.y + Random(-1, 1), 3, 2)
        sleep 50
        loop {
            MouseMove(this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, 0)
            sleep 50
            ToolTip('waiting for trade to be opened', , , 12)
            if PixelSearch(&x, &y, this.coords.detect_trade_open1.x, this.coords.detect_trade_open1.y, this.coords.detect_trade_open2.x, this.coords.detect_trade_open2.y, this.colors.green2, 25) {
                break
            }
            this.CheckBalance()
            if this.balance.current != this.balance.last_trade {
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
        this.executed_trades.InsertAt(1, action reason)
        while this.executed_trades.Length > 10
            this.executed_trades.Pop()
        if !this.stats.HasOwnProp(this.executed_trades[1]) {
            this.stats.%this.executed_trades[1]% := {win:0, lose:0, draw:0}
        }

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
        
        try {
            this.ps.moving_price := {state: PixelSearch(&x1, &y1, this.coords.area_price.x, this.coords.area_price.y, this.coords.area_price.x2, this.coords.area_price.y2, this.colors.moving_price, 5)}
            PixelSearch(&x2, &y2, x1+5, this.coords.area_price.y2, x1-5, y1, this.colors.moving_price, 5)
            this.ps.moving_price.y := (y1+y2)/2
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
            ToolTip('(' A_Sec '.' A_MSec ')' this.debug_str '`nCurrent this.last_trade: ' this.last_trade '`nCurrent balance: ' format('{:.2f}', this.balance.current), 5, A_ScreenHeight*0.9, 11)
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
                this.qualifiers.balance_mark.mark_starting := tresh[1]
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
        MouseClick('L', this.coords.empty_area.x, this.coords.empty_area.y, 1, 2)
        sleep 100
        Send('{Escape 2}')
        this.SetTradeAmount(false)

        return
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
        Send '{LCtrl up}{RCtrl up}{LShift up}{RShift up}{Alt up}{LWin up}{RWin up}'
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
            if RegExMatch(A_Clipboard, 'QT Real') {
                MsgBox('Not on demo website, reloading Demo version.',, 'T2')
                this.ReloadWebsite()
            }
            if !RegExMatch(A_Clipboard, 'USD') {
                if RegExMatch(A_Clipboard, 'i)SIGN IN') {
                    ClickOnPage('SIGN IN')
                }
                tooltip('Error: No balance found`n' A_Clipboard)
                sleep 80
                Send('^f')
                sleep 80
                Send('USD{enter}{Escape}')
                sleep 50
                continue
            }
            if !RegExMatch(A_Clipboard, 'm)^\d{1,3}(,\d{3})*(\.\d{2})*$', &match) {
                if RegExMatch(A_Clipboard, 'i)SIGN IN') {
                    ClickOnPage('SIGN IN')
                }
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
            if cur_bal >= 500000 {
                MsgBox 'Balance too high.'
            }
            cur_bal := Format('{:.2f}', cur_bal - (this.stats.bal_mark))
            this.balance.current := cur_bal
            this.balance.max := Format('{:.2f}', max(cur_bal, this.balance.max))
            this.balance.min := Format('{:.2f}', min(cur_bal, this.balance.min))

            this.stats.max_bal_diff := this.balance.max - this.balance.current
            return
        }
    }

    AddBalance(bal_amount) {
        Send '{LCtrl up}{RCtrl up}{LShift up}{RShift up}{Alt up}{LWin up}{RWin up}'
        if bal_amount < 0 {
            MouseClick('l', this.coords.empty_area.x, this.coords.empty_area.y,1,2)
            this.balance.max := 0
            this.balance.min := 9**10
            sleep 1000
            this.CheckBalance()
        }
        bal_amount := format('{:.2f}', bal_amount)
        A_Clipboard := ''
        if !WinActive(this.wtitle) {
            WinActivate(this.wtitle)  
            sleep 100
        }
        MouseClick('L', this.coords.balance.x + Random(-2, 2), this.coords.balance.y + Random(-2, 2), 1, 2)
        sleep 2000
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

class Constants {
    static GetAmounts1() => [22.93, 47.86, 20]
    static GetAmounts2() => Map(
                                1, [5, 12, 26, 54, 110, 222, 446, 894],
                                2, [11, 24, 50, 104, 210, 422, 846, 1694]
                            )
    static GetAmounts3() => {1:4, 2:9, losses_ina_row:0}
    static GetAmounts4() => {state:0, 1:50, 2:100, losses_ina_row:{1:0, 2:0}}
}
