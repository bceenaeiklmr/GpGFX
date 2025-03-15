; Script     FractalTree.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../src/GpGFX.ahk

/**
 * Fractal tree generator with colored leaves.
 * 
 * @credit I think I saw this on The Coding Train channel
 * https://www.youtube.com/channel/UCvjgXvBlbQiydffZU7m1_aw
 * 
 * @param {int} x1 x coordinate of the starting point of the branch
 * @param {int} y1 y coordinate of the starting point of the branch
 * @param {int} length initial length of the tree
 * @param {int} angle angle of the branch
 * @param {int} depth depth of the recursion
 * @param {int} branch_angle angle between the branches
 */
FractalTree(x1, y1, length, angle, depth, branch_angle, branch_scale := 0.8) {
    
    static Pi := 3.1415926535897932
    static draws := 0

    ; Exit recursion
    if (!depth)
        return

    ; Calculate the end point of the current branch
    x2 := Ceil(x1 + length * Cos(angle * Pi / 180))
    y2 := Ceil(y1 - length * Sin(angle * Pi / 180))

    ; Draw the current branch
    l1 := Line(x1, y1, x2, y2, clrs[(draws+=1)], 1)

    ; Recursively draw the left and right branches
    FractalTree(x2, y2, length * branch_scale, angle - branch_angle, depth - 1, branch_angle)
    FractalTree(x2, y2, length * branch_scale, angle + branch_angle, depth - 1, branch_angle)

    ; Customize the tree
    if (depth <= recursion_depth - 4) {
        size := Random(10, 20)
        fill := Random(0, 1)
        start := Random(0, 180)
        sweep := Random(180, 360)
        ; Add some leaves
        if (!Mod(draws, 5)) {
            r := Rectangle(x2 - size // 2, y2 - size // 2, size, size, clrs[draws], fill)
        } else {
            p := Pie(x2, y2, size, size, start, sweep, clrs[draws], fill)
        }
    }    

    ; Render the drawing layer and the fps panel
    Render.Layers(lyr)
    return
}

; Create a FHD layer and a semi-transparent rectangle and a border
w := 1920
h := 1080
background := Layer(, , w, h)
rect := Rectangle(, , w, h, "0x80000000")
border := Rectangle(, , w, h, Color.GitHubBlue, 0)
border.penwidth := 30
; Draw bg only once
Draw(background)

; Create the main layer and enable overdraw
lyr := Layer( , , w, h)
lyr.redraw := 1

; Set the initial parameters for the tree
initial_x := lyr.w // 2
initial_y := lyr.y + lyr.h - 250
initial_length := 200
initial_angle := 90
branch_angle := 30
branch_scale := 0.85
recursion_depth := 10

; Preload ARGB colors into an array
clrs := []
clrs.Capacity := 2 ** recursion_depth
loop clrs.Capacity {
    clrs.Push(Color.Random("Orange|Red|Yellow|Lime"))
}

; Set rendering to 200 fps and fps layer update frequency
fpstarget := 0
panelfreq := 50
Fps(fpstarget).UpdateFreq(panelfreq)

; Call the fractal tree function recursively
FractalTree(initial_x, initial_y, initial_length, initial_angle, recursion_depth, branch_angle, branch_scale)

; Wait a bit to check the result, erase the layers, and exit
fps.Display(1500)
background := ""
lyr := ""
End()
