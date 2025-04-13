; Script     Tool.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       13.04.2025
; Version    0.7.3

/**
 * The `Pen` class represents a drawing pen used to draw lines and shapes.  
 * @property {ARGB} color - Gets or sets the color of the pen.
 * @property {int} width - Gets or sets the width of the pen.
 */
class Pen {

    /**
     * @property Color Gets or sets the color of the pen.
     */
    Color {
        get {
            local value
            return (DllCall("gdiplus\GdipGetPenColor", "ptr", this.ptr, "int*", &value:=0), value)
        }
        set =>  DllCall("gdiplus\GdipSetPenColor", "ptr", this.ptr, "int", value)
    }

    /**
     * @property Width Gets or sets the width of the pen.
     */
    Width {
        get {
            local value
            return (DllCall("gdiplus\GdipGetPenWidth", "ptr", this.ptr, "float*", &value:=0), value)
        }
        set =>  DllCall("gdiplus\GdipSetPenWidth", "ptr", this.ptr, "float", value)
    }

    /**
     * Creates a new Pen object with the specified color and width.
     * @param {int} ARGB an ARGB color value 
     * @param {int} penwidth the size of the pen
     */
    __New(ARGB, penwidth := 1) {
        DllCall("gdiplus\GdipCreatePen1", "int", ARGB, "float", penwidth, "int", 2, "ptr*", &pPen:=0) 
        this.ptr := pPen
        this.type := 5
        OutputDebug("[+] Pen created " pPen "`n")
    }
    
    /**
     * Deletes the Pen object.
     */
    __Delete() {
        DllCall("gdiplus\GdipDeletePen", "ptr", this.ptr)
        OutputDebug("[-] Pen ptr " this.ptr " deleted`n")
    }
}

class Brush {

    ; To fix the may not have property error.
    ptr := 0

    /**
     * Clones the brush object.
     */
    Clone() {
        DllCall("gdiplus\GdipCloneBrush", "ptr", this.ptr, "ptr*", &pBrush:=0)
        return pBrush
    }

    /**
     * Gets the type of the brush.  
     * 0 SolidBrush  
     * 1 HatchBrush  
     * 2 TextureBrush  
     * 3 PathGradient  
     * 4 LinearGradient  
     * -1 Error  
     */
    Validate() {
        if DllCall("gdiplus\GdipGetBrushType", "ptr", this.ptr, "int*", &result:=0)
            return -1
        else result
    }

    /**
     * Deletes the brush object.
     */
    __Delete() { 
        DllCall("gdiplus\GdipDeleteBrush", "ptr", this.ptr)
        OutputDebug("[-] " this.base.__Class " ptr " this.ptr " deleted`n")
    }

}

class SolidBrush extends Brush {

    /**
     * @property color gets or sets the color of the SolidBrush
     */
    color {
        get {
            local value
            return (DllCall("gdiplus\GdipGetSolidFillColor", "ptr", this.ptr, "int*", &value:=0), value)
        }
        set =>  DllCall("gdiplus\GdipSetSolidFillColor", "ptr", this.ptr, "int", value)
    }

    /**
     * Creates a new SolidBrush object with the specified color.
     * @param {ARGB} ARGB 
     */
    __New(ARGB) {
        DllCall("gdiplus\GdipCreateSolidFill", "int", ARGB, "ptr*", &pBrush:=0)
        this.ptr := pBrush
        this.type := 0
        OutputDebug("[+] SolidBrush created " pBrush "`n")
    }
}

class HatchBrush extends Brush {

    /**
     * Creates a new HatchBrush object with the specified ARGB and hatchstyle.
     * @param foreARGB foreground ARGB
     * @param backARGB background ARGB
     * @param hatchStyle hatch style name or index
     */
    __New(foreARGB, backARGB, hatchStyle) {
        if (hatchStyle > 53 || hatchStyle < 0)
            hatchStyle := this.getStyle(hatchStyle)
        DllCall("gdiplus\GdipCreateHatchBrush"
            ,  "int", hatchStyle      ; hatchStyle
            ,  "int", foreARGB        ; foreground ARGB
            ,  "int", backARGB        ; background ARGB
            , "ptr*", &pBrush:=0)     ; ptr to hatch brush
        this.ptr := pBrush
        this.type := 1
        OutputDebug("[+] HatchBrush created " pBrush "`n")
    }

    ; Verify hatch style input.
    getStyle(value) {
        if (Type(value) == "String" && HatchBrush.styleName.HasProp(value))
            return HatchBrush.styleName.%value%
        throw ValueError("Invalid Hatch style")
    }

    ; Names in array.
    static style :=
        [ "HatchStyleHorizontal"   , "Vertical"             , "ForwardDiagonal"      ; 0-3
        , "BackwardDiagonal"       , "Cross"                , "DiagonalCross"        ; 4-5
        , "05Percent"              , "10Percent"            , "20Percent"            ; 6-8
        , "25Percent"              , "30Percent"            , "40Percent"            ; 9-11
        , "50Percent"              , "60Percent"            , "70Percent"            ; 12-14
        , "75Percent"              , "80Percent"            , "90Percent"            ; 15-17
        , "LightDownwardDiagonal"  , "LightUpwardDiagonal"  , "DarkDownwardDiagonal" ; 18-20
        , "DarkUpwardDiagonal"     , "WideDownwardDiagonal" , "WideUpwardDiagonal"   ; 21-23
        , "LightVertical"          , "LightHorizontal"      , "NarrowVertical"       ; 24-26
        , "NarrowHorizontal"       , "DarkVertical"         , "DarkHorizontal"       ; 27-29
        , "DashedDownwardDiagonal" , "DashedUpwardDiagonal" , "DashedHorizontal"     ; 30-32
        , "DashedVertical"         , "SmallConfetti"        , "LargeConfetti"        ; 33-35
        , "ZigZag"                 , "Wave"                 , "DiagonalBrick"        ; 36-38
        , "HorizontalBrick"        , "Weave"                , "Plaid"                ; 39-41
        , "Divot"                  , "DottedGrid"           , "DottedDiamond"        ; 42-44
        , "Shingle"                , "Trellis"              , "Sphere"               ; 45-47
        , "SmallGrid"              , "SmallCheckerBoard"    , "LargeCheckerBoard"    ; 48-50
        , "OutlinedDiamond"        , "SolidDiamond"         , "Total" ]              ; 51-53

    ; Make accessible the style names as a dictionary.
    static __New() {          
        this.styleName := {}
        for name in this.style {
            this.styleName.%name% := A_Index - 1
        }
    }
}

class TextureBrush extends Brush {

    /**
     * Creates a new TextureBrush object with a specified bitmap or image file.
     * @param {int} pBitmap accepts a Bitmap object or a valid bitmap pointer or a path to an existing image file
     * @param {int} wrapmode how the brush is tiled (0 = Tile, 1 = Clamp)
     * @param {int} resize from file the brush can be resized by a percentage
     * @param {int} x coordinate from top left corner
     * @param {int} y coordinate
     * @param {int} w width
     * @param {int} h height
     */
    __New(pBitmap, wrapmode := 0, resize := 100, x := 0, y := 0, w := 0, h := 0) {

        static extension :=  "i)\.(bmp|png|jpg|jpeg)$"

        local Bmp, E

        ; Check input type.
        if (Type(pBitmap) == "Bitmap") {
            pBitmap := pBitmap.ptr
        }
        else if (Type(pBitmap) == "String" && pBitmap ~= extension) {
            Bmp := Bitmap(pBitmap, resize)
            pBitmap := Bmp.ptr
        }
        else if (Type(pBitmap) == "Number") {
            E := DllCall("gdiplus\GdipGetImageType", "ptr", pBitmap, "int*", &result:=0)
            if (E || result !== 1)
                return -1
        }
        
        ; Set the texture brush based on position and size.
        if (!x && !y && !w && !h) {
            DllCall("gdiplus\GdipCreateTexture"
                ,  "ptr", pBitmap
                ,  "int", wrapmode
                , "ptr*", &pBrush:=0) 
        }
        else {
            (!w) ? w := pBitmap.w - x : 0
            (!h) ? h := pBitmap.h - y : 0
            DllCall("gdiplus\GdipCreateTexture2"
                ,   "ptr", pBitmap
                ,   "int", wrapmode
                , "float", x
                , "float", y
                , "float", w
                , "float", h
                ,  "ptr*", &pBrush:=0)
        }

        ; Set the brush properties.
        this.ptr := pBrush
        this.type := 2

        ; If Bitmap is created it will be deleted automatically.
        OutputDebug("[+] TextureBrush created " pBrush "`n")
        return
    }
}

class LinearGradientBrush extends Brush {

    static LinearGradientMode := {Horizontal: 0, Vertical: 1, ForwardDiagonal: 2, BackwardDiagonal: 3}

    /** 
     * Validate LinearGradientMode value.
     * @param value LinearGradientMode
     */
    LinearGradientMode(&value) {
        if (0 <= value && value <= 3)
            return
        if LinearGradientBrush.LinearGradientMode.HasOwnProp(value) {
            value := LinearGradientBrush.LinearGradientMode.%value%
            return
        }
        throw valueError("Invalid LinearGradientMode")
    }

    /**
     * Creates a new LinearGradientBrush object with the specified colors and mode.
     * @param foreARGB 
     * @param backARGB 
     * @param {int} gradMode 
     * @param {int} wrapMode 
     * @param {int} pRectF 
     */
    __New(foreARGB, backARGB, gradMode := 1, wrapMode := 1, pRectF := 0) {
        this.LinearGradientMode(&gradMode),
        DllCall("gdiplus\GdipCreateLineBrushFromRect"
            ,  "ptr", pRectF            ; pointer to rect structure 
            ,  "int", foreARGB          ; foreground ARGB
            ,  "int", backARGB          ; background ARGB
            ,  "int", gradMode          ; LinearGradientMode
            ,  "int", wrapMode          ; WrapMode
            , "ptr*", &LGpBrush:=0)     ; pointer to the LinearGradientBrush
        this.ptr := LGpBrush
        this.type := 4
        OutputDebug("[+] LinearGradientBrush created " LGpBrush "`n")
    }

    /**
     * Gets or sets the colors of a LinearGradientBrush.
     * @get returns an array [color1, color2]
     * @set this.Color := [0xFF000000, 0xFFFFFFFF]
     */
    Color {
        get {
            local c1, c2
            return (DllCall("gdiplus\GdipGetLineColors", "ptr", this.ptr, "int*", &c1:=0, "int*", &c2:=0), [c1, c2])
        }
        set => DllCall("gdiplus\GdipSetLineColors", "ptr", this.ptr, "int", value[1], "int", value[2])
    } 
}

/**
 * TODO: implement later.
 */
class PathGradient extends Brush {
    __New() {
        DllCall("gdiplus\GdipCreatePathGradient", "ptr*", &pBrush:=0)
        this.tooltype := 3
    }
}