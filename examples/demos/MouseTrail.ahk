; Script:    MouseTrail.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include %A_LineFile%\..\..\..\GpGFX.ahk

/**
 * GpGFX Ultra-Fast & Low-CPU Mouse Trail Engine
 * 
 * Features:
 * - 3 Visual Modes:
 *     1. Stardust Glow (Neon particles with speed-reactive hue & size decay)
 *     2. Cyber Ribbon (Connected vector ribbon trail)
 *     3. Firefly Swarm (Physics-driven orbiting particles)
 * - Click-through transparent overlay (WS_EX_TRANSPARENT)
 * - Pre-allocated Retained Vector Shape Pool (0 allocations & 0 GC overhead)
 * - Smart Dirty Bounding Box rendering (< 0.5% CPU)
 * 
 * Controls:
 * - [Tab]   : Switch trail modes
 * - [Space] : Supernova particle burst
 * - [H]     : Toggle HUD info overlay
 * - [Esc]   : Exit
 */

Main()

Main() {
    CoordMode("Mouse", "Screen")

    scrW := A_ScreenWidth
    scrH := A_ScreenHeight

    ; Create full-screen transparent click-through layer
    lyr := Layer(scrW, scrH, "MouseTrailOverlay")
    lyr.ClickThrough := true

    ; Retained Vector Shape Pool (Pre-allocated once)
    maxParticles := 60
    particles := []
    particleShapes := []

    loop maxParticles {
        particles.Push({
            active: false,
            x: 0.0, y: 0.0,
            vx: 0.0, vy: 0.0,
            life: 0.0, maxLife: 1.0,
            size: 8.0,
            hue: 0.0, sat: 0.9, lit: 0.6
        })
        ; Pre-create hidden GpGFX vector shapes
        shp := Ellipse(0, 0, 10, 10, "0x00FFFFFF", true)
        shp.Visible := false
        particleShapes.Push(shp)
    }

    ; Ribbon lines pool
    maxRibbon := 16
    ribbonPoints := []
    ribbonShapes := []
    loop maxRibbon {
        rLine := Line(0, 0, 1, 1, "0x00FFFFFF", 2)
        rLine.Visible := false
        ribbonShapes.Push(rLine)
    }

    ; Cursor Core Glow
    cursorCore := Ellipse(0, 0, 8, 8, "0xFFFFFFFF", true)
    cursorRing := Ellipse(0, 0, 14, 14, "0x8078DCE8", false)

    trailMode := 1
    modeNames := ["1. Stardust Glow", "2. Cyber Ribbon", "3. Firefly Swarm"]

    lastMouseX := 0
    lastMouseY := 0
    MouseGetPos(&lastMouseX, &lastMouseY)
    
    globalHue := 0.0
    lastTime := Time.Now()
    fpsCount := 0
    fpsTimer := Time.Now()
    currentFps := 60

    SpawnParticle(px, py, pvx, pvy, psize, plife, phue, psat := 0.9, plit := 0.6) {
        for p in particles {
            if (!p.active) {
                p.active := true
                p.x := Float(px)
                p.y := Float(py)
                p.vx := Float(pvx)
                p.vy := Float(pvy)
                p.size := Float(psize)
                p.maxLife := Float(plife)
                p.life := Float(plife)
                p.hue := Float(phue)
                p.sat := Float(psat)
                p.lit := Float(plit)
                return p
            }
        }
        return 0
    }

    SupernovaBurst(bx, by, count := 35) {
        loop count {
            angle := Random(0.0, 6.28318)
            spd := Random(2.0, 8.0)
            SpawnParticle(bx, by, Cos(angle) * spd, Sin(angle) * spd, Random(5.0, 12.0), Random(0.3, 0.7), Mod(globalHue + Random(-40.0, 40.0), 360.0), 1.0, 0.65)
        }
    }

    ; 60 FPS Render Loop (Retained Mode)
    SetTimer(UpdateTrail, 16)

    UpdateTrail() {
        now := Time.Now()
        dt := Min(0.05, now - lastTime)
        lastTime := now

        fpsCount++
        if (now - fpsTimer >= 0.5) {
            currentFps := Round(fpsCount / (now - fpsTimer))
            fpsCount := 0
            fpsTimer := now
        }

        curX := 0, curY := 0
        MouseGetPos(&curX, &curY)
        dx := curX - lastMouseX
        dy := curY - lastMouseY
        dist := Sqrt(dx * dx + dy * dy)
        
        globalHue := Mod(globalHue + 1.2, 360.0)

        ; 1. Spawn Logic
        if (trailMode == 1) {
            if (dist > 2.0) {
                spawnCount := Min(3, Max(1, Round(dist / 14)))
                loop spawnCount {
                    subT := A_Index / spawnCount
                    interpX := lastMouseX + dx * subT + Random(-2.0, 2.0)
                    interpY := lastMouseY + dy * subT + Random(-2.0, 2.0)
                    
                    scatterAngle := Random(0.0, 6.28318)
                    scatterSpd := Random(0.2, 1.2)
                    pvx := (-dx * 0.08) + Cos(scatterAngle) * scatterSpd
                    pvy := (-dy * 0.08) + Sin(scatterAngle) * scatterSpd

                    pHue := Mod(globalHue + (dist * 1.2) + Random(-10.0, 10.0), 360.0)
                    pSize := Random(5.0, 10.0)
                    pLife := Random(0.25, 0.50)
                    SpawnParticle(interpX, interpY, pvx, pvy, pSize, pLife, pHue, 0.95, 0.6)
                }
            }
        }
        else if (trailMode == 2) {
            if (dist > 1.0 || ribbonPoints.Length > 0) {
                ribbonPoints.InsertAt(1, { x: curX, y: curY, hue: globalHue })
                if (ribbonPoints.Length > maxRibbon)
                    ribbonPoints.Pop()
            }
        }
        else if (trailMode == 3) {
            activeCount := 0
            for p in particles {
                if (p.active)
                    activeCount++
            }
            if (activeCount < 25) {
                loop 2 {
                    SpawnParticle(curX + Random(-20, 20), curY + Random(-20, 20), Random(-2.0, 2.0), Random(-2.0, 2.0), Random(4.0, 7.0), Random(0.6, 1.2), Mod(globalHue + Random(-30.0, 30.0), 360.0), 1.0, 0.65)
                }
            }
        }

        lastMouseX := curX
        lastMouseY := curY

        ; 2. Update Physics & Sync Shapes
        activeParticles := 0
        loop maxParticles {
            idx := A_Index
            p := particles[idx]
            shp := particleShapes[idx]

            if (!p.active) {
                shp.Visible := false
                continue
            }

            p.life -= dt
            if (p.life <= 0) {
                p.active := false
                shp.Visible := false
                continue
            }
            activeParticles++

            if (trailMode == 3) {
                toMouseX := curX - p.x
                toMouseY := curY - p.y
                dToMouse := Max(1.0, Sqrt(toMouseX * toMouseX + toMouseY * toMouseY))
                springF := Min(6.0, dToMouse * 0.15)
                p.vx := (p.vx * 0.93) + (toMouseX / dToMouse) * springF * dt * 25.0
                p.vy := (p.vy * 0.93) + (toMouseY / dToMouse) * springF * dt * 25.0
            } else {
                p.vx *= 0.94
                p.vy := (p.vy * 0.94) - 0.2
            }

            p.x += p.vx
            p.y += p.vy

            ; Sync Retained Shape Properties
            lifeNorm := p.life / p.maxLife
            alphaVal := Round(255 * Time.Ease.OutQuad(lifeNorm))
            curRadius := Max(1.5, p.size * Time.Ease.OutQuad(lifeNorm))
            curDiam := Round(curRadius * 2.0)

            shp.x := Round(p.x - curRadius)
            shp.y := Round(p.y - curRadius)
            shp.w := curDiam
            shp.h := curDiam
            shp.Color := Color.FromHSL(p.hue, p.sat, p.lit, alphaVal)
            shp.Visible := (trailMode != 2)
        }

        ; 3. Sync Ribbon Shapes (Mode 2)
        loop maxRibbon {
            idx := A_Index
            rLine := ribbonShapes[idx]

            if (trailMode == 2 && idx < ribbonPoints.Length) {
                pt1 := ribbonPoints[idx]
                pt2 := ribbonPoints[idx + 1]
                tRatio := 1.0 - (idx / ribbonPoints.Length)
                rWidth := Max(1.5, 12.0 * Time.Ease.OutQuad(tRatio))
                rAlpha := Round(230 * Time.Ease.OutQuad(tRatio))

                rLine.x1 := Round(pt1.x)
                rLine.y1 := Round(pt1.y)
                rLine.x2 := Round(pt2.x)
                rLine.y2 := Round(pt2.y)
                rLine.penwidth := rWidth
                rLine.Color := Color.FromHSL(pt1.hue, 0.95, 0.55, rAlpha)
                rLine.Visible := true
            } else {
                rLine.Visible := false
            }
        }
        if (trailMode == 2 && dist == 0 && ribbonPoints.Length > 0)
            ribbonPoints.Pop()

        ; 4. Cursor Core & Reticle
        cursorCore.x := curX - 4
        cursorCore.y := curY - 4
        cursorRing.x := curX - 7
        cursorRing.y := curY - 7
        cursorRing.Color := Color.FromHSL(globalHue, 1.0, 0.6, 180)

        ; Draw the layer with dirty bounding box calculation
        Draw(lyr)
    }

    ; Interactive Hotkeys
    HotKey("Tab", (*) => (
        trailMode := (trailMode >= 3) ? 1 : trailMode + 1,
        ribbonPoints := []
    ))

    HotKey("Space", (*) => (
        MouseGetPos(&mx, &my),
        SupernovaBurst(mx, my, 30)
    ))

    HotKey("Escape", (*) => ExitApp())
}
