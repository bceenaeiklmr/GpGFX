; Script:    BitmapPixelAccess.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

CoordMode("Mouse", "Screen")

; Create a test layer
lyr := Layer(800, 500, "Pixel Inspector Test")

; Background card
card := RoundedRectangle(20, 20, 760, 460, 25, "0xFF1E1E2E", true)

; Draw some colorful shapes
r1 := RoundedRectangle(50, 60, 200, 120, 15, "0xFFE74C3C", true)  ; Red
r2 := Circle(360, 120, 60, "0xFF3498DB", true)                     ; Blue
r3 := ClosedCurve([500, 80, 580, 50, 650, 110, 620, 170, 520, 150], "0xFF2ECC71", true, 0.5) ; Green

; Create a custom Bitmap shape and paint a colorful procedural pattern using SetPixel
bmp := Bitmap(200, 200)
loop 200 {
    y := A_Index - 1
    loop 200 {
        x := A_Index - 1
        ; Generate a plasma/gradient color formula
        r := Integer(128 + 127 * Sin(x / 20.0))
        g := Integer(128 + 127 * Cos(y / 20.0))
        b := Integer(128 + 127 * Sin((x + y) / 30.0))
        argb := (0xFF << 24) | (r << 16) | (g << 8) | b
        bmp.SetPixel(x, y, argb)
    }
}

; Embed our SetPixel-generated bitmap into a preview frame
plasmaBox := RoundedRectangle(50, 220, 220, 220, 15, "Black", true)
plasmaBox.AddImage(bmp)

; Info & Color Swatch panel
panel := RoundedRectangle(320, 220, 420, 220, 15, "0xFF252538", true)
swatch := RoundedRectangle(340, 250, 80, 80, 10, "0xFFFF0000", true)
infoText := Rectangle(440, 230, 280, 190, "0x00000000", true)
infoText.Text("Hover over any shape/plasma`nto inspect pixels in real-time!`n`nPress ESC to close.", "White", 11, "Segoe UI", "", 5, "left", "top")

Draw(lyr)

; Real-time pixel inspector on mouse move
SetTimer(InspectPixel, 20)

InspectPixel() {
    static lastX := -1, lastY := -1
    if (!WinExist("ahk_id " lyr.hwnd))
        ExitApp()

    MouseGetPos(&mx, &my)
    lx := mx - lyr.x
    ly := my - lyr.y

    if (lx >= 0 && ly >= 0 && lx < lyr.w && ly < lyr.h) {
        if (lx != lastX || ly != lastY) {
            lastX := lx
            lastY := ly
            hexColor := lyr.GetPixel(lx, ly, "hex")
            rgba := lyr.GetPixel(lx, ly, "rgba")

            swatch.color := hexColor
            infoText.str := "X: " lx "  |  Y: " ly "`n`nHEX: " hexColor "`nRGBA: (" rgba.r ", " rgba.g ", " rgba.b ", " rgba.a ")`n`nPress ESC to exit."
            Draw(lyr)
        }
    }
}

Esc::ExitApp()
