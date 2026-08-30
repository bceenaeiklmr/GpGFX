; Script:    FrameTimerNative.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

; Create presentation layer
lyr := Layer(860, 520, "GpGFX Render Pacing & FrameTimer Benchmark")

; Background card
bg := RoundedRectangle(10, 10, 840, 500, 20, "0xFF12121E", true)

; Header Title
header := Rectangle(30, 25, 800, 50, "0x00000000", true)
header.Text("GpGFX Render Engine Comparison`n[M] Toggle Mode | [1]=30fps, [2]=60fps, [3]=120fps, [4]=240fps | [ESC]=Exit", "White", 11, "Segoe UI", "Bold", 5, "center", "middle")

; Orbital Center
cx := 430, cy := 270

; Satellites / Particles
satellites := []
loop 8 {
    i := A_Index - 1
    clr := Palette.TokyoNight.Sample(i / 7.0)
    shp := Circle(cx, cy, 22, clr, true)
    satellites.Push({ shp: shp, baseAngle: i * (6.28318 / 8.0), dist: 130 + Mod(i, 2) * 30, speed: 1.5 + i * 0.2 })
}
 
; Center Core
core := Circle(cx - 35, cy - 35, 70, Palette.TokyoNight.primary, true)

; Telemetry Box
teleBox := RoundedRectangle(30, 420, 800, 70, 12, "0xFF1E1E2E", true)
teleText := Rectangle(40, 430, 780, 50, "0x00000000", true)
teleText.Text("Initializing...", "White", 10, "Segoe UI", "", 5, "center", "middle")

Draw(lyr)

; Configuration state
global mode := 1          ; 1 = Standard Render.Layer (MCode Spin), 2 = FrameTimer
global targetFps := 60.0
global isRunning := true 
global frameCount := 0
global lastTelemetryTick := A_TickCount
global lastFpsVal := targetFps
global lastDeltaMsVal := 1000.0 / targetFps

; Setup initial FPS target
Fps.SetTarget(targetFps)

; Start in Mode 1 (Standard Render loop)
RunLoop()

RunLoop() {
    global mode, isRunning, targetFps, frameCount, lastTelemetryTick, lastFpsVal, lastDeltaMsVal

    if (mode == 1) {
        ; MODE 1: Standard GpGFX Tight Render Loop with MCode.QpcSpinWait
        FrameTimer.Stop()
        Fps.SetTarget(targetFps)
        SetTimer(RenderStandardFrame, -1)
    } else {
        ; MODE 2: FrameTimer (Native / Event Callback)
        Fps.SetTarget(0) ; Disable internal Render.Layer throttle
        FrameTimer.Start(RenderTimerFrame, targetFps)
    }
}

; Mode 1: Standard Render.Layer loop
RenderStandardFrame() {
    global mode, isRunning, targetFps, frameCount, lastTelemetryTick, lastFpsVal, lastDeltaMsVal

    while (isRunning && mode == 1) {
        if (!WinExist("ahk_id " lyr.hwnd))
            ExitApp()

        UpdateAnimation()
        UpdateTelemetry(1)

        ; Render with native MCode QPC frame pacing
        Render.Layer(lyr)
    }
}

; Mode 2: FrameTimer Callback
RenderTimerFrame(*) {
    global mode, isRunning, targetFps

    if (!isRunning || mode != 2)
        return

    if (!WinExist("ahk_id " lyr.hwnd)) {
        FrameTimer.Stop()
        ExitApp()
    }

    UpdateAnimation()
    UpdateTelemetry(2)
    Draw(lyr)
}

; Update particle geometry using continuous time (delta-time smooth)
UpdateAnimation() {
    local t := A_TickCount / 1000.0, s, angle, x, y

    for s in satellites {
        angle := s.baseAngle + t * s.speed
        x := cx + Cos(angle) * s.dist - 11
        y := cy + Sin(angle) * s.dist - 11
        s.shp.x := x
        s.shp.y := y
    }
}

; Throttled telemetry updates (updates text every 250ms to avoid string measure overhead every frame)
UpdateTelemetry(currentMode) {
    global frameCount, lastTelemetryTick, lastFpsVal, lastDeltaMsVal, targetFps
    local now := A_TickCount, elapsed, modeName, stats

    frameCount++
    elapsed := now - lastTelemetryTick

    if (elapsed >= 250) {
        lastFpsVal := (frameCount / elapsed) * 1000.0
        lastDeltaMsVal := elapsed / frameCount
        frameCount := 0
        lastTelemetryTick := now

        if (currentMode == 1) {
            modeName := "Standard Render.Layer (MCode.QpcSpinWait Native Loop)"
        } else {
            modeName := FrameTimer.IsAvailable ? "FrameTimer (Native C Thread HWND_MESSAGE)" : "FrameTimer (AHK SetTimer Fallback)"
        }

        teleText.str := "Mode: [" currentMode "] " modeName "`nTarget: " Format("{:.1f} FPS", targetFps) "  |  Actual: " Format("{:.1f} FPS", lastFpsVal) "  |  Frame Time: " Format("{:.2f} ms", lastDeltaMsVal)
    }
}

; Hotkeys
m::
{
    global mode := (mode == 1) ? 2 : 1
    RunLoop()
}

1::ChangeFPS(30.0)
2::ChangeFPS(60.0)
3::ChangeFPS(120.0)
4::ChangeFPS(240.0)

ChangeFPS(newFps) {
    global targetFps := newFps, mode
    if (mode == 1)
        Fps.SetTarget(newFps)
    else
        FrameTimer.SetFPS(newFps)
}

Esc::
{
    global isRunning := false
    FrameTimer.Stop()
    ExitApp()
}
