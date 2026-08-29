; Script     AllShapesConstruction.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

try {
    lyr := Layer(1000, 400, "AllShapesTest")

    ; 1. Rectangles / Squares
    Rectangle(10, 10, 80, 50, "Red", true)
    Square(100, 10, 50, "Blue", true)
    Rectangle(160, 10, 80, 50, "Green", false)

    ; 2. Ellipses
    Ellipse(250, 10, 80, 50, "Yellow", true)
    Ellipse(340, 10, 80, 50, "Cyan", false)

    ; 3. Arc
    Arc(430, 10, 80, 50, "White", 2, 0, 180)

    ; 4. Pie
    Pie(520, 10, 80, 80, 0, 270, "Magenta", true)
    Pie(610, 10, 80, 80, 0, 270, "Orange", false)

    ; 5. Triangle
    Triangle(10, 150, 50, 90, 90, 150, "Lime", true)
    Triangle(110, 150, 150, 90, 190, 150, "Red", false)

    ; 6. Polygon
    Polygon("Purple", true, 1, [210, 150, 230, 90, 270, 90, 290, 150, 250, 180])

    ; 7. Line & Lines
    Line(310, 90, 390, 170, "White", 3)
    Lines("Yellow", 2, [410, 100, 440, 170, 470, 110, 500, 170])

    ; 8. Bezier & Beziers
    Bezier(520, 150, 550, 80, 580, 200, 610, 120, "Cyan", 3)
    Beziers("Pink", 2, [630, 150, 650, 80, 680, 200, 710, 120])

    ; 9. Point
    Point(740, 120, "White")

    ; 10. RoundedRectangle (Filled & Outlined)
    RoundedRectangle(10, 220, 100, 60, 15, "Orange", true)
    RoundRect(120, 220, 100, 60, 20, "Violet", false)

    ; 11. Curve & ClosedCurve (Cardinal Splines)
    Curve([240, 260, 280, 220, 320, 270, 360, 230], "Teal", 3, 0.5)
    ClosedCurve([390, 250, 430, 220, 470, 240, 460, 280, 410, 275], "Gold", true, 0.5)
    ClosedCurve([490, 250, 530, 220, 570, 240, 560, 280, 510, 275], "DeepPink", false, 0.5)

    lyr.Draw()
    Sleep(1000)
    ;lyr.toFile("C:\dev\projects\GpGFX\Test\rendered_shapes.png")
    lyr.Dispose()

    ;FileAppend("All shapes rendered successfully!`n", "C:\dev\projects\GpGFX\Test\shapes_status.txt")
;} catch as err {
;    FileAppend("Caught Error: " err.Message "`nLine: " err.Line "`nWhat: " err.What "`nFile: " err.File "`nStack: " err.Stack "`n", "C:\dev\projects\GpGFX\Test\shapes_status.txt")
}

ExitApp()
