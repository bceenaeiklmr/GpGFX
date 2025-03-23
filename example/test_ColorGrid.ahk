; Script     test_ColorGrid.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../GpGFX.ahk

/**
 * A simple test to show the color transition between two colors on multiple rectangles.
 * The objects display the start and end color and the current index.
 */
TestColorTransition()


TestColorTransition() {

    local lyr, rect, clr, distmax, dist, changes, ARGB1, ARGB2, temp

    ; Create a layer and some rectangles
    lyr := Layer()

    size := 7
    pad := 5

    ; We don't specify the positions, so it will be centered,
    ; and either the width or height will be 'filled'
    rect := CreateGraphicsObject(10, 10, , , , , 5)

    ; Preload colors
    clr := []
    loop rect.Length
        clr.Push([RandomARGB(), RandomARGB()])

    changes := 3
    distmax := 100

    loop changes {
        loop distmax {
            dist := A_Index
            loop rect.length {
                ARGB1 := clr[A_Index][1]
                ARGB2 := clr[A_Index][2]
                rect[A_Index].color := Color.Transition(clr[A_Index][1], clr[A_Index][2], dist)
                rect[A_Index].str := "Rect " A_Index "`n`n`n" intToARGB(ARGB1) "`n`n" intToARGB(ARGB2) "`n`n`nindex " dist
            }
            Draw(lyr)
            Sleep(10)
        }
        ; Swap next color
        loop rect.length {
            temp := clr[A_Index][1]
            clr[A_Index][1] := clr[A_Index][2]
            clr[A_Index][2] := temp
        }
    }
    End()
}
