; Script     03 Reactive Multi-Shape State Sync.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

;3. 🎨 Reactive Multi-Shape State Sync (Single Signal → Multiple Shapes)

;  A single signal can drive multiple UI elements simultaneously (e.g. status indicator dot + label +
;  background glow):

#Include ../../../GpGFX.ahk

lyr := Layer(100, 100, 300, 70, "StatusHUD")
bgCard := RoundedRectangle(12, "0xF0181824", true)

; Signal holds state: "online", "busy", "offline"
sigStatus := Signal("online")

; 1. Status indicator dot changes color reactively:
statusDot := Circle(30, 35, 8, "0xFF00FF66", true).Bind(sigStatus, (val, shp) => (
    shp.colour := (val == "online" ? "0xFF00FF66" : val == "busy" ? "0xFFFFD866" : "0xFFFF6188")
))

; 2. Status text updates reactively:
statusText := Text(55, 26, 200, 30, "System: ONLINE").MiddleLeft().Bind(sigStatus, (val, shp) => (
    shp.str := "System: " StrUpper(val)
))

lyr.Draw()

; Toggle status via keys:
F1::sigStatus.Value := "online"
F2::sigStatus.Value := "busy"
F3::sigStatus.Value := "offline"