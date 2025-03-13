#Requires AutoHotkey v2.0

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

