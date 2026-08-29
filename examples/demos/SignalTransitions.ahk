; Script     SignalTransitions.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../GpGFX.ahk

lyr := Layer(480, 200, "Color Transition Demo")

; Background card using Nord theme
RoundedRectangle(14, Color.Nord.bg, true)
Text("Reactive Health Bar Transition (Red -> Green)", Color.Nord.accent, 12, "Segoe UI", "Bold").MiddleCenter().Shift(0, -40)

; Track background
RoundedRectangle(30, 110, 420, 28, 6, Color.Nord.bgAlt, true)

; Reactive health signal (0.0 = Dead / Red, 1.0 = Full / Green)
sigHP := Signal(0.0)

; Health bar: Width AND Color dynamically transition in real-time
bar := RoundedRectangle(30, 110, 0, 28, 6, Color.Red, true)
    .Bind(sigHP, (val, shp) => (
        shp.w := 420 * val,
        shp.Colour := Color.Mix(Color.Red, Color.Green, val)
    ))

; Centered percentage label
txt := Text("0%", "White", 11, "Segoe UI", "Bold").MiddleCenter().Shift(0, 24)
    .Bind(sigHP, (val, shp) => shp.str := Format("{:0.0f}% HP", val * 100))

lyr.Draw()

; Animate smoothly from 0% to 100% then exit:
global progress := 0
SetTimer(UpdateHealth, 20)

UpdateHealth() {
    global progress
    if (++progress <= 100) {
        sigHP.Value := progress / 100.0  ; Auto-updates color, width, and text!
    } else {
        ExitApp()
    }
}
