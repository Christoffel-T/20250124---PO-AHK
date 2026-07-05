#Requires AutoHotkey v2.0

+F2::Start()

+F3::Restart()

Restart() {
    Send '+{F1}'
    MsgBox 'testrestart'
}

Start() {
    MsgBox 'teststart'
}