; Script:    WorkerPool.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include %A_LineFile%\..\IPC.ahk

/**
 * GpGFX Multi-Process Worker Pool Coordinator
 *
 * Why:
 * AutoHotkey v2 is single-threaded. CPU-heavy operations such as rendering large shape hierarchies,
 * calculating continuous physics simulations, or processing multiple layers can cause UI latency and
 * frame drops. WorkerPool spawns and manages background AutoHotkey worker processes (Worker.ahk) to
 * distribute rendering workloads across multiple CPU cores in parallel.
 *
 * When to Use:
 * - Complex scenes with many shapes: Use WorkerPool.AutoDispatch(layer) to automatically split
 *   shape rendering across background workers when complexity exceeds single-thread thresholds.
 * - Multi-layer compositing: Use WorkerPool.Composite(masterLayer, layer1, layer2, ...) to render
 *   separate layers in parallel on different CPU cores, merging them into a single window update.
 * - Independent physics / simulations: Use WorkerPool.StepWorker(workerId, dt) to run particle loops
 *   in background workers without blocking the main script.
 *
 * How It Works:
 * 1. Process Spawning: Spawns N background worker processes (Worker.ahk) with High process priority.
 * 2. Shared Memory: Allocates an 8 MB shared RAM mapping (FileMapping) per worker.
 * 3. Synchronization: Uses named Windows Mutexes and Semaphores:
 *    - semTask: Notifies the worker process when a task is queued.
 *    - semDone: Notifies the main script when the worker finishes rendering.
 * 4. Zero-Copy Compositing: GdipCreateBitmapFromScan0 binds the worker's shared RAM directly
 *    into a GDI+ Bitmap in the main process, allowing fast hardware-level alpha blending.
 * 5. Screen Update: Composites all rendered worker buffers into a single UpdateLayeredWindow call.
 */
class WorkerPool {

    static workers := []
    static maxWorkers := 4
    static isInitialized := false
    static nextWorkerId := 1

    /**
     * Initializes the worker pool by spawning N background worker processes.
     *
     * @param {Integer} [count=4] Number of worker processes to spawn
     * @returns {void}
     *
     * @example
     * ; Initialize pool with 4 background rendering workers
     * WorkerPool.Init(4)
     */
    static Init(count := 4) {
        local workerScript, idx, memName, mtxName, semTaskName, semDoneName
        local fm, mtx, semTask, semDone, cmd, pid, startIdx, toSpawn, pSharedBmp, e

        if (this.isInitialized && count <= this.workers.Length)
            return

        this.maxWorkers := Max(count, this.workers.Length)
        workerScript := A_LineFile "\..\Worker.ahk"
        startIdx := this.workers.Length + 1
        toSpawn := count - this.workers.Length

        loop toSpawn {
            idx := startIdx + A_Index - 1
            memName := "Local\GpGFX_WorkerMem_" idx
            mtxName := "Local\GpGFX_WorkerMutex_" idx
            semTaskName := "Local\GpGFX_WorkerSemTask_" idx
            semDoneName := "Local\GpGFX_WorkerSemDone_" idx

            fm := FileMapping(memName, , , 8388608)
            mtx := Mutex(mtxName)
            semTask := Semaphore(0, 100, semTaskName)
            semDone := Semaphore(0, 100, semDoneName)

            pSharedBmp := 0
            DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", Layer.w, "int", Layer.h, "int", Layer.w * 4, "int", 0x26200A, "ptr", fm.pBuf + 65536, "ptr*", &pSharedBmp:=0)

            try {
                cmd := Format('"{1}" "{2}" "{3}" "{4}" "{5}" "{6}" {7}', 
                    A_AhkPath, workerScript, memName, mtxName, semTaskName, semDoneName, idx)
                pid := Run(cmd, , "Hide")
                
                this.workers.Push({
                    id: idx,
                    pid: pid,
                    fm: fm,
                    mtx: mtx,
                    semTask: semTask,
                    semDone: semDone,
                    pSharedBitmap: pSharedBmp,
                    busy: false,
                    assignedLayer: 0
                })
            } catch as e {
                GpGFX.DebugLog("[!] Failed to spawn worker " idx ": " e.Message "`n")
            }
        }

        if (!this.isInitialized) {
            this.isInitialized := true
            OnExit((*) => WorkerPool.Shutdown())
        }
    }

    /**
     * Assigns a background worker from the pool to a layer instance in round-robin sequence.
     *
     * @param {Layer} layerObj Target layer instance
     * @returns {Integer} Assigned worker ID (1..maxWorkers)
     *
     * @example
     * workerId := WorkerPool.AssignWorker(myLayer)
     */
    static AssignWorker(layerObj) {
        local id := this.nextWorkerId
        this.nextWorkerId := (this.nextWorkerId >= this.maxWorkers) ? 1 : (this.nextWorkerId + 1)
        if (id <= this.workers.Length) {
            this.workers[id].assignedLayer := layerObj
        }
        return id
    }

    /**
     * Sends a step simulation command to a specific worker to calculate physics and render in parallel.
     *
     * @param {Integer} workerIdx Worker ID (1..N)
     * @param {Float} [dt=0.03] Delta time in seconds
     * @returns {void}
     *
     * @example
     * WorkerPool.StepWorker(1, 0.016)
     */
    static StepWorker(workerIdx, dt := 0.03) {
        local w, lyr, pBuf
        if (workerIdx <= this.workers.Length) {
            w := this.workers[workerIdx]
            lyr := w.assignedLayer
            pBuf := w.fm.pBuf

            w.mtx.Lock()
            NumPut("int", 3, pBuf, 0)          ; TaskType = 3 (Compute Math + Render)
            NumPut("int", 1, pBuf, 4)          ; State = QUEUED
            NumPut("int", lyr.w, pBuf, 8)      ; Width
            NumPut("int", lyr.h, pBuf, 12)     ; Height
            NumPut("float", dt, pBuf, 24)      ; Delta Time
            w.mtx.Release()

            w.busy := true
            w.semTask.Release(1)
        }
    }

    /**
     * Serializes visible vector shapes from a layer into binary memory structs in the worker's shared buffer.
     *
     * @param {Layer} lyr Layer instance
     * @param {Integer} workerIndex Worker ID (1..N)
     * @returns {Integer} Total number of packed shapes
     */
    static PackLayer(lyr, workerIndex) {
        local w := this.workers[workerIndex]
        local pBuf := w.fm.pBuf
        local offset := 64
        local shapeCount := 0
        local shp, sName, shpType, fillFlag, clr, penW, rx, ry, rw, rh, extra1, extra2

        w.mtx.Lock()

        NumPut("int", 2, pBuf, 0)
        NumPut("int", 1, pBuf, 4)
        NumPut("int", lyr.w, pBuf, 8)
        NumPut("int", lyr.h, pBuf, 12)
        NumPut("uint", 0x00FFFFFF, pBuf, 20)

        for shp in lyr.shapes {
            if (!shp.Visible || shp.shape == "Container" || shp.shape == "Dummy" || shp.shape == "Text" || (shp.HasProp("isDummy") && shp.isDummy && !shp.Filled))
                continue

            sName := shp.HasProp("shape") ? String(shp.shape) : "Rectangle"
            shpType := (InStr(sName, "Round")) ? 2
                     : (InStr(sName, "Ellipse") || InStr(sName, "Circle")) ? 3
                     : (InStr(sName, "Line")) ? 4
                     : (InStr(sName, "Polygon") || InStr(sName, "Triangle")) ? 5
                     : 1

            fillFlag := (shp.HasProp("Filled") && shp.Filled) ? 1 : 0
            clr := Color(shp.Color)
            penW := Float(shp.HasProp("penwidth") && shp.penwidth ? shp.penwidth : 1.0)
            rx := Float(shp.x)
            ry := Float(shp.y)
            rw := Float(shp.w)
            rh := Float(shp.h)
            extra1 := Float(shp.HasProp("radius") && shp.radius ? shp.radius : 0.0)
            extra2 := 0

            NumPut("uint", shpType, pBuf, offset + 0)
            NumPut("uint", fillFlag, pBuf, offset + 4)
            NumPut("uint", clr, pBuf, offset + 8)
            NumPut("float", penW, pBuf, offset + 12)
            NumPut("float", rx, pBuf, offset + 16)
            NumPut("float", ry, pBuf, offset + 20)
            NumPut("float", rw, pBuf, offset + 24)
            NumPut("float", rh, pBuf, offset + 28)
            NumPut("float", extra1, pBuf, offset + 32)
            NumPut("uint", extra2, pBuf, offset + 36)

            offset += 48
            shapeCount++

            if (offset >= 130000)
                break
        }

        NumPut("int", shapeCount, pBuf, 16)
        w.mtx.Release()

        return shapeCount
    }

    /**
     * Scores layer complexity and routes rendering to local thread or background workers.
     *
     * @param {Layer} lyr Layer instance
     * @returns {void}
     *
     * @example
     * WorkerPool.AutoDispatch(myLayer)
     */
    static AutoDispatch(lyr) {
        local totalScore := 0, shp, sName, weight
        local shapeCount, chunkSize, workerIdx, startIdx, endIdx

        shapeCount := lyr.shapes.Length
        if (shapeCount == 0)
            return

        for shp in lyr.shapes {
            if (!shp.Visible)
                continue
            sName := shp.HasProp("shape") ? String(shp.shape) : "Rectangle"
            weight := (InStr(sName, "Round") || InStr(sName, "Ellipse") || InStr(sName, "Circle")) ? 1.5
                    : (InStr(sName, "Polygon") || InStr(sName, "Text")) ? 3.0
                    : 1.0
            totalScore += weight
        }

        if (totalScore <= 1500 || this.maxWorkers <= 1) {
            Draw(lyr)
            return
        }

        if (!this.isInitialized)
            this.Init()

        chunkSize := Ceil(shapeCount / this.maxWorkers)
        loop this.maxWorkers {
            workerIdx := A_Index
            startIdx := (workerIdx - 1) * chunkSize + 1
            endIdx := Min(workerIdx * chunkSize, shapeCount)

            if (startIdx <= shapeCount) {
                this.PackShapeSlice(lyr, workerIdx, startIdx, endIdx)
                this.workers[workerIdx].busy := true
                this.workers[workerIdx].semTask.Release(1)
            }
        }

        this.WaitForAll()
    }

    /**
     * Packs a subset slice of shapes into a worker's shared memory.
     *
     * @param {Layer} lyr Layer instance
     * @param {Integer} workerIndex Worker ID (1..N)
     * @param {Integer} startIdx 1-based start shape index
     * @param {Integer} endIdx 1-based end shape index
     * @returns {Integer} Number of packed shapes
     */
    static PackShapeSlice(lyr, workerIndex, startIdx, endIdx) {
        local w := this.workers[workerIndex]
        local pBuf := w.fm.pBuf
        local offset := 64
        local shapeCount := 0
        local idx, shp, sName, shpType, fillFlag, clr, penW, rx, ry, rw, rh, extra1, extra2

        w.mtx.Lock()
        NumPut("int", 2, pBuf, 0)
        NumPut("int", 1, pBuf, 4)
        NumPut("int", lyr.w, pBuf, 8)
        NumPut("int", lyr.h, pBuf, 12)
        NumPut("uint", 0x00FFFFFF, pBuf, 20)

        idx := startIdx
        while (idx <= endIdx && idx <= lyr.shapes.Length) {
            shp := lyr.shapes[idx]
            idx++
            if (!shp.Visible || shp.shape == "Container" || shp.shape == "Dummy" || shp.shape == "Text" || (shp.HasProp("isDummy") && shp.isDummy && !shp.Filled))
                continue

            sName := shp.HasProp("shape") ? String(shp.shape) : "Rectangle"
            shpType := (InStr(sName, "Round")) ? 2
                     : (InStr(sName, "Ellipse") || InStr(sName, "Circle")) ? 3
                     : (InStr(sName, "Line")) ? 4
                     : (InStr(sName, "Polygon") || InStr(sName, "Triangle")) ? 5
                     : 1

            fillFlag := (shp.HasProp("Filled") && shp.Filled) ? 1 : 0
            clr := Color(shp.Color)
            penW := Float(shp.HasProp("penwidth") && shp.penwidth ? shp.penwidth : 1.0)
            rx := Float(shp.x)
            ry := Float(shp.y)
            rw := Float(shp.w)
            rh := Float(shp.h)
            extra1 := Float(shp.HasProp("radius") && shp.radius ? shp.radius : 0.0)
            extra2 := 0

            NumPut("uint", shpType, pBuf, offset + 0)
            NumPut("uint", fillFlag, pBuf, offset + 4)
            NumPut("uint", clr, pBuf, offset + 8)
            NumPut("float", penW, pBuf, offset + 12)
            NumPut("float", rx, pBuf, offset + 16)
            NumPut("float", ry, pBuf, offset + 20)
            NumPut("float", rw, pBuf, offset + 24)
            NumPut("float", rh, pBuf, offset + 28)
            NumPut("float", extra1, pBuf, offset + 32)
            NumPut("uint", extra2, pBuf, offset + 36)

            offset += 48
            shapeCount++
            if (offset >= 130000)
                break
        }

        NumPut("int", shapeCount, pBuf, 16)
        w.mtx.Release()
        return shapeCount
    }

    /**
     * Dispatches a layer rendering task to a worker and signals it to begin.
     *
     * @param {Layer} lyr Layer instance
     * @param {Integer} workerIndex Worker ID (1..N)
     * @returns {void}
     */
    static Dispatch(lyr, workerIndex) {
        local w
        if (!this.isInitialized)
            this.Init()

        w := this.workers[workerIndex]
        this.PackLayer(lyr, workerIndex)
        w.busy := true
        w.assignedLayer := lyr
        w.semTask.Release(1)
    }

    /**
     * Waits for all active workers in the pool to complete and updates the screen.
     *
     * @param {Integer} [timeout=1000] Maximum milliseconds to wait
     * @returns {void}
     */
    static WaitForAll(timeout := 1000) {
        local w, lyr, byteCount, dstX, dstY, winW, winH
        for w in this.workers {
            if (w.busy) {
                w.semDone.Wait(timeout)
                w.busy := false
                lyr := w.assignedLayer
                if (lyr && IsObject(lyr) && lyr.HasProp("gfx") && lyr.gfx.pBits) {
                    byteCount := lyr.w * lyr.h * 4
                    DllCall("RtlCopyMemory", "ptr", lyr.gfx.pBits, "ptr", w.fm.pBuf + 65536, "uptr", byteCount)
                    if (Render.UpdateWindow && lyr.visible) {
                        dstX := Integer(lyr.x)
                        dstY := Integer(lyr.y)
                        winW := Max(1, Integer(lyr.w))
                        winH := Max(1, Integer(lyr.h))
                        DllCall("UpdateLayeredWindow"
                            ,     "ptr", lyr.hwnd
                            ,     "ptr", 0
                            , "uint64*", (dstX & 0xFFFFFFFF) | ((dstY & 0xFFFFFFFF) << 32)
                            , "uint64*", (winW & 0xFFFFFFFF) | ((winH & 0xFFFFFFFF) << 32)
                            ,     "ptr", lyr.gfx.hdc
                            , "uint64*", 0
                            ,    "uint", 0
                            ,   "uint*", (lyr.alpha << 16) | 0x01000000
                            ,    "uint", 2)
                    }
                }
            }
        }
    }

    /**
     * Renders multiple layers concurrently across workers, composites them into a single master canvas,
     * and updates the screen with a single UpdateLayeredWindow OS call.
     *
     * @param {Layer} targetLayer Master layer to composite into
     * @param {Array<Layer>} layers Layers to render in parallel
     * @returns {void}
     *
     * @example
     * WorkerPool.Composite(masterLayer, hudLayer, backgroundLayer, particlesLayer)
     */
    static Composite(targetLayer, layers*) {
        local lyr, idx, w, gfx, dstX, dstY, winW, winH, pBmp
        local numLayers := layers.Length

        if (!this.isInitialized)
            this.Init(Max(4, numLayers))

        loop numLayers {
            idx := A_Index
            if (idx <= this.maxWorkers) {
                lyr := layers[idx]
                w := this.workers[idx]

                if (!w.HasProp("curW") || w.curW != lyr.w || w.curH != lyr.h || !w.pSharedBitmap) {
                    if (w.pSharedBitmap)
                        DllCall("gdiplus\GdipDisposeImage", "ptr", w.pSharedBitmap)
                    w.curW := lyr.w, w.curH := lyr.h
                    pBmp := 0
                    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", lyr.w, "int", lyr.h, "int", lyr.w * 4, "int", 0x26200A, "ptr", w.fm.pBuf + 65536, "ptr*", &pBmp:=0)
                    w.pSharedBitmap := pBmp
                }

                this.PackLayer(lyr, idx)
                w.busy := true
                w.assignedLayer := lyr
                w.semTask.Release(1)
            }
        }

        for w in this.workers {
            if (w.busy) {
                w.semDone.Wait(50)
                w.busy := false
            }
        }

        gfx := targetLayer.gfx.ptr
        DllCall("gdiplus\GdipGraphicsClear", "ptr", gfx, "uint", 0x00FFFFFF)

        loop numLayers {
            idx := A_Index
            if (idx <= this.maxWorkers && this.workers[idx].pSharedBitmap) {
                DllCall("gdiplus\GdipDrawImage", "ptr", gfx, "ptr", this.workers[idx].pSharedBitmap, "float", 0.0, "float", 0.0)
            }
        }

        if (Render.UpdateWindow && targetLayer.visible) {
            dstX := Integer(targetLayer.x)
            dstY := Integer(targetLayer.y)
            winW := Max(1, Integer(targetLayer.w))
            winH := Max(1, Integer(targetLayer.h))
            DllCall("UpdateLayeredWindow"
                ,     "ptr", targetLayer.hwnd
                ,     "ptr", 0
                , "uint64*", (dstX & 0xFFFFFFFF) | ((dstY & 0xFFFFFFFF) << 32)
                , "uint64*", (winW & 0xFFFFFFFF) | ((winH & 0xFFFFFFFF) << 32)
                ,     "ptr", targetLayer.gfx.hdc
                , "uint64*", 0
                ,    "uint", 0
                ,   "uint*", (targetLayer.alpha << 16) | 0x01000000
                ,    "uint", 2)
        }
    }

    /**
     * Shuts down and cleans up all background worker processes and allocated shared memory.
     *
     * @returns {void}
     */
    static Shutdown() {
        local w
        if (!this.isInitialized)
            return

        this.isInitialized := false

        for w in this.workers {
            if (w.pSharedBitmap) {
                if (Gdip.pToken) {
                    try DllCall("gdiplus\GdipDisposeImage", "ptr", w.pSharedBitmap)
                }
                w.pSharedBitmap := 0
            }
            try {
                w.mtx.Lock()
                NumPut("int", 99, w.fm.pBuf, 0)
                w.mtx.Release()
                w.semTask.Release(1)
            }
        }

        this.workers.Length := 0
    }
}