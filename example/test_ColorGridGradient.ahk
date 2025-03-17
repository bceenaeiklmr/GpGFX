; Script     test_ColorGridGradient.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../src/GpGFX.ahk

/**
 * Gradient color, filling a grid of 100 rectangles 1 by 1.
 * With delay, without delay.
 */
TestGradientRects(10)

TestGradientRects(-1)

End()

TestGradientRects(sleeptime := 10) {

    local lyr, obj

    ; Create a layer and a grid of rectangles
    lyr := Layer()
    obj := CreateGraphicsObject(12, 12, , , 50, 50)

    ; Enable overdraw on the layer since the positions are static
    lyr.Redraw := 1

    ; Render the layer using a gradient color transition
    loop obj.Length { 
        obj[A_Index].color := ["15410f", "Lime"]
        Render.Layer(lyr)
        Sleep(sleeptime)
    }

    Fps.Display()
}
