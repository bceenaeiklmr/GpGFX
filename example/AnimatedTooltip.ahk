; Script     AnimatedTooltip.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../src/GpGFX.ahk

/**
 * A simple example for a gradient notification tooltip.
 */
Notification("Hello, " A_UserName "!")


Notification(str := "", color1 := "lime", color2 := "000000", timeout := 1000) {
    
    ; Create layer
    width := 1000
    height := 100
    lyr := Layer(width, height)

    ; Create rectangle with gradient color
    rect := Rectangle(0, 0, 1000, 100, 'Black')
    rect.color := [color1, color2]
    rect.w := 0

    ; Basically how fast the rectangle grows
    unit := 1

    ; Grow
    loop (lyr.w // unit) {
        lyr.Draw()
        rect.w += unit
    }
    ; Text
    loop StrLen(str) {
        strg := SubStr(str, 1, A_index)
        rect.Text(strg, 'black', 24)
        Sleep(15.6)
        lyr.Draw()
    }
    ; Wait
    Sleep(timeout)
    rect.str := ""
    lyr.Draw()
    ; Shrink
    loop (lyr.w // unit) {
        rect.w -= 1
        lyr.Draw()
    }
}
