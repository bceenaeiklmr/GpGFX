; Script     LorenzAttractor.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#include ../../GpGFX.ahk

; Create presentation layer
lyr := Layer(960, 640, "GpGFX Lorenz Attractor (Chaotic System)")

; Background
bg := RoundedRectangle(10, 10, 940, 620, 20, "0xFF0F0F17", true)

; Header Title
header := Rectangle(30, 20, 900, 45, "0x00000000", true)
header.Text("Lorenz Chaotic Attractor (Real-Time 3D Projection & Palette Gradients)`n[P] Toggle Palette | [1]=30fps, [2]=60fps, [3]=120fps, [4]=MAX | [ESC]=Exit", "White", 11, "Segoe UI", "Bold", 5, "center", "middle")

; Telemetry Box
teleBox := RoundedRectangle(30, 560, 900, 50, 10, "0xFF181825", true)
teleText := Rectangle(40, 570, 880, 30, "0x00000000", true)
teleText.Text("Initializing...", "White", 10, "Segoe UI", "", 5, "center", "middle")

; Setup Lorenz System constants (classic chaotic butterfly parameters)
global sigma := 10.0
global rho   := 28.0
global beta  := 8.0 / 3.0
global dt    := 0.008

; Particle State
global lx := 0.1, ly := 0.0, lz := 0.0
global rotY := 0.0, rotX := 0.3

; Trail buffer for points
maxPoints := 1200
trail := []

; Pre-create trail point shapes
cx := 480, cy := 310
scale := 11.5

loop maxPoints {
    i := A_Index - 1
    clr := Palette.TokyoNight.Sample(i / Float(maxPoints))
    pt := Circle(cx, cy, 3, clr, true)
    trail.Push({ shp: pt, x: 0.0, y: 0.0, z: 0.0 })
}

; Lead attractor orb
leadOrb := Circle(cx, cy, 10, "0xFFFFFFFF", true)

Draw(lyr)

; Palette Presets for cycling with [P]
palettes := [Palette.TokyoNight, Palette.Cyberpunk, Palette.Catppuccin, Palette.Nord, Palette.Dracula, Palette.Monokai]
palIdx := 1
currentPalette := palettes[palIdx]

; Set Target FPS to 60.0
Fps.SetTarget(60.0)

; Telemetry tracking
lastTeleUpdate := A_TickCount
frameCount := 0
lastFps := 60.0
lastDeltaMs := 16.67
stepCounter := 0

; Main real-time render loop
while (WinExist(lyr.hwnd)) {
    
    ; Multiple physics sub-steps per visual frame for smooth continuous curves
    loop 3 {
        ; Lorenz differential equations:
        ; dx/dt = sigma * (y - x)
        ; dy/dt = x * (rho - z) - y
        ; dz/dt = x * y - beta * z
        dx := (sigma * (ly - lx)) * dt
        dy := (lx * (rho - lz) - ly) * dt
        dz := (lx * ly - (beta * lz)) * dt

        lx += dx
        ly += dy
        lz += dz
    }

    ; Rotate viewpoint continuously
    rotY += 0.012

    ; Push current 3D position to the front of trail history
    head := trail.Pop()
    head.x := lx
    head.y := ly
    head.z := lz - 25.0 ; center Z axis
    trail.InsertAt(1, head)

    ; 3D Rotation Matrix & Perspective Projection
    cosY := Cos(rotY), sinY := Sin(rotY)
    cosX := Cos(rotX), sinX := Sin(rotX)

    for idx, item in trail {
        ; Y-axis rotation
        x1 := item.x * cosY + item.z * sinY
        z1 := -item.x * sinY + item.z * cosY
        
        ; X-axis tilt
        y2 := item.y * cosX - z1 * sinX
        z2 := item.y * sinX + z1 * cosX

        ; Perspective divide
        fov := 350.0 / (350.0 + z2)
        px := cx + x1 * scale * fov
        py := cy + y2 * scale * fov

        item.shp.x := px - 1.5
        item.shp.y := py - 1.5
        
        ; Fade size along trail
        size := Max(1.5, 4.0 * (1.0 - idx / Float(maxPoints)))
        item.shp.w := size
        item.shp.h := size
    }

    ; Position lead orb at the current head
    leadOrb.x := trail[1].shp.x - 3
    leadOrb.y := trail[1].shp.y - 3

    ; Telemetry update (every 250ms)
    frameCount++
    now := A_TickCount
    if (now - lastTeleUpdate >= 250) {
        lastFps := (frameCount / (now - lastTeleUpdate)) * 1000.0
        lastDeltaMs := (now - lastTeleUpdate) / frameCount
        frameCount := 0
        lastTeleUpdate := now
        teleText.str := "Palette: " currentPalette.name "  |  Target: " (Fps.target ? Fps.target " FPS" : "MAX (Uncapped)") "  |  Actual: " Format("{:.1f} FPS", lastFps) "  |  Frame Time: " Format("{:.2f} ms", lastDeltaMs) "  |  Points: " maxPoints
    }

    ; Render paced frame
    Render.Layer(lyr)
}

; Hotkeys
p::{
    local i, item
    global palIdx := Mod(palIdx, palettes.Length) + 1
    global currentPalette := palettes[palIdx]
    for i, item in trail {
        item.shp.Color := currentPalette.Sample(i / Float(trail.Length))
    }
}

1::Fps.SetTarget(30.0)
2::Fps.SetTarget(60.0)
3::Fps.SetTarget(120.0)
4::Fps.SetTarget(0) ; Max / Unlimited

Esc::ExitApp()
