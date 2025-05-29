#Requires AutoHotkey v2.0

class Utils {
    static is_all_same(arr) {
        for i, v in arr
            if (v != arr[1])  ; Compare each value with the first element
                return false
        return true
    }
    
    static get_timeframe(interval := 15, add_sec := 0) {
        datetime := A_Now + add_sec
        ; datetime := DateAdd(A_NowUTC, -5, 'h')
        seconds := SubStr(datetime, -2)
        rounded_seconds := Floor(seconds / interval) * interval
        rounded_time := SubStr(datetime, 1, -2) Format("{:02}", rounded_seconds)
        return rounded_time
    }

    static PasteText(text) {
        if not text 
            return
        A_Clipboard := ''
        sleep 50
        A_Clipboard := text
        sleep 50
        if !ClipWait(1) {
            MsgBox 'An error occured.'
            return false
        }
        Send '^v'
        sleep 50
    }
        
}
