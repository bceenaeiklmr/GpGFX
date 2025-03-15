; Script     test_ColorGrid.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../src/GpGFX.ahk

/**
 * A simple test to show the color transition between two colors on multiple rectangles.
 * The objects display the start and end color and the current index.
 */
TestColorTransaction()


TestColorTransaction() {

    local lyr, rect, clr, distmax, dist, changes, ARGB1, ARGB2, temp

    ; Create a layer and some rectangles
    lyr := Layer()
    rect := CreateGraphicsObject(7, 0, 0, 200, 200, 5)

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
                rect[A_Index].color := Color.Transation(clr[A_Index][1], clr[A_Index][2], dist)
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
    ; 1 = 1 second delay, use .5 for half a second
    End(1)
}

