; Script     02 Dynamic Visual Binding.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

; Dynamic Visual Binding (Progress / Health Bar)

; Pass a callback (val, shape) => ... to transform numbers into width, height, colors, or coordinates:

#Include ../../../GpGFX.ahk

lyr := Layer(100, 100, 400, 80, "ProgressHUD")
RoundedRectangle(10, "0xF0181824", true)              ; Background card
barBg := Rectangle(20, 30, 360, 20, "0xFF2D2A3E", true) ; Track background

; Reactive download progress (0 to 100)
sigProgress := Signal(0)

; Fill bar: Width dynamically tracks signal percentage
barFill := Rectangle(20, 30, 0, 20, "0xFF00FF66", true).Bind(sigProgress, (val, shp) => shp.w := (360 *
        val) // 100)

; Percent label
txtPct := Text("0%").MiddleCenter().Bind(sigProgress, (val, shp) => shp.str := val "%")

lyr.Draw()

; Simulating a background task:
SetTimer(() => (sigProgress.Value < 100 ? sigProgress.Value += 10 : ExitApp()), 200)