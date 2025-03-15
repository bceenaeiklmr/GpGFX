; Script     LorenzSystem.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../GpGFX.ahk

width := 1440
height := 900

; Create a background layer, draw it once
lyrBg := Layer(width, height)
background := Rectangle(, , width, height, '0xff000000')
Draw(lyrBg)

; Create a canvas layer
canv := Layer(, , width, height)
; Enable overdraw on the layer
canv.Redraw := true

; Currently smoothing mode cannot be changed dynamically, but this will make
; the lines smoother (antialiasing)
DllCall("Gdiplus\GdipSetSmoothingMode", "ptr", Graphics.%canv.id%.gfx, "int", 4)

; Set Fps to persistent, displayed and update it on every 200 frames
Fps().UpdateFreq(200)

; Start rendering
RenderLorenzSystem(50000)

RenderLorenzSystem(test := 5000)
{
    ; https://en.wikipedia.org/wiki/Lorenz_system
    ; https://www.youtube.com/watch?v=f0lkz2gSsIk
    ; credit: GeekDude helped me with the provided code years ago.

    scale := 5
    delta_time := 0.01 / 5

    ls_1 := LorenzSystem(10, 28, 8 / 3, 0.01, 1, 1) ; a, b, c, x, y, z
    ls_2 := LorenzSystem(28, 50, 5 / 2, 0.01, 1, 1) ; a, b, c, x, y, z
    ls_3 := LorenzSystem(38, 70, 9 / 2, 0.01, 10, 1) ; a, b, c, x, y, z

    ls_1.Line := Line(0, 0, 0, 0, 'Red', 2)
    ls_2.Line := Line(0, 0, 0, 0, 'Blue', 1)
    ls_3.Line := Line(0, 0, 0, 0, 'Lime', 1)

    loop test {

        ; Draw the latest step of simulations
        last_x := ls_1.x
        last_y := ls_1.y

        ls_1.step(delta_time)
        ls_1.Line.x1 := width / 2 + last_x * scale - 300
        ls_1.Line.y1 := height / 2 + last_y * scale
        ls_1.Line.x2 := width / 2 + ls_1.x * scale - 300
        ls_1.Line.y2 := height / 2 + ls_1.y * scale

        last_x := ls_2.x, last_y := ls_2.y
        ls_2.step(delta_time)
        ls_2.Line.x1 := width / 2 + last_x * scale + 300
        ls_2.Line.y1 := height / 2 + last_y * scale
        ls_2.Line.x2 := width / 2 + ls_2.x * scale + 300
        ls_2.Line.y2 := height / 2 + ls_2.y * scale

        last_x := ls_3.x, last_y := ls_3.y
        ls_3.step(delta_time)
        ls_3.Line.x1 := width / 2 + last_x * scale
        ls_3.Line.y1 := height / 2 + last_y * scale
        ls_3.Line.x2 := width / 2 + ls_3.x * scale
        ls_3.Line.y2 := height / 2 + ls_3.y * scale

        ; The drawing layer and the fps layer will be rendered
        Render.Layers(canv)
    }
    ; End should be called here, this will destroy the existing layers, freeing up resources
    End(1)
}

; https://en.wikipedia.org/wiki/Lorenz_system
; https://www.youtube.com/watch?v=f0lkz2gSsIk
; credit: G33kDude helped me with the provided code years ago.
class LorenzSystem {

    __New(a, b, c, x, y, z)
    {
        this.a := a
        this.b := b
        this.c := c

        this.x := x
        this.y := y
        this.z := z
    }

    step(dt := 0.01)
    {
        dx := 0
        dy := 0
        dz := 0
        dx += (this.a * (this.y - this.x)) * dt
        dy += (this.x * (this.b - this.z) - this.y) * dt
        dz += (this.x * this.y - this.c * this.z) * dt

        this.x += dx
        this.y += dy
        this.z += dz
    }
}

; End called from function
;lyr2 := ""
;End
