; Script     MouseTrail.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       13.04.2025

#include ../../GpGFX.ahk

; Set the mouse coordinate mode to screen.
CoordMode("Mouse", "Screen")

; Create a layer for the main display.
lyr := Layer()

; A dummy invisible rectangle to keep the layer updated.
dummy := Rectangle(0, 0, 1, 1, 0x0)

; Setup a timer to call the MouseTrail function every 15.67 ms, ~60 FPS (1000 ms / 60 frames).
SetTimer(MouseTrail, 15.67)


; Display a mouse trail effect.
MouseTrail(alpha := 0x90) {

    local x, y, arr, dx, dy, pieSize, px, py, ARGB

    static lastx := 0
    static lasty := 0
    
    ; Get the current mouse position, only continue if it has changed.
    MouseGetPos(&x, &y)
    if (lastx lasty != x y) {

        ; Calculate the direction of the mouse movement.
        dx := (lastx > x) ?  1 : (x > lastx) ? -1 : .33
        dy := (lasty > y) ? -1 : (y > lasty) ?  1 : .33

        ; Array to hold the pie shapes temporarily.
        arr := []

        ; Start looping.
        loop 2 {
            px := Ceil(lastX + Random(1, 192) * dx)
            py := Ceil(lastY + Random(1,  64) * dy)
            pieSize := Random(6, 12)
            ARGB := Color.RandomARGBAlphaMax(alpha, alpha)
            arr.Push(Pie(px, py, pieSize, pieSize, 1, 360, ARGB))
            
            ; Setup a timer to dispose the pie.       
            SetTimer(ObjBindMethod(arr[A_Index], "__Delete"), -Random(200, 350))
        }
        ; Save the mouse position.
        lastx := x
        lasty := y
    }
    ; Update the layer.
    Draw(lyr)   
    return
}

; Exit to clean up resources.
^Esc::End()
