#Requires AutoHotkey v2.0

^F1::Start()

^F2::Restart()

Restart() {
    Send '+{Esc}'
    MsgBox 'testrestart'
    reload
}

Start() {
    run 'main.ahk'
    MsgBox 'teststart'
}