; Script:    AnimatedTooltip.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

/**
 * A simple example of a gradient notification tooltip.
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

    ; Setup 60 FPS pacing
    Fps.SetTarget(144)

    ; Animation growth speed
    unit := 20

    ; Grow
    loop (lyr.w // unit) {
        rect.w += unit
        Render.Layer(lyr)
    }
    ; Typewriter text
    loop StrLen(str) {
        strg := SubStr(str, 1, A_index)
        rect.Text(strg, 'black', 24)
        Render.Layer(lyr)
    }
    ; Pause
    Time.Delay(timeout)
    rect.str := ""
    Render.Layer(lyr)
    ; Shrink
    loop (lyr.w // unit) {
        rect.w -= unit
        Render.Layer(lyr)
    }
    lyr.Dispose()
}
