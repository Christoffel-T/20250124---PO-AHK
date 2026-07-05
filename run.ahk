#Requires AutoHotkey v2.0
TraySetIcon("shell32.dll", 3)
^F1::Start()

^F2::Restart()

Restart() {
    UpdateVS()
    Send '+{Esc}'
    reload
}

Start() {
    UpdateVS()
    run 'main.ahk'
}

UpdateVS() {
    if (WinActive("ahk_exe Code.exe")) {
        WinActivate("ahk_exe Code.exe")
        sleep 200
        Send '^+p'
        sleep 300
        Send 'git pull'
        sleep 300
        Send '{Enter}'
        sleep 3000
    }
}