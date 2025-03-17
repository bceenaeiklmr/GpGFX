; Script     test_BrushTexture.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../src/GpGFX.ahk

; Create a layer
main := Layer()

; Path to the image file
img := A_ScriptDir "\pic\texture.png"

; Create a triangle but using the Polygon class instead of the Triangle class
Triangle_pts := [200, 300, 700, 300, 450, 633]
poly := Polygon("red", 1, 0, Triangle_pts)
Draw(main)
Sleep(1000)

; Change the polygon color to a texture
poly.Color := ["texture", img, .5, 0]
Draw(main)
Sleep(1000)

; Use Texture brush to fill multiple objects
BrushTexture()

; Debug the layer used space
main.debug()

; Clean up is necessary here, destroys the window so the script can start the exit routine
main := ""
; Or just use End

BrushTexture() {
    ; We don't need to create another layer, we can use the global main layer
    ; Set the properties of the object grid
    row := 4
    col := 6
    pad := 10
    objW := 150
    objH := 150

    ; Resize the texture
    resize := 90

    ; Create the object grid
    rect := CreateGraphicsObject(row, col, , , objW, objH, pad)

    ; Fill the objects with random colors or with the texture brush
    loop rect.Length {
        if !Mod(A_Index, 2) {
            wrap := Random(0, 3)
            rect[A_Index].Color := ["texture", img, wrap, resize]
        } else {
            rect[A_Index].Color := Color.Random("Red|Yellow|Green")
        }
    }
    Draw(main)
    Sleep(1000)
}
