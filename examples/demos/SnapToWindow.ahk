; Script     SnapToWindow.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#include ../../GpGFX.ahk

; Snap layer to active window and draw an overlay
lyr := Layer().SnapToWindow("A")
RoundedRectangle("0x601A1A26", true)
Text("HUD SNAPPED TO WINDOW", "0xFF00FF66", 42, "Segoe UI", "Bold") ;.Center()
lyr.Draw()

Run("notepad.exe")
WinWaitActive("ahk_exe notepad.exe")
Sleep(100)
lyr2 := Layer().SnapToWindow("ahk_exe Notepad.exe")
Rectangle("0x303bd361", true) ; 1px outer stroke
Rectangle("0xFFFF0055", 0) ; 1px outer stroke
Text("HUD SNAPPED TO NOTEPAD", "0xff252525", 42, "Segoe UI", "Bold") ;.Center()
lyr2.Draw().Timeout(1500)

Sleep(1400)
WinClose("ahk_exe notepad.exe")





