; Script     BitmapSources.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#include ../../GpGFX.ahk

lyr := Layer(1024, 768, "ImageSources Test")

; 1. Screen region capture auto-embedded into a RoundedRectangle
card1 := RoundedRectangle(50, 50, 400, 300, 20, "0xFF2C3E50", true)
card1.AddImage({ x: 0, y: 0, w: 400, h: 300 })

; 2. Window capture using HWND auto-embedded into a Circle
; Position center at (550, 150) with radius 100 so it aligns with card1 (top: 50, bottom: 250)
card2 := Circle(650, 150, 160, "0xFF16A085", true)
; Capture a live window (Taskbar or active window):
targetHwnd := WinExist("ahk_class Shell_TrayWnd")
card2.AddImage(targetHwnd)

; 3. Direct Graphics.FromHDC test
hdc := DllCall("GetDC", "ptr", 0, "ptr")
gfx := Graphics.FromHDC(hdc)
if (gfx) {
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
}
DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

; 4. Direct Graphics.FromHWND test
gfxHwnd := Graphics.FromHWND(lyr.hwnd)
if (gfxHwnd) {
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfxHwnd)
}

Draw(lyr)
Sleep(2000)

lyr := ""
ExitApp(0)
