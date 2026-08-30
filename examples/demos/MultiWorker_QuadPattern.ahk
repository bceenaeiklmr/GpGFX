; Script:    MultiWorker_QuadPattern.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; Real-Time Multi-Worker Quad Pattern Showcase (Official WorkerPool Architecture)
; 4 Background OS Worker Processes render 4 distinct animated quadrants concurrently!
;
; Quad 1 (Top-Left)     -> Worker 1: Sine Plasma Orbs (Google Turbo Palette)
; Quad 2 (Top-Right)    -> Worker 2: Julia Spiral Matrix (Plasma Palette)
; Quad 3 (Bottom-Left)  -> Worker 3: Cyberpunk Pulsing Rings (Neon Palette)
; Quad 4 (Bottom-Right) -> Worker 4: Thermal Vortex (Heatmap Palette)

quadW := 360
quadH := 360
gap := 12
headerH := 46
footerH := 36
totalW := quadW * 2 + gap * 3
totalH := quadH * 2 + gap * 3 + headerH + footerH

posX := (A_ScreenWidth - totalW) // 2
posY := (A_ScreenHeight - totalH) // 2

; 1. Backdrop HUD Layer
global lyrHUD := Layer(posX, posY, totalW, totalH, "GpGFX Quad Master HUD")
lyrHUD.draggable := true

RoundedRectangle(0, 0, totalW, totalH, 20, "0xFF14141E", true)
RoundedRectangle(0, 0, totalW, totalH, 20, "0x33FCFCFA", false)

Text(20, 14, totalW - 40, 26, "GpGFX MULTI-WORKER QUAD ENGINE (4 WORKER PROCESSES)", "0xFFFCFCFA", 12, "Segoe UI", "Bold").Center().Middle()

; Quadrant Cards & Header Labels on HUD Layer
q1LocalX := gap, q1LocalY := headerH + gap
q2LocalX := gap * 2 + quadW, q2LocalY := headerH + gap
q3LocalX := gap, q3LocalY := headerH + gap * 2 + quadH
q4LocalX := gap * 2 + quadW, q4LocalY := headerH + gap * 2 + quadH

RoundedRectangle(q1LocalX, q1LocalY, quadW, quadH, 12, "0xFF1E1E2E", true)
Text(q1LocalX + 12, q1LocalY + 10, quadW - 24, 20, "WORKER 1: Plasma Orbs (Turbo)", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Top()

RoundedRectangle(q2LocalX, q2LocalY, quadW, quadH, 12, "0xFF1E1E2E", true)
Text(q2LocalX + 12, q2LocalY + 10, quadW - 24, 20, "WORKER 2: Julia Matrix (Plasma)", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Top()

RoundedRectangle(q3LocalX, q3LocalY, quadW, quadH, 12, "0xFF1E1E2E", true)
Text(q3LocalX + 12, q3LocalY + 10, quadW - 24, 20, "WORKER 3: Cyberpunk Rings (Neon)", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Top()

RoundedRectangle(q4LocalX, q4LocalY, quadW, quadH, 12, "0xFF1E1E2E", true)
Text(q4LocalX + 12, q4LocalY + 10, quadW - 24, 20, "WORKER 4: Thermal Vortex (Heatmap)", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Top()

; Center HUD Badge
hudW := 260, hudH := 46
hudX := (totalW - hudW) // 2, hudY := headerH + gap + quadH + (gap - hudH) // 2
RoundedRectangle(hudX, hudY, hudW, hudH, 10, "0xEE1A1A28", true)
RoundedRectangle(hudX, hudY, hudW, hudH, 10, "0x8078DCE8", false)
global fpsText := Text(hudX, hudY, hudW, hudH, "4 Workers ➔ 60 FPS", "0xFF78DCE8", 9.5, "Segoe UI", "Bold").Center().Middle()

Text(20, totalH - 28, totalW - 40, 20, "Drag window anywhere | Press [Esc] to exit", "0xFF727072", 8.5, "Segoe UI").Center().Middle()

Draw(lyrHUD)

; 2. Create the 4 Quadrant Layers
q1X := posX + gap
q1Y := posY + headerH + gap
q2X := posX + gap * 2 + quadW
q2Y := posY + headerH + gap
q3X := posX + gap
q3Y := posY + headerH + gap * 2 + quadH
q4X := posX + gap * 2 + quadW
q4Y := posY + headerH + gap * 2 + quadH

global lyrQ1 := Layer(q1X, q1Y, quadW, quadH, "Quad 1 - Plasma Orbs")
global lyrQ2 := Layer(q2X, q2Y, quadW, quadH, "Quad 2 - Julia Spiral")
global lyrQ3 := Layer(q3X, q3Y, quadW, quadH, "Quad 3 - Neon Pulse")
global lyrQ4 := Layer(q4X, q4Y, quadW, quadH, "Quad 4 - Thermal Vortex")

lyrQ1.Redraw := true
lyrQ2.Redraw := true
lyrQ3.Redraw := true
lyrQ4.Redraw := true

; 3. Populate Animated Shapes in each Quadrant (180 shapes each = 720 total shapes)
numShapes := 180
cx := quadW / 2.0
cy := quadH / 2.0

lutTurbo   := Color.Buf.Turbo
lutPlasma  := Color.Buf.Plasma
lutNeon    := Color.Buf.Neon
lutHeatmap := Color.Buf.Heatmap

; Quad 1: Plasma Orbs
global q1Nodes := []
LayerStack.ActiveLayer := lyrQ1
loop numShapes {
    t := (A_Index - 1) / Float(numShapes - 1)
    clr := lutTurbo.Sample(t)
    shp := Circle(cx, cy, 14, clr, true)
    q1Nodes.Push({ shp: shp, phase: t * 6.283, radius: 20 + t * (quadW * 0.38), speed: 0.03 + (1.0 - t) * 0.04 })
}

; Quad 2: Julia Spiral Matrix
global q2Nodes := []
LayerStack.ActiveLayer := lyrQ2
loop numShapes {
    t := (A_Index - 1) / Float(numShapes - 1)
    clr := lutPlasma.Sample(t)
    shp := RoundedRectangle(cx, cy, 12, 12, 3, clr, true)
    q2Nodes.Push({ shp: shp, angle: t * 12.56, dist: 15 + t * (quadW * 0.4), speed: 0.025 })
}

; Quad 3: Cyberpunk Pulsing Rings
global q3Nodes := []
LayerStack.ActiveLayer := lyrQ3
loop numShapes {
    t := (A_Index - 1) / Float(numShapes - 1)
    clr := lutNeon.Sample(t)
    shp := Circle(cx, cy, 10, clr, true)
    q3Nodes.Push({ shp: shp, angle: t * 6.283, ringIdx: Mod(A_Index, 6), dist: 25 + Mod(A_Index, 6) * 22, speed: 0.04 })
}

; Quad 4: Thermal Vortex Spiral
global q4Nodes := []
LayerStack.ActiveLayer := lyrQ4
loop numShapes {
    t := (A_Index - 1) / Float(numShapes - 1)
    clr := lutHeatmap.Sample(t)
    shp := Circle(cx, cy, 12, clr, true)
    q4Nodes.Push({ shp: shp, angle: t * 18.84, dist: 10 + t * (quadW * 0.4), speed: 0.035 })
}

; Initial draw
Draw(lyrQ1)
Draw(lyrQ2)
Draw(lyrQ3)
Draw(lyrQ4)

; 4. Initialize 4 background worker processes using official WorkerPool!
WorkerPool.Init(4)

; 5. Master Director Animation Loop (Runs smoothly across 4 CPU cores at 60 FPS)
global animTick := 0.0
global fpsCount := 0
global lastTick := A_TickCount
global lastFps := 60.0

SetTimer(DirectorFrame, 1)

DirectorFrame() {
    global animTick, lyrQ1, lyrQ2, lyrQ3, lyrQ4, q1Nodes, q2Nodes, q3Nodes, q4Nodes
    global cx, cy, fpsCount, lastTick, lastFps, fpsText

    animTick += 0.04
    fpsCount++
    if (A_TickCount - lastTick >= 1000) {
        lastFps := fpsCount
        fpsCount := 0
        lastTick := A_TickCount
        fpsText.str := Format("4 Workers ➔ {:d} FPS (Parallel)", lastFps)
    }

    ; Update Quad 1 coordinates (Plasma Orbs)
    for node in q1Nodes {
        node.phase += node.speed
        node.shp.x := cx + Cos(node.phase) * (node.radius + Sin(animTick * 2.0 + node.phase) * 15) - 7
        node.shp.y := cy + Sin(node.phase) * (node.radius + Cos(animTick * 2.0 + node.phase) * 15) - 7
    }

    ; Update Quad 2 coordinates (Julia Matrix)
    for node in q2Nodes {
        node.angle += node.speed
        node.shp.x := cx + Cos(node.angle + animTick) * node.dist - 6
        node.shp.y := cy + Sin(node.angle + animTick) * node.dist - 6
    }

    ; Update Quad 3 coordinates (Neon Pulse)
    for node in q3Nodes {
        node.angle += (node.ringIdx & 1 ? 1 : -1) * node.speed
        pulseDist := node.dist + Sin(animTick * 4.0 + node.ringIdx) * 8
        node.shp.x := cx + Cos(node.angle) * pulseDist - 5
        node.shp.y := cy + Sin(node.angle) * pulseDist - 5
    }

    ; Update Quad 4 coordinates (Thermal Vortex)
    for node in q4Nodes {
        node.angle += node.speed
        spiralDist := node.dist + Sin(animTick * 3.0 + node.angle) * 10
        node.shp.x := cx + Cos(node.angle) * spiralDist - 6
        node.shp.y := cy + Sin(node.angle) * spiralDist - 6
    }

    ; DISPATCH ALL 4 QUADRANTS TO WORKER PROCESSES IN PARALLEL!
    WorkerPool.Dispatch(lyrQ1, 1)
    WorkerPool.Dispatch(lyrQ2, 2)
    WorkerPool.Dispatch(lyrQ3, 3)
    WorkerPool.Dispatch(lyrQ4, 4)

    ; Wait for all 4 CPU cores to finish rendering
    WorkerPool.WaitForAll(50)
}

HotKey("~*Esc", (*) => ExitApp())
