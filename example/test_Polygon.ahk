; Script     test_Polygon.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../src/GpGFX.ahk

/**
 * Draw multiple shapes and test the bounds of the canvas.
 */
testPoly()
testLayerBounds()

testPoly() {
    ; Layer, shape, display
    lyr := Layer(1920, 1080)
    poly := Polygon("Red", 1, 0, [200, 200, 700, 200, 450, 633])
    lyr.Draw()
    Sleep(1000)
}

testLayerBounds() {

    ; layer, background
    lyr := Layer(1920, 1080)
    bg := Rectangle(, , 100, 100, "Yellow")

    ; Points coordinates in the form of [x1, y1, x2, y2, x3, y3, ...]
    aTriangle := [200, 200, 700, 200, 450, 633]
    aHexagon := [1280, 670, 1380, 695, 1380, 745, 1280, 770, 1180, 745, 1180, 695]
    aBezier := [100, 100, 200, 200, 300, 100, 400, 200, 500, 100, 600, 200, 700, 100, 800, 200, 900, 100, 1000, 200, 1100, 100, 1200, 200, 1300, 100]
    aLines := [100, 100, 200, 200, 300, 100, 400, 200, 500, 100, 600, 200, 700, 100, 800, 200, 900, 100, 1000, 200, 1100, 100, 1200, 200, 1300, 100]

    ; Construct shapes
    poly1 := Polygon("2bff00", 0, 0, aTriangle)
    poly2 := Polygon("f700ff", 1, 0, aHexagon)
    bez := Beziers(Color.red, 1, aBezier)
    lns := Lines("Blue", 2, aLines)

    ; Display
    lyr.Draw()
    Sleep(2000)
    lyr.debug(.99, 0)
}
