; Script     Font.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025
; Version    0.7.2

/**
 * The Font class provides functionality for working with fonts in Gdiplus.  
 * A default stock font is created when the class is first accessed.  
 * Shapes can share the same font instance, which is cached and reused.
 */
class Font {

    ; Default rendering quality for string during drawing
    static quality := 0

    ; Default properties, can be overridden by the user
    static default := {
        family : "Tahoma",       ; font family name (installed on the system)
        style : "Regular",       ; see Style flags below
        size : 10,               ; font size
        colour : 0xFFFFFFFF,     ; font colour
        quality : 0,             ; rendering quality
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
    ; TODO: implement later, currently just information (also rendering hint)
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
        AntiAlias                : 4 }
    
    ; Make style and rendering flags accessible by value
    static __New() {
        local key, value
        for key, value in this.Style.OwnProps() {
            this.Style.%value% := key
        }
        for key, value in this.StringFormat.OwnProps() {
            this.StringFormat.%value% := key
        }
    }

    /**
     * Retrieves the default stock font instance, every shape uses this font by default.
     * @returns {Font} stock font instance
     */
    static getStock() {
        if (!this.HasOwnProp("stock")) {
            this.stock := Font()
        }
        else {
            this.stock.used++
        }
        return this.stock
    }

     /**
     * Creates a new Font instance.
     * @param {str} family font family name
     * @param {int} size font size
     * @param {str} style font style
     * @param {int|str} colour accepts a color name or (A)RGB
     * @param {int} quality rendering quality
     * @param {int} alignmentH horizontal alignment
     * @param {int} alignmentV vertical alignment
     */
    static Call(family?, size?, style?, colour?, alignmentH?, alignmentV?) {
        
        ; Paramater validation, family
        if (!IsSet(family)) {
            family := Font.default.family
        }
        else if (family ~= "^(\d+|)$") {
            OutputDebug("[!] Font family name cannot be a number`n")
            return
        }
        
        ; Size
        if (!IsSet(size)) {
            size := Font.default.size
        }
        else if (size < 1) {
            OutputDebug("[!] Font size cannot be less than 1`n")
            return
        }
        
        ; Style
        if (!IsSet(style)) {
            style := Font.default.style
        }
        else if (!Font.Style.HasOwnProp(style)) {
            OutputDebug("[!] Invalid Font style id by number`n")
            return
        }
        style := Font.Style.%style%

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
            OutputDebug("[!] Invalid horizontal alignment value`n")
            return
        }
        ; Vertical alignment
        if (!IsSet(alignmentV)) {
            alignmentV := Font.default.alignmentV
        }
        else if (alignmentV < 0 || alignmentV > 2) {
            OutputDebug("[!] Invalid vertical alignment value`n")
            return
        }
        
        ; Create a unique id for the font
        id := family "|" size "|" style "|" colour

        ; Set default font stock id
        if (!Font.stockid) {
            Font.stockid := id
        }

        ; Check for cached font
        if (Font.cache.HasOwnProp((id := family "|" size "|" style "|" colour))) {
            Font.cache.%id%.used++
            return Font.cache.%id%
        }	

        ; Create the font using GDI+ functions, code based on:
        ; credit: iseahound - TextRender v1.9.3, DrawOnGraphics
        ; https://github.com/iseahound/TextRender
        DllCall("gdiplus\GdipCreateFontFamilyFromName"
                ,   "ptr", StrPtr(family)  ; font family name
                ,   "int", 0               ; system font collection 0
                ,  "ptr*", &hFamily:=0)    ; ptr to font family

        DllCall("gdiplus\GdipCreateFont"
                ,   "ptr", hFamily         ; ptr to font family
                , "float", size            ; font size
                ,   "int", style           ; font style
                ,   "int", 0               ; unit of measure
                ,  "ptr*", &hFont:=0)      ; ptr to font

        DllCall("gdiplus\GdipCreateStringFormat"
                ,   "int", 0x1000 | 0x4000 ; formatAttributes (NoWrap, NoClip)
                ,   "int", 0 			   ; language id default
                ,  "ptr*", &hFormat:=0)    ; ptr to string format

        ; Set string alignments, create the font own brush
        DllCall("gdiplus\GdipSetStringFormatAlign"    , "ptr", hFormat, "int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", hFormat, "int", 1)
        DllCall("gdiplus\GdipCreateSolidFill"         , "int", colour, "ptr*", &pBrush:=0)

        OutputDebug("[+] Font " id " created`n")
        
        return Font.cache.%id% := {hFont:hFont, hFamily:hFamily, hFormat:hFormat
            , pBrush:pBrush, id:id, alignmentH:alignmentH, alignmentV:alignmentV
            , used:1, style : style, quality : Font.quality}
    }

    ; User should not touch these two
    static cache := {}
    static stockid := 0

    /**
     * Removes access to a give font instance. This happens when the font is no longer needed.
     * The fonts used by shapes.
     * @param id 
     */
    static RemoveAccess(id) {

        ; Deleted already
        if !Font.cache.HasOwnProp(id)
            return

        ; Decrement access count
        if (!Font.dispose && (Font.cache.%id%.used -= 1 > 0))
            return

        ; Delete font resources
        fnt := Font.cache.%id%
        DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fnt.hFormat)
        DllCall("gdiplus\GdipDeleteFont", "ptr", fnt.hFont)
        DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fnt.hFamily)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", fnt.pBrush)

        ; Remove property
        Font.cache.DeleteProp(id)

        OutputDebug("[-] Font " id " deleted`n")
        if (ObjOwnPropCount(Font.cache) == 0)
            OutputDebug("[i] All fonts successfully deleted`n")
        return
    }

    static dispose := false

    /**
     * Deletes the font instance and its associated resources.
     */
    static __Delete() {
        ; Dispose will override used count during deletion
        this.dispose := true
        OutputDebug("[i] Deleting all fonts...`n")
        for id, f in Font.cache.OwnProps() {
            this.RemoveAccess(id)
        }
    }
}
