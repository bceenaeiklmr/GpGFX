; Script     test_ColorGridVivid.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../GpGFX.ahk

/**
 * Test to imitate vivid color change in a grid of rectangles.
 */
TestColorChangeVivid(12, 12)


TestColorChangeVivid(row := 1, col := 1) {

    ; Create layer, rects
    main := Layer(1280, 720)
    rect := CreateGraphicsObject(row, col)

    ; Preload colors
    clr := []
    clr.Capacity := rect.Length
    loop clr.Capacity
        clr.Push(Color.GetTransition("Red|Orange|Yellow", "Blue|Lime|Purple"))

    changes := 3
    distmax := 100

    ; Main loop
    loop changes {
        loop distmax {
            disti := A_Index
            loop rect.Length {
                rect[A_Index].Color := Clr[A_Index][disti]
            }
            main.Draw()
            Sleep(10)
        }
    }
}
