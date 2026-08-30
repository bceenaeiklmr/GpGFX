; Script:    AsyncLayer_Showcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include ../../GpGFX.ahk
           
; Enable 1ms timer precision      
DllCall("winmm\timeBeginPeriod", "uint", 1)
OnExit((*) => DllCall("winmm\timeEndPeriod", "uint", 1))

; GpGFX Clean API Async Layer Showcase (Method Chaining + lyr.Async := true)

width := 1040
height := 720

; 1. UI Layer (Main Thread Core 0 - instant 1,000+ FPS) 
global lyrHUD := Layer(40, 40, width, height, "HUD Layer")
lyrHUD.Redraw := true

; Method Chaining in action:
card := RoundedRectangle(10, 10, width - 20, height - 20, 16, "0xFF1E1E24", true)

header := Rectangle(30, 20, width - 60, 45, "0x00000000", true)
    .Text("GpGFX Async Multi-Core Layer Showcase (Clean API)`n[SPACE] Toggle Mode | [ESC] Exit", "White", 11, "Segoe UI", "Bold")

hudCard := RoundedRectangle(40, 75, 480, 95, 10, "0xFF2D2A2E", true)
hudBorder := RoundedRectangle(40, 75, 480, 95, 10, "0x40FCFCFA", false)

global modeBadge := RoundedRectangle(55, 88, 190, 26, 6, "0xFFA9DC76", true)           
global modeText := Rectangle(55, 88, 190, 26, "0x00000000", true)
    .Text("ASYNC WORKER ACTIVE", "0xFF1E1E24", 9.5, "Segoe UI", "Bold")

global fpsLabel := Rectangle(255, 85, 250, 28, "0x00000000", true)
    .Text("FPS: Measuring...", "0xFFFCFCFA", 11, "Consolas", "Bold")

global latLabel := Rectangle(55, 122, 450, 24, "0x00000000", true)
    .Text("1,000 particles computed & rendered on CPU Worker 1", "0xFF939293", 9, "Segoe UI")

Draw(lyrHUD)

; 2. Particle Swarm Layer (Auto-owned by lyrHUD so it NEVER gets covered by clicks!)
global lyrSwarm := Layer(40, 40, width, height, "Swarm Layer")
lyrSwarm.Redraw := true
lyrSwarm.Async := true ; <-- 1 LINE TO ENABLE MULTI-CORE ACCELERATION!

; Single-Threaded particle state fallback
global singleParticles := []
global cx := width // 2       
global cy := height // 2

LayerStack.ActiveLayer := lyrSwarm
loop 1000  {
    singleParticles.Push({
        shp: Circle(cx, cy, Random(3, 7), "0xFFFF6188", true),
        angle: Random(0.0, 6.28318),
        dist: Random(10.0, 220.0),
        speed: Random(0.015, 0.035)
    })
}
Draw(lyrSwarm)

; Initialize background worker swarm
InitWorkerSwarm(lyrSwarm.workerId, 1000, 0xFFFF6188, 10.0, 220.0, 0.015, 0.035)

InitWorkerSwarm(workerIdx, count, clr, minDist, maxDist, minSpeed, maxSpeed) {
    global width, height
    local w := WorkerPool.workers[workerIdx]
    local pBuf := w.fm.pBuf

    w.mtx.Lock()
    NumPut("int", 10, pBuf, 0)
    NumPut("int", 1, pBuf, 4)
    NumPut("int", width, pBuf, 8)
    NumPut("int", height, pBuf, 12)
    NumPut("int", count, pBuf, 16)
    NumPut("uint", clr, pBuf, 20)
    NumPut("float", minDist, pBuf, 24)
    NumPut("float", maxDist, pBuf, 28)
    NumPut("float", minSpeed, pBuf, 32)
    NumPut("float", maxSpeed, pBuf, 36)
    w.mtx.Release()

    w.semTask.Release(1)
    w.semDone.Wait(1000)
}

global mode := 2 ; 1 = Single-Threaded Core 0, 2 = Async Worker Core 1
global isRunning := true
global frameCount := 0
global renderAccumMs := 0.0
global lastFpsUpdate := (DllCall("QueryPerformanceCounter", "int64*", &qpc:=0), qpc)

; Continuous High-Speed Director Loop
SetTimer(Animate, -1)

Animate() {
    global lyrHUD, lyrSwarm, singleParticles, mode, cx, cy
    global isRunning, frameCount, renderAccumMs, lastFpsUpdate, fpsLabel, latLabel
    local qpc, start, totalMs, now, elapsedTotal, currentFps, avgFrameMs, idx, p

    while (isRunning) {
        start := (DllCall("QueryPerformanceCounter", "int64*", &qpc:=0), qpc)

        if (mode == 2) {       
            ; MODE 2: ASYNC WORKER (Director Pattern on CPU Worker 1)
            lyrSwarm.Step(0.03)
            WorkerPool.WaitForAll(50)
        } else {
            ; MODE 1: SINGLE-THREADED (Core 0 AHK Loop)
            loop 1000 {
                idx := A_Index
                p := singleParticles[idx]
                p.angle += p.speed
                p.shp.x := cx + Cos(p.angle) * p.dist
                p.shp.y := cy + Sin(p.angle) * p.dist
            }
            DllCall("gdiplus\GdipGraphicsClear", "ptr", lyrSwarm.gfx.ptr, "uint", 0x00000000)
            Draw(lyrSwarm)
        }

        totalMs := ((DllCall("QueryPerformanceCounter", "int64*", &qpc:=0), qpc) - start) / Render.qpf * 1000.0
        renderAccumMs += totalMs
        frameCount++

        ; Update Telemetry every 150ms
        now := (DllCall("QueryPerformanceCounter", "int64*", &qpc:=0), qpc)
        elapsedTotal := (now - lastFpsUpdate) / Render.qpf * 1000.0
        if (elapsedTotal >= 150.0) {
            currentFps := frameCount / (elapsedTotal / 1000.0)
            avgFrameMs := renderAccumMs / frameCount

            fpsLabel.Text("FPS: " . Format("{:.0f}", currentFps) . " | Frame: " . Format("{:.1f} ms", avgFrameMs))
            latLabel.Text("Mode: " . (mode == 2 ? "Async CPU Worker 1" : "Single-Threaded Core 0") . " | 1,000 particles")
            Draw(lyrHUD)

            frameCount := 0
            renderAccumMs := 0.0
            lastFpsUpdate := now   
        }
       
        Sleep(-1)
    }
}

UpdateModeDisplay() {
    global mode, modeBadge, modeText, lyrHUD
    if (mode == 2) {
        modeBadge.Color := "0xFFA9DC76"
        modeText.Text("ASYNC WORKER ACTIVE", "0xFF1E1E24")
    } else {
        modeBadge.Color := "0xFFFF6188"
        modeText.Text("SINGLE-THREADED", "White")
    }
    Draw(lyrHUD)
}

~Space:: {
    global mode := (mode == 1) ? 2 : 1
    UpdateModeDisplay()
}    

~Esc:: {
    global isRunning
    isRunning := false
    WorkerPool.Shutdown()
    ExitApp()
}
