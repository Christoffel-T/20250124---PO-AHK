#Requires AutoHotkey v2.0
CoordMode('Mouse', 'Screen')
CoordMode('Pixel', 'Screen')
CoordMode('ToolTip', 'Screen')
SendMode('Event')

#Include lib/trader_bot.ahk
#Include lib/utils.ahk
#Include lib/settings.ahk

settings_obj := Settings()
obj_trader := TraderBot(settings_obj)

Hotkey('F1', obj_trader.StartLoop, 'On')
ToolTip('Ready. Press F1 to start', 5, 5, 1)
obj_trader.StartLoop

$^Esc::Pause 1
$+Esc::Reload
$^+Esc::ExitApp