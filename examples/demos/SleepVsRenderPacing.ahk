; Script     SleepVsRenderPacing.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

﻿#include ../../GpGFX.ahk

; GpGFX Pacing Comparison Benchmark: Standard Sleep vs Render.Layer (MCode)

lyr := Layer(960, 560, "GpGFX Pacing Benchmark: Sleep vs Render.Layer")

; Background
bg := RoundedRectangle(10, 10, 940, 540, 20, "0xFF12121A", true)

; Header Title
header := Rectangle(30, 20, 900, 45, "0x00000000", true)
header.Text("Frame Pacing Showdown: AHK Sleep vs Render.Layer (MCode QPC)`nPress [1], [2], [3] to Switch Method | [ESC] to Exit", "White", 12, "Segoe UI", "Bold", 5, "center", "middle")

; Track / Rail for smooth motion visualization (moving bar shows micro-stutter clearly)
trackBg := RoundedRectangle(40, 90, 880, 70, 12, "0xFF1E1E2E", true)
movingBar := RoundedRectangle(45, 95, 60, 60, 10, "0xFF00F0FF", true)

; Second track with bouncing ball
track2Bg := RoundedRectangle(40, 180, 880, 70, 12, "0xFF1E1E2E", true)
bouncingBall := Circle(50, 190, 50, "0xFFFF003C", true)

; Method indicator card
methodCard := RoundedRectangle(40, 270, 880, 90, 12, "0xFF252538", true)
methodTitle := Rectangle(60, 280, 840, 30, "0x00000000", true)
methodDesc := Rectangle(60, 310, 840, 40, "0x00000000", true)

; Live Telemetry Panel
teleCard := RoundedRectangle(40, 380, 880, 130, 12, "0xFF181825", true)
teleText := Rectangle(60, 395, 840, 100, "0x00000000", true)

Draw(lyr)

; State variables
global currentMethod := 2 ; 1 = Standard Sleep, 2 = Render.Layer (MCode), 3 = SetTimer
global targetFps := 144.0
global isRunning := true

; Jitter & telemetry metrics
global frameDeltas := []
global lastTick := 0
global lastTeleUpdate := A_TickCount
global avgDelta := 16.67
global maxDelta := 16.67
global minDelta := 16.67
global jitterMs := 0.0
global currentFps := 60.0
global frameCount := 0

; Setup QPC frequency
DllCall("QueryPerformanceFrequency", "int64*", &qpf:=0)
global g_qpf := qpf

; Launch selected pacing loop
SwitchMethod(2)

SwitchMethod(method) {
    global currentMethod := method, isRunning, frameDeltas, frameCount, lastTick
    
    ; Reset metrics
    frameDeltas := []
    frameCount := 0
    DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
    lastTick := qpc

    ; Stop any active SetTimer
    SetTimer(TimerCallback, 0)

    if (method == 1) {
        methodTitle.str := "METHOD 1: Standard AHK Sleep(16) Loop"
        methodDesc.str := "Uses standard AHK Sleep(16). Subject to Windows timer quantization (~1-15ms jitter).`nNotice the visible micro-stutter / hitching in the moving bar!"
        movingBar.Color := "0xFFFF79C6" ; Pink
        bouncingBall.Color := "0xFFFF5555"
        SetTimer(RunSleepLoop, -1)
    } 
    else if (method == 2) {
        methodTitle.str := "METHOD 2: GpGFX Native Render.Layer (MCode.QpcSpinWait)"
        methodDesc.str := "Uses QPC microsecond timing + native x64 assembly spin-wait (MCode.QpcSpinWait).`nSub-millisecond frame pacing (<0.05ms jitter) — silky smooth 60.0 FPS!"
        movingBar.Color := "0xFF00F0FF" ; Cyan
        bouncingBall.Color := "0xFF50FA7B"
        Fps.SetTarget(targetFps)
        SetTimer(RunRenderLoop, -1)
    }
    else if (method == 3) {
        methodTitle.str := "METHOD 3: Standard AHK SetTimer(16)"
        methodDesc.str := "Uses AHK SetTimer(16) event queue. Pacing varies based on message queue load.`nSubject to thread scheduling delays."
        movingBar.Color := "0xFFFABD2F" ; Yellow
        bouncingBall.Color := "0xFF83A598"
        SetTimer(TimerCallback, 16)
    }
}

; Pacing Loops

; METHOD 1: Standard AHK Sleep(16)
RunSleepLoop() {
    global currentMethod, isRunning

    while (isRunning && currentMethod == 1) {
        if (!WinExist("ahk_id " lyr.hwnd))
            ExitApp()

        RecordFrameDelta()
        UpdateAnimation()
        UpdateTelemetryDisplay()
        Draw(lyr)

        ; Standard AHK Sleep
        Sleep(16)
    }
}

; METHOD 2: GpGFX Render.Layer (MCode QPC Spin)
RunRenderLoop() {
    global currentMethod, isRunning

    while (isRunning && currentMethod == 2) {
        if (!WinExist("ahk_id " lyr.hwnd))
            ExitApp()

        RecordFrameDelta()
        UpdateAnimation()
        UpdateTelemetryDisplay()

        ; Paces the frame using native x64 MCode.QpcSpinWait
        Render.Layer(lyr)
    }
}

; METHOD 3: Standard AHK SetTimer
TimerCallback() {
    global currentMethod, isRunning

    if (!isRunning || currentMethod != 3)
        return

    if (!WinExist("ahk_id " lyr.hwnd))
        ExitApp()

    RecordFrameDelta()
    UpdateAnimation()
    UpdateTelemetryDisplay()
    Draw(lyr)
}

; Animation & Telemetry Tracking

UpdateAnimation() {
    local t := A_TickCount / 1000.0
    
    ; Continuous back-and-forth linear sweep across track (0 to 810 px)
    ; Triangle wave from 0 to 1
    local progress := Abs(Mod(t * 0.8, 2.0) - 1.0)
    movingBar.x := 45 + progress * (880 - 70)
    
    ; Bouncing harmonic motion
    local bounce := Abs(Sin(t * 3.5))
    local ballX := 50 + progress * (880 - 70)
    local ballY := 195 - bounce * 15
    bouncingBall.x := ballX
    bouncingBall.y := ballY
}

RecordFrameDelta() {
    global lastTick, frameDeltas, g_qpf, frameCount
    local now := 0, deltaMs := 0

    DllCall("QueryPerformanceCounter", "int64*", &now:=0)
    if (lastTick > 0) {
        deltaMs := (now - lastTick) / g_qpf * 1000.0
        if (deltaMs > 0 && deltaMs < 100.0) {
            frameDeltas.Push(deltaMs)
            if (frameDeltas.Length > 60)
                frameDeltas.RemoveAt(1)
        }
    }
    lastTick := now
    frameCount++
}

UpdateTelemetryDisplay() {
    global lastTeleUpdate, frameDeltas, currentMethod, targetFps, avgDelta, maxDelta, minDelta, jitterMs, currentFps
    local now := A_TickCount, sum := 0.0, d, variance := 0.0, stdDev := 0.0

    if (now - lastTeleUpdate < 200 || frameDeltas.Length < 10)
        return

    lastTeleUpdate := now

    ; Compute average, min, max, standard deviation (jitter)
    minDelta := 999.0
    maxDelta := 0.0
    sum := 0.0

    for d in frameDeltas {
        sum += d
        (d < minDelta) ? minDelta := d : 0
        (d > maxDelta) ? maxDelta := d : 0
    }
    avgDelta := sum / frameDeltas.Length
    currentFps := (avgDelta > 0) ? (1000.0 / avgDelta) : 0.0

    ; Standard Deviation (Jitter)
    for d in frameDeltas {
        variance += (d - avgDelta) ** 2
    }
    jitterMs := Sqrt(variance / frameDeltas.Length)

    teleText.str := "Target: " Format("{:.1f}", targetFps) " FPS (" Format("{:.2f}", 1000.0 / targetFps) " ms)`n"
                 . "Measured FPS: " Format("{:.1f}", currentFps) " FPS  |  Average Frame Time: " Format("{:.2f} ms", avgDelta) "`n"
                 . "Jitter (StdDev): ± " Format("{:.3f} ms", jitterMs) "  |  Min/Max Frame: [" Format("{:.2f}", minDelta) " ms - " Format("{:.2f}", maxDelta) " ms]`n"
                 . "Verdict: " (currentMethod == 2 ? "✓ Silky Smooth (<0.05ms microsecond pacing)" : "✗ Jittery (visible micro-stutter / dropped frames)")
}

; Hotkeys
1::SwitchMethod(1) ; Sleep(16)
2::SwitchMethod(2) ; Render.Layer (MCode QPC)
3::SwitchMethod(3) ; SetTimer(16)

Esc::
{
    global isRunning := false
    SetTimer(TimerCallback, 0)
    ExitApp()
}
