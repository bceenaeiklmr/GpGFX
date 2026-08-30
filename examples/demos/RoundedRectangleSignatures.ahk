; Script:    RoundedRectangleSignatures.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

﻿#include ../../GpGFX.ahk

lyr := Layer(800, 600, "RoundedRectangle Test")

; 1. Filled rounded rectangle with custom radius
rr1 := RoundedRectangle(50, 50, 200, 100, 20, "0xFF3498DB", true)

; 2. Outlined rounded rectangle with pen
rr2 := RoundRect(300, 50, 200, 100, 30, "0xFFE74C3C", false)
rr2.penwidth := 4

; 3. Centered rounded rectangle using alias RoundRectangle
rr3 := RoundRectangle(200, 100, 15, "0xFF2ECC71", true)

; 4. Dynamic toggling test
rr4 := RoundedRectangle(50, 200, 150, 80, 15, "0xFFF1C40F", true)
Draw(lyr)
Sleep(500)

; Toggle filled to false (switches to outline Pen)
rr4.filled := false
rr4.penwidth := 3
Draw(lyr)
Sleep(500)

; Modify radius
rr4.r := 35
Draw(lyr)
Sleep(500)

; Toggle back to filled
rr4.filled := true
Draw(lyr)
Sleep(500)

lyr := ""
ExitApp(0)
