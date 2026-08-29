; Script     SignalStateSync.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../GpGFX.ahk

lyr := Layer(400, 160, "ColorBuffer.Sample Reactive Demo")
RoundedRectangle(12, "0xFF181824", true)

; Reactive position signal (0.0 to 1.0)
sigPos := Signal(0.0)

; Circle's color dynamically samples Plasma colormap as signal updates
circ := Circle(200, 80, 50, ColorBuffer.Plasma[0.0], true)
    .Bind(sigPos, (val, shp) => shp.Colour := ColorBuffer.Plasma[val])

; Label displays current sample percentage
txt := Text("Plasma: 0%", "White", 11, "Segoe UI", "Bold").Center()
    .Bind(sigPos, (val, shp) => shp.str := Format("Plasma: {:0.0f}%", val * 100))

lyr.Draw()

; Animate signal from 0% to 100% over 2 seconds (Signal auto-redraws on .Value change):
global animStep := 0
SetTimer(Animate, 20)

Animate() {
    global animStep
    if (++animStep <= 100) {
        sigPos.Value := animStep / 100.0  ; Auto-triggers shape update & layer redraw!
    } else {
        ExitApp()
    }
}
