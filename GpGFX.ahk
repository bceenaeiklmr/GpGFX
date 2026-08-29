; Script     GpGFX.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

/**
 * GpGFX - 2D Vector Graphics, Layer Composition & Rendering for AutoHotkey v2
 *
 * Acknowledgments and community Credits:
 * - iseahound: Graphics, TextRender, and ImagePut foundations (https://github.com/iseahound)
 * - tic: Original GDI+ library for AutoHotkey
 * - Tariq Porter: Gdip2 library architecture (https://github.com/tariqporter/Gdip2)
 * - Marius Șucan: Gdip_DrawRoundedRectangle2, color algorithms, and GDI+ enhancements
 * - AHKv2-Gdip contributors: mmikeww, buliasz, nnnik, AHK-just-me, sswwaagg, Rseding91 (https://github.com/mmikeww/AHKv2-Gdip)
 * - Community contributors: GeekDude, mcl, mikeyww, neogna2, robodesign, SKAN, Helgef
 * - Steve Gray (Lexikos): Creator and maintainer of AutoHotkey v2
 */

; Directives
#Requires AutoHotkey v2
#Warn All ;, OutputDebug

; Preload GDI+ library
#DllLoad Gdiplus.dll

class GpGFX {
    static version := "1.0.0"
    static debug := true
    static DebugLog(msg) => (GpGFX.debug && OutputDebug(msg))
}

class Gdip {

    ; Pointer to GDI+ session token
    static pToken := 0

    /**
     * Auto-initializes GDI+ when GpGFX is loaded.
     */
    static __New() {
        local e
        try {
            SetWinDelay(-1) ; Reduce window messaging delay for layered window updates
            KeyHistory(0)  ; Disable key history for lower interpreter overhead
            ListLines(0)
            ProcessSetPriority("AboveNormal")

            Gdip.Startup()
            OnExit((*) => Gdip.ExitFn())
            OnError((*) => (LayerStack.HideAll(), 0), -1) ; Hide layers and release capture on unhandled error

            GpGFX.DebugLog("[i] GpGFX initialized (Pacing Mode: " . Render.timerMode . ").`n")
        }
        catch as e {
            OutputDebug("[!] Gdip.__New failed: " e.Message "`n" e.Stack "`n")
        }
    }

    /**
     * Cleanly disposes all engine resources on exit.
     */
    static ExitFn() {
        if (Render.timerMode == "Legacy") {
            try DllCall("winmm\timeEndPeriod", "uint", 1)
        }
        MCode.DisposeHiResTimer()
        Fps.Remove()        
        LayerStack.DisposeAll()
        Font.DisposeAll()
        Gdip.Shutdown()
        GpGFX.DebugLog("[i] GpGFX exited cleanly with all resources freed.`n")
    }
    
    /**
     * Starts up Gdiplus and initializes the Gdiplus token.
     * 
     * Deprecated: https://www.autohotkey.com/boards/viewtopic.php?t=72011
     * recommended by Helgef. (AutoHotkey preloads the Gdiplus library)  
     * 
     *	if !DllCall('GetModuleHandle', 'str', 'gdiplus', 'uptr')
     *		if !DllCall('LoadLibrary', 'str', 'gdiplus', 'uptr') ; success > 0 
     *			throw Error('Gdiplus failed to load.')
     */
    static Startup() {
        local gdipStartupInput, pToken := 0

        if (this.pToken)
            return

        gdipStartupInput := Buffer(32, 0)
        NumPut("int", 1, gdipStartupInput, 0) ; GdiplusVersion = 1
        DllCall("gdiplus\GdiplusStartup", "ptr*", &pToken:=0, "ptr", gdipStartupInput, "ptr", 0)
        if (!pToken) {
            throw Error("Gdiplus failed to start.")
        }

        this.pToken := pToken
        GpGFX.DebugLog("[+] Gdiplus has started, token: " this.pToken "`n")
    }

    /**
     * Shuts down Gdiplus.  
     * 
     * The load library part was removed, free library is not needed.
     * @info recommended by Helgef. Link above: https://www.autohotkey.com/boards/viewtopic.php?t=72011
     *   
     *	if hModule := DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
     *		DllCall("FreeLibrary", "ptr", hModule)
     */
    static Shutdown(*) {
        local pToken
        if (!this.pToken)
            return
        pToken := this.pToken
        this.pToken := 0
        DllCall("gdiplus\GdiplusShutdown", "ptr", pToken)
        GpGFX.DebugLog("[-] Gdiplus has shut down, token: " pToken "`n")
    }
}

; 1. Core Graphics & Rendering Pipeline
#include %A_LineFile%\..\core\Graphics.ahk
#include %A_LineFile%\..\core\MCode.ahk
#include %A_LineFile%\..\core\Color.ahk
#include %A_LineFile%\..\core\Palette.ahk
#include %A_LineFile%\..\core\Bitmap.ahk
#include %A_LineFile%\..\core\Font.ahk
#include %A_LineFile%\..\core\TextLayout.ahk
#include %A_LineFile%\..\core\Tool.ahk
#include %A_LineFile%\..\core\Layer.ahk
#include %A_LineFile%\..\core\Shape.ahk
#include %A_LineFile%\..\core\Shapes.ahk
#include %A_LineFile%\..\core\Draw.ahk

; 2. Timing, Telemetry, Concurrency & Utilities
#include %A_LineFile%\..\core\Time.ahk
#include %A_LineFile%\..\core\Fps.ahk
#include %A_LineFile%\..\core\FrameTimer.ahk
#include %A_LineFile%\..\core\IPC.ahk
#include %A_LineFile%\..\core\WorkerPool.ahk
#include %A_LineFile%\..\core\Debug.ahk
#include %A_LineFile%\..\core\Function.ahk
#include %A_LineFile%\..\core\Dialog.ahk