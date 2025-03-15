; Script     Layer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025
; Version    0.7.0

; Layers class contains the layers objects data.
class Layers {
    /**
     * Prototype and __Init are removed for faster lookup in Layers.OwnProps() enumeration.
     */
}

/**
 * Getter and setter for the layer class and the layers data.
 * @param Name
 * @returns {property} 
 */
get_Layer(Name, this) {
    return Layers.%this.id%.%Name%
}
set_Layer(Name, this, value) {
    Layers.%this.id%.%Name% := value 
}

/**
 * Layer class is a container for the Graphics object and shapes.  
 */
class Layer {

    ; Used to index the layer in the layers object
    static id := 0

    ; Shape creation happens based on the active layer
    static activeid := 0

    ; Prepares the layer for drawing
    Prepare() {

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
            ObjOwnPropCount(Shapes.%this.id%) * StrLen(Shape.id) * (2+1))

        ; Calculate the bounds of the layer
        for k, v in Shapes.%this.id%.OwnProps() {
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

            ; TODO: measure again the differences, remove pipe with a fixed length id
            str .= v.id "|"
        }

        DIBw := Graphics.%this.id%.w
        DIBh := Graphics.%this.id%.h
        
        ; Calculate the width and height of the layer, drawing outside of the DIB section will cause an error
        E := 0
        this.width  := (w := x2 - x1) <= DIBw ? w : (E += 1, DIBw) ; TODO can be outside of the monitor area
        this.height := (h := y2 - y1) <= DIBh ? h : (E += 2, DIBh)
        switch E {
            case 1: OutputDebug("[!] Increase DIBw`n")
            case 2: OutputDebug("[!] Increase DIBh`n")
            case 3: OutputDebug("[!] Increase DIBw and DIBh`n")
        }

        this.x1 := x1
        this.y1 := y1
        this.x2 := x2 
        this.y2 := y2

        this.prepared := SubStr(str, 1, -1)
        return
    }

    /**
     * Resizes the layer and its Graphics object.
     * @param w width of the layer.
     * @param h height.
     * @returns {Layer} Resize and center can be chained.
     */
    Resize(w, h) {
        Graphics.%this.id% := ""
        Graphics.%this.id% := Graphics(w, h)
        this.w := w
        this.h := h
        this.Prepare()
        return this
    }

    /**
     * Centers the layer on the screen.
     * @returns {Layer} Center and resize can be chained.
     */
    Center() {
        this.x := (A_ScreenWidth  - this.w) // 2
        this.y := (A_ScreenHeight - this.h) // 2
        WinMove(this.x, this.y, , , this.hwnd)
        return this
    }

    /**
     * Sets the layer position to the monitor
     * Currently only supports the primary monitor.
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

    /**
     * Debug a layer by drawing rectangles around the DIB and used area.
     * @param {int} time elapsed time in seconds before the layer is cleared.
     * @param {int} filled filled or not filled rectangles.
     * @param {int} alpha transparency of the rectangles.
     */
    Debug(time := 1, filled := 0, alpha := 0x60) {
        
        local rect1, rect2, tmpLayer
        
        ; Prepare the layer for drawing (get bounds)
        this.Prepare()
        
        ; Create a temporary objects
        tmpLayer := Layer(this.x, this.y, this.w, this.h)
       
        ; Shapes, with indicator text
        rect1 := Rectangle(0, 0, this.w, this.h, 'blue')
        rect2 := Rectangle(this.x1, this.y1, this.width, this.height, "red", filled)
        rect1.Text("Layer DIB size", "black", 42)
        rect2.Text("Layer used size", "black", 21)
        rect1.alpha := alpha
        rect2.alpha := alpha

        ; Draw and return
        tmpLayer.Draw()
        Sleep(time * 1000)
        return
    }

    ; Layer-window visibility, and accessiblity methods
    ; credit: iseahound
    Show() {
        DllCall('ShowWindow', 'ptr', this.hwnd, 'int', 4) ; NA - No Activate
        this.visible := 1
    }

    Hide() {
        DllCall('ShowWindow', 'ptr', this.hwnd, 'int', 0) ; SW_HIDE - Hide
        this.visible := 0
    }

    ShowHide() {
        (this.visible) ? this.Hide() : this.Show()
        ; TODO: this.TextVisible := !this.TextVisible
    }

    Clickthrough(v) {
        WinSetExStyle((v) ? +0x20 : -0x20, this.hWnd)
    }

    TopMost() {
        WinSetAlwaysOnTop(1, this.hwnd)
    }

    NoActivate() {
        WinSetExStyle(0x8000000, this.hwnd)
    }

    AlwaysOnTop() {
        WinSetAlwaysOnTop(-1, this.hwnd)
    }


    ; Saves the position of the layer to an array or object
    SavePos(arr := false) {
        return (arr) ? [this.x, this.y, this.w, this.h]
                     : {x : this.x, y : this.y, w : this.w, h : this.h}
    }

    ; Restores the position of the layer from an array or object
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

    ; Clears the layer by setting the alpha to zero
    ; credit: iseahound
    Clean() {
        DllCall('UpdateLayeredWindow'
            ,    'ptr', this.hWnd            ; hWnd
            ,    'ptr', 0                    ; hdcDst
            ,    'ptr', 0                    ; *pptDst
            ,    'ptr', 0                    ; *psize
            ,    'ptr', 0                    ; hdcSrc
            ,    'ptr', 0                    ; *pptSrc
            ,   'uint', 0                    ; crKey
            ,  'uint*', 0 << 16 | 0x01 << 24 ; *pblend
            ,   'uint', 2                    ; dwFlags
            ,    'int')                      ; Success = 1
    }

    ;{ Property setters

    ; Hidden layers will be skipped during the drawing
    set_Visible(value) {
        if (IsBool(value))
            Layers.%this.id%.Visible := value
    }

    ; Enables overdraw the Graphics
    set_Redraw(value) {
        if (IsBool(value))
            Layers.%this.id%.Redraw := value
    }

    ; Sets the update frequency of the layer (draws, not ms)
    set_Alpha(value) {
        if (value <= 255 && value >= 0)
            Layers.%this.id%.Alpha := value
    }
    ;}

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
     */
    __New(x?, y?, w?, h?, name := "") {

        local win, hwnd

        local props, getter, setter

        ; Swap x, y params with w, h, enable auto-centering
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

        ; Set the layer active id, create object to layer and shape
        this.id := ++Layer.id
        Layer.activeid := this.id
        Layers.%this.id% := {}
        Shapes.%this.id% := {}

        ; Debugging purpose
        this.name := name == "" ? "layer" this.id : name 

        /** 
        * Window options
        * WS_POPUP          0x80000000  small window
        * WS_EX_LAYERED     0x80000     layered window
        * WS_EX_TOPMOST     0x8         top window
        * WS_EX_TOOLWINDOW  0x80        hide taskbar
        * credit iseahound
        */
        static style := 0x80000000, styleEx := 0x80088

        ; Create the window
        win := Gui("-caption +" style " +E" styleEx)
        win.Show("NA")
        hwnd := win.hwnd
        Layers.%this.id%.Window := win

        ; Initialize a Gdiplus Graphics object
        Graphics.%this.id% := Graphics(w, h)

        ; Blueprint of the shared properties
        props := {
            x : x, y : y,
            w : w, h : h,
            x1: 0, y1: 0,
            x2: 0, y2: 0,
            width : 0, weight : 0,
            hwnd : hwnd,
            updatefreq : 0,
            alpha : [0xFF],
            redraw : [false],
            visible : [true],
            name : name ; dbg
        }

        ; Set the properties, Array holds a unique setter
        for name, value in props.OwnProps() {
            if (Type(value) == "Array") {
                if (value.Length == 2) {
                    getter := this.%("get_" value[2])%
                } else {
                    getter := get_Layer.Bind(name)
                }
                setter := this.%("set_" name)%
                value := value[1]
            }
            else {
                setter := set_Layer.Bind(name)
                getter := get_Layer.Bind(name)
            }
            this.DefineProp(name, {get : getter, set : setter})
            this.%name% := value
        }

        ; Bind Draw to this instance
        this.Draw := Draw.Bind()

        OutputDebug("[+] Layer " this.id " created`n")
    }

    ; Deletes an instance
    __Delete() {
        local k, id := 0
        if (Layers.HasProp(this.id) && WinExist(Layers.%this.id%.hWnd)) {
           
            ; Delete the shapes and graphics
            Graphics.DeleteProp(this.id)
            Shapes.DeleteProp(this.id)
            DllCall("DestroyWindow", "ptr", Layers.%this.id%.hWnd)
            OutputDebug("[-] Window " this.id " destroyed`n")  
            
            ; The previous layer id has to be set as active again to ensure consruct new shapes on the correct layer
            for k in Layers.OwnProps() {
                if (k !== this.id) && (k !== Fps.id)
                        id := k
            }
            ; Delete and set back id
            Layers.DeleteProp(this.id)
            Layer.activeid := id
            OutputDebug("[-] Layer " this.id " deleted`n") 
        }
    }

    ; Delete layers and shapes
    static __Delete() {
        for k, v in Layers.OwnProps() {
            if (Layers.HasProp(k) && Layers.%k%.HasProp("hwnd")) { ; not proto
                Graphics.DeleteProp(k)
                Shapes.DeleteProp(k)
                DllCall("DestroyWindow", "ptr", Layers.%k%.hwnd)
                Layers.DeleteProp(k)
                n := (IsSet(n)) ? n + 1 : 1
            }
        }
        (IsSet(n)) ? OutputDebug("[-] All layers deletion, deleted: " n "`n") : ''
    }
}
