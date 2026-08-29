; Script     Worker.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#SingleInstance Off

/**
 * GpGFX Dedicated Background Worker Process
 *
 * Why:
 * AutoHotkey v2 runs on a single thread. CPU-intensive operations (batch shape rasterization,
 * particle simulation math, and 4K pixel scanning) can cause frame drops and block hotkeys if
 * executed on the main UI thread. Worker.ahk runs in an independent background process to
 * utilize multi-core CPUs.
 *
 * When to Use:
 * - Parallelizing layer rendering across multiple worker processes (managed by WorkerPool.ahk).
 * - Multi-core SIMD pixel searching across different screen quadrants.
 * - Background math calculations (particle systems, physics) rendered directly off-thread.
 *
 * How It Works:
 * 1. Shared Memory (FileMapping):
 *    A shared 8 MB RAM buffer connects the main script and this worker process with zero disk I/O.
 * 2. Synchronization (Mutex & Semaphores):
 *    - Mutex: Serializes read/write access to task header fields.
 *    - semTask: Worker waits in a kernel sleep (0% CPU) until the main process posts a task.
 *    - semDone: Worker signals this semaphore when task execution finishes.
 * 3. Direct Framebuffer Rasterization (Scan0):
 *    GdipCreateBitmapFromScan0 binds GDI+ rendering directly into the shared memory pointer at offset 65536.
 *
 * Task Dispatch IDs:
 * - Task 1:  QPC spin-wait
 * - Task 2:  Vector shape rasterization (Rectangles, RoundedRects, Ellipses, Lines)
 * - Task 3:  Local particle simulation and rendering
 * - Task 4:  Parallel SIMD PixelSearch kernel (src/pixelsearch.c)
 * - Task 10: Initialize swarm particle buffer
 * - Task 99: Shutdown and exit process
 */

; Increase process priority for precise timing
ProcessSetPriority("High")

; Include GpGFX core
#include %A_LineFile%\..\..\GpGFX.ahk

mapName     := A_Args.Length >= 1 ? A_Args[1] : "Local\GpGFX_WorkerMem_1"
mtxName     := A_Args.Length >= 2 ? A_Args[2] : "Local\GpGFX_WorkerMutex_1"
semTaskName := A_Args.Length >= 3 ? A_Args[3] : "Local\GpGFX_WorkerSemTask_1"
semDoneName := A_Args.Length >= 4 ? A_Args[4] : "Local\GpGFX_WorkerSemDone_1"
workerId    := A_Args.Length >= 5 ? A_Args[5] : 1

; 8 MB shared RAM mapping (Header + Parameters + Scan0 Framebuffer)
fm := FileMapping(mapName, , , 8388608)
mtx := Mutex(mtxName)
semTask := Semaphore(0, 100, semTaskName)
semDone := Semaphore(0, 100, semDoneName)

; Reusable drawing tools
pBrush := 0
pPen := 0
DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFFFFFFFF, "ptr*", &pBrush:=0)
DllCall("gdiplus\GdipCreatePen1", "uint", 0xFFFFFFFF, "float", 1.0, "int", 2, "ptr*", &pPen:=0)

; Offscreen surface state
curW := 0
curH := 0
pBitmap := 0
pGraphics := 0
hMasterMap := 0
pMasterScan0 := 0

; Native x64 compiled machine code kernel for SIMD PixelSearch (Source: src/pixelsearch.c)
pMCodePixelSearch := MCode.Call("SIXJD4T3AQAAQVdBVkFVQVRVV1ZTSInLSIPsGEyLGU2F2w" . 
    "+EeAEAAItzEItRCESLcxSLSQxEi2MYRItTHESLeyBMi2sohfYPhZMAAABFOfwPj0MBAABMY8JB" . 
    "D6/USGPSTAHaTYXtD4RZAQAAQYtFAIXAD4UoAQAARTnWD4+CAQAASWPG6xdmLg8fhAAAAAAASI" . 
    "PAAUE5wg+MEwEAADkMgnXux0MwAQAAAIlDNESJYziJSzxNhe10CEHHRQABAAAAuAEAAABIg8QY" . 
    "W15fXUFcQV1BXkFfw2YuDx+EAAAAAACJzw+27UQPtsnB7xBAD7b/RTn8D4+gAAAASGPCQQ+v1E" . 
    "SJfCQMSGPSSQHTSInCTYXtdAxBi0UAhcAPhYEAAABFOdZ/Y0SJdCQITWPGDx9AAEOLDIOJyMHo" . 
    "EA+2wCn4QYnHQfffRA9I+A+2xSnoQYnG99hBD0jGRA+28UE5x0EPTcdFKc5FifdB999FD0j+RD" . 
    "n4QQ9MxznwfmdJg8ABRTnCfa5Ei3QkCEGDxAFJAdNEOWQkDA+Ndf///8dDMAAAAAAxwOke////" . 
    "Zg8fhAAAAAAAQYPEAUwBwkU553zdTYXtD4Wn/v//RTnWD46z/v//QYPEAUwBwkU5/H7r670PH0" . 
    "AAx0MwAQAAAESJQzREiWM4iUs8TYXtD4W9/v//6cD+//8xwMNBg8QBTAHCRTn8D45Z/v//64Qx" . 
    "wMM=")

EnsureSurface(w, h) {
    global curW, curH, pBitmap, pGraphics, fm
    local pScan0
    if (w != curW || h != curH || !pGraphics) {
        if (pGraphics) {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGraphics)
            pGraphics := 0
        }
        if (pBitmap) {
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
            pBitmap := 0
        }
        curW := w
        curH := h
        ; Direct rasterization into shared RAM buffer (Scan0 at offset 65536)
        pScan0 := fm.pBuf + 65536
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", w * 4, "int", 0x26200A, "ptr", pScan0, "ptr*", &pBitmap:=0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pBitmap, "ptr*", &pGraphics:=0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", pGraphics, "int", 4)
    }
}

global localParticles := []

; Main Worker Event Loop
loop {
    ; Wait for task dispatch signal from main process (zero CPU usage while idle)
    res := semTask.Wait(0xFFFFFFFF)
    if (res != 0)
        continue

    mtx.Lock()
    taskType := NumGet(fm.pBuf, 0, "int")

    ; Task 99: Shutdown
    if (taskType == 99) {
        mtx.Release()
        break
    }

    ; Task 10: Initialize internal particle buffer
    if (taskType == 10) {
        w        := NumGet(fm.pBuf, 8, "int")
        h        := NumGet(fm.pBuf, 12, "int")
        count    := NumGet(fm.pBuf, 16, "int")
        clr      := NumGet(fm.pBuf, 20, "uint")
        minDist  := NumGet(fm.pBuf, 24, "float")
        maxDist  := NumGet(fm.pBuf, 28, "float")
        minSpeed := NumGet(fm.pBuf, 32, "float")
        maxSpeed := NumGet(fm.pBuf, 36, "float")

        EnsureSurface(w, h)
        localParticles.Length := 0
        loop count {
            localParticles.Push({
                angle: Random(0.0, 6.28318),
                dist: Random(minDist, maxDist),
                speed: Random(minSpeed, maxSpeed),
                size: Random(3.0, 7.0),
                color: clr
            })
        }
        NumPut("int", 3, fm.pBuf, 4) ; State = DONE
        mtx.Release()
        semDone.Release(1)
        continue
    }

    ; Task 3: Calculate particle math & rasterize to Scan0
    if (taskType == 3) {
        w  := NumGet(fm.pBuf, 8, "int")
        h  := NumGet(fm.pBuf, 12, "int")
        dt := NumGet(fm.pBuf, 24, "float")
        cx := Float(w // 2)
        cy := Float(h // 2)

        EnsureSurface(w, h)
        DllCall("gdiplus\GdipGraphicsClear", "ptr", pGraphics, "uint", 0x00000000)
        for pt in localParticles {
            pt.angle += pt.speed
            px := cx + Cos(pt.angle) * pt.dist
            py := cy + Sin(pt.angle) * pt.dist
            DllCall("gdiplus\GdipSetSolidFillColor", "ptr", pBrush, "uint", pt.color)
            DllCall("gdiplus\GdipFillEllipse", "ptr", pGraphics, "ptr", pBrush, "float", px, "float", py, "float", pt.size, "float", pt.size)
        }
        DllCall("gdiplus\GdipFlush", "ptr", pGraphics, "int", 1)
        NumPut("int", 3, fm.pBuf, 4) ; State = DONE
        mtx.Release()
        semDone.Release(1)
        continue
    }

    ; Task 1: High-precision QPC wait
    if (taskType == 1) {
        param1 := NumGet(fm.pBuf, 8, "int64")
        mtx.Release()
        MCode.QpcSpinWait(param1)
        mtx.Lock()
        NumPut("int", 3, fm.pBuf, 4) ; State = DONE
        mtx.Release()
        semDone.Release(1)
        continue
    }

    ; Task 4: Parallel SIMD PixelSearch across shared master framebuffer
    if (taskType == 4) {
        targetClr := NumGet(fm.pBuf, 8, "uint")
        var       := NumGet(fm.pBuf, 12, "int")
        subX1     := NumGet(fm.pBuf, 16, "int")
        subY1     := NumGet(fm.pBuf, 20, "int")
        subX2     := NumGet(fm.pBuf, 24, "int")
        subY2     := NumGet(fm.pBuf, 28, "int")
        imgW      := NumGet(fm.pBuf, 32, "int")
        imgH      := NumGet(fm.pBuf, 36, "int")
        stride    := imgW * 4

        if (!pMasterScan0) {
            hMasterMap := DllCall("OpenFileMappingW", "uint", 0x000F001F, "int", 0, "wstr", "Local\GpGFX_PixelSearch_MasterFB", "ptr")
            if (hMasterMap)
                pMasterScan0 := DllCall("MapViewOfFile", "ptr", hMasterMap, "uint", 0x000F001F, "uint", 0, "uint", 0, "uptr", 0, "ptr")
        }
        pScan0 := pMasterScan0 ? pMasterScan0 : (fm.pBuf + 65536)

        ; Setup SearchCtx struct in shared memory at offset 128
        pCtx := fm.pBuf + 128
        NumPut("ptr",  pScan0,      pCtx, 0)
        NumPut("int",  stride,     pCtx, 8)
        NumPut("uint", targetClr,  pCtx, 12)
        NumPut("int",  var,        pCtx, 16)
        NumPut("int",  subX1,      pCtx, 20)
        NumPut("int",  subY1,      pCtx, 24)
        NumPut("int",  subX2,      pCtx, 28)
        NumPut("int",  subY2,      pCtx, 32)
        NumPut("ptr",  0,          pCtx, 40)

        ; Execute native x64 compiled search kernel
        DllCall(pMCodePixelSearch, "ptr", pCtx, "int")

        found := NumGet(pCtx, 48, "int")
        fx    := NumGet(pCtx, 52, "int")
        fy    := NumGet(pCtx, 56, "int")
        fClr  := NumGet(pCtx, 60, "uint")

        NumPut("int", found, fm.pBuf, 52)
        NumPut("int", fx,    fm.pBuf, 56)
        NumPut("int", fy,    fm.pBuf, 60)
        NumPut("uint", fClr, fm.pBuf, 64)

        if (found)
            NumPut("int", 1, fm.pBuf, 48)

        NumPut("int", 3, fm.pBuf, 4) ; State = DONE
        mtx.Release()
        semDone.Release(1)
        continue
    }

    ; Task 2: Vector Shape Batch Rasterization
    if (taskType == 2) {
        w          := NumGet(fm.pBuf, 8, "int")
        h          := NumGet(fm.pBuf, 12, "int")
        shapeCount := NumGet(fm.pBuf, 16, "int")
        clearClr   := NumGet(fm.pBuf, 20, "uint")

        EnsureSurface(w, h)
        DllCall("gdiplus\GdipGraphicsClear", "ptr", pGraphics, "uint", clearClr)

        offset := 64
        loop shapeCount {
            shpType  := NumGet(fm.pBuf, offset + 0, "uint")
            fillFlag := NumGet(fm.pBuf, offset + 4, "uint")
            clr      := NumGet(fm.pBuf, offset + 8, "uint")
            penW     := NumGet(fm.pBuf, offset + 12, "float")
            rx       := NumGet(fm.pBuf, offset + 16, "float")
            ry       := NumGet(fm.pBuf, offset + 20, "float")
            rw       := NumGet(fm.pBuf, offset + 24, "float")
            rh       := NumGet(fm.pBuf, offset + 28, "float")
            rad      := NumGet(fm.pBuf, offset + 32, "float")

            if (fillFlag) {
                DllCall("gdiplus\GdipSetSolidFillColor", "ptr", pBrush, "uint", clr)
                if (shpType == 1) { ; Rectangle
                    DllCall("gdiplus\GdipFillRectangle", "ptr", pGraphics, "ptr", pBrush, "float", rx, "float", ry, "float", rw, "float", rh)
                } else if (shpType == 3) { ; Ellipse
                    DllCall("gdiplus\GdipFillEllipse", "ptr", pGraphics, "ptr", pBrush, "float", rx, "float", ry, "float", rw, "float", rh)
                } else if (shpType == 2) { ; Rounded Rectangle (Filled)
                    r := Max(1.0, Min(rad, rw / 2.0, rh / 2.0))
                    d := 2.0 * r
                    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath:=0)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx, "float", ry, "float", d, "float", d, "float", 180, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + r, "float", ry, "float", rx + rw - r, "float", ry)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx + rw - d, "float", ry, "float", d, "float", d, "float", 270, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + rw, "float", ry + r, "float", rx + rw, "float", ry + rh - r)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx + rw - d, "float", ry + rh - d, "float", d, "float", d, "float", 0, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + rw - r, "float", ry + rh, "float", rx + r, "float", ry + rh)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx, "float", ry + rh - d, "float", d, "float", d, "float", 90, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx, "float", ry + rh - r, "float", rx, "float", ry + r)
                    DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath)
                    DllCall("gdiplus\GdipFillPath", "ptr", pGraphics, "ptr", pBrush, "ptr", pPath)
                    DllCall("gdiplus\GdipDeletePath", "ptr", pPath)
                }
            } else {
                DllCall("gdiplus\GdipSetPenColor", "ptr", pPen, "uint", clr)
                DllCall("gdiplus\GdipSetPenWidth", "ptr", pPen, "float", penW)
                if (shpType == 1) {
                    DllCall("gdiplus\GdipDrawRectangle", "ptr", pGraphics, "ptr", pPen, "float", rx, "float", ry, "float", rw, "float", rh)
                } else if (shpType == 3) {
                    DllCall("gdiplus\GdipDrawEllipse", "ptr", pGraphics, "ptr", pPen, "float", rx, "float", ry, "float", rw, "float", rh)
                } else if (shpType == 2) { ; Rounded Rectangle (Outline)
                    pw := penW / 2.0
                    r := rad
                    (rw <= rh && (r + pw > rw / 2)) ? (r := (rw / 2 > pw) ? rw / 2 - pw : 0)
                        : (rh < rw && r + pw > rh / 2) ? (r := (rh / 2 > pw) ? rh / 2 - pw : 0)
                        : (r < pw / 2) ? (r := pw / 2) : 0
                    d := 2.0 * r
                    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath:=0)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx + pw, "float", ry + pw, "float", d, "float", d, "float", 180, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + pw + r, "float", ry + pw, "float", rx + rw - r - pw, "float", ry + pw)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx + rw - d - pw, "float", ry + pw, "float", d, "float", d, "float", 270, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + rw - pw, "float", ry + r + pw, "float", rx + rw - pw, "float", ry + rh - r - pw)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx + rw - d - pw, "float", ry + rh - d - pw, "float", d, "float", d, "float", 0, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + rw - r - pw, "float", ry + rh - pw, "float", rx + r + pw, "float", ry + rh - pw)
                    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", rx + pw, "float", ry + rh - d - pw, "float", d, "float", d, "float", 90, "float", 90)
                    DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", rx + pw, "float", ry + rh - r - pw, "float", rx + pw, "float", ry + r + pw)
                    DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath)
                    DllCall("gdiplus\GdipDrawPath", "ptr", pGraphics, "ptr", pPen, "ptr", pPath)
                    DllCall("gdiplus\GdipDeletePath", "ptr", pPath)
                } else if (shpType == 4) {
                    DllCall("gdiplus\GdipDrawLine", "ptr", pGraphics, "ptr", pPen, "float", rx, "float", ry, "float", rx + rw, "float", ry + rh)
                }
            }

            offset += 48
        }

        DllCall("gdiplus\GdipFlush", "ptr", pGraphics, "int", 1)
        NumPut("int", 3, fm.pBuf, 4) ; State = DONE
        mtx.Release()
        semDone.Release(1)
    }
}

; Cleanup on exit
if (pBrush)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", pBrush)
if (pPen)
    DllCall("gdiplus\GdipDeletePen", "ptr", pPen)
if (pGraphics)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGraphics)
if (pBitmap)
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)

ExitApp()
