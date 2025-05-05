#Requires AutoHotkey v2.0

class Settings {
    __New() {
        this.settings_file := 'settings.ini'
        this.general := this.read_settings('General', ['wtitle'])
        this.wtitle := this.general.wtitle
        this.coords := this.read_settings('coords', ['balance', 'top_up', 'time1', 'time_15', 'detect_trade_open1', 'detect_trade_open2', 'detect_trade_close1', 'detect_trade_close2', 'trades_closed', 'trades_opened', 'area', 'area_price', 'BUY', 'SELL', 'Payout', 'coin', 'cryptocurrencies', 'stocks', 'coin_top', 'empty_area'])
        this.colors := this.read_settings('colors', ['blue', 'orange', 'green', 'green2', 'red', 'moving_price'], )
    }

    read_settings(section, arr) {
        _map := Map()
        for v in arr {
            _iniread := IniRead(this.settings_file, section, v, '')
            if _iniread = '' {
                if section = 'coords' {
                    loop {
                        sleep 10
                        MouseGetPos(&_x, &_y, &_win)
                        tooltip('x: ' _x ', y: ' _y '`nPress [Left Ctrl] to set coordinate for: ' v)
                        if GetKeyState('LControl', 'P') {
                            _iniread := _x ', ' _y
                            IniWrite(_iniread, this.settings_file, section, v)
                            tooltip()
                            KeyWait 'LControl'
                            break
                        }
                    }
                } else {
                    Loop {
                        _ib := InputBox('Enter value for ' v, 'Settings', 'h100')
                        if _ib.Result = 'Cancel' {
                            ExitApp
                        }
                        if not _ib.Value = '' {
                            break
                        }
                    }
                    _iniread := _ib.Value
                    IniWrite(_iniread, this.settings_file, section, v)
                }
            }
            if section != 'coords' {
                _map.%v% := _iniread
                continue
            }
            _split := StrSplit(_iniread, ',', ' ')
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

