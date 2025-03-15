; Script     testColorGridGradient.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../GpGFX.ahk

/**
 * Gradient color, filling a grid of rectangles 1 by 1
 */
TestGradientRects()

TestGradientRects() {

    local lyr, obj

    ; Create a layer and a grid of rectangles
    lyr := Layer()
    obj := CreateGraphicsObjectGrid(3, 12, 0, 0, 100, 100)

    ; Enable overdraw on the layer since the positions are static
    lyr.Redraw := 1

    ; Render the layer using a gradient color transition
    loop obj.Length { 
        obj[A_Index].color := ["15410f", "Lime"]
        Render.Layer(lyr)
        Sleep(10)
    }

    Fps.Display()
    End()
}
