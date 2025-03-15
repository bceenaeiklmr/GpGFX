; Script     test_MultipleLayer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../src/GpGFX.ahk

/**
 * This example demonstrates how to create multiple layers and render them with a specific fps.
 */
MultipleLayerWithFps()

MultipleLayerWithFps() {

    ; Create a layer, resize and center it
    lyr := Layer()
        .Resize(400, 300)
        .Center()
    
    ; lyr := Layer(400, 300) ; will be the same as above

    ; Create a rect
    rect := Rectangle(0, 0, 320, 240, "0x800000FF", 1)

    ; Create another layer and rect
    lyr2 := Layer(0, 0, 100, 100)
    rect2 := Rectangle(0, 0, 100, 100, "Red", 1)

    ; Set the fps to 60
    Fps(60)

    ; Loop 255 times moving the layers and changing the alpha on the first layer
    loop 255 {
        lyr.x += 1
        lyr.alpha := A_Index
        lyr2.x += 2
        Render.Layers(lyr, lyr2)    
    }

    ; Cleanup the layer, Since functions use local the cleanup is not necessary
    ; lyr := unset
    ; lyr2 := unset

    ; End will make sure fps window is destroyed
    End(.8)
}
