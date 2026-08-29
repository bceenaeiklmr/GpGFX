; Script     ObjectGrid.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#include ../GpGFX.ahk

lyr := Layer()

rects := CreateGraphicsObject(12, 12, , , , , 5, 0xFF000000)

start := A_TickCount

loop rects.Length {
    rects[A_index].color := "Random"
    rects[A_index].str := "Rect " A_index
    lyr.Draw
}
lyr.Clean()

MsgBox("Time taken to draw " rects.Length " rectangles: " (A_TickCount - start) " ms`n" .
 "Fps: " Format("{:.2f}", (1000 / (A_TickCount - start) * rects.Length)), "Benchmark Result", 64 " T2")

lyr := ""



