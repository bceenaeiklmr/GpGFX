; Script     GpGFX.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025
; Version    0.7.0

/**
 * Wanted to say thank you for everyone who contributes to the AHK community.
 * 
 * @credit iseahound: Graphics, Textrender, ImagePut
 * https://github.com/iseahound thank you for your work.
 * 
 * @credit tic: for creating the Gdip library  (Gdip)
 * @credit for contributing to the library https://github.com/mmikeww/AHKv2-Gdip
 *         mmikeww, buliasz, nnnik, AHK-just-me, sswwaagg, Rseding91,
 *         let me know if I missed someone. Thank you guys.
 * 
 * Special thanks to: GeekDude, mcl, mikeyww, neogna2, robodesign, SKAN, Helgef.
 * 
 * Finally, Lexikos for creating and maintaining AutoHotkey v2.
 */

; Users should include this file (GpGFX.ahk) in their scripts to use GpGFX.
; See the examples for further information.

#Requires AutoHotkey >=2.0.18
#Warn

#include Bitmap.ahk
#include Color.ahk
#include Draw.ahk
#include Font.ahk
#include Fps.ahk
#include Function.ahk
#include Graphics.ahk
#include Layer.ahk
#include Shape.ahk
#include Shapes.ahk
#include Tool.ahk

#DllLoad Gdiplus.dll ; preload the Gdiplus library
if !DllCall("GetModuleHandle", "str", "Gdiplus.dll") {
    ; loading the library manually doesn't makes much sense,
    ; but can be implemented here if needed
    MsgBox("In-built command failed to load Gdiplus.dll.`n" .
        "The program will exit.")
    ExitApp()
}

; Startup
Gdip.Startup()
OnExit(ExitFn)
SetWinDelay(0)
OutputDebug("[i] GpGFX started...`n")


; Global hotkeys:
; Note: Any hotkey will hang the script. (TODO: later)
;       Needs a customized exit routine.
; ^esc::ExitApp


; Release resources on program exit
ExitFn(*) {
    ; A bit overkill, but does the job for now, layer and especially fonts
    ; didn't not get deleted properly.
    GoodBye()
    Fps.__Delete()
    Font.__Delete()
    Layer.__Delete()
    Gdip.ShutDown()
    OutputDebug("[i] GpGFX exiting...`n")
}

/**
 * Gdiplus class handles the initialization and shutdown of Gdiplus.
 */
class Gdip {

    ; Pointer to the Gdiplus token
    static pToken := 0
    
    /**
     * Starts up Gdiplus and initializes the Gdiplus token.
     * 
     * Depracated: https://www.autohotkey.com/boards/viewtopic.php?t=72011
     * recommended by Helgef. (AutoHotkey preloads the Gdiplus library)  
     * 
     *	if !DllCall('GetModuleHandle', 'str', 'gdiplus', 'uptr')
     *		if !DllCall('LoadLibrary', 'str', 'gdiplus', 'uptr') ; success > 0 
     *			throw Error('Gdiplus failed to load.')
     */
    static Startup() {
        GdiplusVersion := 1
        StartupInput := Buffer(32, 0) ; struct
        Numput("int", GdiplusVersion, StartupInput)
        DllCall("Gdiplus\GdiplusStartup", "ptr*", &pToken:=0, "ptr", StartupInput, "ptr", 0)
        if (!this.pToken := pToken) {
            throw Error("Gdiplus failed to start.")
        }
        OutputDebug("[+] Gdiplus has started, token: " this.ptoken "`n")
    }

    /**
     * Shuts down Gdiplus.  
     * 
     * The load library part was removed.
     * @info recommended by Helgef. Link above.
     *   
     *	if hModule := DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
     *		DllCall("FreeLibrary", "ptr", hModule)
     */
    static Shutdown(*) {
        DllCall("gdiplus\GdiplusShutdown", "ptr", this.pToken)
        OutputDebug("[-] Gdiplus has shut down, token: " this.pToken "`n")
    }	
}
