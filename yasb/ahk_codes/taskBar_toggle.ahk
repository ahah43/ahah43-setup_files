#Requires AutoHotkey v2.0


DetectHiddenWindows True
    
; Check if Visible bit (0x10000000) is set
if (WinGetStyle("ahk_class Shell_TrayWnd") & 0x10000000)
    WinHide "ahk_class Shell_TrayWnd"
else
    WinShow "ahk_class Shell_TrayWnd"

ExitApp