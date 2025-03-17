; Script     test_CreateGraphicsObject.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../src/GpGFX.ahk

/**
 * Test for the createGraphicsObject function.
 */

; Creates a full screen layer
main := Layer()

; Test cases
rect := CreateGraphicsObject(13, 4) ; should fill the available area
loop rect.Length
    rect[A_Index].Color := Color()
main.Draw
Sleep 1000
rect := ""

rect := CreateGraphicsObject(2, 2, 0, 0, 200, 200, 25) ; should start at (0, 0)
loop rect.Length
    rect[A_Index].Color := Color()
main.Draw
Sleep 1000
rect := ""

rect :=  CreateGraphicsObject(2, 2, 100, 200, 200, 50, 25) ; should start at (100, 100)
loop rect.Length
    rect[A_Index].Color := Color()
main.Draw
Sleep 1000
rect := ""

rect := CreateGraphicsObject(2, 2, 0, 0, 200, 200, 5) ; should start at (0, 0) with padding 1
loop rect.Length
    rect[A_Index].Color := Color()
main.Draw
Sleep 1000
rect := ""

rect := CreateGraphicsObject(3, 3, 0, 0, 200, 200, 0) ; should start at (0, 0) with padding 0
loop rect.Length
    rect[A_Index].Color := Color()
main.Draw
Sleep 1000
rect := ""

rect := CreateGraphicsObject(2, 2, , 50, 200, 200, 0) ; x unset, y set
loop rect.Length
    rect[A_Index].Color := Color()
main.Draw
Sleep 1000

End
