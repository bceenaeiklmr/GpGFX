; Script:    01_Layer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

; Create an auto layer, the size is the same as the screen size,
lyr := Layer()

; Create a red rectangle shape (adds it to the last layer automatically)
Rectangle("red")

; Draw the layer for 1500 milliseconds
lyr.Draw(-1500)

; Delete the layer, since the layer is window and it makes the script persistent
;lyr := ""