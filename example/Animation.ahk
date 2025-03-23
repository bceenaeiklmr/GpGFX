; Script     Animation.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025

#include ../GpGFX.ahk

/**
 * How to perform basic animations with shapes.
 */

; Create a layer.
lyr := Layer()

; Create shapes.
obj := CreateGraphicsObject(1, 13, , , 150, 150)

; Split str into an array.
str := StrSplit("Hello, World!")

; Hide shapes, set text.
for v in obj {
    v.Hide()
    v.Text(str[A_Index], , 24)
}

; Perform roll down animation.
Shape.RollDown(obj, 1, 10)
Sleep(1000)

; Change shape color.
for v in obj {
    v.Color := ""
    Sleep(50)
    lyr.Draw
}
Sleep(1000)

; Roll up.
Shape.RollUp(obj, 1, 10)

; Start the cleanup.
End()
