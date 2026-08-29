; Script     01 Direct Text Binding.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

; file: Direct Text Binding (Auto-Updating Text)

#include ../../../GpGFX.ahk

; Omitting the callback in .Bind(sig) binds sig.Value directly to the shape 's text string:

lyr := Layer(100, 100, 300, 100, "VolumeHUD")
RoundedRectangle(12, "0xF0181824", true)

; 1. Create a reactive signal
sigVolume := Signal(50)

; 2. Bind directly to text shape (auto-updates when sigVolume.Value changes!)
Text("Vol: 50%").MiddleCenter().Bind(sigVolume, (val, shp) => shp.str := "Volume: " val "%")

lyr.Draw()

; Hotkeys mutate the signal with 0 timers:
+Up:: sigVolume.Value := Min(100, sigVolume.Value + 5)
+Down:: sigVolume.Value := Max(0, sigVolume.Value - 5)