; Script     06_Signals_and_Animation.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

; Example:    06_Signals_and_Animation.ahk
; Description: Demonstrates reactive Signals for zero-CPU data binding and smooth non-blocking animations.
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; Create canvas window
lyr := Layer(640, 460).Center()
RoundedRectangle(640, 460, 14, "0xFF1E1E2E")

; Header
Text(25, 20, 590, 30, "GpGFX Reactive Signals & Animations", "0xFFCDD6F4", 15, "Segoe UI", "Bold").Left()
Text(25, 55, 590, 20, "Modifying a Signal automatically updates bound shapes and redraws the layer.", "0xFFA6ADC8", 10).Left()

; 1. Create a Reactive Signal State Variable
counterSig := Signal(0)

; 2. Create a Text Shape and Bind it to the Signal!
; Whenever counterSig.Value changes, this shape auto-updates and redraws the layer with 0 ms latency!
counterDisplay := Text(40, 100, 250, 60, "0", "0xFF89B4FA", 28, "Segoe UI", "Bold").Center()
counterDisplay.Bind(counterSig, (val, shp) => shp.str := "Count: " val)

; 3. Interactive Buttons modifying the Signal
Button(40, 180, 120, 38, "+1 Add", (*) => counterSig.Value++, "0xFFA6E3A1", "0xFF313244")
Button(170, 180, 120, 38, "-1 Sub", (*) => counterSig.Value--, "0xFFF38BA8", "0xFF313244")

; 4. Smooth Non-Blocking Animation using Signal.Animate
; Progress bar background card
RoundedRectangle(340, 100, 250, 60, 8, "0xFF313244")

; Animated Progress Bar fill
progressSig := Signal(0)
barFill := RoundedRectangle(340, 100, 0, 60, 8, "0xFFFAB387")
barFill.Bind(progressSig, (val, shp) => shp.w := val)

; Progress Percentage Text
progLabel := Text(340, 118, 250, 30, "0%", "0xFFCDD6F4", 12, "Segoe UI", "Bold").Center()
progLabel.Bind(progressSig, (val, shp) => shp.str := Round((val / 250) * 100) "%")

Button(340, 180, 250, 38, "Animate Progress (easeOut)", (*) => AnimateProgress(), "0xFFCBA6F7", "0xFF313244")

AnimateProgress() {
    ; Smoothly animate from 0px to 250px over 700 ms using "easeOut" easing curve
    Signal.Animate(progressSig, 0, 250, 700, "easeOut")
}

; 5. Shape Property Animations: RollDown / RollUp & FadeIn / FadeOut
demoCard := RoundedRectangle(40, 250, 550, 110, 10, "0xFF28283D")
Text(55, 275, 520, 60, "Built-in Property Animations:`nshp.RollDown() • shp.RollUp() • shp.FadeIn() • shp.FadeOut()", "0xFFCDD6F4", 11, "Segoe UI").Left()

Button(40, 380, 120, 36, "Roll Up", (*) => demoCard.RollUp(400, "easeIn"), "0xFFF38BA8", "0xFF313244")
Button(170, 380, 120, 36, "Roll Down", (*) => demoCard.RollDown(400, "easeOut"), "0xFFA6E3A1", "0xFF313244")
Button(300, 380, 120, 36, "Fade Out", (*) => demoCard.FadeOut(300), "0xFFFAB387", "0xFF313244")
Button(430, 380, 120, 36, "Fade In", (*) => demoCard.FadeIn(300), "0xFF89B4FA", "0xFF313244")

; Enable drag & initial render
lyr.Drag().Draw()

Esc::ExitApp()
