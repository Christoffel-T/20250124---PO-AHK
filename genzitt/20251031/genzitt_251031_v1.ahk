; ==============================
; Project Metadata
; ==============================
ProjectName := A_ScriptName
Version     := "1.0.0"
Author      := "Christoffel"
DateCreated := "2025-01-01"
; ==============================

#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode 'ToolTip', 'Screen'
CoordMode 'Mouse', 'Client'
CoordMode 'Pixel', 'Client'
SendMode 'Event'

hotkeys := Map()
hotkeys.start1       := LoadSetting('Hotkeys', 'start1', '$!x')
hotkeys.start2       := LoadSetting('Hotkeys', 'start2', '$!d')
hotkeys.start3       := LoadSetting('Hotkeys', 'start3', '$!s')
hotkeys.pause       := LoadSetting('Hotkeys', 'pause', 'Esc')
hotkeys.tog_tooltip := LoadSetting('Hotkeys', 'toggle_tooltip', '+F1')
hotkeys.reload      := LoadSetting('Hotkeys', 'reload', '+Esc')
hotkeys.settings    := LoadSetting('Hotkeys', 'settings', '^F1')
hotkeys.exit        := LoadSetting('Hotkeys', 'exit', '^Esc')

hotkeys.pause       := '$' hotkeys.pause
A_MenuMaskKey := "vkFF"
Initialize

Main(var, ThisHotkey) {
    global
    try
        KeyWait ThisHotkey
    KeyWait(SubStr(ThisHotkey, -1))
    KeyWait 'Ctrl'
    KeyWait 'Shift'
    KeyWait 'Alt'
    KeyWait 'LWin'
    MainTooltip('Running.')
    Hotkey(hotkeys.start1, 'Off')
    Hotkey(hotkeys.start2, 'Off')
    Hotkey(hotkeys.start3, 'Off')
    Hotkey(hotkeys.pause, 'On')
    switch var {
        case '1':
            Action1()
        case '2':
            Action2()
        case '3':
            Action3()
        default: 
            MsgBox('Unknown action: ' var)
    }
    ToolTip()
    return ReadyState()

    Action1() {
        A_Clipboard := ''
        Loop {
            ToolTip('Please copy the entire shipping address')
            if StrLen(A_Clipboard) >= 10 {
                break
            }
        }
        address := StrSplit(A_Clipboard, '`n', '`r')
        full_name := address[1]
        phone := address[2]
        street_address := address[3]
        address2 := StrSplit(address[4], ',', ' ')
        city := Trim(address2[1])
        state_zip := Trim(address2[2])
        RegExMatch(address[4], '\d{4,}.*', &zip_code)
        zip_code := zip_code[]
        KeyWait('LControl')
        sleep 50
        while !GetKeyState('LControl', 'P') {
            ToolTip('Press [Left Ctrl] to paste the address ')
            sleep 20
        }
        KeyWait('LControl')
        ToolTip('Pasting address...')
        sleep 200
        PasteText(full_name)
        PasteText(phone)
        PasteText(street_address)
        PasteText(city, false)
        PasteText(state_zip, false)
        PasteText(zip_code, false)
        ToolTip()
    }

    Action2() {
        PasteText('Thank you for shopping with us!')
        PasteText(store_name)
    }

    Action3() {
        ClickOnPage('More actions')
        sleep 200
        SendEvent('{Tab}{Enter}')
        sleep 1000
        SendEvent('{Tab}')
        sleep 200
        SendEvent('{Right 4}')
        sleep 200
        SendEvent('{Tab}')
        sleep 200
        PasteText(A_Clipboard)
    }

    ClickOnPage(text) {
        SendEvent('^f')
        sleep 200
        SendEvent('^a{Delete}')
        sleep 200
        SendEvent(text)
        sleep 400
        SendEvent('{Enter}{Escape}')
        sleep 200
        SendEvent('{Enter}')
    }

    PasteText(text, quick:=true) {
        A_Clipboard := text
        sleep 200
        if quick
            SendEvent('^v')
        else
            SendEvent(text)
        sleep 200
        SendEvent('{Tab}')
        sleep 200
    }
}

Selector(text, button:='LControl') {
    while !GetKeyState(button, 'P') {
        MouseGetPos(&x, &y, &win_id, &ctrlNN)
        win := WinGetTitle(win_id) ' ahk_class ' WinGetClass(win_id)
        ToolTip('Press [Left Ctrl] to ' text '`n(' x ',' y ' | ' win ')')
        sleep 20
    }
    KeyWait(button)
    ToolTip
    val := {x: x, y: y, win: win, win_id: win_id, ctrlNN: ctrlNN}
    return val
}

LoadSetting(sect, key, default_or_mode := 'NONE') {
    settings_file := 'settings.ini'
    val := IniRead(settings_file, sect, key, '')
    if RegExMatch(val, "^\{.*\}$") {
        val := Trim(val, '{}')
        _obj := {}
        for v in StrSplit(val, ',', ' `t') {
            _ := StrSplit(v, ':', ' `t')
            _obj.%_[1]% := _[2]
        }
        val := _obj
        return val
    } else if val
        return val

    switch default_or_mode {
        case 'NONE':
            val := ''
        case 'winNameClass':
            val := Selector('select this window')
        case '1coord':
            val := Selector('set coordinate for: ' key)
        case '2coord':
            val := {}
            val2 := Selector('set TOP-LEFT coordinate for: ' key)
            val.x1 := val2.x
            val.y1 := val2.y
            val.win := val2.win
            val2 := Selector('set BOTTOM-RIGHT coordinate for: ' key)
            val.x2 := val2.x
            val.y2 := val2.y
        default:
            val := default_or_mode 

    }
    if IsObject(val) {
        _ := '{'
        for k, v in val.OwnProps() {
            _ .= k ': ' v ', '
        }
        _ := Trim(_, ', ') '}'
        IniWrite(_, settings_file, sect, key)
    } else {
        IniWrite(val, settings_file, sect, key)
    }
    return val
}

class SettingsGUI {
    static __New() {
        this.gui_obj := Gui('AlwaysOnTop')
        this.gui_obj.AddText('xm w100', 'Setting1')
        this.ctrl_setting1 := this.gui_obj.AddEdit('w100 yp', 'Setting1')
        this.gui_obj.AddText('xm w100', 'Setting2')
        this.ctrl_setting2 := this.gui_obj.AddEdit('w100 yp', 'Setting2')
        this.ctrl_btn_save := this.gui_obj.AddButton('w100', 'Save')
        this.ctrl_btn_cancel := this.gui_obj.AddButton('w100', 'Cancel')

        this.ctrl_btn_save.OnEvent('Click', this.Save.Bind(this))
        this.ctrl_btn_cancel.OnEvent('Click', this.Cancel.Bind(this))
    }

    static Save(*) {
        this.gui_obj.Submit()
    }
    
    static Cancel(*) {
        this.Hide()
    }

    static Show() {
        this.gui_obj.Show()
    }

    static Hide() {
        this.gui_obj.Hide()
    }
}

Initialize() {
    global
    ; HotIfWinActive("")
    Hotkey(hotkeys.start1, Main.Bind('1'))
    Hotkey(hotkeys.start2, Main.Bind('2'))
    Hotkey(hotkeys.start3, Main.Bind('3'))
    ; HotIfWinActive
    Hotkey(hotkeys.tog_tooltip, ToggleTooltip)
    Hotkey(hotkeys.pause, PauseScript)
    Hotkey(hotkeys.settings, (*) => SettingsGUI.Show(), 'Off')
    Hotkey(hotkeys.reload, (*) => Reload())
    Hotkey(hotkeys.exit, (*) => ExitApp())
    
    tog_tooltip := True
    
    MainTooltip('Initializing... Please follow the instructions.')
    ib := InputBox('Please enter the Store name:', 'Store Name Required', 'h110')
    store_name := ib.Value
    coords := {}

    ReadyState
}

SelectScreenRegion(Key:='LButton', Color := "Lime", Transparent:= 80) {
    ToolTip('SELECTION MODE', 5, 5, 19)
    hotkey('$' Key, (*) => 0, 'On')
    KeyWait(Key, 'D')
	CoordMode("Mouse", "Screen")
	MouseGetPos(&sX, &sY)
	ssrGui := Gui("+AlwaysOnTop -caption +Border +ToolWindow +LastFound -DPIScale")
	WinSetTransparent(Transparent)
	ssrGui.BackColor := Color
	Loop 
	{
		Sleep 10
		MouseGetPos(&eX, &eY)
		W := Abs(sX - eX), H := Abs(sY - eY)
		X := Min(sX, eX), Y := Min(sY, eY)
		ssrGui.Show("x" X " y" Y " w" W " h" H)
	} Until !GetKeyState(Key, "p")
	ssrGui.Destroy()
    hotkey('$' Key, 'Off')
    ToolTip(, , , 19)

	Return { X: X, Y: Y, W: W, H: H, X2: X + W, Y2: Y + H }
}

ReadyState() {
    MainTooltip('Ready (' ProjectName ' v' Version ')')
    ; HotIfWinActive("")
    Hotkey(hotkeys.start1, "On")
    Hotkey(hotkeys.start2, "On")
    Hotkey(hotkeys.start3, "On")
    Hotkey(hotkeys.pause, "Off")
    ; HotIfWinActive
    Hotkey(hotkeys.reload, "On")
    ; Hotkey(hotkeys.settings, "On")
    Hotkey(hotkeys.exit, "On")
}

MainTooltip(var) {
    str_hotkeys := '    ' FormatHotkey(hotkeys.start1)         '`t`t: Paste Address'
    str_hotkeys .= '`n    ' FormatHotkey(hotkeys.start2)         '`t`t: Paste "Thanks ..." and Store name'
    str_hotkeys .= '`n    ' FormatHotkey(hotkeys.start3)         '`t`t: More Actions - Add Note'
    ; for k, v in hotkeys.OwnProps() {
    ;     str_hotkeys .= '    ' FormatHotkey(v) '`t`t: ' k '`n'
    ; }
    ; str_hotkeys := Trim(str_hotkeys, '`n')
    if tog_tooltip {
        ToolTip(
        (
            var '`nHotkeys:`n' str_hotkeys '
                ' FormatHotkey(hotkeys.pause)         '`t`t: Pause/Resume
                ' FormatHotkey(hotkeys.reload)        '`t: Stop/Reload
                ' FormatHotkey(hotkeys.tog_tooltip)   '`t: Show/Hide info
                ' FormatHotkey(hotkeys.exit)          '`t: Exit'
        ), 5, 5, 2)
        ToolTip('',,, 11)
        ToolTip('',,, 12)
    } else {
        ToolTip ,,, 2
        ToolTip ,,, 11
        ToolTip ,,, 12
    }
}

ToggleTooltip(ThisHotkey) {
    global tog_tooltip
    tog_tooltip := !tog_tooltip
    ReadyState()
}

FormatHotkey(hotkey) {
    hotkey := StrReplace(hotkey, "+", "Shift+")
    hotkey := StrReplace(hotkey, "^", "Ctrl+")
    hotkey := StrReplace(hotkey, "!", "Alt+")
    hotkey := StrReplace(hotkey, "#", "Win+")
    return hotkey
}

PauseScript(*) {
    Pause(-1)
    if A_IsPaused
        MainTooltip('Paused.')
    else
        MainTooltip('Running...')
}

RunAsAdmin() {
    full_command_line := DllCall("GetCommandLine", "str")

    if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
    {
        try
        {
            if A_IsCompiled
                Run '*RunAs "' A_ScriptFullPath '" /restart'
            else
                Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        }
        ExitApp
    }
}
