; Script     test_ColorSmoothTransition.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../src/GpGFX.ahk

/**
 * The main purpose of this script is to check if shapes can be constructed
 * on the right layer after a layer destruction.
 */

; Create a layer first
lyr1 := Layer(1280, 720)

; Call the func that creates its own layer
TestColorSmoothTransition()

; The rectangle will be created on the first layer
rect := Rectangle(0, 0, 1280, 720, "5d16e473")
rect.Text("Layer id: " rect.layerid "`n`n"
    . "Indeed created on the first layer.", "white", 42)
Draw(lyr1)
Sleep(1000)

End(1)

TestColorSmoothTransition() {

    local lyr, rect, colors, changes, dist, distmax

    ; Create a layer and some rectangles
    lyr := Layer()
    rect := CreateGraphicsObject(1, 7, , 200, 200, 200)

    ; Preload colors
    colors := []
    colors.Capacity := rect.Length
    variance := 42
    loop rect.Length {
        color1 := "2ba3b3"
        color2 := Color.Random("Green", variance)
        colors.Push(Color.GetTransition(color1, color2, true))
    }

    changes := 1
    distmax := colors[1].Length

    loop changes {
        loop distmax {
            dist := A_Index
            loop rect.length {
                rect[A_Index].color := colors[A_Index][dist]
                rect[A_Index].str := "Rect " A_Index "`n`n`n"
                  . intToARGB(colors[A_Index][dist]) "`n`n`n"
                  . "index " dist
            }
            Render.Layer(lyr)
            Sleep(10)
        }
    }

    Fps().Display()
}
