; Script:    Function.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2

/**
 * GpGFX Global Helper and Utility Functions
 *
 * Core utilities:
 * - Screen & Window: Capture desktop / window screenshots (Screenshot), enumerate multi-monitor geometry (GetMonitorInfo), query true visible window bounds (WinGetVisiblePos).
 * - Layer Helpers: Clear all active layered windows (Clean / Clear), export layers to disk (SaveLayer).
 * - Color & Value Validation: Format ARGB hex strings (itoARGB), validate color ranges and types (IsARGB, IsAlphaValue, IsBool).
 * - Dialogs & Lifecycle: Always-on-top debug modals (TopMsg, Alert), application lifecycle helpers (End, Welcome, GoodBye).
 */

/**
 * Erases and clears all currently registered layered windows from the display.
 *
 * @returns {void}
 *
 * @example
 * Clean() ; Clears all active layers
 */
Clean() {
    local lyr, i, ptr
    for i, ptr in LayerStack.pointers {
        lyr := ObjFromPtrAddRef(ptr)
        DllCall("UpdateLayeredWindow"
            ,   "ptr", lyr.hwnd                ; hWnd
            ,   "ptr", 0                       ; hdcDst
            ,   "ptr", 0                       ; *pptDst
            ,   "ptr", 0                       ; *psize
            ,   "ptr", 0                       ; hdcSrc
            ,   "ptr", 0                       ; *pptSrc
            ,  "uint", 0                       ; crKey
            , "uint*", 0 << 16 | 0x01 << 24    ; *pblend
            ,  "uint", 2                       ; dwFlags
            ,   "int")                         ; Success = 1
        lyr := ""
    }
}

; Alias for Clean
Clear() => Clean()

/**
 * Exports a layer's rendered surface to an image file on disk.
 *
 * @param {Layer|Object} lyr Layer instance to export
 * @param {String} filepath Output file path (e.g. "screenshot.png")
 * @param {Boolean} [cropToContent=true] When true, crops image to the bounding box of visible shapes
 * @returns {Boolean} True on success, false otherwise
 *
 * @example
 * SaveLayer(myLayer, "output.png")
 */
SaveLayer(lyr, filepath, cropToContent := true) {
    if (IsObject(lyr) && lyr.HasMethod("toFile"))
        return lyr.toFile(filepath, cropToContent)
    return false
}

/**
 * Takes a screenshot of the primary screen or a specific rectangular bounding region.
 *
 * @param {String} [filepath] Optional output file path (e.g. "screen.png"). If omitted, returns a GDI+ bitmap pointer
 * @param {Integer} [x=0] Left screen coordinate
 * @param {Integer} [y=0] Top screen coordinate
 * @param {Integer} [w=0] Capture width in pixels (0 for full screen width)
 * @param {Integer} [h=0] Capture height in pixels (0 for full screen height)
 * @returns {Integer|void} GDI+ bitmap pointer if filepath is omitted, void if saved to file
 *
 * @example
 * ; 1. Capture full screen to file
 * Screenshot("desktop.png")
 *
 * ; 2. Capture a 400x300 region at (100, 100)
 * Screenshot("region.png", 100, 100, 400, 300)
 *
 * ; 3. Get in-memory GDI+ bitmap pointer
 * pBmp := Screenshot(, 0, 0, 800, 600)
 */
Screenshot(filepath?, x := 0, y := 0, w := 0, h := 0) {
    local hdc, bi, hbm, obm, sdc, pBitmap, pBits, pCodec
    
    if (!w)
        w := A_ScreenWidth
    if (!h)
        h := A_ScreenHeight

    hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    bi := Buffer(40, 0)
    NumPut(  "uint", 40, bi,  0) ; Size
    NumPut(   "int",  w, bi,  4) ; Width
    NumPut(   "int", -h, bi,  8) ; Height - Negative so (0, 0) is top-left
    NumPut("ushort",  1, bi, 12) ; Planes
    NumPut("ushort", 32, bi, 14) ; BitCount / BitsPerPixel
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits:=0, "ptr", 0, "uint", 0, "ptr")
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

    ; Retrieve device context for the screen
    sdc := DllCall("GetDC", "ptr", 0, "ptr")

    ; Copy screen portion to memory DC
    DllCall("gdi32\BitBlt"
        , "ptr", hdc, "int", 0, "int", 0, "int", w, "int", h
        , "ptr", sdc, "int", x, "int", y, "uint", 0x00CC0020 | 0x40000000) ; SRCCOPY | CAPTUREBLT

    DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)

    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap := 0)

    ; Cleanup GDI objects
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC",     "ptr", hdc)

    if IsSet(filepath) {
        pCodec := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", pCodec, "hresult")
        DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", filepath, "ptr", pCodec, "ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
        return
    }
    
    return pBitmap
}

/**
 * Retrieves comprehensive geometry and work area information for all connected monitors.
 *
 * @returns {Array<Object>} List of monitor objects [{ index, name, x, y, w, h, wx, wy, ww, wh, isPrimary }, ...]
 *
 * @example
 * monitors := GetMonitorInfo()
 * for mon in monitors {
 *     ; mon.x, mon.y, mon.w, mon.h, mon.isPrimary
 * }
 */
GetMonitorInfo() {
    local primaryIdx := MonitorGetPrimary()
    local list := []
    local i, l, t, r, b, wl, wt, wr, wb, monName

    loop MonitorGetCount() {
        i := A_Index
        l := 0, t := 0, r := 0, b := 0
        wl := 0, wt := 0, wr := 0, wb := 0
        MonitorGet(i, &l, &t, &r, &b)
        MonitorGetWorkArea(i, &wl, &wt, &wr, &wb)
        monName := ""
        try monName := MonitorGetName(i)

        list.Push({
            index: i,
            name: monName,
            isPrimary: (i == primaryIdx),
            x: l,
            y: t,
            w: r - l,
            h: b - t,
            wx: wl,
            wy: wt,
            ww: wr - wl,
            wh: wb - wt
        })
    }
    return list
}

/**
 * Queries the true visible bounding box of a window (excluding invisible Windows drop shadow padding).
 *
 * @param {Integer|String} hwnd Target window handle (HWND) or window title
 * @param {VarRef} [outX] Output variable for visible X coordinate
 * @param {VarRef} [outY] Output variable for visible Y coordinate
 * @param {VarRef} [outW] Output variable for visible Width
 * @param {VarRef} [outH] Output variable for visible Height
 * @returns {Object} { x, y, w, h, x1, y1, x2, y2 }
 *
 * @credit GeekDude & Marius Șucan
 *
 * @example
 * bounds := WinGetVisiblePos("ahk_exe notepad.exe")
 * ; bounds.x, bounds.y, bounds.w, bounds.h
 */
WinGetVisiblePos(hwnd, &outX?, &outY?, &outW?, &outH?) {
    local hr, x1, y1, x2, y2, w, h

    if (!IsInteger(hwnd))
        hwnd := WinExist(hwnd)
    if (!hwnd)
        return { x: 0, y: 0, w: 0, h: 0, x1: 0, y1: 0, x2: 0, y2: 0 }

    static DWMWA_EXTENDED_FRAME_BOUNDS := 9
    static rect := Buffer(16, 0)
    
    ; 1. Try DWM True Visible Frame Bounds (Windows 10/11)
    hr := DllCall("dwmapi\DwmGetWindowAttribute", 
            "ptr",  hwnd, 
            "uint", DWMWA_EXTENDED_FRAME_BOUNDS, 
            "ptr",  rect, 
            "uint", 16, 
            "int")

    ; 2. Fallback to standard GetWindowRect if DWM fails
    if (hr != 0)
        DllCall("GetWindowRect", "ptr", hwnd, "ptr", rect)

    x1 := NumGet(rect, 0,  "int")
    y1 := NumGet(rect, 4,  "int")
    x2 := NumGet(rect, 8,  "int")
    y2 := NumGet(rect, 12, "int")
    w  := Max(0, x2 - x1)
    h  := Max(0, y2 - y1)

    if IsSet(outX)
        outX := x1
    if IsSet(outY)
        outY := y1
    if IsSet(outW)
        outW := w
    if IsSet(outH)
        outH := h

    return {x: x1, y: y1, w: w, h: h, x1: x1, y1: y1, x2: x2, y2: y2}
}

; Alias for WinGetVisiblePos
GetWindowVisibleRect(args*) => WinGetVisiblePos(args*)

/**
 * Converts a 32-bit ARGB integer into a formatted hexadecimal string ("0xAARRGGBB" or "0xRRGGBB").
 *
 * @param {Integer} int ARGB color integer
 * @param {Boolean} [rgb=false] If true, formats as 24-bit 0xRRGGBB
 * @returns {String} Formatted hex string
 *
 * @example
 * hexStr := itoARGB(0xFFFF0000) ; "0xFFFF0000"
 */
itoARGB(int, rgb := false) {
    static buf := Buffer(20, 0)
    DllCall("wsprintf", "ptr", buf, "str", (rgb) ? "0x%06X" : "0x%08X", "int", (rgb) ? int &= 0xFFFFFF : int, "Cdecl")
    return StrGet(buf)
}

; Alias for itoARGB
intToARGB(int, rgb := false) => itoARGB(int, rgb)

/**
 * Checks if a value is a boolean (0 or 1 integer).
 *
 * @param {Any} val Value to check
 * @returns {Boolean}
 */
IsBool(val) => (val is Integer) && (val == 0 || val == 1)

/**
 * Checks if an integer is a valid 8-bit alpha value (0 to 255).
 *
 * @param {Any} val Value to check
 * @returns {Boolean}
 */
IsAlphaValue(val) => (val is Integer && val <= 0xFF && val >= 0x0)

/**
 * Validates whether an input represents a valid 32-bit ARGB color (integer or hex string).
 *
 * @param {Any} ARGB Value to validate
 * @returns {Boolean}
 *
 * @example
 * IsARGB("0xFF00FF00") ; true
 * IsARGB("#78DCE8")   ; true
 */
IsARGB(ARGB) {
    if (ARGB is String)
        return (RegExMatch(ARGB, "^(0x|#)?[0-9a-fA-F]{6,8}$") > 0)
    else if (ARGB is Integer)
        return (ARGB >= 0x00000000 && ARGB <= 0xFFFFFFFF)
    return false
}

/**
 * Resolves a numeric numpad direction (1-9) to a named position string.
 *
 * @param {Integer} n Numpad position (1=bottomleft, 2=bottomcenter, 3=bottomright, 7=topleft, 8=topcenter, 9=topright)
 * @returns {String} Named position string (e.g. "topcenter")
 */
PositionByNumber(n) {
    switch n {
        case 7: return "topleft"
        case 8: return "topcenter"
        case 9: return "topright"
        case 4: return "middleleft"
        case 5: return "middlecenter"
        case 6: return "middleright"
        case 1: return "bottomleft"
        case 2: return "bottomcenter"
        case 3: return "bottomright"
        default: return "topcenter"
    }
}

/**
 * Displays an always-on-top system modal message box for debugging.
 *
 * @param {String} [text=""] Message text
 * @param {String} [title="GpGFX Debug"] Message box title
 * @param {Integer} [options=4096] MsgBox options (default 4096 = MB_SYSTEMMODAL)
 * @returns {String} Result string from MsgBox
 *
 * @example
 * TopMsg("Value: " myVar)
 */
TopMsg(text := "", title := "GpGFX Debug", options := 4096) {
    DllCall("user32\ReleaseCapture")
    return (MsgBox)(text, title, options)
}

/**
 * Displays an always-on-top task modal alert box.
 *
 * @param {String} [text=""] Alert message text
 * @param {String} [title="GpGFX Alert"] Alert box title
 * @param {Integer} [options=262144] MsgBox options (default 262144 = MB_TASKMODAL)
 * @returns {String} Result string from MsgBox
 *
 * @example
 * Alert("Operation completed successfully!")
 */
Alert(text := "", title := "GpGFX Alert", options := 262144) {
    DllCall("user32\ReleaseCapture")
    return (MsgBox)(text, title, options)
}

/**
 * Offsets a shape's horizontal X coordinate.
 *
 * @param {Shape} shapeObj Target shape instance
 * @param {Number} [x=0] Offset delta to add to X
 * @returns {void}
 */
ModifyX(shapeObj, x := 0) {
    shapeObj.x += x
    GpGFX.DebugLog("[!] Signal executed: " shapeObj.name ".x is now " shapeObj.x "`n")
}

/**
 * Gracefully terminates the script with an optional animated goodbye card.
 *
 * @param {Float} [delay] Optional delay in seconds before closing
 * @returns {void}
 *
 * @example
 * End()     ; Exits immediately
 * End(0.5)  ; Displays goodbye animation for 0.5s then exits
 */
End(delay?) {
    if (IsSet(delay))
        GoodBye(delay)
    ExitApp()
}

/**
 * Displays an animated typewriter welcome card.
 *
 * @param {Float} [delay=0.5] Delay in seconds before continuing
 * @returns {void}
 *
 * @example
 * Welcome()
 */
Welcome(delay := .5) {
    local lyr, rect, rectbot

    lyr := Layer(360, 250)
    rect := Rectangle(0, 0, 360, 240, "0x80000000")
    rectbot := Rectangle(0, 240, 360, 10)
    rectbot.Color := [Color.Random("Red|Yellow|Violet|Blue|Lime")
                    , Color.Random("Red|Yellow|Violet|Blue|Lime")]
    rect.Text("", "white", 24)

    Clean()
    loop parse, systext.welcome {
        rect.str .= A_LoopField
        if (A_LoopField !== "`n")
            Sleep(20)
        Draw(lyr)
    }

    Sleep(200)
    Draw(lyr)
    Sleep(delay * 1000)
}

/**
 * Displays an animated goodbye card on script termination.
 *
 * @param {Float} [delay=0.25] Delay in seconds before exiting
 * @returns {void}
 */
GoodBye(delay := .25) {
    local lyr, rect, rectbot
    static called := false
    if (called)
        return

    lyr := Layer(360, 260)
    rect := Rectangle(0, 0, 360, 240, "0x80000000")
    rectbot := Rectangle(0, 240, 360, 10)
    rectbot.Color := [Color.Random("Red|Yellow|Violet|Blue|Lime")
                    , Color.Random("Red|Yellow|Violet|Blue|Lime")]
    rect.Text(, "white", 24)

    Clean()
    loop parse, "exiting..." {
        rect.str .= A_LoopField
        if (A_LoopField !== "`n")
            Sleep(10)
        Draw(lyr)
    }

    Sleep(200)
    Draw(lyr)
    Sleep(delay * 1000)
    called := true
}

/**
 * Random message generator for welcome and goodbye animations.
 */
class systext {

    static welcome {
        get {
            local arr := [
                "Hello, Universe!",
                "Greetings, Earthling!",
                "Stay a while and listen.",
                "Ah, a fresh soul to corrupt!",   
                "Welcome, traveler!",             
                "Well met!",                      
                "Greetings, Champion!",           
                "Ahh yes, we've`n`nbeen expecting you.",
                "It's showtime!",                 
                "Welcome... " A_Year "..." ]      
            return arr[Random(1, arr.Length)]
        }
    }

    static goodbye {
        get {
            local arr := [
                "Tschüss!",
                "Goodbye!",
                "Au revoir!",
                "Arrivederci!",
                "Auf Wiedersehen!",
                "Farewell, my friend!",
                "Until we meet again.",
                "Lok’tar ogar!" ,
                "May the Force be with you." ]
            return arr[Random(1, arr.Length)]
        }
    }
}