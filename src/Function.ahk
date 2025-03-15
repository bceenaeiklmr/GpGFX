; Script     Function.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025
; Version    0.7.0

/** Returnsn a ARGB with 0xFF alpha.
 * @returns {int}
 */
RandomARGB() => Random(0xFF000000, 0xFFFFFFFF)

/** Returns a ARGB with a provided alpha
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
 * @return {void}
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
 * @return {void}
 */
GoodBye(delay := .5) {

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
    loop parse, systext.goodbye {
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
 * Clean all layers
 * @return {void}
 * credit: iseahound
 */
Clean() {
    for k, v in Layers.OwnProps() {
        if (v.HasOwnProp("hwnd"))
            DllCall("UpdateLayeredWindow"
                , "ptr", v.hwnd                 ; hWnd
                , "ptr", 0                      ; hdcDst
                , "ptr", 0                      ; *pptDst
                , "ptr", 0                      ; *psize
                , "ptr", 0                      ; hdcSrc
                , "ptr", 0                      ; *pptSrc
                , "uint", 0                     ; crKey
                , "uint*", 0 << 16 | 0x01 << 24 ; *pblend
                , "uint", 2                     ; dwFlags
                , "int")                        ; Success = 1
    }
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
 * Check if the value is a number
 * @param {int} 
 * @return {bool}
 */
IsAlphaNum(int) {
    return (Type(int) == "Integer" && int <= 255 && int >= 0) ? true : false
}

/**
 * Validate an ARGB value
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
 * Convert an int to ARGB
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
 * Alias for itoARGB, convert an int to ARGB
 * @param {int} 
 * @return {str}
 */
intToARGB(int) => itoARGB(int)

/**
 * Position enumerations
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
