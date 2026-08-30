; Script:    SplineCurves.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

lyr := Layer(1000, 600, "Curves Test")

; 1. Open Curve passing through points
pts1 := [50, 150, 150, 50, 250, 200, 350, 80, 450, 180]
c1 := Curve(pts1, "Cyan", 3, 0.5)

; 2. Filled ClosedCurve
pts2 := [550, 150, 650, 60, 750, 120, 780, 220, 680, 260, 580, 200]
cc1 := ClosedCurve(pts2, "0xFF9B59B6", true, 0.5)

; 3. Outlined ClosedCurve
pts3 := [100, 400, 200, 320, 320, 380, 280, 500, 150, 520]
cc2 := ClosedCurve(pts3, "0xFFE67E22", false, 0.7)
cc2.penwidth := 4

; 4. Dynamic toggling test
pts4 := [550, 420, 680, 340, 800, 400, 750, 520, 600, 500]
cc3 := ClosedCurve(pts4, "0xFF2ECC71", true, 0.5)

lyr.Draw()
Sleep(500)

; Toggle filled to false (switches to outline Pen)
cc3.filled := false
cc3.penwidth := 3
lyr.Draw()
Sleep(500)

; Modify tension
cc3.tension := 1.2
lyr.Draw()
Sleep(500)

; Toggle back to filled
cc3.filled := true
lyr.Draw()
Sleep(500)

lyr := ""
ExitApp(0)
