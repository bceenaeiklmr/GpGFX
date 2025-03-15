; Script     test_ColorNames.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../src/GpGFX.ahk

; Create a layer and a background rectangle
main := Layer(1280, 720)
back := Rectangle(,, main.w, main.h, 0x80000000)

; Create a canvas layer
canv := Layer(main.w, main.h)

; Create rectangles from the available color names
rect := []
rectW := 100
rectH := 50
pad := 100

; Number of draws in the main loop
test := 2 ** 10

; Get the color names and ARGB values from the Color class
for cname, ARGB in Color.OwnProps() {

    ; Parse only color names
    if (!IsARGB(ARGB))
        continue
    
    ; Add some randomness to the position
    rx := Random(pad, main.w - rectW - pad)
    ry := Random(pad, main.h - rectH - pad)
    
    ; Create the rectangle, set its name
    r := Rectangle(rx, ry, rectW, rectH, ARGB)
    r.str := cname
    rect.Push(r)
}

; Draw the background once
Draw(main)

; Start the main loop
loop test {
    loop rect.Length {
        rect[A_Index].x += Random(1, -1)
        rect[A_Index].y += Random(1, -1)
    }
    ; We measure the fps, we use render instead of draw
    Render.Layer(canv)
}

; Display the fps panel
Fps.Display(2000)

; Clean up
main := ""
canv := ""
End
