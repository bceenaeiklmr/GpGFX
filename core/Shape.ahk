; Script:    Shape.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2

/**
 * GpGFX Shape & Reactive Signal System
 *
 * Core vector shape primitive container, rasterization tool configurator, and reactive data binder.
 *
 * Features:
 * - Signal System: Reactive variable state management with delta-time easing animations (Signal.Animate).
 * - Vector Primitives: Rectangles, Ellipses, Polygons, Triangles, Lines, Beziers, Curves, and Arcs.
 * - Tool Initialization: Dynamic binding of GDI+ Pens, SolidBrushes, HatchBrushes, Gradients, and TextureBrushes.
 * - Text Layout & Typography: Word-wrapped and character-level typographic formatting with rich color segmentation.
 * - Image & Bitmap Layering: Embedded GdipBitmap operations, Color LUTs, pixel scanning, and image transforms.
 * - Interactivity: Sub-50ns native WindowProc hit testing for Click, Hover, and continuous vector dragging.
 * - Motion & Transitions: Delta-timed property animations (Animate, RollDown, RollUp, FadeIn, FadeOut).
 */

; Point buffer accessor helpers
get_ShapePoint(offset, shapeObj) => NumGet(shapeObj.pPoints, offset, "float")
set_ShapePoint(offset, shapeObj, value) => (NumPut("float", value, shapeObj.pPoints, offset), value)

/**
 * Creates a structured grid of shapes with automatic spacing and centering.
 *
 * @param {Integer} [row=3] Number of rows
 * @param {Integer} [col=3] Number of columns
 * @param {Integer} [x] Starting X coordinate (centered on layer if omitted)
 * @param {Integer} [y] Starting Y coordinate (centered on layer if omitted)
 * @param {Integer} [w=0] Width per cell (calculated from layer dimensions if 0)
 * @param {Integer} [h=0] Height per cell (calculated from layer dimensions if 0)
 * @param {Integer} [pad=25] Padding between cells in pixels
 * @param {Integer|String} [colour=0xFF000000] Default shape fill/stroke color
 * @param {Layer} [layer=LayerStack.ActiveLayer] Target layer instance
 * @returns {Array<Shape>} Array of created Rectangle shapes
 *
 * @example
 * ; Create a 4x4 grid of cards
 * grid := CreateGraphicsObject(4, 4, , , 100, 100, 15, "0xFF2E3440")
 */
CreateGraphicsObject(row := 3, col := 3, x?, y?, w := 0, h := 0, pad := 25, colour := 0xFF000000, layer := LayerStack.ActiveLayer) {
    if (!layer)
        throw Error("CreateGraphicsObject: No active layer available.")

    local totalWidth, totalHeight, baseX, baseY, objx, objy, i, j
    local width  := layer.gfx.w
    local height := layer.gfx.h
    local obj    := []

    ; Calculate dimensions based on layer bounds and padding if not specified
    if (!w && !h) {
        w := (width  - (col + 1) * pad) // col
        h := (height - (row + 1) * pad) // row
        if (w != h)
            w := h := Min(w, h)
    }

    totalWidth  := col * w + (col - 1) * pad
    totalHeight := row * h + (row - 1) * pad

    baseX := (!IsSet(x)) ? (width - totalWidth) // 2   : x
    baseY := (!IsSet(y)) ? (height - totalHeight) // 2 : y

    loop row {
        i := A_Index
        loop col {
            j := A_Index
            objx := baseX + (j - 1) * (w + pad)
            objy := baseY + (i - 1) * (h + pad)
            obj.Push(Rectangle(objx, objy, w, h, colour))
        }
    }
    return obj
}

/**
 * Reactive Signal state variable for zero-CPU event-driven graphics and reactive HUDs.
 * Shapes and Layers can bind directly to signals via `shape.Bind(sig)` or `layer.Draw(sig)`.
 * Modifying `sig.Value := newVal` automatically notifies all bound subscribers and triggers layer redraws.
 */
class Signal {

    __val := 0
    __subscribers := []

    /**
     * Creates a new reactive Signal instance.
     *
     * @param {Any} [initialValue=0] The initial value of the signal (number, string, object, array, etc.)
     *
     * @example
     * ; 1. Numeric signal
     * sigHealth := Signal(100)
     *
     * ; 2. Object state signal
     * sigPlayer := Signal({ x: 100, y: 200, score: 0 })
     */
    __New(initialValue := 0) {
        this.__val := initialValue
    }

    /**
     * Gets or sets the signal's current value.
     * Modifying this property notifies all subscribers and triggers redraws of bound shapes/layers.
     * @type {Any}
     */
    Value {
        get => this.__val
        set {
            if (this.__val !== value) {
                this.__val := value
                this.Notify()
            }
        }
    }

    /**
     * Subscribes a callback function to value change notifications.
     *
     * @param {Function} fn Callback executed on change: `fn(newVal)`
     * @returns {Signal} this (for chaining)
     *
     * @example
     * sig.Subscribe((newVal) => ToolTip("Value changed to: " newVal))
     */
    Subscribe(fn) {
        this.__subscribers.Push(fn)
        return this
    }

    /**
     * Unsubscribes a previously registered callback function.
     *
     * @param {Function} fn The callback function to remove
     * @returns {void}
     */
    Unsubscribe(fn) {
        local i := this.__subscribers.Length
        while (i > 0) {
            if (this.__subscribers[i] == fn)
                this.__subscribers.RemoveAt(i)
            i--
        }
    }

    /**
     * Manually triggers notification of all subscribers with the current value.
     *
     * @returns {void}
     */
    Notify() {
        local fn
        for fn in this.__subscribers {
            try (fn)(this.__val)
        }
    }

    /**
     * Smoothly animates a Signal from a start value to an end value over durationMs using delta time.
     * Non-blocking (runs on background high-precision timer at ~60fps).
     *
     * @param {Signal} sig The Signal instance to animate
     * @param {Float|Integer} fromVal Starting value
     * @param {Float|Integer} toVal Ending value
     * @param {Integer} [durationMs=400] Duration of the animation in milliseconds
     * @param {String|Function} [easing="easeInOut"] Easing function ("linear", "easeIn", "easeOut", "easeInOut", "sine", "bounce", or custom fn(t))
     * @param {Function} [onDone] Optional callback executed when animation completes: fn(sig)
     * @returns {Signal} sig
     *
     * @example
     * sigHeight := Signal(0)
     * rect.Bind(sigHeight, (h, shp) => shp.h := h)
     * Signal.Animate(sigHeight, 0, 400, 500, "easeOut")
     */
    static Animate(sig, fromVal, toVal, durationMs := 400, easing := "easeInOut", onDone?) {
        static PI := 3.141592653589793
        local easeFn

        if (IsObject(easing)) {
            easeFn := easing
        }
        else {
            switch StrLower(String(easing)), 0 {
                case "linear":      easeFn := (t) => t
                case "easein":      easeFn := (t) => t * t * t
                case "easeout":     easeFn := (t) => 1 - ((1 - t) ** 3)
                case "sine", "sin": easeFn := (t) => (1 - Cos(t * PI)) / 2
                case "bounce":      easeFn := (t) => (
                    t < 0.3636 ? 7.5625 * t * t :
                    t < 0.7272 ? 7.5625 * (t -= 0.5454) * t + 0.75 :
                    t < 0.9090 ? 7.5625 * (t -= 0.8181) * t + 0.9375 :
                    7.5625 * (t -= 0.9545) * t + 0.984375
                )
                default: easeFn := (t) => (t < 0.5 ? 4 * t * t * t : 1 - ((-2 * t + 2) ** 3) / 2)
            }
        }

        local startTick := A_TickCount
        sig.Value := fromVal

        local timerFn
        timerFn := () => (
            __Tick()
        )

        __Tick() {
            local elapsed := A_TickCount - startTick
            local progress := durationMs > 0 ? Min(1.0, elapsed / durationMs) : 1.0
            local easedProgress := easeFn(progress)
            local currentVal := fromVal + (toVal - fromVal) * easedProgress
            sig.Value := currentVal

            if (progress >= 1.0) {
                SetTimer(timerFn, 0)
                sig.Value := toVal
                if (IsSet(onDone) && IsObject(onDone))
                    (onDone)(sig)
            }
        }

        SetTimer(timerFn, 16)
        return sig
    }
}

/**
 * Core vector shape container and graphics object base class.
 */
class Shape {
    
    id         := 0
    layerPtr   := 0
    signals    := []
    isPrepared := false
    isDisposed := false
    x          := 0
    y          := 0
    w          := 0
    h          := 0
    r          := 10
    tension    := 0.5
    name       := ""
    shape      := ""
    ptr        := 0
    Tool       := 0
    Font       := 0
    Bitmap     := 0

    __color    := 0x00000000
    __alpha    := 255
    __filled   := false
    __penwidth := 1
    __visible  := true

    __str         := ""
    __strH        := 0
    __strV        := 0
    __strQ        := 5
    __textColor   := 0xFFFFFFFF
    __lineHeight  := 0
    __lineSpacing := 1.35
    __tabSize     := 4
    __isRichText  := false
    __textRuns    := []
    __textLines   := []
    __textRaw     := ""

    strX := 0
    strY := 0

    pBitmap := 0
    bmpX := 0
    bmpY := 0
    bmpW := 0
    bmpH := 0
    bmpSrcX := 0
    bmpSrcY := 0
    bmpSrcW := 0
    bmpSrcH := 0
    bmpW0 := 0
    bmpH0 := 0

    eventMap := Map()
    _hoverNormalClr := 0
    _hoverActiveClr := 0

    /**
     * Sets or gets the alpha opacity channel of the shape (0 - 255).
     * @type {Integer}
     */
    Alpha {
        get => this.__alpha
        set {
            local clr

            if (this.__alpha == value)
                return

            if (value < 0 || value > 255)
                throw ValueError("[!] Alpha value must be between 0 and 255")

            if (this.Tool.type == 0 || this.Tool.type == 5) {
                this.__color := (this.__color & 0x00FFFFFF) | (value << 24)
                this.Tool.color := this.__color
            }
            else if (this.Tool.type == 4) {
                clr := this.Tool.color
                clr[1] := (clr[1] & 0x00FFFFFF) | (value << 24)
                clr[2] := (clr[2] & 0x00FFFFFF) | (value << 24)
                this.Tool.color := clr
                this.__color := clr
            }
            else {
                throw ValueError("[!] Alpha modification supported on Pen, SolidBrush, and LinearGradientBrush.")
            }

            this.__alpha := value
        }
    }

    /**
     * Sets or gets the primary shape fill/stroke color or brush descriptor.
     * Supports color names ("Red", "Lime"), hex strings ("#FF0000", "0xFF0000FF"),
     * integers (0xFF0000FF), gradient arrays (["Red", "Blue"]), and texture brushes.
     * @type {Integer|String|Array}
     */
    Color {
        get => this.__color
        set {
            local tooltype, rad

            if (value is Integer || (value is String && value != "")) {
                value := Color(value)
                this.__color := value
                this.__alpha := (value >> 24) & 0xFF

                if (!this.Tool || this.Tool.type !== 0 && this.Tool.type !== 5) {
                    if (IsObject(this.Tool) && this.Tool.HasMethod("Dispose"))
                        this.Tool.Dispose()
                    this.Tool := (this.Filled) ? SolidBrush(value) : Pen(value, this.penwidth)
                }

                this.Tool.Color := value
                return
            }
            else if (value is Array) {
                tooltype := this.Tool.type

                if (!this.filled) {
                    this.shape := "Filled" this.shape
                    this.__filled := true
                }

                if (value.Length == 2) {
                    if (value[1] ~= "i)^(texture|hatch|gradient)$")
                        throw ValueError("[!] Invalid color type descriptor")

                    value[1] := Color(value[1])
                    value[2] := Color(value[2])

                    if (tooltype == 4) {
                        this.Tool.color := [value[1], value[2]]
                        return
                    }

                    value.InsertAt(1, unset)
                    tooltype := 4
                }
                else {
                    switch value[1], 0 {
                        case "hatch":    tooltype := 1
                        case "texture":  tooltype := 2
                        case "gradient": tooltype := 4
                        default: throw ValueError("[!] Unrecognized brush type: " value[1])
                    }
                }

                if (IsObject(this.Tool) && this.Tool.HasMethod("Dispose"))
                    this.Tool.Dispose()
                this.Tool := 0

                switch tooltype {
                    case 1:
                        this.Tool := HatchBrush(Color(value[2]), Color(value[3]), value.Has(4) ? value[4] : 0)
                    case 2:
                        this.Tool := TextureBrush(value[2]
                            , value.Has(3) ? value[3] : 0
                            , value.Has(4) ? value[4] : 100
                            , value.Has(5) ? value[5] : 0
                            , value.Has(6) ? value[6] : 0
                            , value.Has(7) ? value[7] : 0
                            , value.Has(8) ? value[8] : 0)
                    case 3:
                        if (value.Length >= 4 && value[2] is String && value[2] = "radial") {
                            rad := value.Has(5) ? value[5] : Max(this.w, this.h) / 2.0
                            this.Tool := PathGradientBrush.Radial(this.x + this.w / 2.0, this.y + this.h / 2.0, rad, value[3], value[4])
                        }
                        else if (value.Length >= 4) {
                            this.Tool := PathGradientBrush(value[2], value[3], value[4])
                        }
                    case 4:
                        this.Tool := LinearGradientBrush(Color(value[2]), Color(value[3]), this.x, this.y, this.w, this.h, (value.Has(4)) ? value[4] : 0, 1)
                }
            }
        }
    }

    ; Alias for Color
    Colour {
        get => this.__color
        set => this.Color := value
    }

    /**
     * Toggles the raster tool between a Pen (outline) and a SolidBrush (filled).
     * @type {Boolean}
     */
    Filled {
        get => this.__filled
        set {
            local tooltype, clr
        
            if !(value == 0 || value == 1)
                return

            if ((this.Tool.type == 0 || this.Tool.type == 5) && this.filled == value)
                return

            tooltype := this.Tool.type
            clr := this.__color
            if (IsObject(this.Tool) && this.Tool.HasMethod("Dispose"))
                this.Tool.Dispose()
            this.Tool := 0

            if (clr is Array) {
                clr := clr[1]
                this.__color := clr
            }

            if (value) {
                if (SubStr(this.shape, 1, 6) !== "Filled")
                    this.shape := "Filled" this.shape
                this.Tool := SolidBrush(clr)
            }
            else {
                if (SubStr(this.shape, 1, 6) == "Filled")
                    this.shape := SubStr(this.shape, 7)
                this.Tool := Pen(clr, this.penwidth)
            }
            
            this.__filled := value
        }
    }

    /**
     * Sets or gets the pen alignment mode ('inset'=1, 'center'=0, 'outset'=2).
     * @type {Integer}
     */
    PenMode {
        get => (this.Tool.type == 5) ? this.Tool.Mode : 0
        set {
            if (this.Tool.type == 5)
                this.Tool.mode := value
        }
    }

    /**
     * Sets or gets the stroke width of the shape's pen in pixels.
     * @type {Integer}
     */
    PenWidth {
        get => this.__penwidth
        set {
            static sizeMin := 1, sizeMax := 16384
            if (value >= sizeMin && value <= sizeMax) {
                if (this.Tool.type == 5)
                    this.Tool.width := value
                this.__penwidth := value
                if (this.layerPtr) {
                    try {
                        local lyr := ObjFromPtrAddRef(this.layerPtr)
                        lyr.isDirtyBounds := true
                        lyr := ""
                    }
                }
                return
            }
            throw ValueError("[!] Invalid value for PenWidth property")
        }
    }

    /**
     * Gets the right geometric edge of the shape (x + w).
     * @type {Integer}
     */
    Right => (this.x + this.w)

    /**
     * Gets the bottom geometric edge of the shape (y + h).
     * @type {Integer}
     */
    Bottom => (this.y + this.h)

    /**
     * Gets the horizontal center coordinate of the shape (x + w / 2).
     * @type {Float}
     */
    CenterX => (this.x + (this.w / 2))

    /**
     * Gets the vertical center coordinate of the shape (y + h / 2).
     * @type {Float}
     */
    CenterY => (this.y + (this.h / 2))

    /**
     * Gets the bounding rectangle of the shape as a coordinate object {x, y, w, h}.
     * @type {Object}
     */
    Bounds => { x: this.x, y: this.y, w: this.w, h: this.h }

    /**
     * Sets or gets the visibility state of the shape.
     * @type {Boolean}
     */
    Visible {
        get => this.__visible
        set {
            if (value == this.__visible)
                return

            if (value == true || value == false)
                this.__visible := value
            else if (value == -1 || value = "toggle")
                this.__visible ^= 1
            else
                throw ValueError("[!] Invalid value for Visible property. Accepted: 0, 1, -1, 'toggle'")

            if (this.layerPtr) {
                try {
                    local lyr := ObjFromPtrAddRef(this.layerPtr)
                    lyr.isDirtyBounds := true
                    lyr := ""
                }
            }
        }
    }

    /**
     * Text string or multi-color segmented text attached to the shape.
     * @type {String}
     */
    str {
        get => this.__str
        set {
            if (this.__str == value)
                return
            this.__str := value
            this.PrepareTextLayout()
        }
    }

    /**
     * Pre-tokenizes formatted multi-color strings to eliminate parsing inside the Draw loop.
     *
     * @returns {void}
     */
    PrepareTextLayout() => TextLayout.Prepare(this)

    /**
     * Sets or gets the tab size in number of spaces (default: 4).
     * @type {Integer}
     */
    tabSize {
        get => this.__tabSize
        set {
            this.__tabSize := (value > 0) ? Integer(value) : 4
            if (this.str != "")
                this.PrepareTextLayout()
        }
    }

    tabSpacing {
        get => this.__tabSize
        set => this.tabSize := value
    }

    /**
     * Sets or gets the line height in pixels (0 = automatic based on font size and lineSpacing).
     * @type {Number}
     */
    lineHeight {
        get => this.__lineHeight
        set => this.__lineHeight := (value > 0) ? value : 0
    }

    /**
     * Sets or gets the line spacing multiplier (default: 1.35).
     * @type {Float}
     */
    lineSpacing {
        get => this.__lineSpacing
        set => this.__lineSpacing := (value > 0) ? value : 1.35
    }

    /**
     * Sets horizontal text alignment ("left", "center", "right" or 0, 1, 2).
     * @type {Integer}
     */
    strH {
        get => this.__strH
        set {
            if (value is String) {
                switch StrLower(value) {
                    case "left"  , "near"  : this.__strH := 0
                    case "center", "middle": this.__strH := 1
                    case "right" , "far"   : this.__strH := 2
                    default: throw ValueError("[!] Invalid horizontal alignment: " value)
                }
            }
            else if (value is Integer && value >= 0 && value <= 2) {
                this.__strH := value
            }
            else throw ValueError("[!] Invalid horizontal alignment value: " value)
        }
    }

    /**
     * Sets vertical text alignment ("top", "middle", "bottom" or 0, 1, 2).
     * @type {Integer}
     */
    strV {
        get => this.__strV
        set {
            if (value is String) {
                switch StrLower(value) {
                    case "top"   , "up"    : this.__strV := 0
                    case "middle", "center": this.__strV := 1
                    case "bottom", "down"  : this.__strV := 2
                    default: throw ValueError("[!] Invalid vertical alignment: " value)
                }
            }
            else if (value is Integer && value >= 0 && value <= 2) {
                this.__strV := value
            }
            else throw ValueError("[!] Invalid vertical alignment value: " value)
        }
    }

    strHorizontal {
        get => this.__strH
        set => this.strH := value
    }
    strVertical {
        get => this.__strV
        set => this.strV := value
    }

    /**
     * Sets horizontal and/or vertical text alignment with chaining support.
     *
     * @param {String|Integer} [h] Horizontal alignment ("left", "center", "right" or 0, 1, 2)
     * @param {String|Integer} [v] Vertical alignment ("top", "middle", "bottom" or 0, 1, 2)
     * @returns {Shape} this (for chaining)
     */
    TextAlign(h?, v?) {
        IsSet(h) && this.strH := h
        IsSet(v) && this.strV := v
        return this
    }
    StringAlign(h?, v?) => this.TextAlign(h?, v?)
    TextAlignment(h?, v?) => this.TextAlign(h?, v?)
    StringAlignment(h?, v?) => this.TextAlign(h?, v?)
    Align(h?, v?) => this.TextAlign(h?, v?)

    Left()        => (this.strH := 0, this)
    Center()      => (this.strH := 1, this)
    Right()       => (this.strH := 2, this)
    Top()         => (this.strV := 0, this)
    Middle()      => (this.strV := 1, this)
    Bottom()      => (this.strV := 2, this)

    TopLeft()      => this.Align(0, 0)
    TopCenter()    => this.Align(1, 0)
    TopRight()     => this.Align(2, 0)
    BottomLeft()   => this.Align(0, 2)
    BottomCenter() => this.Align(1, 2)
    BottomRight()  => this.Align(2, 2)
    MiddleLeft()   => this.Align(0, 1)
    MiddleCenter() => this.Align(1, 1)
    MiddleRight()  => this.Align(2, 1)

    stringFormatAlign {
        get => this.__strH
        set => this.strH := value
    }

    stringFormatLineAlign {
        get => this.__strV
        set => this.strV := value
    }

    strPosition {
        set {
            this.strH := value[1]
            this.strV := value[2]
        }
    }

    strQuality {
        get => this.__strQ
        set {
            if (value < 0 || value > 5)
                throw ValueError("[!] Invalid text rendering quality value")
            this.__strQ := value
        }
    }

    ImageWidth  => (this.Bitmap ? this.Bitmap.w : 0)
    ImageHeight => (this.Bitmap ? this.Bitmap.h : 0)

    LayerWidth {
        get {
            local lyr := ObjFromPtrAddRef(this.layerPtr)
            local w := lyr.w
            lyr := ""
            return w
        }
    }

    LayerHeight {
        get {
            local lyr := ObjFromPtrAddRef(this.layerPtr)
            local h := lyr.h
            lyr := ""
            return h
        }
    }

    LayerDimensions {
        get {
            local lyr := ObjFromPtrAddRef(this.layerPtr)
            local wh := { w: lyr.w, h: lyr.h }
            lyr := ""
            return wh
        }
    }

    ToolType => this.Tool.type
    HasSignal => (this.signals.Length ? true : false)

    /**
     * Attaches or updates text properties on the shape.
     *
     * @param {String} [str] Text string or rich formatted text
     * @param {Integer|String} [colour] Font brush color
     * @param {Integer} [size] Font size
     * @param {String} [family] Font family name
     * @param {String|Integer} [style] Font style ("Regular", "Bold", "Italic")
     * @param {Integer} [quality] Text rendering quality hint
     * @param {Integer|String} [alignmentH] Horizontal alignment
     * @param {Integer|String} [alignmentV] Vertical alignment
     * @param {Float} [lineSpacing] Line spacing multiplier
     * @param {Number} [lineHeight] Explicit line height
     * @returns {Shape} this (for chaining)
     *
     * @example
     * rect.Text("Score: 100", "Gold", 16, "Segoe UI", "Bold")
     */
    Text(str?, colour?, size?, family?, style?, quality?, alignmentH?, alignmentV?, lineSpacing?, lineHeight?) {
        static FontSizeMin := 1, FontSizeMax := 16384
        local fontId

        IsSet(lineSpacing) && this.lineSpacing := lineSpacing
        IsSet(lineHeight) && this.lineHeight := lineHeight

        if (IsSet(style)) {
            if (IsInteger(style)) {
                ; Numeric style flag
            }
            else if (style == "" || style = "normal" || style = "regular") {
                style := 0
            }
            else if (Font.Style.HasOwnProp(style)) {
                style := Font.Style.%style%
            }
            else {
                throw ValueError("[!] Invalid font style: " style)
            }
        }
        else {
            style := (IsObject(this.Font) && this.Font.HasProp("style")) ? this.Font.style : (IsObject(Font.default) && Font.default.HasProp("style") && Font.Style.HasOwnProp(Font.default.style) ? Font.Style.%(Font.default.style)% : 0)
        }
            
        if (IsSet(quality)) {
            if (quality < 0 || quality > 5)
                throw ValueError("[!] Invalid rendering quality value")
            this.__strQ := quality
        }
        quality := this.__strQ

        if (IsSet(alignmentH)) {
            if (IsInteger(alignmentH) && (alignmentH >= 0 && alignmentH <= 2))
                this.strH := alignmentH
            else if (alignmentH is String && RegExMatch(alignmentH, "i)^(left|center|right|near|middle|far)$"))
                this.strH := alignmentH
            else
                throw ValueError("[!] Invalid horizontal alignment value: " alignmentH)
        }
        else {
            alignmentH := this.strH
        }

        if (IsSet(alignmentV)) {
            if (IsInteger(alignmentV) && (alignmentV >= 0 && alignmentV <= 2))
                this.strV := alignmentV
            else if (alignmentV is String && RegExMatch(alignmentV, "i)^(top|center|bottom|middle|up|down)$"))
                this.strV := alignmentV
            else
                throw ValueError("[!] Invalid vertical alignment value: " alignmentV)
        }
        else {
            alignmentV := this.strV
        }

        if (IsSet(colour)) {
            colour := itoARGB(Color(colour))
        }
        else {
            colour := (IsObject(this.Font) && this.Font.HasProp("colour")) ? this.Font.colour : ((IsObject(this.Font) && this.Font.HasProp("color")) ? this.Font.color : (IsObject(Font.default) ? Font.default.colour : 0xFFFFFFFF))
            colour := itoARGB(Color(colour))
        }

        size   := IsSet(size)   ? size   : ((IsObject(this.Font) && this.Font.HasProp("size")) ? this.Font.size : (IsObject(Font.default) ? Font.default.size : 10))
        family := IsSet(family) ? family : ((IsObject(this.Font) && this.Font.HasProp("family")) ? this.Font.family : (IsObject(Font.default) ? Font.default.family : "Segoe UI"))

        fontId := family "|" size "|" style
        if (!IsObject(this.Font) || !this.Font.HasProp("id") || this.Font.id !== fontId) {
            if (IsObject(this.Font))
                Font.Release(this.Font)
            this.Font := Font(family, size, style)
            if (!IsObject(this.Font))
                this.Font := Font.getStock()
        }

        this.__textColor := colour
        if (IsObject(this.Font)) {
            this.Font.colour := colour
            this.Font.color  := colour
            if (this.Font.HasProp("pBrush") && this.Font.pBrush) {
                DllCall("gdiplus\GdipSetSolidFillColor", "ptr", this.Font.pBrush, "int", colour)
            }
        }

        if (IsSet(str)) {
            this.str := str
        }    
        else if (this.str !== "") {
            this.PrepareTextLayout()
        }

        return this
    }

    /**
     * Calculates the exact pixel bounding box of a character range with zero GDI+ calls.
     *
     * @param {Integer} startChar 1-based character index in visible text
     * @param {Integer} [charLen=1] Number of characters to measure
     * @returns {Object} { x, y, w, h, line, found, rects }
     */
    GetTextRangeRect(startChar, charLen := 1) => TextLayout.GetRangeRect(this, startChar, charLen)

    /**
     * Finds a word in the text and returns its exact pixel bounding box.
     *
     * @param {String} word Word or phrase to locate
     * @param {Integer} [occurrence=1] 1-based instance index
     * @returns {Object} { x, y, w, h, line, found, rects }
     */
    GetWordRect(word, occurrence := 1) {
        local rawText := this.__textRaw
        if (rawText == "" || word == "")
            return { x: 0, y: 0, w: 0, h: 0, line: 0, found: false, rects: [] }

        local startPos := 1, matchPos := 0, count := 0
        local wordLen := StrLen(word)

        while (count < occurrence) {
            matchPos := InStr(rawText, word, false, startPos)
            if (!matchPos)
                return { x: 0, y: 0, w: 0, h: 0, line: 0, found: false, rects: [] }
            count += 1
            startPos := matchPos + wordLen
        }

        return this.GetTextRangeRect(matchPos, wordLen)
    }

    /**
     * Gets the exact pixel (x, y) coordinates of a character for caret cursor positioning.
     *
     * @param {Integer} charIndex 1-based character index
     * @returns {Object} { x, y, h, line }
     */
    GetCharPos(charIndex) {
        local r := this.GetTextRangeRect(charIndex, 1)
        return { x: r.x, y: r.y, h: r.h, line: r.line }
    }

    /**
     * Moves and resizes the shape on its parent layer.
     *
     * @param {Integer|String} [x] New X position or delta ("+10", "-5")
     * @param {Integer|String} [y] New Y position or delta
     * @param {Integer|String} [w] New width or delta
     * @param {Integer|String} [h] New height or delta
     * @returns {Shape} this (for chaining)
     */
    Move(x?, y?, w?, h?) {
        static calc(current, val) {
            if (val is String) {
                if (SubStr(Trim(val), 1, 1) ~= "^[+-]$")
                    return current + val
            }
            return val + 0
        }

        IsSet(x) && this.x := calc(this.x, x)
        IsSet(y) && this.y := calc(this.y, y)
        IsSet(w) && this.w := calc(this.w, w)
        IsSet(h) && this.h := calc(this.h, h)
        return this
    }

    /**
     * Attaches an image/bitmap to the shape.
     *
     * @param {String|Integer|Object} source File path, HWND, HBITMAP, HICON, screen rect, or Bitmap
     * @param {Integer|String} [option=0] Scaling percentage or explicit "w100 h50"
     * @param {String} [effect=0] Color matrix effect ("grayscale", "sepia", "invert")
     * @param {Integer} [x=0] Horizontal offset within shape
     * @param {Integer} [y=0] Vertical offset within shape
     * @returns {Shape} this (for chaining)
     */
    AddImage(source, option := 0, effect := 0, x := 0, y := 0) {
        local bmp, maxW, maxH, scale, targetW, targetH

        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("Dispose")) {
            this.Bitmap.Dispose()
        }
        this.Bitmap := 0
        this.pBitmap := 0

        this.bmpX := x
        this.bmpY := y

        if (IsObject(source) && source.HasProp("Bitmap") && IsObject(source.Bitmap) && source.Bitmap.HasProp("ptr") && source.Bitmap.ptr) {
            bmp := source.Bitmap.Clone()
            if (source.HasProp("Visible"))
                source.Visible := false
        }
        else if (IsObject(source) && (source is GdipBitmap || (source.HasProp("ptr") && !source.HasProp("shape")))) {
            bmp := source
        }
        else {
            bmp := GdipBitmap(source)
        }

        if (!bmp || !bmp.ptr)
            return this

        if (!option) {
            maxW := this.w * 0.95
            maxH := this.h * 0.95
            scale := (bmp.w && bmp.h) ? Min(maxW / bmp.w, maxH / bmp.h) : 1
            targetW := Max(1, Round(bmp.w * scale))
            targetH := Max(1, Round(bmp.h * scale))
            if ((targetW != bmp.w || targetH != bmp.h || effect) && targetW > 0 && targetH > 0) {
                bmp.Resize("w" . targetW . " h" . targetH, effect)
            }
            this.Bitmap := bmp
            this.pBitmap := bmp.ptr
        }
        else {
            if (option || effect) {
                bmp.Resize(option, effect)
            }
            this.Bitmap := bmp
            this.pBitmap := bmp.ptr
        }
        return this
    }

    Image(source, option := 0, effect := 0, x := 0, y := 0) => this.AddImage(source, option, effect, x, y)

    /**
     * Applies a 256-entry Color Lookup Table (LUT) adjustment directly to this shape's bitmap.
     *
     * @param {Array|Buffer} lutB Blue channel table
     * @param {Array|Buffer} lutG Green channel table
     * @param {Array|Buffer} lutR Red channel table
     * @param {Array|Buffer} [lutA] Alpha channel table
     * @returns {Shape} this (for chaining)
     */
    ApplyLUT(lutB, lutG, lutR, lutA?) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("ApplyLUT")) {
            this.Bitmap.ApplyLUT(lutB, lutG, lutR, lutA?)
        }
        return this
    }

    SetPixel(x, y, clr) {
        if (!IsObject(this.Bitmap) || !this.Bitmap.HasProp("ptr") || !this.Bitmap.ptr) {
            this.Bitmap := GdipBitmap(Max(1, Integer(this.w)), Max(1, Integer(this.h)))
            this.pBitmap := this.Bitmap.ptr
        }
        return this.Bitmap.SetPixel(x, y, clr)
    }

    GetPixel(x, y, outFormat := "hex") {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("GetPixel"))
            return this.Bitmap.GetPixel(x, y, outFormat)
        return 0
    }

    Resize(option := 0, cmatrix := 0) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("Resize")) {
            this.Bitmap.Resize(option, cmatrix)
            this.pBitmap := this.Bitmap.ptr
        }
        return this
    }

    RotateFlip(flip := 1) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("RotateFlip"))
            this.Bitmap.RotateFlip(flip)
        return this
    }

    Clone(x?, y?, w?, h?) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("Clone"))
            return this.Bitmap.Clone(x?, y?, w?, h?)
        return 0
    }

    Crop(x, y, w, h) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("Crop")) {
            local cropped := this.Bitmap.Crop(x, y, w, h)
            if (cropped) {
                this.Bitmap.Dispose()
                this.Bitmap := cropped
                this.pBitmap := cropped.ptr
            }
        }
        return this
    }

    ToFile(filepath) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("ToFile"))
            return this.Bitmap.ToFile(filepath)
        return false
    }

    ToASCII(targetW := 80, targetH?, ramp := " .:-=+*#@", colored := false, doubleChar := false) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("ToASCII"))
            return this.Bitmap.ToASCII(targetW, targetH?, ramp, colored, doubleChar)
        return ""
    }

    PixelSearch(color, variation := 0, startX := 0, startY := 0, endX := 0, endY := 0) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("PixelSearch"))
            return this.Bitmap.PixelSearch(color, variation, startX, startY, endX, endY)
        return false
    }

    PixelCount(color, variation := 0) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("PixelCount"))
            return this.Bitmap.PixelCount(color, variation)
        return 0
    }

    LockBits(x := 0, y := 0, w := 0, h := 0, lockMode := 3, pixelFormat := 0x26200A) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("LockBits"))
            return this.Bitmap.LockBits(x, y, w, h, lockMode, pixelFormat)
        return 0
    }

    UnlockBits(bitmapData) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("UnlockBits"))
            return this.Bitmap.UnlockBits(bitmapData)
        return 0
    }

    ToClipboard() {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod("ToClipboard"))
            return this.Bitmap.ToClipboard()
        if (this.layerPtr) {
            local lyr := ObjFromPtrAddRef(this.layerPtr)
            if (IsObject(lyr))
                return lyr.ToClipboard(true)
        }
        return false
    }

    Show() {
        this.Visible := 1
        return this
    }

    Hide() {
        this.Visible := 0
        return this
    }

    ShowHide() {
        this.Visible ^= 1
        return this
    }

    SavePos(toArray := false) {
        return (toArray) ? [this.x, this.y, this.w, this.h]
            : { x: this.x, y: this.y, w: this.w, h: this.h }
    }

    RestorePos(obj) {
        if (Type(obj) == "Object") {
            (obj.HasOwnProp("x")) ? this.x := obj.x : 0
            (obj.HasOwnProp("y")) ? this.y := obj.y : 0
            (obj.HasOwnProp("w")) ? this.w := obj.w : 0
            (obj.HasOwnProp("h")) ? this.h := obj.h : 0
        }
        else if (Type(obj) == "Array") {
            (obj.Has(1)) ? this.x := obj[1] : 0
            (obj.Has(2)) ? this.y := obj[2] : 0
            (obj.Has(3)) ? this.w := obj[3] : 0
            (obj.Has(4)) ? this.h := obj[4] : 0
        }
        return obj
    }

    Position(x := 'center', y := 'center') {
        local layerObj := ObjFromPtrAddRef(this.layerPtr)
        if (Type(x) == 'String' || Type(y) == 'String') {
            if x ~= 'i)c(ent(er)?)?' && y ~= 'i)c(ent(er)?)?' {
                this.x := (layerObj.w - this.w) // 2
                this.y := (layerObj.h - this.h) // 2
            }
            else if x ~= 'i)c(ent(er)?)?' {
                this.x := (layerObj.w - this.w) // 2
                this.y := y ? IsFloat(y) ? Ceil(y) : y : this.y
            }
            else if y ~= 'i)c(ent(er)?)?' {
                this.y := (layerObj.h - this.h) // 2
                this.x := x ? IsFloat(x) ? Ceil(x) : x : this.x
            }
        } else if IsInteger(x) && IsInteger(y) {
            this.x := x
            this.y := y
        } else if IsFloat(x) && IsFloat(y) {
            this.x := Ceil(x)
            this.y := Ceil(y)
        } else
            throw Error('Position coordinates must be integer, float, or "center".')
        layerObj := ""
        return this
    }

    /**
     * Sets a native vector event handler evaluated in < 50 nanoseconds via direct WindowProc hit testing.
     *
     * @param {String} [event="Click"] "Click", "LeftMouseDown", "LeftMouseUp", "RightMouseDown", "MouseEnter", "MouseLeave", "MouseMove", "MouseScroll"
     * @param {Function} [fn] Callback function executed when event occurs
     * @param {Array} params Additional parameters to pass to fn
     * @returns {Shape} this (for chaining)
     */
    OnEvent(event := "Click", fn?, params*) {
        if (IsSet(fn)) {
            if (!this.eventMap)
                this.eventMap := Map()
            
            local wrappedFn, maxP
            if (params.Length) {
                wrappedFn := ((s, mx, my) => (fn)(params*))
            } else if (HasProp(fn, "MaxParams")) {
                maxP := fn.MaxParams
                wrappedFn := (maxP == 0) ? ((s, mx, my) => (fn)())
                           : (maxP == 1) ? ((s, mx, my) => (fn)(s))
                           : (maxP == 2) ? ((s, mx, my) => (fn)(s, mx))
                           : fn
            } else {
                wrappedFn := fn
            }

            switch event, 0 {
                case "click", "leftclick":
                    this.eventMap["Click"] := wrappedFn
                case "lbuttondown", "leftmousedown", "down":
                    this.eventMap["LeftMouseDown"] := wrappedFn
                case "lbuttonup", "leftmouseup", "up":
                    this.eventMap["LeftMouseUp"] := wrappedFn
                case "rclick", "rightclick", "rbuttonup", "rightmouseup":
                    this.eventMap["RightMouseUp"] := wrappedFn
                case "rbuttondown", "rightmousedown":
                    this.eventMap["RightMouseDown"] := wrappedFn
                case "dblclick", "doubleclick", "leftmousedoubleclick":
                    this.eventMap["LeftMouseDoubleClick"] := wrappedFn
                case "hover", "mouseenter", "mouseover":
                    this.eventMap["MouseEnter"] := wrappedFn
                case "leave", "mouseleave", "mouseout":
                    this.eventMap["MouseLeave"] := wrappedFn
                case "inside", "mouseinside":
                    this.Hover(fn, (params.Length) ? params[1] : unset)
                case "move", "mousemove":
                    this.eventMap["MouseMove"] := wrappedFn
                case "wheel", "mousewheel", "scroll":
                    this.eventMap["MouseScroll"] := wrappedFn
                default:
                    this.eventMap[event] := wrappedFn
            }
        }
        return this
    }

    /**
     * Attaches interactive mouse hover color feedback with zero-allocation brush switching.
     *
     * @param {Integer|String} hoverColour Color to show when mouse enters the shape
     * @param {Integer|String} [normalColour] Original color to restore (defaults to current color)
     * @returns {Shape} this
     */
    Hover(hoverColour, normalColour?) {
        local clrNormal := (IsSet(normalColour)) ? Color(normalColour) : this.colour
        local clrHover := Color(hoverColour)

        this._hoverNormalClr := clrNormal
        this._hoverActiveClr := clrHover

        if (IsSet(normalColour))
            this.colour := clrNormal

        this.OnEvent("MouseEnter", (shp, mx, my) => (shp.colour := shp._hoverActiveClr, shp.RedrawLayer()))
        this.OnEvent("MouseLeave", (shp, mx, my) => (shp.colour := shp._hoverNormalClr, shp.RedrawLayer()))
        return this
    }

    /**
     * Attaches interactive mouse hover opacity/alpha feedback.
     *
     * @param {Integer} [hoverAlpha=255] Alpha when hovered (0-255)
     * @param {Integer} [normalAlpha] Alpha when unhovered (0-255)
     * @returns {Shape} this
     */
    HoverAlpha(hoverAlpha := 255, normalAlpha?) {
        local curClr := this.colour
        local baseRGB := curClr & 0x00FFFFFF
        local clrNorm := IsSet(normalAlpha) ? ((normalAlpha << 24) | baseRGB) : curClr
        local clrHov  := (hoverAlpha << 24) | baseRGB

        if (IsSet(normalAlpha))
            this.colour := clrNorm

        return this.Hover(clrHov, clrNorm)
    }

    /**
     * Fluent hover configuration method for shapes and buttons with optional click handler.
     *
     * @param {Integer|String} hoverColour Color to show on hover
     * @param {Integer|String} [normalColour] Normal color to restore on leave
     * @param {Function} [onClick] Optional click callback function
     * @returns {Shape} this (for chaining)
     */
    OnHover(hoverColour, normalColour?, onClick?) {
        this.Hover(hoverColour, normalColour?)
        if (IsSet(onClick))
            this.OnClick(onClick)
        return this
    }

    TextOffset(dx := 0, dy := 0) {
        this.strX += dx
        this.strY += dy
        return this
    }
    Shift(dx := 0, dy := 0) => this.TextOffset(dx, dy)

    OnClick(fn, params*) => this.OnEvent("Click", fn, params*)

    /**
     * Binds a reactive Signal to a shape property or updater function.
     * Modifying sig.Value automatically updates the shape and redraws its parent layer.
     *
     * @param {Signal} sig The Signal instance to watch
     * @param {Function} [fn] Callback: fn(val, shape). If omitted, updates shape.str
     * @returns {Shape} this
     */
    Bind(sig, fn?) {
        if (IsObject(sig) && sig.HasMethod("Subscribe")) {
            if (IsSet(fn)) {
                sig.Subscribe((val) => (fn(val, this), this.RedrawLayer()))
            }
            else {
                sig.Subscribe((val) => (this.str := String(val), this.RedrawLayer()))
            }
        }
        return this
    }

    /**
     * Triggers an immediate redraw of the shape's parent layer.
     *
     * @returns {void}
     */
    RedrawLayer() {
        if (this.layerPtr) {
            try {
                local lyr := ObjFromPtrAddRef(this.layerPtr)
                if (IsObject(lyr) && !lyr.isDisposed)
                    Draw(lyr)
                lyr := ""
            }
        }
    }

    /**
     * Moves this shape to the top of its parent layer's drawing order (renders last, on top of other shapes).
     *
     * @returns {Shape} this
     *
     * @example
     * card.BringToFront()
     */
    BringToFront() {
        if (this.layerPtr) {
            try {
                local lyr, idx, shp
                lyr := ObjFromPtrAddRef(this.layerPtr)
                if (IsObject(lyr) && !lyr.isDisposed && lyr.HasProp("shapes") && lyr.shapes is Array) {
                    for idx, shp in lyr.shapes {
                        if (shp == this) {
                            lyr.shapes.RemoveAt(idx)
                            lyr.shapes.Push(this)
                            break
                        }
                    }
                }
                lyr := ""
            }
        }
        return this
    }

    /**
     * Moves this shape to the bottom of its parent layer's drawing order (renders first, behind other shapes).
     *
     * @returns {Shape} this
     *
     * @example
     * background.SendToBack()
     */
    SendToBack() {
        if (this.layerPtr) {
            try {
                local lyr, idx, shp
                lyr := ObjFromPtrAddRef(this.layerPtr)
                if (IsObject(lyr) && !lyr.isDisposed && lyr.HasProp("shapes") && lyr.shapes is Array) {
                    for idx, shp in lyr.shapes {
                        if (shp == this) {
                            lyr.shapes.RemoveAt(idx)
                            lyr.shapes.InsertAt(1, this)
                            break
                        }
                    }
                }
                lyr := ""
            }
        }
        return this
    }

    /**
     * Converts the current shape into an interactive button with centered label and hover/click feedback.
     *
     * @param {String} [label=""] Text to display on the button
     * @param {Function} [onClick] Function to execute when clicked
     * @param {Integer|String} [hoverColour] Background color when hovered
     * @param {Integer|String} [textColour="0xFFFFFFFF"] Label text color
     * @param {Integer} [fontSize=10] Font size
     * @param {String} [fontFamily="Segoe UI"] Font family
     * @returns {Shape} this
     *
     * @example
     * rect.Button("Submit", () => MsgBox("Clicked!"))
     */
    Button(label := "", onClick?, hoverColour?, textColour := "0xFFFFFFFF", fontSize := 10, fontFamily := "Segoe UI") {
        if (label !== "") {
            this.Text(label, textColour, fontSize, fontFamily, "Bold")
            this.Center()
        }

        local hovClr := (IsSet(hoverColour)) ? hoverColour : "0xFF403C58"
        this.Hover(hovClr)

        if (IsSet(onClick))
            this.OnClick(onClick)

        return this
    }

    CtrlUpdate() => this

    /**
     * Animates a numerical property of this shape smoothly over time using delta-time and easing curves.
     *
     * @param {String} propName Property name (e.g. "h", "w", "x", "y", "Alpha")
     * @param {Number} toVal Target value
     * @param {Integer} [durationMs=400] Duration in milliseconds
     * @param {String|Function} [easing="easeInOut"] Easing type ("linear", "easeIn", "easeOut", "easeInOut", "sine", "bounce")
     * @param {Function} [onDone] Callback executed on completion: fn(shape)
     * @returns {Shape} this (for chaining)
     */
    Animate(propName, toVal, durationMs := 400, easing := "easeInOut", onDone?) {
        local fromVal := this.%propName%
        local sig := Signal(fromVal)
        sig.Subscribe((val) => (
            this.%propName% := val,
            this.RedrawLayer()
        ))
        Signal.Animate(sig, fromVal, toVal, durationMs, easing, (*) => (
            IsSet(onDone) && (onDone)(this)
        ))
        return this
    }

    /**
     * Smoothly rolls down / reveals the shape from top to bottom over time.
     *
     * @param {Integer} [durationMs=400] Animation duration in ms
     * @param {String} [easing="easeOut"] Easing type
     * @param {Function} [onDone] Callback on completion
     * @returns {Shape} this
     */
    RollDown(durationMs := 400, easing := "easeOut", onDone?) {
        local targetH := this.HasProp("__targetH") ? this.__targetH : (this.h > 0 ? this.h : 100)
        this.__targetH := targetH
        this.h := 0
        this.Visible := true
        return this.Animate("h", targetH, durationMs, easing, onDone?)
    }

    /**
     * Smoothly rolls up / collapses the shape to 0 height over time.
     *
     * @param {Integer} [durationMs=400] Animation duration in ms
     * @param {String} [easing="easeIn"] Easing type
     * @param {Function} [onDone] Callback on completion
     * @returns {Shape} this
     */
    RollUp(durationMs := 400, easing := "easeIn", onDone?) {
        if (this.h > 0)
            this.__targetH := this.h
        return this.Animate("h", 0, durationMs, easing, (shp) => (
            shp.Visible := false,
            IsSet(onDone) && (onDone)(shp)
        ))
    }

    /**
     * Smoothly fades in the shape from 0 alpha to target opacity.
     *
     * @param {Integer} [durationMs=300] Duration in ms
     * @param {Integer} [targetAlpha=255] Target alpha (0..255)
     * @param {Function} [onDone] Callback on completion
     * @returns {Shape} this
     */
    FadeIn(durationMs := 300, targetAlpha := 255, onDone?) {
        this.Alpha := 0
        this.Visible := true
        return this.Animate("Alpha", targetAlpha, durationMs, "easeOut", onDone?)
    }

    /**
     * Smoothly fades out the shape from current alpha to 0.
     *
     * @param {Integer} [durationMs=300] Duration in ms
     * @param {Function} [onDone] Callback on completion
     * @returns {Shape} this
     */
    FadeOut(durationMs := 300, onDone?) {
        return this.Animate("Alpha", 0, durationMs, "easeIn", (shp) => (
            shp.Visible := false,
            IsSet(onDone) && (onDone)(shp)
        ))
    }

    Shrink(Unit := 1) {
        local fake, w, h
        h := w := 1
        this.Text()
        fake := Rectangle(this.x, this.y, this.w, this.h, '0x00FFFFFF')
        loop {
            (this.h > this.w) ? w := this.w / this.h : 0
            (this.w > this.h) ? h := this.h / this.w : 0
            (this.w > 0) ? (this.w -= Ceil(unit * w), this.x += Ceil(unit * w / 2)) : this.w := 0
            (this.h > 0) ? (this.h -= Ceil(unit * h), this.y += Ceil(unit * h / 2)) : this.h := 0
            if (!this.h || !this.w) {
                Draw(this.layerPtr)
                this.visible := 0
                return
            }
            Draw(this.layerPtr)
        }
    }

    static Shrink(unit := 1, objects*) {
        local x1, y1, x2, y2, finished, whichlayer, v, i, w, h

        for v in objects {
            if (A_Index == 1) {
                x1 := v.x
                y1 := v.y
                x2 := v.x + v.w
                y2 := v.y + v.h
            }
            (v.x < x1) ? x1 := v.x : 0
            (v.y < y1) ? y1 := v.y : 0
            (v.x + v.w > x2) ? x2 := v.x + v.w : 0
            (v.y + v.h > y2) ? y2 := v.y + v.h : 0
        }

        objects.Push(Rectangle(x1, y1, x2 - x1, y2 - y1, '0x00FFFFFF'))
        whichlayer := ""

        loop {
            i := A_Index
            finished := 0

            for v in objects {
                if (!InStr(whichlayer, v.layerPtr))
                    whichlayer .= v.LayerPtr "|"

                if (i == 1)
                    v.str := ""

                h := w := 1
                (v.h > v.w) ? w := v.w / v.h : 0
                (v.w > v.h) ? h := v.h / v.w : 0

                (v.w > 0) ? (v.w -= Ceil(unit * w), v.x += Ceil(unit * w / 2)) : v.w := 0
                (v.h > 0) ? (v.h -= Ceil(unit * h), v.y += Ceil(unit * h / 2)) : v.h := 0

                if (0 >= v.h || 0 >= v.w) {
                    finished += 1
                    v.visible := 0
                }
            }

            loop parse, whichlayer, "|" {
                if (!A_LoopField)
                    continue
                Draw((A_LoopField + 0))
                if (finished = objects.Length) {
                    for v in objects
                        v.Hide()
                    try Draw(A_LoopField)
                    return
                }
            }
        }
    }

    Grow(delay := 15.6) {
        local heightEnd := this.h
        this.h := 0
        while (heightEnd > this.h) {
            this.h := (heightEnd < this.h + A_Index) ? heightEnd : this.h + A_Index
            Draw(this.layerPtr)
            Sleep(delay)
        }	
    }

    static Grow(delay := 15.6, Objects*) {
        local v, finished, pos
        
        pos := []
        for v in Objects {
            pos.Push(v.SavePos())
            v.h := 0
            v.visible := 1
        }

        loop {
            finished := 0
            for v in Objects {
                (pos[A_Index].h == v.h) ? finished += 1 : v.h += 1
            }
            Draw(Objects[A_Index].layerPtr)

            if (finished == Objects.Length)
                return
            Sleep(delay)
        }

        for v in Objects
            v.RestorePos(pos[A_Index])
    }

    /**
     * Initializes a new Shape instance and registers it with the active layer.
     *
     * @param {Object} obj Property initializer dictionary
     */
    __New(obj) {
        local targetLayer

        if (!targetLayer := LayerStack.ActiveLayer)
            throw Error("No active Layer available for shape construction.")

        this.setMissingProp(&obj)
        this.InitializeTool()

        this.setBaseProps(obj)
        this.setUniqueProps(obj)
        
        targetLayer.Register(this)
        this.ptr := ObjPtr(this)
        this.name := this.shape . this.id
        
        this.Bitmap := { ptr: 0 }
        this.Font := Font.getStock()
        this.str := ""
        this.strX := 0
        this.strY := 0
        this.strH := Font.default.alignmentH
        this.strV := Font.default.alignmentV
        this.strQ := Font.default.quality

        this.pBitmap := 0
        this.bmpX := 0
        this.bmpY := 0
        this.bmpW := 0
        this.bmpH := 0
        this.bmpSrcX := 0
        this.bmpSrcY := 0
        this.bmpSrcW := 0
        this.bmpSrcH := 0
        this.bmpW0 := 0
        this.bmpH0 := 0

        GpGFX.DebugLog("[+] Shape created: " this.name " [ID: " this.id "]`n")
    }

    /**
     * Initializes the drawing tool (Pen or SolidBrush) based on the filled status.
     *
     * @returns {void}
     */
    InitializeTool() {
        static pensizeMin := 1, pensizeMax := 16384
        local baseType := Type(this)
        if (SubStr(baseType, 1, 6) == "Filled")
            baseType := SubStr(baseType, 7)

        if (baseType == "Text" || baseType == "Picture" || baseType == "Bitmap" || baseType == "Image" || baseType == "Container" || baseType == "Dummy" || (this.HasProp("isDummy") && this.isDummy)) {
            this.Tool := { ptr: 0, type: 0 }
            this.shape := baseType
            return
        }

        if (this.__filled == 1) {
            this.Tool := SolidBrush(this.__color)
            this.shape := "Filled" baseType
        }
        else if (!this.__filled || this.__filled > 1) {
            if (this.__filled > 1 && this.__filled <= 100) {
                this.__penwidth := this.__filled
            }
            if (this.__penwidth < pensizeMin || this.__penwidth > pensizeMax) {
                throw ValueError("[!] Invalid pen width value: " this.__penwidth)
            }
            this.Tool := Pen(this.__color, this.__penwidth)
            this.shape := baseType
        }
        else {
            throw ValueError("[!] Invalid value during tool initialization")
        }
    }

    setMissingProp(&obj) {
        local clrVal := obj.HasProp("colour") ? obj.colour : (obj.HasProp("color") ? obj.color : 0x00000000)
        this.__color := Color(clrVal)
        this.__alpha := (this.__color >> 24) & 0xFF
        this.__visible := true
        if (obj.HasProp("colour"))
            obj.DeleteProp("colour")
        if (obj.HasProp("color"))
            obj.DeleteProp("color")
        
        if (obj.HasProp("filled")) {
            this.__filled := (obj.filled == 1 || obj.filled == 0) ? obj.filled : 1
            obj.DeleteProp("filled")
        }
        else {
            this.__filled := false
        }
    
        if (obj.HasProp("penwidth")) {
            this.__penwidth := (obj.penwidth >= 1 && obj.penwidth <= 100) ? obj.penwidth : 1
            obj.DeleteProp("penwidth")
        }    
        else
            this.__penwidth := 1

        if (!obj.HasProp("x")) {
            obj.x := 0
            obj.y := 0
            obj.w := 50
            obj.h := 50
        }
    }

    setBaseProps(props) {
        local propName, propValue
        for propName, propValue in props.OwnProps() {
            this.%propName% := propValue
        }
    }

    setUniqueProps(obj) {
        local xindex, yindex, xname, yname, xoffset, yoffset

        if (this.shape ~= "Triangle|Polygon|Beziers|Lines|Curve|ClosedCurve") {
            local flatPts := [], ptNode
            if (IsObject(obj.points)) {
                for ptNode in obj.points {
                    if (IsObject(ptNode)) {
                        flatPts.Push(ptNode.HasProp("x") ? ptNode.x : ptNode[1])
                        flatPts.Push(ptNode.HasProp("y") ? ptNode.y : ptNode[2])
                    } else {
                        flatPts.Push(ptNode)
                    }
                }
            }
            
            this.points  := flatPts.Length // 2
            this.bPoints := Buffer(8 * this.points, 0)
            this.pPoints := this.bPoints.ptr

            loop this.points {
                xindex := A_Index * 2 - 1
                yindex := A_Index * 2
                xname := "x" A_Index
                yname := "y" A_Index
                xoffset := (A_Index - 1) * 8
                yoffset := xoffset + 4
                this.DefineProp(xname, {
                    get: get_ShapePoint.Bind(xoffset),
                    set: set_ShapePoint.Bind(xoffset)
                })
                this.DefineProp(yname, {
                    get: get_ShapePoint.Bind(yoffset),
                    set: set_ShapePoint.Bind(yoffset)
                })

                this.%xname% := Float(flatPts[xindex])
                this.%yname% := Float(flatPts[yindex])
            }

            if (this.shape == "Triangle" || this.shape == "FilledTriangle") {
                this.getBounds := (shp?) => getBoundsTriangle(this)
            }
            else {
                this.getBounds := (shp?) => getBoundsPoints(this)
            }
        }
        else if (this.shape == "Bezier") {
            this.getBounds := (shp?) => getBoundsBezier(this)
        }
        else if (this.shape == "Line") {
            this.getBounds := (shp?) => getBoundsLine(this)
        }
    }

    addSupplementaryProps(obj) {
        switch (this.shape) {
            case "RoundedRectangle", "FilledRoundedRectangle":
                this.r := (obj.HasProp("r")) ? obj.r : 10
            case "Polygon", "FilledPolygon", "Triangle", "FilledTriangle", "Beziers", "Lines", "Curve", "ClosedCurve", "FilledClosedCurve":
                this.pPoints := 0
                this.points := 0
                if (this.shape ~= "Polygon|FilledPolygon|ClosedCurve|FilledClosedCurve")
                    this.fillmode := (obj.HasProp("fillmode")) ? obj.fillmode : 0
                if (this.shape ~= "Curve|ClosedCurve|FilledClosedCurve")
                    this.tension := (obj.HasProp("tension")) ? obj.tension : 0.5
            case "Arc", "Pie", "FilledPie":
                this.startangle := obj.startangle
                this.sweepangle := obj.sweepangle
            case "Bezier":
                this.x1 := obj.x1
                this.y1 := obj.y1
                this.x2 := obj.x2
                this.y2 := obj.y2
                this.x3 := obj.x3
                this.y3 := obj.y3
                this.x4 := obj.x4
                this.y4 := obj.y4
            case "Line":
                this.x1 := obj.x1
                this.y1 := obj.y1
                this.x2 := obj.x2
                this.y2 := obj.y2
        }
    }

    AddSignal(fn, params*) {
        local sigObj := { shp: this, fn: fn, params: params }
        this.signals.Push(sigObj)
        if (this.layerPtr) {
            try {
                local lyr := ObjFromPtrAddRef(this.layerPtr)
                lyr.signalSequence.Push(sigObj)
                lyr := ""
            }
        }
    }

    HasSignal() => (this.signals.Length ? true : false)

    ExecuteSignals() {
        local sig
        for sig in this.signals {
            (sig.fn)(this, sig.params*)
        }
    }

    /**
     * Safely disposes shape resources, detached font reference counts, tools, and underlying bitmaps.
     *
     * @returns {void}
     */
    Dispose() {
        if (this.isDisposed)
            return
        this.isDisposed := true

        if (this.HasProp("Font") && IsObject(this.Font)) {
            Font.Release(this.Font)
            this.Font := 0
        }

        if (this.layerPtr) {
            try {
                local layerObj := ObjFromPtrAddRef(this.layerPtr)
                if (IsObject(layerObj) && !layerObj.isDisposed)
                    layerObj.Unregister(this.id)
                layerObj := ""
            }
            this.layerPtr := 0
        }

        if (this.HasProp("Tool") && IsObject(this.Tool) && this.Tool.HasMethod("Dispose")) {
            this.Tool.Dispose()
        }
        this.Tool := 0

        if (this.HasProp("Bitmap") && IsObject(this.Bitmap) && this.Bitmap.HasMethod("Dispose")) {
            this.Bitmap.Dispose()
        }
        this.Bitmap := 0
        this.pBitmap := 0

        if (this.HasProp("Ctrl") && this.Ctrl) {
            try this.Ctrl := 0
        }

        if (Gdip.pToken)
            GpGFX.DebugLog("[-] Shape destroyed: " this.name " [ID: " this.id "]`n")
    }

    /**
     * Dynamic method forwarder: forwards any missing method directly to the underlying GdipBitmap.
     */
    __Call(name, params) {
        if (IsObject(this.Bitmap) && this.Bitmap.HasMethod(name)) {
            return (this.Bitmap.%name%)(params*)
        }
        throw MethodError("This value of type '" Type(this) "' has no method named '" name "'.", -1, name)
    }

    __Delete() => this.Dispose()
}
