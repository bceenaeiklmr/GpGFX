; Script     FrameTimer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2

/**
 * GpGFX Frame Timer Controller
 *
 * Provides asynchronous, event-driven frame rate pacing for non-blocking animation loops:
 * - How it works:
 *   1. Launches a dedicated background C thread in GpGFX.Core.dll at THREAD_PRIORITY_TIME_CRITICAL.
 *   2. Uses sub-millisecond QPC spin-waiting to reach target frame deadlines (e.g. 16.666 ms for 60 FPS, 6.944 ms for 144 FPS).
 *   3. When each frame deadline arrives, the background thread posts a lightweight Windows message (HWND_MESSAGE) to AutoHotkey.
 *   4. AutoHotkey receives the message via OnMessage() and automatically triggers your callback function or draws registered layers on the main thread.
 * - Automatic Fallback: Smoothly falls back to an internal AHK SetTimer loop when GpGFX.Core.dll is not present.
 * - Difference from Render: Render is synchronous (for tight while/loop blocks), while FrameTimer is asynchronous (event-driven, leaves the main script responsive).
 */
class FrameTimer {

    static hLib := 0
    static hMsgWnd := 0
    static msgId := 0
    static isRunning := false
    static callback := 0
    static layers := []
    static fps := 60.0
    static autoMode := 1

    ; DLL export function pointers
    static pStart := 0
    static pStop := 0
    static pSetFPS := 0
    static pAck := 0
    static pStats := 0

    /**
     * Initializes and loads GpGFX.Core.dll if available.
     * Searches root, native/bin/, and script directory.
     *
     * @returns {Boolean} True if native DLL loaded and initialized, false otherwise
     */
    static Init() {
        local dllPaths, path, hDll, HWND_MESSAGE

        if (this.hLib)
            return true

        dllPaths := [
            A_LineFile "\..\GpGFX.Core.dll",
            A_LineFile "\..\native\bin\GpGFX.Core.dll",
            A_WorkingDir "\GpGFX.Core.dll",
            A_WorkingDir "\native\bin\GpGFX.Core.dll"
        ]

        for path in dllPaths {
            if (FileExist(path)) {
                hDll := DllCall("LoadLibrary", "str", path, "ptr")
                if (hDll) {
                    this.hLib    := hDll
                    this.pStart  := DllCall("GetProcAddress", "ptr", hDll, "astr", "StartFrameTimer", "ptr")
                    this.pStop   := DllCall("GetProcAddress", "ptr", hDll, "astr", "StopFrameTimer", "ptr")
                    this.pSetFPS := DllCall("GetProcAddress", "ptr", hDll, "astr", "SetTargetFPS", "ptr")
                    this.pAck    := DllCall("GetProcAddress", "ptr", hDll, "astr", "FrameCompleted", "ptr")
                    this.pStats  := DllCall("GetProcAddress", "ptr", hDll, "astr", "GetFrameStats", "ptr")
                    break
                }
            }
        }

        if (!this.hLib || !this.pStart)
            return false

        ; Create hidden message-only window (HWND_MESSAGE = -3)
        if (!this.hMsgWnd) {
            this.msgId := DllCall("RegisterWindowMessage", "str", "GpGFX_FrameReady", "uint")
            HWND_MESSAGE := -3
            this.hMsgWnd := DllCall("CreateWindowEx"
                , "uint", 0, "str", "STATIC", "str", "", "uint", 0
                , "int", 0, "int", 0, "int", 0, "int", 0
                , "ptr", HWND_MESSAGE
                , "ptr", 0, "ptr", 0, "ptr", 0, "ptr")

            OnMessage(this.msgId, ObjBindMethod(this, "__OnNativeFrame"))
        }

        return true
    }

    /**
     * Checks if the native C throttle DLL is loaded and ready.
     *
     * @returns {Boolean}
     */
    static IsAvailable => (this.hLib && this.pStart)

    /**
     * Starts the frame timer with a target callback function or layer list.
     *
     * @param {Func|Array|Layer} target Callback function or Layer(s) to render on each frame
     * @param {Float} [fps=60.0] Target frame rate
     * @param {Integer} [autoMode=1] 1 = continuous pulse (default), 0 = wait for FrameCompleted() handshake
     * @returns {Boolean} True on success
     *
     * @example
     * ; 1. Render a layer at 60 FPS
     * FrameTimer.Start(myLayer, 60.0)
     *
     * ; 2. Custom game loop callback at 144 FPS
     * FrameTimer.Start(UpdateGame, 144.0)
     */
    static Start(target, fps := 60.0, autoMode := 1) {
        local success, interval

        this.fps := fps
        this.autoMode := autoMode

        if (IsObject(target) && target.HasMethod("Call")) {
            this.callback := target
            this.layers := []
        } else if (target is Array) {
            this.layers := target
            this.callback := 0
        } else if (IsObject(target)) {
            this.layers := [target]
            this.callback := 0
        }

        ; If native DLL is available, launch native thread
        if (this.Init()) {
            success := DllCall(this.pStart
                , "ptr",    this.hMsgWnd
                , "uint",   this.msgId
                , "double", Float(fps)
                , "int",    Integer(autoMode)
                , "int")

            if (success) {
                this.isRunning := true
                return true
            }
        }

        ; Fallback: Pure AHK timer loop if native DLL is not present
        this.isRunning := true
        interval := Max(1, Floor(1000.0 / fps))
        SetTimer(ObjBindMethod(this, "__FallbackTick"), interval)
        return true
    }

    /**
     * Stops the frame timer.
     *
     * @returns {void}
     *
     * @example
     * FrameTimer.Stop()
     */
    static Stop() {
        if (!this.isRunning)
            return

        if (this.hLib && this.pStop) {
            DllCall(this.pStop)
        }

        SetTimer(ObjBindMethod(this, "__FallbackTick"), 0)
        this.isRunning := false
    }

    /**
     * Updates the target frame rate dynamically while running.
     *
     * @param {Float} fps New target frame rate
     * @returns {void}
     *
     * @example
     * FrameTimer.SetFPS(120.0)
     */
    static SetFPS(fps) {
        local interval
        this.fps := fps
        if (this.hLib && this.pSetFPS) {
            DllCall(this.pSetFPS, "double", Float(fps))
        } else if (this.isRunning) {
            interval := Max(1, Floor(1000.0 / fps))
            SetTimer(ObjBindMethod(this, "__FallbackTick"), interval)
        }
    }

    /**
     * Retrieves live frame pacing statistics from the native thread.
     *
     * @returns {Object} { lastDeltaMs: Float, avgFps: Float, totalFrames: Integer }
     *
     * @example
     * stats := FrameTimer.Stats
     * MsgBox("Average FPS: " stats.avgFps)
     */
    static Stats {
        get {
            local lastDelta := 0.0, avgFps := 0.0, totalFrames := 0
            if (this.hLib && this.pStats) {
                DllCall(this.pStats, "double*", &lastDelta:=0, "double*", &avgFps:=0, "uint64*", &totalFrames:=0)
                return { lastDeltaMs: lastDelta, avgFps: avgFps, totalFrames: totalFrames }
            }
            return {lastDeltaMs: 1000.0 / Max(1, this.fps), avgFps: this.fps, totalFrames: 0}
        }
    }

    /**
     * Internal handler invoked when WM_GPGFX_FRAME message arrives from native C thread.
     */
    static __OnNativeFrame(wParam, lParam, msg, hwnd) {
        local lyr, fn

        if (!this.isRunning)
            return

        if (this.callback) {
            fn := this.callback
            fn()
        } else {
            for lyr in this.layers {
                if (lyr.visible)
                    Draw(lyr)
            }
        }

        ; If handshake mode, acknowledge frame completion back to native thread
        if (!this.autoMode && this.hLib && this.pAck) {
            DllCall(this.pAck)
        }
    }

    /**
     * Internal fallback tick when native DLL is not loaded.
     */
    static __FallbackTick() {
        local lyr, fn

        if (!this.isRunning)
            return

        if (this.callback) {
            fn := this.callback
            fn()
        } else {
            for lyr in this.layers {
                if (lyr.visible)
                    Draw(lyr)
            }
        }
    }
}
