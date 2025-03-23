; Script     test_Image.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../GpGFX.ahk

/**
 * Square object instead of rectangle, image properties during drawing.
 * How to move instantly the layer.
 */

; Create a layer
lyr := Layer(0, 0, A_ScreenWidth, A_ScreenHeight)

; Create a square
size := 256
sq := Square(0, 0, size, "Red")

; Add an image to the square
sq.AddImage(A_ScriptDir "\pic\texture.png", "200", "sepia")

; Draw the layer
Draw(lyr)

; Play with the image
loop 20 {
    sq.bmpX += 5    ; move the destination image
    sq.bmpY += 5
    sq.bmpW += 0
    sq.bmpH += 0
    sq.bmpSrcX -= 5 ; move the source image
    sq.bmpSrcY -= 5
    sq.bmpSrcW += 0
    sq.bmpSrcH += 0
    Draw(lyr)
    Sleep(100)
}

; Move the layer
t1 := A_TickCount
loop 2560 - size {
    ; Since the object is static now, we can move the layer in a different way.
    ; This is way faster than drawing and updating the layer.
    ; TODO: Consider to move the Update function to the Layer class outside from Draw.
    x := A_Index
    WinMove(x, , , , lyr.hwnd)
}

; Calculate the rough fps for layer moving
; Using fps instead of fpsv would try to override the Fps class (reserved keyword)
fpsv := (2560 - size) / (A_TickCount - t1) * 1000
MsgBox(A_TickCount - t1 . "ms `t fps " Round(fpsv, 2), "Image test", "T1")

; The layer will not be garbage collected, since it's a global variable
; lyr := "" ; either unset or let it be destroyed by End.
End()
