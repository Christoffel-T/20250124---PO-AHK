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
        if (text == "") 
            return

        ; Store previous clipboard to restore it later (optional but polite)
        oldData := ClipboardAll() 
        
        A_Clipboard := "" ; Clear clipboard
        A_Clipboard := text
        sleep 100
        
        if !ClipWait(2) { ; Increased timeout to 2 seconds for safety
            MsgBox "Clipboard failed to update."
            return false
        }

        Send "^v"
        
        ; CRITICAL: Give the destination app time to "read" the clipboard 
        ; before the script continues and potentially changes the clipboard again.
        Sleep 200 
    }        
}
