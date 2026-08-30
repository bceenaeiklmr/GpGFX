; Script:    DynamicGradientSphere.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../GpGFX.ahk


; DYNAMIC 3D GRADIENT SPHERE — SIGNAL & RENDER DEMO

; Features:
; - Real-time 3D wireframe perspective projection with depth-cued alpha lighting
; - Signal-driven reactive state (Rotation, Tilt, Hue, Pulsing Core)
; - Zero-allocation vertex pipeline with pre-allocated memory buffers
; - Interactive Mouse Drag 3D Orbit & Momentum Inertia
; - Multi-Theme Colormaps (Rainbow, Cyberpunk, Turbo, Neon, Fire)
; - Rock-solid 60 FPS pacing via Render.Layer

width := 860
height := 680

lyr := Layer((A_ScreenWidth - width) // 2, (A_ScreenHeight - height) // 2, width, height, "Dynamic 3D Gradient Sphere")
lyr.draggable := 95 ; Built-in non-blocking window drag for top header (my <= 95)


; Configuration & Constants

Pi := 3.141592653589793
DegToRad := Pi / 180.0

sphereRadius := 200
centerX := width / 2
centerY := 380

latSteps := 16
lonSteps := 32


; Reactive Signals

sigRotY   := Signal(0.0)    ; Y-axis rotation (degrees)
sigRotX   := Signal(15.0)   ; X-axis tilt (degrees)
sigHue    := Signal(0.0)    ; Active color hue (0..360)
sigSat    := Signal(1.0)    ; Saturation (0..1)
sigCore   := Signal(0.0)    ; Glowing core breathing wave
sigTheme  := Signal(1)      ; 1=Rainbow, 2=Cyberpunk, 3=Turbo, 4=Neon, 5=Fire
sigSpeed  := Signal(0.6)    ; Auto-rotation speed

autoRotate := true
themeNames := ["Rainbow HSL", "Cyberpunk Neon", "Turbo Heatmap", "Electric Aura", "Solar Flare"]


; Sphere Vertices & Pre-Allocated Projection Buffers

rawVertices := []
latIndex := 0
while (latIndex < latSteps) {
    theta := latIndex * Pi / (latSteps - 1)
    sinTheta := Sin(theta)
    cosTheta := Cos(theta)
    
    lonIndex := 0
    while (lonIndex < lonSteps) {
        phi := lonIndex * 2 * Pi / (lonSteps - 1)
        rawVertices.Push({
            x: Cos(phi) * sinTheta,
            y: cosTheta,
            z: Sin(phi) * sinTheta
        })
        lonIndex += 1
    }
    latIndex += 1
}

totalVerts := rawVertices.Length

; Pre-allocate flat projected coordinate arrays (zero runtime heap allocation per frame)
projX := []
projY := []
projZ := []
projScale := []
projX.Length := totalVerts
projY.Length := totalVerts
projZ.Length := totalVerts
projScale.Length := totalVerts

loop totalVerts {
    projX[A_Index] := 0.0
    projY[A_Index] := 0.0
    projZ[A_Index] := 0.0
    projScale[A_Index] := 1.0
}


; Visual Background, Glassmorphic Panels & Core Glow

; Dark space backdrop with rounded border
bg := RoundedRectangle(8, 8, width - 16, height - 16, 16, "0xFF12131A", true)
bgBorder := RoundedRectangle(8, 8, width - 16, height - 16, 16, "0xFF232533", 2)

; Glowing pulsating inner core (Signal-driven breathing)
coreAura := Circle(centerX - 60, centerY - 60, 120, "0x2288C0D0", true)
coreCenter := Circle(centerX - 24, centerY - 24, 48, "0x44BD93F9", true)


; Sphere Wireframe Lines Initialization

sphereLines := []

; 1. Latitude rings
lat := 1
while (lat <= latSteps) {
    lon := 1
    while (lon < lonSteps) {
        i1 := (lat - 1) * lonSteps + lon
        i2 := i1 + 1
        shp := Line(0, 0, 0, 0, "0xFF445566", 1)
        sphereLines.Push({ shape: shp, a: i1, b: i2, idx: sphereLines.Length + 1 })
        lon += 1
    }
    lat += 1
}

; 2. Longitude rings
lon := 1
while (lon <= lonSteps) {
    lat := 1
    while (lat < latSteps) {
        i1 := (lat - 1) * lonSteps + lon
        i2 := lat * lonSteps + lon
        shp := Line(0, 0, 0, 0, "0xFF445566", 1)
        sphereLines.Push({ shape: shp, a: i1, b: i2, idx: sphereLines.Length + 1 })
        lat += 1
    }
    lon += 1
}


; Sleek Glassmorphic UI Header & Telemetry

headerCard := RoundedRectangle(24, 20, width - 48, 70, 10, "0x801A1C28", true)
headerBorder := RoundedRectangle(24, 20, width - 48, 70, 10, "0x403B4252", 1)

title := Dummy(40, 26, 400, 28)
title.Font := Font("Segoe UI", 13, "Bold", "0xFFF8F8F2", 5)
title.strH := 0
title.str := "DYNAMIC 3D GRADIENT SPHERE"

infoText := Dummy(40, 52, 450, 24)
infoText.Font := Font("Consolas", 10, "Regular", "0xFF8BE9FD", 5)
infoText.strH := 0
infoText.str := "INITIALIZING..."

themeBadge := RoundedRectangle(width - 240, 32, 200, 42, 8, "0xFF282A36", true)
themeBadgeBorder := RoundedRectangle(width - 240, 32, 200, 42, 8, "0xFF6272A4", 1)
themeLabel := Dummy(width - 240, 32, 200, 42)
themeLabel.Font := Font("Segoe UI", 10, "Bold", "0xFFFF79C6", 5)
themeLabel.strH := 1
themeLabel.strV := 1
themeLabel.str := "[C] Rainbow HSL"

; Sliders
hueBar := RoundedRectangle(40, 105, 360, 6, 3, "0xFF282A36", true)
hueThumb := Circle(40, 102, 12, "0xFFFF5555", true)
hueLabel := Dummy(40, 114, 360, 20)
hueLabel.Font := Font("Segoe UI", 9, "Regular", "0xFF6272A4", 5)
hueLabel.strH := 0
hueLabel.str := "HUE SPECTRUM (Up / Down)"

satBar := RoundedRectangle(460, 105, 360, 6, 3, "0xFF282A36", true)
satThumb := Circle(460 + 360 - 12, 102, 12, "0xFF50FA7B", true)
satLabel := Dummy(460, 114, 360, 20)
satLabel.Font := Font("Segoe UI", 9, "Regular", "0xFF6272A4", 5)
satLabel.strH := 0
satLabel.str := "SATURATION (Shift + Up / Down)"

; Footer Help Overlay
footerCard := RoundedRectangle(24, height - 48, width - 48, 34, 8, "0x801A1C28", true)
footerText := Dummy(24, height - 48, width - 48, 34)
footerText.Font := Font("Segoe UI", 9, "Regular", "0xFF8E8E98", 5)
footerText.strH := 1
footerText.strV := 1
footerText.str := "Drag Mouse to Rotate 3D  |  [Space] Auto-Spin  |  [C] Palette Theme  |  [Up/Down] Hue  |  [Esc] Exit"


; Fast 3D Projection & Line Shading Function

Update3DSphere() {
    local i, v, x, y, z, z2, sx, sy, scale, camera := 3.6
    local cosY, sinY, cosX, sinX, radX, radY
    local lineData, idxA, idxB, ax, ay, az, bx, by, bz, depth, depthAlpha, lineClr
    local baseHue, curSat, thm, pWave, auraR, auraA

    baseHue := sigHue.Value
    curSat  := sigSat.Value
    thm     := sigTheme.Value
    pWave   := sigCore.Value

    ; Update glowing breathing core
    auraR := 50 + Sin(pWave) * 14
    auraA := Ceil(30 + Sin(pWave) * 20)
    coreAura.x := centerX - auraR
    coreAura.y := centerY - auraR
    coreAura.w := auraR * 2
    coreAura.h := auraR * 2
    coreAura.Colour := (auraA << 24) | 0x00BD93F9

    radY := sigRotY.Value * DegToRad
    radX := sigRotX.Value * DegToRad

    cosY := Cos(radY), sinY := Sin(radY)
    cosX := Cos(radX), sinX := Sin(radX)

    ; 1. Fast zero-allocation vertex rotation & perspective projection
    i := 1
    while (i <= totalVerts) {
        v := rawVertices[i]

        ; Y-axis rotation
        x := v.x * cosY - v.z * sinY
        z := v.x * sinY + v.z * cosY

        ; X-axis rotation
        y := v.y * cosX - z * sinX
        z2 := v.y * sinX + z * cosX

        ; Perspective divide
        scale := camera / (camera - z2)
        projX[i] := centerX + x * sphereRadius * scale
        projY[i] := centerY + y * sphereRadius * scale
        projZ[i] := z2
        projScale[i] := scale
        i += 1
    }

    ; 2. Fast depth-shaded line updates
    local numLines := sphereLines.Length
    local turboBuf := (thm == 3) ? ColorBuffer.Turbo : 0
    i := 1
    while (i <= numLines) {
        lineData := sphereLines[i]
        idxA := lineData.a
        idxB := lineData.b

        ax := projX[idxA], ay := projY[idxA], az := projZ[idxA]
        bx := projX[idxB], by := projY[idxB], bz := projZ[idxB]

        ; Update line geometry
        lineData.shape.x1 := ax
        lineData.shape.y1 := ay
        lineData.shape.x2 := bx
        lineData.shape.y2 := by

        ; Normalized depth: 1.0 = closest to screen, 0.0 = furthest in back
        depth := ((az + bz) * 0.5 + 1.0) * 0.5
        depth := (depth < 0.0) ? 0.0 : (depth > 1.0 ? 1.0 : depth)

        ; Front lines are bright and opaque; back lines fade softly
        depthAlpha := Ceil(35 + depth * 220)

        ; Multi-Theme Dynamic Palette Shading
        switch thm {
            case 1: ; Rainbow HSL Spectrum
                local lineHue := Mod(baseHue + (idxA * 2.8) + (depth * 50), 360)
                local lightness := 0.25 + depth * 0.45
                lineClr := Color.FromHSL(lineHue, curSat, lightness)
                lineData.shape.Colour := (depthAlpha << 24) | (lineClr & 0x00FFFFFF)

            case 2: ; Cyberpunk Neon (Cyan -> Hot Pink -> Purple)
                local t := Mod((idxA / totalVerts) + (baseHue / 360.0), 1.0)
                local rgb := (t < 0.5) ? Color.Mix(0x00F0FF, 0xFF007F, t * 2.0) : Color.Mix(0xFF007F, 0xBD93F9, (t - 0.5) * 2.0)
                lineData.shape.Colour := (depthAlpha << 24) | (rgb & 0x00FFFFFF)

            case 3: ; Turbo Heatmap
                local t := Mod((idxA / totalVerts) + depth * 0.4 + (baseHue / 360.0), 1.0)
                local rgb := turboBuf[t]
                lineData.shape.Colour := (depthAlpha << 24) | (rgb & 0x00FFFFFF)

            case 4: ; Electric Aura (Neon Green -> Deep Sky Blue)
                local t := Mod(depth + (baseHue / 360.0), 1.0)
                local rgb := Color.Mix(0x50FA7B, 0x00BFFF, t)
                lineData.shape.Colour := (depthAlpha << 24) | (rgb & 0x00FFFFFF)

            case 5: ; Solar Flare (Gold -> Orange -> Crimson)
                local t := Mod(depth * 0.8 + (idxA * 0.002) + (baseHue / 360.0), 1.0)
                local rgb := Color.Mix(0xFFD866, 0xFF1493, t)
                lineData.shape.Colour := (depthAlpha << 24) | (rgb & 0x00FFFFFF)
        }

        i += 1
    }
}


; Mouse Drag Orbit & Interactive Window Handling

isDragging := false
lastMouseX := 0
lastMouseY := 0
dragVelocityX := 0.0
dragVelocityY := 0.0

OnMessage(0x0201, OnLButtonDown) ; WM_LBUTTONDOWN
OnMessage(0x0202, OnLButtonUp)   ; WM_LBUTTONUP
OnMessage(0x0200, OnMouseMove)   ; WM_MOUSEMOVE

OnLButtonDown(wParam, lParam, msg, hwnd) {
    global isDragging, lastMouseX, lastMouseY, dragVelocityX, dragVelocityY
    if (hwnd == lyr.hwnd) {
        local mx := lParam & 0xFFFF
        local my := (lParam >> 16) & 0xFFFF
        
        ; Clicks on header (my < 95) are automatically dragged by lyr.draggable
        if (my >= 95) {
            isDragging := true
            lastMouseX := mx
            lastMouseY := my
            dragVelocityX := 0.0
            dragVelocityY := 0.0
        }
    }
}

OnLButtonUp(wParam, lParam, msg, hwnd) {
    global isDragging
    isDragging := false
}

OnMouseMove(wParam, lParam, msg, hwnd) {
    global isDragging, lastMouseX, lastMouseY, dragVelocityX, dragVelocityY, sigRotY, sigRotX
    if (isDragging && (wParam & 0x0001)) { ; MK_LBUTTON
        local mx := lParam & 0xFFFF
        local my := (lParam >> 16) & 0xFFFF
        
        local dx := mx - lastMouseX
        local dy := my - lastMouseY

        dragVelocityX := dx * 0.35
        dragVelocityY := dy * 0.35

        sigRotY.Value += dragVelocityX
        sigRotX.Value := Max(-85.0, Min(85.0, sigRotX.Value - dragVelocityY))

        lastMouseX := mx
        lastMouseY := my
    }
}


; Hotkey Handlers

#HotIf WinExist(lyr.hwnd)
Space:: {
    global autoRotate
    autoRotate := !autoRotate
}
c:: {
    global sigTheme, themeNames, themeLabel
    local nextTheme := Mod(sigTheme.Value, 5) + 1
    sigTheme.Value := nextTheme
    themeLabel.str := "[C] " . themeNames[nextTheme]
}
Left::  sigRotY.Value -= 4.0
Right:: sigRotY.Value += 4.0
Up::    sigHue.Value := Mod(sigHue.Value + 5.0, 360.0)
Down::  sigHue.Value := Mod(sigHue.Value - 5.0 + 360.0, 360.0)
+Up::   sigSat.Value := Min(1.0, sigSat.Value + 0.05)
+Down:: sigSat.Value := Max(0.0, sigSat.Value - 0.05)
Esc::   ExitApp()
#HotIf


; Main Signal-Driven Animation & Render Loop

Fps.target := 60
pulseTimer := 0.0

while WinExist(lyr.hwnd) {

    ; 1. Inertia and Auto-Rotation
    if (!isDragging) {
        if (autoRotate) {
            sigRotY.Value += sigSpeed.Value
        }
        ; Smooth deceleration of drag momentum
        if (Abs(dragVelocityX) > 0.01) {
            sigRotY.Value += dragVelocityX
            dragVelocityX *= 0.92
        }
        if (Abs(dragVelocityY) > 0.01) {
            sigRotX.Value := Max(-85.0, Min(85.0, sigRotX.Value - dragVelocityY))
            dragVelocityY *= 0.92
        }
    }

    ; Continuous hue wave
    sigHue.Value := Mod(sigHue.Value + 0.25, 360.0)
    pulseTimer += 0.06
    sigCore.Value := pulseTimer

    ; 2. Compute 3D Frame
    Update3DSphere()

    ; 3. Reactive UI Updates
    infoText.str := Format("ROT: X {:+0.1f} | Y {:0.1f} | HUE: {:0.0f} | FPS: {:0.1f}", sigRotX.Value, Mod(sigRotY.Value, 360.0), sigHue.Value, Fps.lastfps)
    hueThumb.x := 40 + (360 - 12) * (sigHue.Value / 360.0)
    satThumb.x := 460 + (360 - 12) * sigSat.Value

    ; 4. High-Precision Layer Presentation via Render Engine
    Render.Layer(lyr)
}

ExitApp()