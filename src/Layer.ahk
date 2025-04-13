; Script     Layer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       13.04.2025
; Version    0.7.3

; Layers class contains the layers objects data.
class Layers {
    /**
     * Prototype and __Init are removed for faster lookup in Layers.OwnProps() enumeration.
     */
}

; Getter and setter for the layer class and the layers data.
get_Layer(name, this) {
    return Layers.%this.id%.%name%
}
set_Layer(name, this, value) {
    Layers.%this.id%.%name% := value 
}

/**
 * Layer class is a container for the Graphics object and shapes.  
 */
class Layer {

    ; Used to index the layer in the layers object
    static id := 0

    ; Shape creation happens based on the active layer
    static activeid := 0

    /**
     * Set tha alpha (transparency) of the layer.
     * @param {int} value 0-255
     */
    Alpha {
        get => Layers.%this.id%.alpha
        set => (value <= 255 && value >= 0) ? Layers.%this.id%.alpha := value : 0
    }

    /**
     * Sets the shape rendering quality of the layer.
     * @param {str} value fast or low, balanced or normal, high or quality
     */
    Quality {
        get => Layers.%this.id%.quality
        set => (value == "i)^(fast|low|balanced|normal|quality|high)$") ? Layers.%this.id%.quality := value : 0
    }

    /**
     * Sets the update frequency of the layer (draws, not ms).
     * @param {int} value
     */
    UpdateFreq {
        get => Layers.%this.id%.updatefreq
        set => (value >= 0) ? Layers.%this.id%.updatefreq := value : 0
    }

    /**
     * Enables overdraw the Graphics.
     * @param {bool} true for overdraw; default false (deletes graphics)
     */
    Redraw {
        get => Layers.%this.id%.redraw
        set => (IsBool(value)) ? Layers.%this.id%.redraw := value : 0
    }

    /**
     * Sets the visibility of the layer. Hidden layers will be skipped during draw.
     * @param {bool} value true or false
     */
    Visible {
        get => Layers.%this.id%.visible
        set => (IsBool(value)) ? Layers.%this.id%.visible := value : 0
    }

    ;{ Visibility methods

    /**
     * Visibility and accessiblity methods for the layer.  
     * In some cases Clickthrough, AlwaysOnTop, TopMost can be useful.  
     * Hide, Show, ShowHide effects the layer, you can avoid a Draw call this way.  
     * @credit iseahound - TextRender v1.9.3
     * https://github.com/iseahound/TextRender
     */

    Show() {
        DllCall("ShowWindow", "ptr", this.hwnd, "int", SW_NOACTIVATE:=4)
        this.visible := 1
    }

    Hide() {
        DllCall("ShowWindow", "ptr", this.hwnd, "int", SW_HIDE:=0)
        this.visible := 0
    }

    ShowHide() {
        (this.visible) ? this.Hide() : this.Show()
    }

    AlwaysOnTop() {
        WinSetAlwaysOnTop(-1, this.hwnd)
    }

    Clickthrough(v) {
        WinSetExStyle((v) ? +0x20 : -0x20, this.hwnd)
    }

    NoActivate() {
        WinSetExStyle(0x8000000, this.hwnd)
    }

    TopMost() {
        WinSetAlwaysOnTop(1, this.hwnd)
    }

    /**
     * Debug a layer by drawing rectangles around the DIB and used area.
     * @param {int} time elapsed time in seconds before the layer is deleted
     * @param {int} filled filled or not filled rectangles
     * @param {int} alpha transparency of the rectangles
     */
    Debug(time := 1, filled := 0, alpha := 0x60) {
        
        local rect1, rect2, lyr
        
        ; Prepare the layer for drawing. (bounds)
        Layer.Prepare(this.id)
        
        ; Create a temporary objects.
        lyr := Layer(this.x, this.y, this.w, this.h)
       
        ; Create shapes, with indicator text.
        rect1 := Rectangle(0, 0, this.w, this.h, "blue")
        rect2 := Rectangle(this.x1, this.y1, this.width, this.height, "red", filled)
        rect1.Text("Layer DIB size", "black", 42)
        rect2.Text("Layer used size", "black", 21)
        rect1.alpha := alpha
        rect2.alpha := alpha

        ; Display.
        lyr.Draw()
        Sleep(time * 1000)
        return
    }

    /**
     * Centers the layer on the screen.
     * @returns {Layer} Center and Resize methods can be chained
     */
    Center() {
        this.x := (A_ScreenWidth  - this.w) // 2
        this.y := (A_ScreenHeight - this.h) // 2
        WinMove(this.x, this.y, , , this.hwnd)
        return this
    }

    /**
     * Moves the layer to the specified position.
     * @param x coordinate
     * @param y coordinate
     * @returns {Layer} Move and Resize methods can be chained
     */
    Move(x?, y?) {
        if (IsSet(x))
            this.x := x
        if (IsSet(y))
            this.y := y
        WinMove(x?, y?, , , this.hwnd)
        return this
    }

    /**
     * Resizes the layer and its Graphics object.
     * @param w width
     * @param h height
     * @returns {Layer} Resize and center can be chained
     */
    Resize(w, h) {
        Graphics.%this.id% := ""
        Graphics.%this.id% := Graphics(w, h)
        this.w := w
        this.h := h
        Layer.Prepare(this.id)
        return this
    }

    /**
     * Sets the layer position to the monitor.  
     * Currently only supports the primary monitor, broken.
     * @param {int} disp monitor number.
     */
    setMonitor(disp := 1) {
        local x1, mon

        mon := MonitorGetCount()
        if (disp > mon || disp < 1)
            return

        MonitorGetWorkArea(disp, &x1)
        this.x := x1
        this.y := 0
        return
    }

    ; Save the position of the layer to an array or object.
    SavePos(arr := false) {
        return (arr) ? [this.x, this.y, this.w, this.h]
            : {x : this.x, y : this.y, w : this.w, h : this.h}
    }

    ; Restores the position of the layer from an array or object.
    RestorePos(obj) {
        if (Type(obj) == "Array" && obj.Length == 4) {
            this.x := obj[1], this.y := obj[2]
            this.w := obj[3], this.h := obj[4]
            return
        }
        (obj.HasOwnProp("x")) ? this.x := obj.x : 0
        (obj.HasOwnProp("y")) ? this.y := obj.y : 0
        (obj.HasOwnProp("w")) ? this.w := obj.w : 0
        (obj.HasOwnProp("h")) ? this.h := obj.h : 0
        return
    }
    ;}

    /**
     * Export the layer to PNG.
     * @credit iseahound - ImagePut v1.11
     * https://github.com/iseahound/ImagePut
     */
    toFile(filepath) {
        local pBitmap, pCodec
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", Graphics.%this.id%.hbm, "ptr", 0, "ptr*", &pBitmap:=0)
        pCodec := Buffer(16)
        ; Get the CLSID of the PNG codec.
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", pCodec, "hresult")
        DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", filepath, "ptr", pCodec, "ptr", 0)
    }

    /**
     * Clears the layer by setting the alpha to zero.
     * @credit iseahound - Textrender v1.9.3, UpdateLayeredWindow
     * https://github.com/iseahound/TextRender
     */
    Clean() {
        DllCall("UpdateLayeredWindow"
            ,    "ptr", this.hWnd                ; hWnd
            ,    "ptr", 0                        ; hdcDst
            ,    "ptr", 0                        ; *pptDst
            ,    "ptr", 0                        ; *psize
            ,    "ptr", 0                        ; hdcSrc
            ,    "ptr", 0                        ; *pptSrc
            ,   "uint", 0                        ; crKey
            ,  "uint*", 0 << 16 | 0x01 << 24     ; *pblend
            ,   "uint", 2                        ; dwFlags
            ,    "int")                          ; Success = 1
    }

    GraphicsQuality(shapeForm) {

        static setting := 0

        gfx := Graphics.%this.id%.gfx

        switch shapeForm {

            case "Rectangle":
                if (setting == 320)
                    return
                setting := 320
                ; Balanced settings for sharp-edged shapes
                DllCall('gdiplus\GdipSetSmoothingMode', 'ptr', gfx, 'int', 3)
                DllCall('gdiplus\GdipSetPixelOffsetMode', 'ptr', gfx, 'int', 2)
                DllCall('gdiplus\GdipSetInterpolationMode', 'ptr', gfx, 'int', 0)

            case "Curved":
                switch this.quality {
                    case "fast", "low":
                        if (setting == 320)
                            return
                        setting := 320
                        ; Fast settings for curved shapes
                        DllCall('gdiplus\GdipSetSmoothingMode', 'ptr', gfx, 'int', 3)
                        DllCall('gdiplus\GdipSetPixelOffsetMode', 'ptr', gfx, 'int', 2)
                        DllCall('gdiplus\GdipSetInterpolationMode', 'ptr', gfx, 'int', 0)

                    case "balanced", "normal":
                        if (setting == 224)
                            return
                        setting := 224
                        ; Balanced settings for curved shapes
                        DllCall('gdiplus\GdipSetSmoothingMode', 'ptr', gfx, 'int', 2)
                        DllCall('gdiplus\GdipSetPixelOffsetMode', 'ptr', gfx, 'int', 2)
                        DllCall('gdiplus\GdipSetInterpolationMode', 'ptr', gfx, 'int', 4)

                    case "high", "quality":
                        if (setting == 447)
                            return
                        setting := 447
                        ; High-quality settings for curved shapes
                        DllCall('gdiplus\GdipSetSmoothingMode', 'ptr', gfx, 'int', 4)
                        DllCall('gdiplus\GdipSetPixelOffsetMode', 'ptr', gfx, 'int', 4)
                        DllCall('gdiplus\GdipSetInterpolationMode', 'ptr', gfx, 'int', 7)
                }
        }
    }

    setReferenceObj() {
        Layers.%this.id% := {id: this.id
            , alpha: 0xFF, redraw: false
            , visible: true, quality : "balanced", updatefreq: 0}
    }

    ; Prepares the layer for drawing
    static Prepare(id) {

        local k, v, w, h, x1, y1, x2, y2, DIBw, DIBh, E, str

        ; Initialize variables for layer bounds
        static DIBsize := 32767
        x1 :=  DIBsize
        y1 :=  DIBsize
        x2 := -DIBsize
        y2 := -DIBsize

        ; After some tests it seems its faster to pass the shape ids as a string        
        VarSetStrCapacity(&str,
            ; (obj count * Shape's id length + pipe) * 2
            ObjOwnPropCount(Shapes.%id%) * StrLen(Shape.id) * (2 + 1))

        ; Calculate the bounds of the layer
        for k, v in Shapes.%id%.OwnProps() {
            if (!v.Visible) {
                continue
            }			
            ; Get bounds of the shapes that doesn't have x, y, w, h coordinates
            if (v.shape ~= "(Triangle|Polygon|Bezier|Line)$")
                v.getBounds()

            if (v.hasSignal)
                v.fn()

            ; It's important to calculate unique bounds and execute the signals beforehand
                  (v.x < x1) ? x1 := v.x : 0
                  (v.y < y1) ? y1 := v.y : 0
            (v.x + v.w > x2) ? x2 := v.x + v.w : 0
            (v.y + v.h > y2) ? y2 := v.y + v.h : 0

            str .= v.id "|"
        }

        DIBw := Graphics.%id%.w
        DIBh := Graphics.%id%.h
        
        ; Calculate the width and height of the layer, drawing outside of the DIB section will cause an error
        E := 0
        Layers.%id%.width  := (w := x2 - x1) <= DIBw ? w : (E += 1, DIBw) ; TODO: can be outside of the monitor area
        Layers.%id%.height := (h := y2 - y1) <= DIBh ? h : (E += 2, DIBh)
        switch E {
            ; This happens when the shapes are outside of the DIB section
            case 1: OutputDebug("[!] Increase DIBw`n")
            case 2: OutputDebug("[!] Increase DIBh`n")
            case 3: OutputDebug("[!] Increase DIBw and DIBh`n")
        }

        Layers.%id%.x1 := x1
        Layers.%id%.y1 := y1
        Layers.%id%.x2 := x2 
        Layers.%id%.y2 := y2

        return SubStr(str, 1, -1)
    }

    /**
     * Layers class contains the layers objects data.  
     * This method removes the Prototype and __Init properties for faster lookup
     * in the Layers.OwnProps() enumeration.
     */
    static __New() {
        Layers.DeleteProp("__Init")
        Layers.DeleteProp("Prototype")
    }

    /**
     * Layer is a window with a Graphics object and container for graphics objects.
     * @param {int} x position on the screen
     * @param {int} y position
     * @param {int} w width
     * @param {int} h height
     * @param {str} name debugging purpose
     * @param {int} hParent parent window
     */
    __New(x?, y?, w?, h?, name := "", hParent := 0) {

        local win, hwnd, prop, props, value

        ; Width, height provided as x and y, auto-center.
        if (IsSet(x) && IsSet(y) && !IsSet(w) && !IsSet(h)) {
            w := x
            h := y
            x := (A_ScreenWidth  - w) // 2
            y := (A_ScreenHeight - h) // 2
        }
        else {
            if (!IsSet(w))
                w := A_ScreenWidth
            if (!IsSet(h))
                h := A_ScreenHeight
            if (!IsSet(x))
                x := (A_ScreenWidth  - w) // 2
            if (!IsSet(y))
                y := (A_ScreenHeight - h) // 2
        }

        ; Set the layer active id, create object to layer and shape.
        this.id := ++Layer.id
        Layer.activeid := this.id
        Shapes.%this.id% := {}
        this.setReferenceObj()

        ; Debugging purpose.
        this.name := (name == "") ? "layer" this.id : name 

        /** 
        * Window styles, extended styles:  
        * 
        * WS_POPUP          0x80000000  small window  
        * WS_EX_LAYERED     0x80000     layered window  
        * WS_EX_TOPMOST     0x8         top window  
        * WS_EX_TOOLWINDOW  0x80        hide taskbar
        * 
        * @credit iseahound - TextRender v1.9.3, CreateWindow
        */
        static style := 0x80000000, styleEx := 0x80088

        ; Create the window.
        hParent := (hParent) ? " +parent" hParent : ""
        win := Gui("-caption +" style " +E" styleEx " +Owner " hParent)
        win.Show("NA")
        hwnd := win.hwnd
        Layers.%this.id%.Window := win

        ; Initialize a Gdiplus Graphics object.
        Graphics.%this.id% := Graphics(w, h)

        ; Blueprint of the shared properties.
        props := {
            x : x, y : y,
            w : w, h : h,
            x1: 0, y1: 0,
            x2: 0, y2: 0,
            width : 0, height : 0,
            hwnd : hwnd,
            name : name
        }

        ; Set the properties, array holds unique setters.
        for prop, value in props.OwnProps() {
            this.DefineProp(prop, {get : get_Layer.Bind(prop), set : set_Layer.Bind(prop)})
            this.%prop% := value
        }

        ; Bind Draw to this instance.
        this.Draw := Draw.Bind()
        Layers.%this.id%.GraphicsQuality := this.GraphicsQuality

        OutputDebug("[+] Layer " this.id " created`n")
    }

    ; Deletes an instance.
    __Delete() {
        local id := 0
        local k
        
        ; Layer may not exist.
        if (Layers.HasProp(this.id) && WinExist(Layers.%this.id%.hWnd)) {
           
            ; Delete the graphics, and shapes.
            Graphics.DeleteProp(this.id)
            Shapes.DeleteProp(this.id)
            DllCall("DestroyWindow", "ptr", Layers.%this.id%.hWnd)
            OutputDebug("[-] Window " this.id " destroyed`n")  
            
            ; The previous layer id has to be set as active again to ensure
            ; new shapes spawn on the correct layer.
            for k in Layers.OwnProps() {
                if (k !== this.id) && (k !== Fps.id)
                    id := k
            }
            ; Delete and set back id.
            Layers.DeleteProp(this.id)
            Layer.activeid := id

            OutputDebug("[-] Layer " this.id " deleted`n") 
        }
    }

    ; Delete layers and shapes.
    static __Delete() {
        local id
        for id in Layers.OwnProps() {
            if (Layers.%id%.HasProp("hwnd")) {
                Graphics.DeleteProp(id)
                Shapes.DeleteProp(id)
                DllCall("DestroyWindow", "ptr", Layers.%id%.hwnd)
                Layers.DeleteProp(id)
                OutputDebug("[-] All layers deletion, deleted: " id "`n")
            }
        }
    }
}