; Script:    Font.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

/**
 * GpGFX Font and Typography Management
 *
 * Provides font creation, caching, measurement, and formatting:
 * - Font(...): Creates or retrieves cached GDI+ font instances with shared brushes and string formats.
 * - Measurement: Fast typographic character and string measurement (MeasureChar, MeasureString).
 * - Custom Fonts: Dynamic loading of private .ttf / .otf files (LoadFromFile) and installed font enumeration (GetInstalledFonts).
 * - Quality Resolution: Smart TextRenderingHint selection based on size, family, and rotation (ResolveQuality).
 */
class Font {

    ; Default rendering quality for string during drawing (3 = AntiAliasGridFit, 4 = AntiAlias, 5 = ClearTypeGridFit)
    static quality := 5

    ; Default properties, can be overridden by the user
    static default := {
        family : "Segoe UI",     ; font family name (installed on the system)
        style : "Regular",       ; see Style flags below
        size : 10,               ; font size
        colour : 0xFFFFFFFF,     ; font colour
        color : 0xFFFFFFFF,      ; font color alias
        quality : 5,             ; rendering quality (5 = ClearTypeGridFit: Windows subpixel ClearType)
        alignmentH : 1,          ; left 0, center 1, right 2
        alignmentV : 1           ; top 0, middle 1, bottom 2
    }

    ; Style flags
    static Style := {
          Regular    : 0,
          Bold       : 1,
          Italic     : 2,
          BoldItalic : 3,
          Underline  : 4,
          Strikeout  : 8 }

    ; StringFormat flags specifies the text layout and formatting options
    static StringFormat := {
        DirectionRightToLeft  : 0x0001,
        DirectionVertical     : 0x0002,
        NoFitBlackBox         : 0x0004,
        DisplayFormatControl  : 0x0020,
        NoFontFallback        : 0x0400,
        MeasureTrailingSpaces : 0x0800,
        NoWrap                : 0x1000,	  
        LineLimit             : 0x2000,
        NoClip                : 0x4000 }

    ; Rendering hint flags
    static RenderingHint := {
        SystemDefault            : 0,
        SingleBitPerPixelGridFit : 1,
        SingleBitPerPixel        : 2,
        AntiAliasGridFit         : 3,
        AntiAlias                : 4,
        ClearTypeGridFit         : 5 }
    
    ; Font cache storage
    static cache := {}
    static stockid := ""

    /**
     * Retrieves the default stock font instance.
     *
     * @returns {Object} Default stock font cache object
     *
     * @example
     * fnt := Font.getStock()
     */
    static getStock() {
        return this.Call()
    }

    /**
     * Enumerates and returns an Array of all installed system font family names.
     *
     * @returns {Array<String>} List of font family names (e.g. ["Arial", "Calibri", "Segoe UI", ...])
     *
     * @example
     * fonts := Font.GetInstalledFonts()
     * for fontName in fonts {
     *     ; Process installed font names
     * }
     */
    static GetInstalledFonts() {
        local pCollection := 0, count := 0, pFamilies, list := [], pFamily, nameBuf
        DllCall("gdiplus\GdipNewInstalledFontCollection", "ptr*", &pCollection:=0)
        if (!pCollection)
            return list

        DllCall("gdiplus\GdipGetFontCollectionFamilyCount", "ptr", pCollection, "int*", &count:=0)
        if (count > 0) {
            pFamilies := Buffer(count * A_PtrSize, 0)
            DllCall("gdiplus\GdipGetFontCollectionFamilyList", "ptr", pCollection, "int", count, "ptr", pFamilies, "int*", &count)

            nameBuf := Buffer(64, 0)
            loop count {
                pFamily := NumGet(pFamilies, (A_Index - 1) * A_PtrSize, "ptr")
                DllCall("gdiplus\GdipGetFamilyName", "ptr", pFamily, "ptr", nameBuf, "ushort", 1033)
                list.Push(StrGet(nameBuf, "utf-16"))
                DllCall("gdiplus\GdipDeleteFontFamily", "ptr", pFamily)
            }
        }
        return list
    }

    /**
     * Loads a custom .ttf or .otf font file from disk into the process private font memory.
     * Accessible by font family name across all shapes and layers without installing to Windows.
     *
     * @param {String} fontPath Path to .ttf or .otf file
     * @returns {Boolean} True on success, false if file does not exist or failed
     *
     * @example
     * ; Load custom font file
     * if (Font.LoadFromFile("assets/fonts/Inter-Bold.ttf")) {
     *     Text("Hello", "0xFFFFFFFF", 12, "Inter", "Bold")
     * }
     */
    static LoadFromFile(fontPath) {
        if (!FileExist(fontPath))
            return false
        ; FR_PRIVATE (0x10) - Available only to this process
        local added := DllCall("gdi32\AddFontResourceExW", "wstr", fontPath, "uint", 0x10, "ptr", 0, "int")
        return (added > 0)
    }

    /**
     * Determines the optimal GDI+ TextRenderingHint based on font size, family, rotation, and style.
     * 
     * @param {Integer|Float} [size=10] Font size in points
     * @param {String} [family="Segoe UI"] Font family name
     * @param {Integer} [style=0] Style flags (Bold, Italic)
     * @param {Boolean} [isRotated=false] Whether the text/shape is rotated
     * @returns {Integer} GDI+ TextRenderingHint (1, 3, 4, or 5)
     *
     * @example
     * ; Small UI text defaults to ClearTypeGridFit (5)
     * hint := Font.ResolveQuality(10, "Segoe UI") ; returns 5
     *
     * ; Large display text (>=28pt) or rotated text defaults to AntiAlias (4)
     * hint := Font.ResolveQuality(36, "Segoe UI") ; returns 4
     */
    static ResolveQuality(size := 10, family := "Segoe UI", style := 0, isRotated := false) {
        ; 1. Rotated text: Grid-fitting distorts rotated vectors, so pure AntiAlias is required
        if (isRotated)
            return 4 ; TextRenderingHintAntiAlias

        ; 2. Large display titles (>= 28pt): Smooth vector curves dominate without needing stem snapping
        if (size >= 28)
            return 4 ; TextRenderingHintAntiAlias

        ; 3. Standard UI / Desktop / Coding fonts (Segoe UI, Consolas, Arial, Tahoma, etc. <= 27pt):
        ;    ClearTypeGridFit (5) provides high contrast and sharp stems
        return 5 ; TextRenderingHintClearTypeGridFit
    }

    /**
     * Creates or retrieves a cached Font instance.
     *
     * @param {String} [family="Segoe UI"] Font family name
     * @param {Number} [size=10] Font size in points
     * @param {String|Integer} [style="Regular"] Font style ("Regular", "Bold", "Italic", "BoldItalic", "Underline", "Strikeout")
     * @param {Integer|String} [colour=0xFFFFFFFF] Text color (named color, hex string, or ARGB integer)
     * @param {Integer|String} [quality] Rendering quality (0=SystemDefault, 3=AntiAliasGridFit, 4=AntiAlias, 5=ClearTypeGridFit)
     * @param {Integer} [alignmentH=1] Horizontal alignment (0=Left/Near, 1=Center, 2=Right/Far)
     * @param {Integer} [alignmentV=1] Vertical alignment (0=Top/Near, 1=Middle/Center, 2=Bottom/Far)
     * @returns {Object} Font object with GDI+ font handles and metrics
     *
     * @example
     * ; 1. Standard UI font
     * fnt := Font("Segoe UI", 11)
     *
     * ; 2. Bold title font with custom color
     * fnt := Font("Arial", 16, "Bold", "0xFF00F0FF")
     *
     * ; 3. Monospaced font with explicit ClearType quality
     * fnt := Font("Consolas", 10, "Regular", "#A9DC76", 5, 0, 0)
     */
    static Call(family?, size?, style?, colour?, quality?, alignmentH?, alignmentV?) {
        
        local id, hFamily := 0, hFont := 0, hFormat := 0, pBrush := 0, status, fntObj

        ; Parameter validation, family
        if (!IsSet(family)) {
            family := Font.default.family
        }
        else if (family ~= "^(\d+|)$") {
            GpGFX.DebugLog("[!] Font family name cannot be a number`n")
            return
        }
        
        ; Size
        if (!IsSet(size)) {
            size := Font.default.size
        }
        else if (size < 1) {
            GpGFX.DebugLog("[!] Font size cannot be less than 1`n")
            return
        }
        
        ; Style
        if (!IsSet(style)) {
            style := Font.default.style
        }
        if (IsInteger(style)) {
            ; already integer style
        }
        else if (Font.Style.HasOwnProp(style)) {
            style := Font.Style.%style%
        }
        else {
            style := 0
        }

        ; Colour
        if (!IsSet(colour)) {
            colour := Font.default.colour
        }
        else {
            colour := Color(colour)
        }
        colour := itoARGB(colour)

        ; Horizontal alignment
        if (!IsSet(alignmentH)) {
            alignmentH := Font.default.alignmentH
        }
        else if (alignmentH < 0 || alignmentH > 2) {
            GpGFX.DebugLog("[!] Invalid horizontal alignment value`n")
            return
        }
        ; Vertical alignment
        if (!IsSet(alignmentV)) {
            alignmentV := Font.default.alignmentV
        }
        else if (alignmentV < 0 || alignmentV > 2) {
            GpGFX.DebugLog("[!] Invalid vertical alignment value`n")
            return
        }

        ; Quality (Smart automatic resolution if not explicitly specified)
        if (!IsSet(quality)) {
            quality := Font.ResolveQuality(size, family, style)
        }
        if (IsInteger(quality)) {
            ; already integer quality
        }
        else if (Font.RenderingHint.HasOwnProp(quality)) {
            quality := Font.RenderingHint.%quality%
        }
        else {
            quality := 5
        }
        
        ; Create a unique id for the font (family | size | style - colour and quality are dynamic render properties)
        id := family "|" size "|" style

        ; Track stock id
        if (Font.stockid == "") {
            Font.stockid := Font.default.family "|" Font.default.size "|" Font.Style.%(Font.default.style)%
        }

        ; Check for cached font
        if (Font.cache.HasOwnProp(id)) {
            Font.cache.%id%.used++
            return Font.cache.%id%
        }	

        if (!Gdip.pToken)
            return {hFont:0, hFamily:0, hFormat:0, family:family, pBrush:0, color:colour, colour:colour
                , id:id, alignmentH:alignmentH, alignmentV:alignmentV
                , style:style, quality:quality, size:size, used:1, chrWidth:Map(), lineHeight:0}

        ; Create the font family using GDI+ functions
        status := DllCall("gdiplus\GdipCreateFontFamilyFromName"
                ,   "ptr", StrPtr(family)  ; font family name
                ,   "int", 0               ; system font collection 0
                ,  "ptr*", &hFamily:=0)

        ; Fallback if the requested font is not installed
        if (status != 0 || !hFamily) {
            GpGFX.DebugLog("[!] Font family '" family "' not found. Falling back to '" Font.default.family "'`n")
            family := Font.default.family
            status := DllCall("gdiplus\GdipCreateFontFamilyFromName"
                    ,   "ptr", StrPtr(family)
                    ,   "int", 0
                    ,  "ptr*", &hFamily:=0)
            
            ; Last resort fallback
            if (status != 0 || !hFamily) {
                family := "Arial"
                DllCall("gdiplus\GdipCreateFontFamilyFromName"
                    ,   "ptr", StrPtr(family)
                    ,   "int", 0
                    ,  "ptr*", &hFamily:=0)
            }
        }

        statusFont := DllCall("gdiplus\GdipCreateFont"
                ,   "ptr", hFamily         ; ptr to font family
                , "float", size            ; font size
                ,   "int", style           ; font style
                ,   "int", 0               ; unit of measure
                ,  "ptr*", &hFont:=0)

        ; Fallback to Regular style (0) if the font doesn't have the requested style variant (e.g. Segoe UI Emoji has no Bold)
        if (statusFont != 0 || !hFont) {
            DllCall("gdiplus\GdipCreateFont"
                ,   "ptr", hFamily
                , "float", size
                ,   "int", 0
                ,   "int", 0
                ,  "ptr*", &hFont:=0)
        }

        DllCall("gdiplus\GdipCreateStringFormat"
                ,   "int", 0               ; formatAttributes (default with automatic WordWrap)
                ,   "int", 0 			   ; language id default
                ,  "ptr*", &hFormat:=0),

        ; Create zero-margin Typographic format for precise character/rich-text layout
        DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "ptr*", &hFormatTypo:=0),

        ; Set string alignments, create the font own brush
        DllCall("gdiplus\GdipSetStringFormatAlign"    , "ptr", hFormat, "int", alignmentH),
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", hFormat, "int", alignmentV),
        DllCall("gdiplus\GdipCreateSolidFill"         , "int", colour, "ptr*", &pBrush:=0)

        GpGFX.DebugLog("[+] Font " id " created`n")
        
        local isMono := (family ~= "i)^(consolas|cascadia|courier|lucida console|monaco|monospace|fixedsys|sf mono|fira code|jetbrains mono|source code pro|inconsolata|dejavu sans mono|ubuntu mono)$")
        local tempObj := { hFont: hFont, hFormatTypo: hFormatTypo, hFormat: hFormat, size: size, color: colour, quality: quality, chrWidth: Map(), lineHeight: 0, isMonospace: false, monoWidth: 0 }
        local wM := Font.MeasureChar(tempObj, "M")
        local monoW := 0

        if (isMono && wM > 0) {
            monoW := wM
        } else {
            ; Dynamic validation: Check if glyphs "M", "i", and "." have identical typographic advance widths
            local wi := Font.MeasureChar(tempObj, "i")
            local wDot := Font.MeasureChar(tempObj, ".")
            if (Abs(wM - wi) < 0.05 && Abs(wM - wDot) < 0.05 && wM > 0) {
                isMono := true
                monoW := wM
            }
        }

        fntObj := {
            hFont : hFont, hFamily : hFamily, hFormat : hFormat, hFormatTypo : hFormatTypo, family : family
            , pBrush : pBrush, color : colour, colour : colour, id : id, alignmentH : alignmentH, alignmentV : alignmentV
            , used : 1, style : style, quality : quality, size : size, chrWidth : Map(), lineHeight : tempObj.lineHeight
            , isMonospace : isMono, monoWidth : monoW, charWidth : monoW
        }

        Font.cache.%id% := fntObj
        return fntObj
    }

    static __measGfx := 0
    static GetMeasureGraphics() {
        if (!Font.__measGfx && Gdip.pToken) {
            local hdc := DllCall("user32\GetDC", "ptr", 0, "ptr")
            local pGfx := 0
            DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &pGfx:=0)
            DllCall("user32\ReleaseDC", "ptr", 0, "ptr", hdc)
            Font.__measGfx := pGfx
        }
        return Font.__measGfx
    }

    /**
     * Measures exact typographic character width with 0 padding margins.
     * Fast-paths constant fixed-pitch character widths in O(1) for monospaced fonts.
     *
     * @param {Object} fntObj Font object returned from Font(...)
     * @param {String} ch Single character or glyph to measure
     * @returns {Float} Measured typographic character width in pixels
     *
     * @example
     * fnt := Font("Segoe UI", 12)
     * w := Font.MeasureChar(fnt, "A")
     */
    static MeasureChar(fntObj, ch) {
        ; 1. Monospace Fast-Path (O(1) zero DllCalls)
        if (fntObj.HasProp("isMonospace") && fntObj.isMonospace && fntObj.monoWidth > 0) {
            if (ch == "`t")
                return fntObj.monoWidth * 4
            return fntObj.monoWidth
        }

        ; 2. Cache Lookup
        if (fntObj.chrWidth.Has(ch))
            return fntObj.chrWidth[ch]

        if (ch == "`t") {
            local spcW := Font.MeasureChar(fntObj, A_Space)
            local tabW := spcW * 4
            fntObj.chrWidth[ch] := tabW
            return tabW
        }

        static RectF := Buffer(16, 0)
        static testRectF := Buffer(16, 0)
        static init := (NumPut("float", 10000, testRectF, 8), NumPut("float", 10000, testRectF, 12))

        local hFmt := (fntObj.HasProp("hFormatTypo") && fntObj.hFormatTypo) ? fntObj.hFormatTypo : fntObj.hFormat
        local gfx := Font.GetMeasureGraphics()

        local oVal := Ord(ch)
        local isEmoji := (oVal >= 0x1F000 || (oVal >= 0x2600 && oVal <= 0x27BF) || (oVal >= 0x2300 && oVal <= 0x23FF))
        local hFnt := (isEmoji) ? Font("Segoe UI Emoji", fntObj.size, 0, fntObj.color, fntObj.quality).hFont : fntObj.hFont

        DllCall("gdiplus\GdipMeasureString"
            ,   "ptr", gfx
            ,   "wstr", ch
            ,   "int", -1
            ,   "ptr", hFnt
            ,   "ptr", testRectF
            ,   "ptr", hFmt
            ,   "ptr", RectF
            , "uint*", 0
            , "uint*", 0)

        local cw := NumGet(RectF, 8, "float")
        if (!fntObj.lineHeight)
            fntObj.lineHeight := NumGet(RectF, 12, "float")

        if (cw <= 0)
            cw := (ch == A_Space) ? (fntObj.size * 0.3) : (fntObj.size * 0.55)

        fntObj.chrWidth[ch] := cw
        return cw
    }

    /**
     * Measures the rendered width of a string using GDI+.
     * Instant O(1) computation for monospaced fonts.
     *
     * @param {Object} fntObj Font object returned from Font(...)
     * @param {String} text Text string to measure
     * @returns {Float} Measured width in pixels
     *
     * @example
     * fnt := Font("Segoe UI", 12)
     * textWidth := Font.MeasureString(fnt, "Hello World")
     */
    static MeasureString(fntObj, text) {
        if (fntObj.HasProp("isMonospace") && fntObj.isMonospace && fntObj.monoWidth > 0)
            return StrLen(text) * fntObj.monoWidth

        static RectF := Buffer(16, 0)
        static testRectF := Buffer(16, 0)
        static init := (NumPut("float", 100000, testRectF, 8), NumPut("float", 100000, testRectF, 12))

        local hFmt := (fntObj.HasProp("hFormatTypo") && fntObj.hFormatTypo) ? fntObj.hFormatTypo : fntObj.hFormat
        local gfx := Font.GetMeasureGraphics()

        DllCall("gdiplus\GdipMeasureString"
            ,   "ptr", gfx
            ,   "wstr", text
            ,   "int", -1
            ,   "ptr", fntObj.hFont
            ,   "ptr", testRectF
            ,   "ptr", hFmt
            ,   "ptr", RectF
            , "uint*", 0
            , "uint*", 0)

        return NumGet(RectF, 8, "float")
    }

    /**
     * Decrements reference count and deletes the font resources if unused.
     *
     * @param {String|Object} fontOrId Font object or font ID string
     * @returns {void}
     *
     * @example
     * Font.Release(myFont)
     */
    static Release(fontOrId) {
        if (!fontOrId)
            return

        local id := IsObject(fontOrId) ? (fontOrId.HasProp("id") ? fontOrId.id : "") : String(fontOrId)
        if (id == "" || !Font.cache.HasOwnProp(id))
            return

        local fnt := Font.cache.%id%
        fnt.used -= 1

        if (fnt.used <= 0) {
            Font.DestroyFont(fnt),
            Font.cache.DeleteProp(id)
            GpGFX.DebugLog("[-] Font " id " deleted`n")
        }

        if (ObjOwnPropCount(Font.cache) == 0)
            GpGFX.DebugLog("[i] All fonts successfully deleted`n")
    }

    /**
     * Backward-compatible alias for Release.
     *
     * @param {String|Object} id Font object or font ID string
     * @returns {void}
     */
    static Unregister(id) {
        this.Release(id)
    }

    /**
     * Helper to destroy GDI+ font handles with double-free protection.
     *
     * @param {Object} fnt Font cache object
     * @returns {void}
     */
    static DestroyFont(fnt) {
        if (!IsObject(fnt))
            return
        if (Gdip.pToken) {
            if (fnt.HasProp("hFormat") && fnt.hFormat) {
                DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fnt.hFormat)
                fnt.hFormat := 0
            }
            if (fnt.HasProp("hFormatTypo") && fnt.hFormatTypo) {
                DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fnt.hFormatTypo)
                fnt.hFormatTypo := 0
            }
            if (fnt.HasProp("hFont") && fnt.hFont) {
                DllCall("gdiplus\GdipDeleteFont", "ptr", fnt.hFont)
                fnt.hFont := 0
            }
            if (fnt.HasProp("hFamily") && fnt.hFamily) {
                DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fnt.hFamily)
                fnt.hFamily := 0
            }
            if (fnt.HasProp("pBrush") && fnt.pBrush) {
                DllCall("gdiplus\GdipDeleteBrush", "ptr", fnt.pBrush)
                fnt.pBrush := 0
            }
        } else {
            fnt.hFormat := 0
            fnt.hFont := 0
            fnt.hFamily := 0
            fnt.pBrush := 0
        }
    }

    /**
     * Disposes all remaining cached fonts before Gdiplus shutdown.
     *
     * @returns {void}
     */
    static DisposeAll() {
        local id, fnt
        GpGFX.DebugLog("[i] Font: Disposing all cached fonts...`n")
        if (Font.__measGfx) {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", Font.__measGfx)
            Font.__measGfx := 0
        }
        for id, fnt in Font.cache.Clone().OwnProps() {
            GpGFX.DebugLog("[i] Disposing font " id "`n")
            Font.DestroyFont(fnt)
            Font.cache.DeleteProp(id)
        }
        GpGFX.DebugLog("[i] All fonts successfully deleted`n")
    }
}