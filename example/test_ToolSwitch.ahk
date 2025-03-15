; Script     test_ToolSwitch.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../src/GpGFX.ahk

; Create a layer and a rect, set font color and font size
lyr := Layer(600, 600)
rect := Rectangle(,, 600, 600, "0x21000000")
rect.Text(, "cecece", 42)

; Set img path to texture brush
img := A_ScriptDir "\pic\texture.png"

; Delay between the changes in ms
t := 500

loop {
    switch A_Index {
        ; Start with a standard color shift
        case 1:
            rect.color := "Red"
            rect.str := "Standard color"
        
        ; Change color and alpha
        case 2:
            rect.color := "Black"
            rect.alpha := 0x42
            rect.str := "Alpha 0x42"
        
        ; Set back to 0xFF
        case 3:
            rect.alpha := 0xFF
            rect.str := "Alpha 0xFF"
        
        ; Get a random color from a list
        case 4:
            rect.color := "Red|Blue|Green"
            rect.str := "Color list"
        
        ; Change the brush to gradient and use colors from lists
        case 5:
            rect.color := ["Red|Blue|Green", "Yellow|Violet|Purple"]
            rect.str := "Gradient color list"
        
        ; Random gradient colors
        case 6:
            rect.color := [RandomARGB(), ""]
            rect.str := "Random gradient colors"
        
        ; Hatch pattern without background
        case 7:
            rect.color := ["hatch", "", 0x0, 24]
            rect.str := "Hatch transparent"
        
        ; Hatch with two colors
        case 8:
            rect.color := ["hatch", "Black", "Lime", 33]
            rect.str := "Hatch two colors" 
        
        ; Set back to pen brush
        case 9:
            rect.filled := 0, rect.color := "blue"
            rect.str := "Pen brush"
        
        ; Use a texture brush
        case 10:
            rect.color := ["texture", img, 1, 0]
            rect.str := "Texture"
        
        ; Breaks the loop
        default: break
    }
    ; The layer can be draw with a function or with its own method
    lyr.Draw
    Sleep(t)
}
; Without a function the window will not be destroyed,
; calling End is necessary in this case
End
