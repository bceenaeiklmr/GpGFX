; Script     Function.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025
; Version    0.7.2

/**
 * Clean all layers.
 * @credit iseahound - Textrender v1.9.3, UpdateLayeredWindow
 * https://github.com/iseahound/TextRender
 */
Clean() {
    local k, v
    for k, v in Layers.OwnProps() {
        if (v.HasOwnProp("hwnd"))
            DllCall("UpdateLayeredWindow"
                ,   "ptr", v.hwnd                  ; hWnd
                ,   "ptr", 0                       ; hdcDst
                ,   "ptr", 0                       ; *pptDst
                ,   "ptr", 0                       ; *psize
                ,   "ptr", 0                       ; hdcSrc
                ,   "ptr", 0                       ; *pptSrc
                ,  "uint", 0                       ; crKey
                , "uint*", 0 << 16 | 0x01 << 24    ; *pblend
                ,  "uint", 2                       ; dwFlags
                ,   "int")                         ; Success = 1
    }
}

Clear() => Clean()

/**
 * Export a layer to a file.
 * @param {obj} lyr layer object
 * @param {str} path output file path
 * @credit iseahound - ImagePut v1.11, select_codec
 * https://github.com/iseahound/ImagePut
 */
SaveLayer(lyr, filepath) {
	
    ; Create a bitmap from the layer.
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", Graphics.%lyr.id%.hbm, "ptr", 0, "ptr*", &pBitmap:=0)

    pCodec := Buffer(16)
    ; Get the CLSID of the PNG codec.
	DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", pCodec, "hresult")
	DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", filepath, "ptr", pCodec, "ptr", 0)
	DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    return
}

/**
 * Takes a screenshot of the screen.
 * @param {str} filepath output file path
 * @param {int} x coordinate
 * @param {int} y coordinate
 * @param {int} w width
 * @param {int} h height
 * @return {ptr} pointer to Bitmap  
 * 
 * @credit iseahound - ImagePut v1.11 ScreenshotToBuffer
 * https://github.com/iseahound/ImagePut
 */
Screenshot(filepath, x := 0, y := 0, w := 0, h := 0) {
    
    (!w) ? w := A_ScreenWidth : 0
	(!h) ? h := A_ScreenHeight : 0

    hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    bi := Buffer(40, 0)          ; sizeof(bi) = 40
    NumPut(  "uint", 40, bi,  0) ; Size
    NumPut(   "int",  w, bi,  4) ; Width
    NumPut(   "int", -h, bi,  8) ; Height - Negative so (0, 0) is top-left
    NumPut("ushort",  1, bi, 12) ; Planes
    NumPut("ushort", 32, bi, 14) ; BitCount / BitsPerPixel
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits:=0, "ptr", 0, "uint", 0, "ptr")
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

	; Retrieve the device context for the screen.
    sdc := DllCall("GetDC", "ptr", 0, "ptr")

    ; Copies a portion of the screen to a new device context.
    DllCall("gdi32\BitBlt"
        , "ptr", hdc, "int", 0, "int", 0, "int", w, "int", h
        , "ptr", sdc, "int", x, "int", y, "uint", 0x00CC0020 | 0x40000000) ; SRCCOPY | CAPTUREBLT

    DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)

    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap := 0)

    ; Cleanup the hBitmap and device contexts.
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC",     "ptr", hdc)

	if IsSet(filepath) {
        pCodec := Buffer(16)
        ; Get the CLSID of the PNG codec.
	    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", pCodec, "hresult")
	    DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", filepath, "ptr", pCodec, "ptr", 0)
		DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
		return
	}
	
	return pBitmap
}

/** Return a random ARGB with 0xFF alpha.
 * @returns {int}
 */
RandomARGB() => Random(0xFF000000, 0xFFFFFFFF)

/** Return a random ARGB with provided alpha.
 * @param {int} alpha
 * @returns {int}
 */
RandomARGBalpha(alpha) => alpha | Random(0x000000, 0xFFFFFF)

/**
 * Deletes the layer and its windows so the script can exit.
 * @param delay Sleep(delay * 1000)
 */
End(delay?) {
    if (IsSet(delay))
        GoodBye(delay)
    Fps.__Delete()
    Font.__Delete()
    Layer.__Delete()
    Exitapp()
}

/**
 * Display a welcome message, an experimental function. Annoying after a while.
 * Currently disabled.
 * @param {float} delay
 */
Welcome(delay := .5) {

    local lyr, rect

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
 * Display a goodbye message, an experimental function. Less annoying than Welcome.  
 * Useful for debugging purposes.
 * @param {float} delay * 1000 ms, timeout
 */
GoodBye(delay := .25) {

    local lyr, rect

    ; can be called only once, to prevent multiple calls
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
    ;loop parse, systext.goodbye {
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
    return
}

/**
 * Check if the value is boolean
 * @param {int} 
 * @return {bool}
 */
IsBool(int) {
    return (Type(int) == "Integer") && (int == 0 || int == 1) ? true : false
}

/**
 * Check if the value is a number.
 * @param {int} 
 * @return {bool}
 */
IsAlphaNum(int) {
    return (Type(int) == "Integer" && int <= 255 && int >= 0) ? true : false
}

/**
 * Validate an ARGB value.
 * @param ARGB 
 */
IsARGB(ARGB) {
    if (Type(ARGB) == "Integer")
        return (ARGB >= 0x00000000 && ARGB <= 0xFFFFFFFF) ? true : false
    else
    if (Type(ARGB) == "String")
        return (RegExMatch(ARGB, "^(0x|#)?[0-9a-fA-F]{6,8}$")) ? true : false
    return false
}

/**
 * Convert an int to ARGB.
 * @param {int} 
 * @return {str}
 * Slightly performs better than Format("{:08X}", int)
 * autohotkey.com/docs/v2/lib/DllCall.htm #4
 */
itoARGB(int) {
    static buf := Buffer(20)
    DllCall("wsprintf", "ptr", buf, "str", "0x%X", "int", int, "Cdecl")
     return StrGet(buf)
}

/**
 * Alias for itoARGB, convert an int to ARGB.
 * @param {int} 
 * @return {str}
 */
intToARGB(int) => itoARGB(int)

/**
 * Position enumerations.
 * @param {int|str} n
 * @return {int} position index
 * TODO: later
 */
PositionByNumber(n) {
    switch n {
        case 1: p := "BottomLeft"
        case 2: p := "BottomCenter"
        case 3: p := "BottomRight"
        case 4: p := "MiddleLeft"
        case 5: p := "MiddleCenter"
        case 6: p := "MiddleRight"
        case 7: p := "TopLeft"
        case 8: p := "TopCenter"
        case 9: p := "TopRight"
    }
}

/**
 * The messages for the welcome and goodbye functions.
 * @return {str} returns a random message
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
                "Ahh yes, we've`n`nbeen expecting you."
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

/**
 * Deprecated function
 * 
 * ; This function is deprecated due to its inefficiency
 *  itoARGB_deprecated(int) {
 *      if (Type(int) == "Integer" || Type(int) == "String") {
 *          ARGB := int & 0xFFFFFFFF
 *          if (ARGB < 0x00000000 && ARGB > 0xFFFFFFFF)  ; not valid ARGB
 *              return 0
 *          Hex := "0x"
 *          i := 7
 *          while (i >= 0) {
 *              Hex .= SubStr("0123456789ABCDEF", ((ARGB >> (i-- * 4)) & 0xF) + 1, 1)
 *          }
 *          return Hex
 *      }
 *  }
 * 
 *  ; Erase a region of a graphics object
 *  EraseRegion(ppvBits, DIB_Width, x, y, w, h) {
 *      bytesPerPixel := 4
 *      bytesPerRow := DIB_Width * bytesPerPixel  ; Total bytes per row in the full DIB *
 *      ; Pointer to top-left of the erase region
 *      startPtr := ppvBits + (y * bytesPerRow) + (x * bytesPerPixel)
 *      ; Loop through the height of the region
 *      loop h { 
 *          ; Zero out just this row
 *          DllCall("RtlZeroMemory", "ptr", startPtr, "uptr", w * bytesPerPixel)  
 *          ; Move to the next row
 *          startPtr += bytesPerRow  
 *      }
 *   }
 */
