; Script:    ColorGridGradient.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

/**
 * Gradient color, filling a grid of 100 rectangles 1 by 1.
 * With delay, without delay.
 */
TestGradientRects(60)

TestGradientRects(0)

End()

TestGradientRects(fps := 60) {

    local lyr, obj

    ; Create a layer and a grid of rectangles
    lyr := Layer(1920, 1080)
    obj := CreateGraphicsObject(12, 12, , , 50, 50)

    ; Enable overdraw on the layer since the positions are static
    lyr.Redraw := true

    ; Set frame pacing target
    Fps.SetTarget(fps)

    ; Render the layer using a gradient color transition
    loop obj.Length { 
        obj[A_Index].color := ["15410f", "Lime"]
        Render.Layer(lyr)
    }

    Fps.Display()
    lyr.Dispose()
}
