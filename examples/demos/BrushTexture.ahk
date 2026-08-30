; Script:    BrushTexture.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

; Create a layer
main := Layer()

; Create a procedural in-memory texture bitmap (64x64 checkerboard)
img := GdipBitmap(64, 64)
loop 64 {
    y := A_Index - 1
    loop 64 {
        x := A_Index - 1
        clr := Mod(x // 8 + y // 8, 2) ? 0xFF89B4FA : 0xFF313244
        img.SetPixel(x, y, clr)
    }
}

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
