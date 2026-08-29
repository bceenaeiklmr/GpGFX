; Script     Debug.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

/**
 * GpGFX diagnostics & telemetry
 *
 * Debug provides telemetry, process resource tracking, and hardware inspection.
 *
 * Core Capabilities:
 * - Metrics: Live FPS, render latency, frametime, frame count, active layer count, and total shape count.
 * - System Resources: Process working set memory (MB), normalized process CPU usage (%), physical cores, and logical threads.
 * - Extensibility: Pluggable metric registration system (Register, Unregister, Poll, GetSummary).
 */
class Debug {

    static Layer := 0
    static Shape := 0
    static enabled := false
    static updateFreq := 30
    static collectors := Map()
    static metrics := Map()

    ; CPU sampling state
    static __prevKernel := 0
    static __prevUser := 0
    static __prevTime := 0
    static __cachedCpu := 0.0

    static __New() {
        ; Register core built-in metrics
        this.Register("fps",       () => Round(Fps.lastfps, 1))
        this.Register("render",    () => Round(Fps.lastrender, 2) " ms")
        this.Register("frametime", () => Round(Fps.frametime, 2) " ms")
        this.Register("frames",    () => Fps.frames)
        this.Register("shapes",    () => Debug.__CountShapes())
        this.Register("layers",    () => LayerStack.pointers.Count)
        this.Register("mem",       () => Debug.__GetMemoryMB() " MB")
        this.Register("cpu",       () => Debug.__GetCpuPercent() "%")
    }

    /**
     * Registers a custom metric collector function.
     *
     * @param {String} name Unique identifier for the metric (case-insensitive)
     * @param {Func} fn Function returning the metric value or formatted string
     * @returns {void}
     *
     * @example
     * ; 1. Register a custom particle count metric
     * Debug.Register("particles", () => activeParticles.Length)
     *
     * ; 2. Register game score
     * Debug.Register("score", () => "Score: " . playerScore)
     */
    static Register(name, fn) {
        this.metrics[StrLower(name)] := fn
    }

    /**
     * Unregisters a metric collector by name.
     *
     * @param {String} name Name of the metric to remove
     * @returns {void}
     *
     * @example
     * Debug.Unregister("score")
     */
    static Unregister(name) {
        if this.metrics.Has(StrLower(name))
            this.metrics.Delete(StrLower(name))
    }

    /**
     * Polls all registered collectors and returns a Map containing current metric values.
     *
     * @returns {Map} Map of metric names to current values
     *
     * @example
     * currentMetrics := Debug.Poll()
     * fpsVal := currentMetrics["fps"]
     * memVal := currentMetrics["mem"]
     */
    static Poll() {
        local name := "", fn := 0
        for name, fn in this.metrics {
            try {
                this.collectors[name] := fn()
            } catch {
                this.collectors[name] := "err"
            }
        }
        return this.collectors
    }

    /**
     * Formats all active metrics into a concise single-line summary string.
     *
     * @returns {String} Formatted telemetry string
     *
     * @example
     * ; Output telemetry to status bar or console
     * statusText.str := Debug.GetSummary()
     */
    static GetSummary() {
        this.Poll()
        return    "fps "   (this.collectors.Has("fps")    ? this.collectors["fps"]    :   "0")
            . "   render " (this.collectors.Has("render") ? this.collectors["render"] : "0ms")
            . "   shapes " (this.collectors.Has("shapes") ? this.collectors["shapes"] :   "0")
            . "   layers " (this.collectors.Has("layers") ? this.collectors["layers"] :   "0")
            . "   mem "    (this.collectors.Has("mem")    ? this.collectors["mem"]    : "0MB")
            . "   cpu "    (this.collectors.Has("cpu")    ? this.collectors["cpu"]    :  "0%")
    }

    /**
     * Queries kernel system information to count available physical processor cores.
     *
     * @returns {Integer} Total physical core count
     *
     * @example
     * ; Dynamically size worker pools to match physical CPU cores
     * numWorkers := Debug.GetPhysicalCoreCount()
     */
    static GetPhysicalCoreCount() {
        local len, buf, structSize, count, physicalCores, offset, relationship
        static cachedPhysical := 0
        if (cachedPhysical)
            return cachedPhysical

        DllCall("Kernel32\GetLogicalProcessorInformation", "Ptr", 0, "UInt*", &len:=0)
        buf := Buffer(len, 0)
        if (!DllCall("Kernel32\GetLogicalProcessorInformation", "Ptr", buf, "UInt*", &len))
            return (cachedPhysical := 1)
        
        structSize := 32
        count := len // structSize
        physicalCores := 0
        
        Loop count {
            offset := (A_Index - 1) * structSize
            relationship := NumGet(buf, offset + A_PtrSize, "UInt")
            if (relationship == 0) ; RelationProcessorCore
                physicalCores += 1
        }
        return cachedPhysical := (physicalCores) ? physicalCores : 1
    }

    /**
     * Returns total logical processor threads (including HyperThreading / SMT).
     *
     * @returns {Integer} Total logical processor count
     *
     * @example
     * threads := Debug.GetLogicalProcessorCount()
     */
    static GetLogicalProcessorCount() {
        local sysInfo
        static cachedLogical := 0
        if (cachedLogical)
            return cachedLogical

        sysInfo := Buffer(48, 0)
        DllCall("GetSystemInfo", "Ptr", sysInfo)
        cachedLogical := NumGet(sysInfo, 32, "UInt")
        return (cachedLogical) ? cachedLogical : (EnvGet("NUMBER_OF_PROCESSORS") || 1)
    }

    /**
     * Returns total shape count across all currently active registered layers.
     */
    static __CountShapes() {
        local count := 0, ptr := 0, lyr := 0
        for id, ptr in LayerStack.pointers {
            try {
                lyr := ObjFromPtrAddRef(ptr)
                if (IsObject(lyr) && lyr.HasProp("shapes"))
                    count += lyr.shapes.Length
                lyr := ""
            }
        }
        return count
    }

    /**
     * Returns the process Working Set (private committed memory) in MB.
     */
    static __GetMemoryMB() {
        static pmc := Buffer(72, 0)
        NumPut("uint", 72, pmc, 0)
        if DllCall("psapi\GetProcessMemoryInfo", "ptr", -1, "ptr", pmc, "uint", 72)
            return Round(NumGet(pmc, 24, "uint64") / 1048576, 1) ; WorkingSetSize
        return 0.0
    }

    /**
     * Calculates approximate process CPU usage % between consecutive sample intervals.
     */
    static __GetCpuPercent() {
        local qpc := 0, now := 0.0, kTime := 0, uTime := 0, totalProcTime := 0, elapsedSec := 0.0, cpu := 0.0
        static ftCreate := Buffer(8, 0), ftExit := Buffer(8, 0), ftKernel := Buffer(8, 0), ftUser := Buffer(8, 0)

        DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
        now := qpc / Render.qpf

        ; Sample every 400ms at most to avoid noise and high timer overhead
        if (this.__prevTime && (now - this.__prevTime < 0.4))
            return this.__cachedCpu

        if DllCall("GetProcessTimes", "ptr", -1, "ptr", ftCreate, "ptr", ftExit, "ptr", ftKernel, "ptr", ftUser) {
            kTime := NumGet(ftKernel, 0, "int64")
            uTime := NumGet(ftUser, 0, "int64")

            if (this.__prevTime) {
                totalProcTime := (kTime - this.__prevKernel) + (uTime - this.__prevUser) ; in 100-ns units
                elapsedSec := now - this.__prevTime
                if (elapsedSec > 0) {
                    ; Convert 100-ns units to seconds (1 sec = 10,000,000 units), normalize by logical processors
                    cpu := (totalProcTime / 10000000) / elapsedSec / Debug.GetLogicalProcessorCount() * 100
                    this.__cachedCpu := Round(Max(0.0, Min(100.0, cpu)), 1)
                }
            }

            this.__prevKernel := kTime
            this.__prevUser := uTime
            this.__prevTime := now
        }

        return this.__cachedCpu
    }
}
