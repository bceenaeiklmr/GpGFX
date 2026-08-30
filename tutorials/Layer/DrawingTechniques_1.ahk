; Script:    DrawingTechniques_1.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../../GpGFX.ahk

lyr := Layer(600, 480)

counter := Signal(0)

; Bind shape to auto-display signal value:
Text("0").Bind(counter)

; Bind layer to auto redraw whenever counter changes:
lyr.Draw(counter)

loop 5 {
    counter.Value := counter.Value + 1
    Sleep(1000)
}