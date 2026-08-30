; Script:    ShorthandShapes.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Include ../../GpGFX.ahk

lyr := Layer()

; 1. Full layer 1px red stroke outline
Rectangle("0xFFFF0055", false)

; 2. Or with color names and booleans:
Rectangle("red", false)
Rectangle(0xFFFF0055, 0)
RoundedRectangle("0xFFFF0055", false)
RoundedRectangle(15, "0xFFFF0055", false)   ; With custom radius
Square("blue", false)
Circle("purple", false)
Circle(50, "yellow", false)                 ; With custom radius
Ellipse("gold", false)
Pie("orange", false)
Triangle("cyan", false)

lyr.Draw(-1500)