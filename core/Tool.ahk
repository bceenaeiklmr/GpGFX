; Script     Tool.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2

/**
 * GpGFX Native GDI+ Drawing Tools & Raster Brushes
 *
 * Provides object-oriented wrappers for GDI+ rasterization tools:
 * - Pen: Outline stroke tool with pixel width, alignment modes (Center=0, Inset=1, Outset=2), and ARGB color.
 * - SolidBrush: Fast single-color fill brush.
 * - HatchBrush: Two-color geometric crosshatch/pattern brush (53 GDI+ hatch styles).
 * - TextureBrush: Tiled/clamped image texture brush from bitmaps or image files.
 * - LinearGradientBrush: 2-color and multi-stop linear gradients with in-place rotation, scaling, and translation.
 * - PathGradientBrush: Complex radial, elliptical, and arbitrary polygon path gradients with center/surround blending.
 */

class Pen {

    ptr := 0
    type := 5
    __mode := 0

    /**
     * Gets or sets the 32-bit ARGB color of the pen.
     * @type {Integer}
     */
    Color {
        get {
            local value := 0
            return (DllCall("gdiplus\GdipGetPenColor", "ptr", this.ptr, "uint*", &value), value)
        }
        set => DllCall("gdiplus\GdipSetPenColor", "ptr", this.ptr, "uint", value)
    }

    /**
     * Gets or sets the stroke width of the pen in pixels.
     * @type {Float}
     */
    Width {
        get {
            local value := 0.0
            return (DllCall("gdiplus\GdipGetPenWidth", "ptr", this.ptr, "float*", &value), value)
        }
        set => DllCall("gdiplus\GdipSetPenWidth", "ptr", this.ptr, "float", value)
    }

    /**
     * Gets or sets the pen alignment mode ("center"=0, "inset"=1, "outset"=2).
     * @type {Integer|String}
     */
    Mode {
        get => this.__mode
        set {
            local m := value
            if (m is String) {
                switch StrLower(m), 0 {
                    case "center",  "middle":            m := 0
                    case "inset" ,  "inside":            m := 1
                    case "outset", "outside", "outline": m := 2
                    default:                             m := 0
                }
            }
            this.__mode := m
            DllCall("gdiplus\GdipSetPenMode", "ptr", this.ptr, "int", (m == 2) ? 0 : m)
        }
    }

    /**
     * Creates a new GDI+ Pen instance.
     *
     * @param {Integer|String} ARGB Stroke color
     * @param {Float} [penwidth=1] Stroke thickness in pixels
     * @param {Integer|String} [mode=0] Alignment mode ("center", "inset", "outset")
     *
     * @example
     * ; 2px solid cyan outline pen
     * myPen := Pen("0xFF00F0FF", 2, "inset")
     */
    __New(ARGB, penwidth := 1, mode := 0) {
        static GpUnitPixel := 2
        local pPen := 0
        DllCall("gdiplus\GdipCreatePen1", "uint", Color(ARGB), "float", penwidth, "int", GpUnitPixel, "ptr*", &pPen)
        this.ptr  := pPen
        this.type := 5
        this.__mode := 0
        this.Mode := mode
        GpGFX.DebugLog("[+] Pen created " pPen "`n")
    }

    /**
     * Deletes the underlying GDI+ pen handle.
     *
     * @returns {void}
     */
    Dispose() {
        local pPen
        if (!this.ptr)
            return
        pPen := this.ptr
        this.ptr := 0
        if (Gdip.pToken) {
            DllCall("gdiplus\GdipDeletePen", "ptr", pPen)
            GpGFX.DebugLog("[-] Pen ptr " pPen " deleted`n")
        }
    }

    __Delete() => this.Dispose()
}

class Brush {
    ptr := 0
    type := -1

    /**
     * Clones the brush into a new GDI+ handle.
     *
     * @returns {Integer} Cloned brush pointer
     */
    Clone() {
        local pBrush := 0
        DllCall("gdiplus\GdipCloneBrush", "ptr", this.ptr, "ptr*", &pBrush)
        return pBrush
    }

    /**
     * Validates the brush handle and returns its GDI+ brush type.
     *
     * @returns {Integer} GDI+ brush type (0=Solid, 1=Hatch, 2=Texture, 3=PathGradient, 4=LinearGradient)
     */
    Validate() {
        local result := 0
        if (DllCall("gdiplus\GdipGetBrushType", "ptr", this.ptr, "int*", &result))
            return -1
        return result
    }

    /**
     * Deletes the underlying GDI+ brush handle.
     *
     * @returns {void}
     */
    Dispose() { 
        local pBrush
        if (!this.ptr)
            return
        pBrush := this.ptr
        this.ptr := 0
        if (Gdip.pToken) {
            DllCall("gdiplus\GdipDeleteBrush", "ptr", pBrush)
            GpGFX.DebugLog("[-] " Type(this) " ptr " pBrush " deleted`n")
        }
    }

    __Delete() => this.Dispose()
}

class SolidBrush extends Brush {

    /**
     * Gets or sets the 32-bit ARGB fill color.
     * @type {Integer}
     */
    Color {
        get {
            local value := 0
            return (DllCall("gdiplus\GdipGetSolidFillColor", "ptr", this.ptr, "uint*", &value), value)
        }
        set => DllCall("gdiplus\GdipSetSolidFillColor", "ptr", this.ptr, "uint", value)
    }

    /**
     * Creates a solid single-color fill brush.
     *
     * @param {Integer|String} ARGB Fill color
     *
     * @example
     * brush := SolidBrush("0xFF78DCE8")
     */
    __New(ARGB) {
        local pBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "uint", Color(ARGB), "ptr*", &pBrush:=0)
        this.ptr  := pBrush
        this.type := 0
        GpGFX.DebugLog("[+] SolidBrush created " pBrush "`n")
    }
}

class HatchBrush extends Brush {

    ForegroundColor {
        get {
            local ARGB := 0
            return (DllCall("gdiplus\GdipGetHatchForegroundColor", "ptr", this.ptr, "uint*", &ARGB:=0), Format("0x{:08X}", ARGB))
        }
    }

    BackgroundColor {
        get {
            local ARGB := 0
            return (DllCall("gdiplus\GdipGetHatchBackgroundColor", "ptr", this.ptr, "uint*", &ARGB:=0), Format("0x{:08X}", ARGB))
        }
    }

    HatchStyle {
        get {
            local style := 0
            return (DllCall("gdiplus\GdipGetHatchStyle", "ptr", this.ptr, "int*", &style:=0), style)
        }
    }

    StyleName {
        get {
            local style := this.HatchStyle
            if (style >= 0 && style < HatchBrush.style.Length)
                return HatchBrush.style[style + 1]
            return String(style)
        }
    }

    /**
     * Creates a two-color geometric hatch pattern brush.
     *
     * @param {Integer|String} foreARGB Foreground pattern color
     * @param {Integer|String} [backARGB=0] Background fill color
     * @param {Integer|String} [hatchStyle=0] Pattern style (0-52 or style name e.g. "Cross", "DiagonalCross", "ZigZag")
     *
     * @example
     * brush := HatchBrush("White", "0xFF1E1E2E", "Cross")
     */
    __New(foreARGB, backARGB := 0, hatchStyle := 0) {
        local pBrush := 0
        foreARGB := Color(foreARGB)
        backARGB := Color(backARGB)

        if (!IsInteger(hatchStyle) || hatchStyle > 52 || hatchStyle < 0)
            hatchStyle := this.getStyle(hatchStyle)

        DllCall("gdiplus\GdipCreateHatchBrush"
            ,   "int", hatchStyle
            ,  "uint", foreARGB
            ,  "uint", backARGB
            , "ptr*", &pBrush:=0)

        this.ptr  := pBrush
        this.type := 1
        GpGFX.DebugLog("[+] HatchBrush created " pBrush "`n")
    }

    static __styleNames := Map()

    static styleNames {
        get {
            local i, name
            if (!this.__styleNames.Count) {
                for i, name in this.style {
                    if (name != "Total")
                        this.__styleNames[name] := i - 1
                }
            }
            return this.__styleNames
        }
    }

    getStyle(value) {
        local valLower := StrLower(String(value)), name, id
        if (valLower == "horizontal")
            return 0
        for name, id in HatchBrush.styleNames {
            if (StrLower(name) == valLower)
                return id
        }
        throw ValueError("Invalid Hatch style: " value)
    }

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
}

class TextureBrush extends Brush {

    bmpRef := 0

    /**
     * Creates an image texture brush for tiled or clamped pattern rendering.
     *
     * @param {String|Integer|GdipBitmap} pBitmap Bitmap instance, pointer, or file path
     * @param {Integer} [wrapmode=0] Tiling wrap mode (0=Tile, 1=Clamp, 2=TileFlipX, 3=TileFlipY, 4=TileFlipXY)
     * @param {Integer} [resize=100] Scaling percentage if loading from file
     * @param {Float} [x=0] Source sub-rectangle X
     * @param {Float} [y=0] Source sub-rectangle Y
     * @param {Float} [w=0] Source sub-rectangle Width
     * @param {Float} [h=0] Source sub-rectangle Height
     */
    __New(pBitmap, wrapmode := 0, resize := 100, x := 0, y := 0, w := 0, h := 0) {
        static extension := "i)\.(bmp|png|jpg|jpeg)$"
        local pBrush := 0, ptrToUse := 0

        if (HasProp(pBitmap, "ptr")) {
            ptrToUse := pBitmap.ptr
            this.bmpRef := pBitmap
        }
        else if (pBitmap is String && pBitmap ~= extension) {
            this.bmpRef := GdipBitmap(pBitmap, resize)
            ptrToUse := this.bmpRef.ptr
        }
        else if (IsInteger(pBitmap)) {
            ptrToUse := pBitmap
        }
        else {
            throw ValueError("Invalid bitmap input for TextureBrush")
        }

        if (!ptrToUse)
            throw ValueError("Invalid or uninitialized bitmap pointer for TextureBrush")

        if (!x && !y && !w && !h) {
            DllCall("gdiplus\GdipCreateTexture", "ptr", ptrToUse, "int", wrapmode, "ptr*", &pBrush)
        }
        else {
            DllCall("gdiplus\GdipCreateTexture2"
                ,   "ptr", ptrToUse
                ,   "int", wrapmode
                , "float", x, "float", y, "float", w, "float", h
                ,  "ptr*", &pBrush)
        }

        this.ptr  := pBrush
        this.type := 2
        GpGFX.DebugLog("[+] TextureBrush created " pBrush "`n")
    }

    Dispose() {
        this.bmpRef := 0
        super.Dispose()
    }
}

class LinearGradientBrush extends Brush {

    static LinearGradientMode := Map(
        "Horizontal"      , 0,
        "Vertical"        , 1,
        "ForwardDiagonal" , 2,
        "BackwardDiagonal", 3
    )

    static rectBuf := Buffer(16, 0)

    /**
     * Creates a 2-color or multi-stop linear gradient brush.
     *
     * @param {Integer|String} foreARGB Starting color
     * @param {Integer|String} backARGB Ending color
     * @param {Float} [x=0] Gradient bounding box X
     * @param {Float} [y=0] Gradient bounding box Y
     * @param {Float} [w=100] Gradient bounding box Width
     * @param {Float} [h=100] Gradient bounding box Height
     * @param {Integer|String} [gradMode=1] Direction (0="Horizontal", 1="Vertical", 2="ForwardDiagonal", 3="BackwardDiagonal")
     * @param {Integer} [wrapMode=1] Wrap mode (1=TileFlipX)
     */
    __New(foreARGB, backARGB, x := 0, y := 0, w := 100, h := 100, gradMode := 1, wrapMode := 1) {
        local LGpBrush := 0

        if (gradMode is String && LinearGradientBrush.LinearGradientMode.Has(gradMode))
            gradMode := LinearGradientBrush.LinearGradientMode[gradMode]

        NumPut("float", x, LinearGradientBrush.rectBuf, 0)
        NumPut("float", y, LinearGradientBrush.rectBuf, 4)
        NumPut("float", w, LinearGradientBrush.rectBuf, 8)
        NumPut("float", h, LinearGradientBrush.rectBuf, 12)

        DllCall("gdiplus\GdipCreateLineBrushFromRect"
            ,   "ptr", LinearGradientBrush.rectBuf
            ,  "uint", Color(foreARGB)
            ,  "uint", Color(backARGB)
            ,   "int", gradMode
            ,   "int", wrapMode
            ,  "ptr*", &LGpBrush:=0)

        this.ptr  := LGpBrush
        this.type := 4
        GpGFX.DebugLog("[+] LinearGradientBrush created " LGpBrush "`n")
    }

    Color {
        get {
            local c1 := 0, c2 := 0
            DllCall("gdiplus\GdipGetLineColors", "ptr", this.ptr, "uint*", &c1, "uint*", &c2)
            return [c1, c2]
        }
        set {
            if (value is Array && value.Length >= 2)
                DllCall("gdiplus\GdipSetLineColors", "ptr", this.ptr, "uint", Color(value[1]), "uint", Color(value[2]))
        }
    }

    /**
     * Shifts/translates the gradient coordinates in-place without recreating the brush.
     */
    Translate(dx, dy, order := 0) => DllCall("gdiplus\GdipTranslateLineTransform", "ptr", this.ptr, "float", dx, "float", dy, "int", order)

    /**
     * Rotates the gradient angle in degrees in-place.
     */
    Rotate(angle, order := 0) => DllCall("gdiplus\GdipRotateLineTransform", "ptr", this.ptr, "float", angle, "int", order)

    /**
     * Scales the gradient dimensions in-place.
     */
    Scale(sx, sy, order := 0) => DllCall("gdiplus\GdipScaleLineTransform", "ptr", this.ptr, "float", sx, "float", sy, "int", order)

    /**
     * Resets any applied rotation, translation, or scaling transform.
     */
    ResetTransform() => DllCall("gdiplus\GdipResetLineTransform", "ptr", this.ptr)

    /**
     * Sets multi-stop gradient color blend in-place.
     *
     * @param {Array} clrList Array of ARGB colors
     * @param {Array} positions Array of float positions (0.0 to 1.0)
     */
    SetPresetBlend(clrList, positions) {
        if (!IsObject(clrList) || !IsObject(positions) || clrList.Length != positions.Length)
            return
        local count := clrList.Length
        local pClrBuf := Buffer(count * 4, 0)
        local pPosBuf := Buffer(count * 4, 0)
        loop count {
            NumPut("uint",  Color(clrList[A_Index]), pClrBuf, (A_Index - 1) * 4)
            NumPut("float", Float(positions[A_Index]), pPosBuf, (A_Index - 1) * 4)
        }
        return DllCall("gdiplus\GdipSetLinePresetBlend", "ptr", this.ptr, "ptr", pClrBuf, "ptr", pPosBuf, "int", count)
    }
}

class PathGradientBrush extends Brush {

    static __centerPtBuf := Buffer(8, 0)
    static __colorBuf := Buffer(4, 0)

    /**
     * Creates a PathGradientBrush from a GDI+ GraphicsPath or an Array of points [[x1,y1], [x2,y2], ...].
     *
     * @param {Object|Array} pointsOrPath GraphicsPath object or array of at least 3 points
     * @param {Integer|String} [centerColor="White"] Center focal color
     * @param {Integer|String|Array} [surroundColor=0] Boundary color or array of colors
     * @param {Integer} [wrapMode=0] WrapMode (0=Clamp, 1=Tile)
     */
    __New(pointsOrPath, centerColor := "White", surroundColor := 0, wrapMode := 0) {
        local pBrush := 0, cClr, count, ptBuf, ptNode, px, py

        cClr := Color(centerColor)

        if (IsObject(pointsOrPath) && pointsOrPath.HasProp("ptr")) {
            DllCall("gdiplus\GdipCreatePathGradientFromPath", "ptr", pointsOrPath.ptr, "ptr*", &pBrush:=0)
        }
        else if (pointsOrPath is Array && pointsOrPath.Length >= 3) {
            count := pointsOrPath.Length
            ptBuf := Buffer(count * 8, 0)
            loop count {
                ptNode := pointsOrPath[A_Index]
                px := IsObject(ptNode) ? (ptNode.HasProp("x") ? ptNode.x : ptNode[1]) : 0
                py := IsObject(ptNode) ? (ptNode.HasProp("y") ? ptNode.y : ptNode[2]) : 0
                NumPut("float", Float(px), ptBuf, (A_Index - 1) * 8 + 0)
                NumPut("float", Float(py), ptBuf, (A_Index - 1) * 8 + 4)
            }
            DllCall("gdiplus\GdipCreatePathGradient", "ptr", ptBuf, "int", count, "int", wrapMode, "ptr*", &pBrush:=0)
        }
        else {
            throw ValueError("PathGradientBrush requires a GraphicsPath or Array of at least 3 points")
        }

        if (!pBrush)
            throw Error("Failed to create PathGradientBrush")

        this.ptr  := pBrush
        this.type := 3

        DllCall("gdiplus\GdipSetPathGradientCenterColor", "ptr", pBrush, "uint", cClr)

        if (surroundColor is Array && surroundColor.Length > 0)
            this.SetSurroundColors(surroundColor)
        else
            this.SetSurroundColor(surroundColor)

        GpGFX.DebugLog("[+] PathGradientBrush created " pBrush "`n")
    }

    /**
     * Creates a circular or elliptical radial gradient brush.
     *
     * @param {Number} cx Center X
     * @param {Number} cy Center Y
     * @param {Number} radius Gradient radius in pixels
     * @param {Integer|String} [centerColor="White"] Inner core color
     * @param {Integer|String} [surroundColor=0] Outer perimeter color
     * @param {Integer} [wrapMode=0] WrapMode
     * @returns {PathGradientBrush}
     *
     * @example
     * radBrush := PathGradientBrush.Radial(150, 150, 100, "0xFF00FFFF", "0x00000000")
     */
    static Radial(cx, cy, radius, centerColor := "White", surroundColor := 0, wrapMode := 0) {
        local pPath := 0, r := Float(radius), brush
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath:=0)
        DllCall("gdiplus\GdipAddPathEllipse", "ptr", pPath, "float", cx - r, "float", cy - r, "float", 2 * r, "float", 2 * r)
        brush := PathGradientBrush({ ptr: pPath }, centerColor, surroundColor, wrapMode)
        DllCall("gdiplus\GdipDeletePath", "ptr", pPath)
        return brush
    }

    /**
     * Creates a rectangular path gradient brush from a bounding box.
     *
     * @param {Number} x Top-left X
     * @param {Number} y Top-left Y
     * @param {Number} w Width
     * @param {Number} h Height
     * @param {Integer|String} [centerColor="White"] Center color
     * @param {Integer|String} [surroundColor=0] Outer border color
     * @returns {PathGradientBrush}
     */
    static FromRect(x, y, w, h, centerColor := "White", surroundColor := 0) {
        local pts := [
            [x, y],
            [x + w, y],
            [x + w, y + h],
            [x, y + h]
        ]
        return PathGradientBrush(pts, centerColor, surroundColor)
    }

    CenterPoint {
        get {
            local ptBuf := Buffer(8, 0)
            DllCall("gdiplus\GdipGetPathGradientCenterPoint", "ptr", this.ptr, "ptr", ptBuf)
            return [NumGet(ptBuf, 0, "float"), NumGet(ptBuf, 4, "float")]
        }
        set {
            if (value is Array && value.Length >= 2)
                this.SetCenter(value[1], value[2])
        }
    }

    FocusScales {
        get {
            local xScale := 0.0, yScale := 0.0
            DllCall("gdiplus\GdipGetPathGradientFocusScales", "ptr", this.ptr, "float*", &xScale:=0, "float*", &yScale:=0)
            return [xScale, yScale]
        }
        set {
            if (value is Array && value.Length >= 2)
                this.SetFocusScales(value[1], value[2])
            else if (value is Number)
                this.SetFocusScales(value, value)
        }
    }

    GammaCorrection {
        get {
            local useGamma := 0
            DllCall("gdiplus\GdipGetPathGradientGammaCorrection", "ptr", this.ptr, "int*", &useGamma:=0)
            return useGamma
        }
        set => DllCall("gdiplus\GdipSetPathGradientGammaCorrection", "ptr", this.ptr, "int", !!value)
    }

    WrapMode {
        get {
            local wm := 0
            DllCall("gdiplus\GdipGetPathGradientWrapMode", "ptr", this.ptr, "int*", &wm:=0)
            return wm
        }
        set => DllCall("gdiplus\GdipSetPathGradientWrapMode", "ptr", this.ptr, "int", value)
    }

    SetCenter(x, y) {
        NumPut("float", Float(x), PathGradientBrush.__centerPtBuf, 0)
        NumPut("float", Float(y), PathGradientBrush.__centerPtBuf, 4)
        return DllCall("gdiplus\GdipSetPathGradientCenterPoint", "ptr", this.ptr, "ptr", PathGradientBrush.__centerPtBuf)
    }

    SetCenterColor(clr) => DllCall("gdiplus\GdipSetPathGradientCenterColor", "ptr", this.ptr, "uint", Color(clr))

    SetSurroundColor(clr) {
        NumPut("uint", Color(clr), PathGradientBrush.__colorBuf, 0)
        local count := 1
        return DllCall("gdiplus\GdipSetPathGradientSurroundColorsWithCount", "ptr", this.ptr, "ptr", PathGradientBrush.__colorBuf, "int*", &count)
    }

    SetSurroundColors(clrList) {
        if (!IsObject(clrList) || clrList.Length == 0)
            return
        local count := clrList.Length
        local pClrBuf := Buffer(count * 4, 0)
        loop count {
            NumPut("uint", Color(clrList[A_Index]), pClrBuf, (A_Index - 1) * 4)
        }
        return DllCall("gdiplus\GdipSetPathGradientSurroundColorsWithCount", "ptr", this.ptr, "ptr", pClrBuf, "int*", &count)
    }

    SetPresetBlend(clrList, positions) {
        if (!IsObject(clrList) || !IsObject(positions) || clrList.Length != positions.Length)
            return
        local count := clrList.Length
        local pClrBuf := Buffer(count * 4, 0)
        local pPosBuf := Buffer(count * 4, 0)
        loop count {
            NumPut("uint", Color(clrList[A_Index]), pClrBuf, (A_Index - 1) * 4)
            NumPut("float", Float(positions[A_Index]), pPosBuf, (A_Index - 1) * 4)
        }
        return DllCall("gdiplus\GdipSetPathGradientPresetBlend", "ptr", this.ptr, "ptr", pClrBuf, "ptr", pPosBuf, "int", count)
    }

    SetFocusScales(xScale := 0.0, yScale := 0.0) => DllCall("gdiplus\GdipSetPathGradientFocusScales", "ptr", this.ptr, "float", Float(xScale), "float", Float(yScale))

    Translate(dx, dy, order := 0) => DllCall("gdiplus\GdipTranslatePathGradientTransform", "ptr", this.ptr, "float", Float(dx), "float", Float(dy), "int", order)

    Rotate(angle, order := 0) => DllCall("gdiplus\GdipRotatePathGradientTransform", "ptr", this.ptr, "float", Float(angle), "int", order)

    Scale(sx, sy, order := 0) => DllCall("gdiplus\GdipScalePathGradientTransform", "ptr", this.ptr, "float", Float(sx), "float", Float(sy), "int", order)

    ResetTransform() => DllCall("gdiplus\GdipResetPathGradientTransform", "ptr", this.ptr)
}

; Tool Factory Aliases
PathGradient(args*)     => PathGradientBrush(args*)
PathGradientTool(args*) => PathGradientBrush(args*)
RadialGradient(args*)   => PathGradientBrush.Radial(args*)