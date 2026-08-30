; Script:    02_Basic_Shapes.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

; Example:    02_Basic_Shapes.ahk
; Description: Demonstrates core vector shape primitives (Rectangles, Circles, Triangles, Lines, Beziers).
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; Create a 700x450 canvas window
lyr := Layer(700, 450).Center()

; Dark background canvas
RoundedRectangle(700, 450, 12, "0xFF181825")

; Title
Text(20, 20, 660, 30, "GpGFX Vector Shape Primitives", "0xFFCDD6F4", 14, "Segoe UI", "Bold").Left()

; Row 1: Solid & Outline Shapes
; 1. Filled Rectangle (x, y, w, h, colour)
Rectangle(40, 70, 100, 70, "0xFF89B4FA") ; Solid Blue Fill
Text(40, 150, 100, 20, "Rectangle", "0xFFA6ADC8", 9).Center()

; 2. Stroked Rectangle with 2px Pen (filled: false)
rectStroke := Rectangle(170, 70, 100, 70, "0xFF89B4FA", false)
rectStroke.penwidth := 2
Text(170, 150, 100, 20, "Stroke Rect", "0xFFA6ADC8", 9).Center()

; 3. Rounded Rectangle with corner radius 14px
RoundedRectangle(300, 70, 100, 70, 14, "0xFFA6E3A1") ; Solid Green
Text(300, 150, 100, 20, "RoundedRect", "0xFFA6ADC8", 9).Center()

; 4. Circle (x, y, radius, colour)
Circle(480, 105, 35, "0xFFFAB387") ; Peach Circle
Text(430, 150, 100, 20, "Circle", "0xFFA6ADC8", 9).Center()

; 5. Triangle (x1, y1, x2, y2, x3, y3, colour)
Triangle(610, 140, 560, 70, 660, 70, "0xFFF38BA8") ; Mauve Triangle
Text(560, 150, 100, 20, "Triangle", "0xFFA6ADC8", 9).Center()

; Row 2: Curves, Splines & Lines
; 6. Straight Line (x1, y1, x2, y2, colour, penwidth)
Line(40, 260, 140, 210, "0xFFF9E2AF", 3)
Text(40, 290, 100, 20, "Line", "0xFFA6ADC8", 9).Center()

; 7. Cubic Bezier Curve (start, control1, control2, end, colour, penwidth)
Bezier(170, 270, 200, 190, 240, 310, 270, 220, "0xFFCBA6F7", 3)
Text(170, 290, 100, 20, "Bezier Spline", "0xFFA6ADC8", 9).Center()

; 8. Cardinal Spline Curve through points array
Curve([300, 260, 330, 210, 360, 270, 390, 220], "0xFF94E2D5", 3, 0.5)
Text(300, 290, 100, 20, "Smooth Curve", "0xFFA6ADC8", 9).Center()

; 9. Filled Polygon from arbitrary vertex points
Polygon([450, 270, 480, 210, 520, 230, 540, 280, 470, 290], "0xFF89DCEB")
Text(440, 290, 100, 20, "Polygon", "0xFFA6ADC8", 9).Center()

; 10. Pie Wedge (x, y, w, h, startAngle, sweepAngle, colour)
Pie(570, 210, 70, 70, 30, 280, "0xFFF5C2E7")
Text(560, 290, 100, 20, "Pie Wedge", "0xFFA6ADC8", 9).Center()

; Bottom Instructions
Text(20, 400, 660, 30, "Press ESC to exit • Drag window with mouse", "0xFF6C7086", 10).Center()
lyr.Drag()

; Render to screen
lyr.Draw()

Esc::ExitApp()
