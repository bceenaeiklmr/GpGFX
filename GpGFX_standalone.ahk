; Script     GpGFX_standalone.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       13.04.2025
; Version    0.7.3

/**
 * Wanted to say thank you for everyone who contributes to the AHK community.
 * @credit iseahound: Graphics, Textrender, ImagePut
 * 		   https://github.com/iseahound thank you for your work.
 * 
 * @credit tic: for creating the Gdip library  (Gdip)
 * @credit for contributing to the library https://github.com/mmikeww/AHKv2-Gdip
 *         mmikeww, buliasz, nnnik, AHK-just-me, sswwaagg, Rseding91,
 *         let me know if I missed someone. Thank you guys.
 * 
 * Special thanks to: GeekDude, mcl, mikeyww, neogna2, robodesign, SKAN, Helgef.
 * Finally, Lexikos for creating and maintaining AutoHotkey v2.
 */

; See the examples for further information.

#Requires AutoHotkey v2
#Warn

; Preload the Gdiplus library.
#DllLoad Gdiplus.dll
if (!DllCall("GetModuleHandle", "str", "Gdiplus.dll")) {
    ; Loading the library manually can be implemented here if needed.
    MsgBox("In-built command failed to load Gdiplus.dll.`n"
        . "The program will exit.")
    ExitApp()
}

; Startup.
Gdip.Startup()
OnExit(ExitFn)
SetWinDelay(0)
OutputDebug("[i] GpGFX started...`n")


; Global hotkeys:
; Note: Any hotkey will hang the script. Use with caution.
; I recommend using hotkeys in the other script, that includes GpGFX.ahk.
;^esc::ExitApp


; Release resources on program exit.
ExitFn(*) {
    ; Overkill, but does the job for now, layers and especially fonts
    ; didn't not get deleted properly in some cases.
    ;GoodBye() ; Comment this line out if you want to see the exit message
    Fps.__Delete()
    Font.__Delete()
    Layer.__Delete()
    Gdip.ShutDown()
    OutputDebug("[i] GpGFX exiting...`n")
}

/**
 * Gdiplus class handles the initialization and shutdown of Gdiplus.
 */
class Gdip {

    ; Pointer to the Gdiplus token
    static pToken := 0
    
    /**
     * Starts up Gdiplus and initializes the Gdiplus token.
     * 
     * Deprecated: https://www.autohotkey.com/boards/viewtopic.php?t=72011
     * recommended by Helgef. (AutoHotkey preloads the Gdiplus library)  
     * 
     *	if !DllCall('GetModuleHandle', 'str', 'gdiplus', 'uptr')
     *		if !DllCall('LoadLibrary', 'str', 'gdiplus', 'uptr') ; success > 0 
     *			throw Error('Gdiplus failed to load.')
     */
    static Startup() {
        gdipStartupInput := Buffer(32, 0)
        Numput("int", gdipVersion:=1, gdipStartupInput)
        DllCall("Gdiplus\GdiplusStartup", "ptr*", &pToken:=0, "ptr", gdipStartupInput, "ptr", 0)
        if (!this.pToken := pToken) {
            throw Error("Gdiplus failed to start.")
        }
        OutputDebug("[+] Gdiplus has started, token: " this.ptoken "`n")
    }

    /**
     * Shuts down Gdiplus.  
     * 
     * The load library part was removed, free library is not needed.
     * @info recommended by Helgef. Link above.
     *   
     *	if hModule := DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
     *		DllCall("FreeLibrary", "ptr", hModule)
     */
    static Shutdown(*) {
        DllCall("gdiplus\GdiplusShutdown", "ptr", this.pToken)
        OutputDebug("[-] Gdiplus has shut down, token: " this.pToken "`n")
    }
}


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


class Shapes {
    ; This class stores the shape data for the drawing process.
    ; Prototype and __Init are removed for faster lookup.
    ; TODO: implement static __Get and __Set to make it not accessible for the user
}

; Base getter and setter for the shapes properties.
get_Shape(name, this) {
    return Shapes.%this.Layerid%.%this.id%.%name%
}

set_Shape(name, this, value) {
    Shapes.%this.Layerid%.%this.id%.%name% := value
}

; For shapes that uses a buffer for points.
set_ShapePoint(name, offset, this, value) {
    NumPut("float", value, Shapes.%this.LayerId%.%this.id%.pPoints, offset)
    return Shapes.%this.LayerId%.%this.id%.%name% := value
}

/**
 * Create a grid of shapes with specified parameters.
 * @param {int} row number of rows in the grid
 * @param {int} col number of columns in the grid
 * @param {int} x   X-coordinate position (optional)
 * @param {int} y   Y-coordinate position (optional)
 * @param {int} w   width of the grid objects (optional)
 * @param {int} h   height of the grid objects (optional)
 * @param {int} pad padding around the grid objects (default is 25)
 * @returns {array}
 */
CreateGraphicsObject(row := 3, col := 3, x?, y?, w := 0, h := 0, pad := 25, colour := 0xFF000000) {

    local totalWidth, totalHeight
    local width := Layers.%Layer.Activeid%.w
    local height := Layers.%Layer.Activeid%.h
    local obj := []

    ; Calculate width and height for objects if not provided or if they are too large.
    if (!w && !h) {
        w := (width - (col + 1) * pad) // col
        h := (height - (row + 1) * pad) // row

        ; Ensure width and height are equal to maintain the shape as a square.
        if (w != h) {
            w := h := Min(w, h)
        }
    }
    ; Calculate width, and height if they are not provided.
    else if (!w) {
        w := (width - (col + 1) * pad) // col
    }
    else if (!h) {
        h := (height - (row + 1) * pad) // row
    }

    ; Calculate total grid dimensions.
    totalWidth := col * w + (col - 1) * pad
    totalHeight := row * h + (row - 1) * pad

    ; Calculate base positions for centering if x or y are not specified.
    if (!IsSet(x))
        baseX := (width - totalWidth) // 2
    else
        baseX := x

    if (!IsSet(y))
        baseY := (height - totalHeight) // 2
    else
        baseY := y

    ; Create objects.
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
 * The `Shape` class serves as a container for various shapes and their associated methods.  
 * It provides a unified interface for working with different types of shapes.
 *   
 * Shapes: `Rectangle`, `Square`, `Ellipse`, `Pie`, `Polygon`, `Triangle`, `Point`, `Line`, `Lines`, `Arc`, `Bezier`, `Beziers`.  
 * Filled Shapes: `Rectangle`, `Square`, `Ellipse`, `Pie`, `Polygon`, `Triangle`
 * 
 */
class Shape {

    ; Default values for the shape.
    static alpha := 0xFF
    static visible := true

    ;{ Properties
    /**
     * Sets the alpha value of the shape modifying the tool alpha channel.
     * @property {int} alpha
     * @example
     * this.alpha := 0xFF ; 255 (max, opaque)
     * this.alpha := 0x0  ; 0   (min, transparent)
     */
    Alpha {

        get => Shapes.%this.layerid%.%this.id%.alpha

        set {
            
            local obj, clr
            
            if (!isAlphaValue(value)) {
                throw ValueError("[!] Accepted type: integer.")
            }

            ; Return if no change in alpha value
            obj := Shapes.%this.Layerid%.%this.id%
            if (obj.alpha == value)
                return

            ; Set the new tool color and alpha value
            if (obj.Tool.type == 0 || obj.Tool.type == 5) {
                obj.Tool.color := (obj.color & 0x00FFFFFF) | (value << 24)
            }
            else if (obj.Tool.type == 4) {
                clr :=  obj.Tool.color
                clr[1] := (clr[1] & 0x00FFFFFF) | (value << 24)
                clr[2] := (clr[2] & 0x00FFFFFF) | (value << 24)
                obj.Tool.color := clr
            }
            else {
                throw ValueError("[!] Only Pen, SolidBrush," .
                    "and LinearGradientBrush supported.")
            }

            obj.alpha := value
        }
    }

    /**
     * @property {int|str} Color
     * @example
     * ; Solid Brush, Pen:
     * this.Color := ""                   ; Random color
     * this.Color := "Lime"               ; Color name by calling the color class
     * this.Color := Color.Lime           ; Direct access to value by name
     * this.Color := "red|blue|green"     ; Random color from multiple names
     * this.Color := "0xFF0000FF"         ; 0xARGB
     * this.Color := "#FF0000FF"          ; #ARGB
     * this.Color := "0x0000FF"           ; 0xRGB
     * this.Color := "#0000FF"            ; #RGB
     * this.Color := 0xFF000000           ; Hex
     * 
     * ; Linear Gradient: [["Gradient"], foreARGB, backARGB, [GradientMode]]
     * ; Horizontal = 0, Vertical = 1, ForwardDiagonal = 2, BackwardDiagonal = 3
     * this.Color := ["Gradient", "Red", "Blue"]
     * this.Color := ["Red", "Blue"] ; Gradient keyword can be omitted
     * this.Color := ["Gradient", "Red", "Blue", 1] ; Vertical gradient
     * this.Color := ["Gradient", "Red", "Blue", "ForwardDiagona"]
     * 
     * ; Hatch: ["Hatch", foreARGB, backARGB, hatchStyle]
     * ; Hatch keyword must be defined.
     * ; See tools HatchBrush for more details.
     * this.Color := ["Hatch", "Red", "Blue", 42]
     * 
     * ; Texture: ["Texture", pBitmap, wrapmode, resize, x, y, w, h]
     * ; Texture keyword must be defined.
     * ; pBitmap accepts a Bitmap object or a valid bitmap pointer or a path to an existing image file.
     * ; wrapmode how the brush is tiled (0 = Tile, 1 = Clamp)
     * this.Color := ["Texture", filePath, 0, 100, 0, 0, 100, 100] ; from file
     * this.Color := ["Texture", pBitmap, 0, 200, 0, 0, 100, 100] ; pointer to a Bitmap
     * this.Color := ["Texture", BitmapInstance, 0, 33] ; pointer to a Bitmap
     */
    Color {

        get => Shapes.%this.layerid%.%this.id%.Tool.color

        set {

            local obj

            ; SolidBrush, Pen
            if (value && Type(value) == "Integer" || (Type(value) == "String")) {

                obj := Shapes.%this.Layerid%.%this.id%
                value := Color(value)

                ; Dispose the current tool if not brush or pen
                if (!obj.Tool || obj.Tool.Type !== 0 && obj.Tool.Type !== 5) {
                    obj.Tool := ""
                    obj.Tool := (obj.Filled) ? SolidBrush(value) : Pen(value, obj.penwidth)
                }

                ; Set the color
                obj.Tool.Color := value
                return
            }
            ; GradientBrush, HatchBrush, TextureBrush
            else if (Type(value) == "Array") {

                obj := Shapes.%this.layerid%.%this.id%
                tooltype := obj.Tool.Type

                ; Append "Filled" to the shape as a prefix.
                if (!obj.filled)
                    this.shape := "Filled" this.shape

                ; The name not defined, default Linear Gradient Mode
                if (value.Length == 2) {

                    if (value[1] ~= "i)^(texture|hatch|gradient)$") {
                        throw ValueError("[!] Invalid color type")
                    }

                    ; Validate color values.
                    value[1] := Color(value[1])
                    value[2] := Color(value[2])

                    ; It's already gradient, simply set LinearGradientBrush's color property.
                    if (tooltype == 4) {
                        obj.Tool.color := [value[1], value[2]]
                        return
                    }

                    ; Set LinearGradient mode
                    value.InsertAt(1, "")
                    tooltype := 4
                }
                else {
                    switch value[1], 0 {
                        case "hatch": tooltype := 1
                        case "texture": tooltype := 2
                        case "gradient": tooltype := 4
                        default: throw ValueError
                    }
                }

                ; Dispose the current tool, and create the new one
                obj.Tool := ""

                switch tooltype {
                    case 1:
                        obj.Tool := HatchBrush(Color(value[2]), Color(value[3]), value[4])
                    case 2:
                        obj.Tool := TextureBrush(value[2],
                            value.has(3) ? value[3] : 0,
                            value.has(4) ? value[4] : 100)     ; TODO: implement fit to shape
                    case 3:
                        return
                    case 4:
                        rectF := Buffer(16),
                        NumPut("float", this.x, rectF, 0),
                        NumPut("float", this.y, rectF, 4),
                        NumPut("float", this.w, rectF, 8),
                        NumPut("float", this.h, rectF, 12),
                        obj.tool := LinearGradientBrush(color(value[2]), color(value[3])
                            , (value.Has(4)) ? value[4] : 0 ; LinearGradientMode
                            , 1 ; WrapMode
                            , rectF.ptr)
                }
            }
            return
        }
    }

    /**
     * Changes the tool between a pen and a brush based on the filled status.
     * @param {bool} value indicating whether the shape should be filled or not.  
     */
    Filled {

        get => Shapes.%this.layerid%.%this.id%.filled

        set {

            local obj, tooltype 
        
            if (!IsBool(value))
                return

            ; Get the shape reference
            obj := Shapes.%this.layerid%.%this.id%
            if ((obj.Tool.type == 0 || obj.Tool.type == 5) && obj.filled == value)
                return

            ; Save the current color and tool type before deleting the tool
            tooltype := obj.Tool.type
            if (obj.Tool.HasOwnProp("color"))
                clr := obj.Tool.color
            else
                clr := Random(0xFF000000, 0xFFFFFFFF)
            obj.Tool := ""

            ; It's a switchback from gradient to pen
            if (Type(clr) == "Array") {
                clr := clr[1]
            }

            ; Change the shape tool type
            if (value) {
                ; Append filled to the shape form
                this.shape := "Filled" this.shape
                obj.Tool := SolidBrush(clr)
            }
            else {
                ; Remove filled from the shape form
                this.shape := SubStr(this.shape, 7)
                obj.Tool := Pen(clr, obj.penwidth)
            }
            
            obj.filled := value
        }

    }

    /**
     * Sets the pen width of the shape.
     * @param {int} value - width of the pen in pixels
     */
    PenWidth {
        
        get => Shapes.%this.layerid%.%this.id%.penwidth

        set {
            if (value >= 1 && value <= 100) {
                local obj := Shapes.%this.layerid%.%this.id%
                if (obj.Tool.type == 5)
                    obj.Tool.width := value
                obj.penwidth := value
                return
            }
            throw ValueError("[!] Invalid value for PenWidth property")
        }
    }

    /**
     * Sets the visibility of the shape.  
     * @param {bool} value - The visibility state of the shape.
     */
    Visible {

        get => Shapes.%this.layerid%.%this.id%.visible

        set {
            if !(IsBool(value) || (value !== -1 || value != "toggle")) {
                return
            }
            Shapes.%this.layerid%.%this.id%.visible ^= 1
            return
        }
    }

    ; Read only properties.
    ImageWidth {
        get => Shapes.%this.layerid%.%this.id%.Bitmap.w
    }

    ImageHeight {
        get => Shapes.%this.layerid%.%this.id%.Bitmap.h
    }

    LayerWidth {
        get => Layers.%this.layerid%.w
    }

    LayerHeight {
        get => Layers.%this.layerid%.h
    }

    ToolType {
        get => Shapes.%this.layerid%.%this.id%.Tool.type
    }
    ;}

    /**
     * Allows to insert of text onto the shape.  
     * @param {str} str text
     * @param {clr} colour font brush color
     * @param {int} size font size
     * @param {str} family font family name
     * @param {str} style font style
     * @param {int} quality text rendering quality
     */
    Text(str?, colour?, size?, family?, style?, quality?) {
        
        local obj
        
        obj := Shapes.%this.Layerid%.%this.id%

        ; String.
        if (IsSet(str))
            this.str := str
        
        ; Colour.
        if (IsSet(colour))
            colour := Color(colour)
        else
            colour := obj.Font.color

        ; Size.
        if (IsSet(size)) {
            if (size < 1)
                throw ValueError("[!] Invalid font size")
        } else
            size := obj.Font.size

        ; Family.
        if (IsSet(family) && family ~= "^\d+$") 
            throw ValueError("[!] Invalid font family")
        else if (!IsSet(family))
            family := obj.Font.family

        ; Style.
        if (IsSet(style)) {
            if (!Font.style.HasOwnProp(style))
                throw ValueError("[!] Invalid font style")
            style := Font.style.%style%
        }
        else {
            style := Font.Style.%(obj.Font.style)%
        }
            
        ; Quality.
        if (IsSet(quality)) {
            if (quality < 0 || quality > 4)
                throw ValueError("[!] Invalid rendering quality value")
            if (this.strQ != quality) {
                this.strQ := quality
            }
        }
        quality := this.strQ

        ; Get a new or an existing font
        if (obj.Font.id !== (family "|" size "|" style "|" colour)) {
            if (obj.Font.id !== Font.stockid)
                Font.RemoveAccess(obj.Font.id)
            obj.Font := Font(family, size, style, colour, quality)
        }
        return
    }

    /**
     * Moves and resizes the shape object on its layer.  
     * Note: Consider using '+' and '-' signs to increment or decrement values. 
     * @param {int} x new X position on the layer (opt)
     * @param {int} y new Y position on the layer (opt)
     * @param {int} w new width of the shape (opt)
     * @param {int} h new height of the shape (opt)
     */
    Move(x?, y?, w?, h?) { ; TODO: only works with xywh shapes; implement + -
        IsSet(x) ? this.x := Type(x) !== "Integer" ? Integer(x) : x : ""
        IsSet(y) ? this.y := Type(x) !== "Integer" ? Integer(y) : y : ""
        IsSet(w) ? this.w := Type(x) !== "Integer" ? Integer(w) : w : ""
        IsSet(h) ? this.h := Type(x) !== "Integer" ? Integer(h) : h : ""
    }

    /**
     * Adds an image to the shape.
     * @param {str} filepath file path to an existing image
     * @param {str} option percentage or width, height (opt)
     * @param {str} effect color matrix name (opt)
     * @param {str} x coordinate (opt)
     * @param {str} y coordinate (opt)
     */
    AddImage(filepath, option := 0, effect := 0, x := 0, y := 0) {

        local obj

        if (!FileExist(filepath)) {
            throw ValueError("[!] The specified file does not exist.")
        }
        
        ; Delete the existing bitmap
        obj := Shapes.%this.Layerid%.%this.id%
        if (obj.Bitmap.HasProp("ptr") && obj.Bitmap.ptr) {
            obj.Bitmap := ""
        }

        ; Try to squeeze the image into the shape if no option is provided (broken)
        ;if (!option) {
        ;    if (this.w != this.h) {
        ;        if (this.w > this.h)
        ;            option := "w" . Ceil(this.w * .95) . " h" . Ceil(this.h * (this.w / this.h) * .95)
        ;        else
        ;            option := "w" . Ceil(this.w * (this.h / this.w) * .95) . " h" . Ceil(this.h * .95)
        ;    }
        ;    else {
        ;        option := "w" . Ceil(this.w * .9) . " h" . Ceil(this.h * .9)
        ;    }
        ;}
        
        obj.Bitmap := Bitmap(filepath, option, effect)
        this.pBitmap := obj.Bitmap.ptr
        return
    }

    ;{ Visibility methods
    Show() {
        this.Visible := 1
    }

    Hide() {
        this.Visible := 0
    }

    ShowHide() {
        this.Visible ^= 1
    }

    SavePos() {
        return {x : this.x, y : this.y, w : this.w, h : this.h}
    }

    RestorePos(obj) {
        (obj.HasOwnProp("x")) ? this.x := obj.x : 0
        (obj.HasOwnProp("y")) ? this.y := obj.y : 0
        (obj.HasOwnProp("w")) ? this.w := obj.w : 0
        (obj.HasOwnProp("h")) ? this.h := obj.h : 0
    }

    /**
     * Sets the position of the object.
     * @param {int|str} x position, or 'center' to center horizontally
     * @param {int|str} y position, or 'center' to center vertically
     */
    Position(x := 'center', y := 'center') {
        if (Type(x) == 'String' || Type(y) == 'String') {
            if x ~= 'i)c(ent(er)?)?' && y ~= 'i)c(ent(er)?)?' {
                this.x := (this.layerWidth - this.w) // 2
                this.y := (this.layerHeight - this.h) // 2
            }
            else if x ~= 'i)c(ent(er)?)?' {
                this.x := (this.layerWidth - this.w) // 2
                this.y := y ? IsFloat(y) ? Ceil(y) : y : this.y
            }
            else if y ~= 'i)c(ent(er)?)?' {
                this.y := (this.layerHeight - this.h) // 2
                this.x := x ? IsFloat(x) ? Ceil(x) : x : this.x
            }
        } else if IsInteger(x) && IsInteger(y) {
            this.x := x
            this.y := y
        } else if IsFloat(x) && IsFloat(y) {
            this.x := Ceil(x)
            this.y := Ceil(y)
        } else
            throw Error('Integer, float or keyword.')
    }
    ;}

    /**
     * Sets an event handler for the object.
     * @param {str} event event type to handle
     * @param {fn} fn function to execute when the event occurs
     * @param {obj} params additional parameters for the event handler fn
     */
    OnEvent(event := "Click", fn?, params*) {
        if (this.Shape ~= "^Bezier|Line|Point")
            return
        
        ; Create an invisible text control on the layer GUI
        this.Ctrl := Layers.%this.LayerId%.Window.AddText(
            "X" this.x " Y" this.y " W" this.w " H" this.h)
        
        ; The layer may not be prepared yet, which could raise an error
        try this.CtrlUpdate()
        this.Ctrl.OnEvent(event, (*) => (fn)(params*))
        return
    }

    ; Updates the position of the shape's Gui control.  
    ; Only move controls when you really need to.
    CtrlUpdate() {
        local x, y
        x := this.x - Layers.%this.layerid%.x1
        y := this.y - Layers.%this.layerid%.y1
        this.Ctrl.Move(x, y, this.w, this.h)
        return
    }

    ; Bind a function to the shape object.
    ; Experimental function, unfortunately, the params has to be provided
    ; Signals are executed during each layer preparation.
    Signal(fn, params*) {
        this.hasSignal := true
        if !params.Length {
            this.Fn := (*) => (fn)(this)
        } else {
            this.Fn := (*) => (fn)(this, params*)
        }
        ;this.fn := fn.Bind(this, params*) ;ObjBindMethod(this, fn, params*) ; nope
        ;this.Fn := (*) => (fn)(params*) ; nada
        return
    }

    ;{ Animation function
    /**
     * Displays the shape with a roll-down animation effect. This function animates the shape by incrementally revealing it from top to bottom.  
     * @param {str} TargetFrame - The desired frame rate during the animation.
     * @param {int} unit - The unit size of the increment.
     */
    RollDown(unit := 1, delay := -1) {
        Shape.RollDown([this], unit, delay)
    }

    static RollDown(obj, unit, delay := -1) {
        local str, desiredHeight, v
        for v in obj {
            str := v.str
            v.str := ""
            v.visible := 1
            desiredHeight := v.h
            v.h := 0
            while (desiredHeight > v.H) {
                Draw(v.layerid)
                v.h += A_Index * unit
                Sleep(delay)
            }
            v.str := str
            Draw(v.layerid)
        }
    }

    RollUp(unit := 1, delay := -1) {
        Shape.RollUp([this], unit, delay)
    }

    /**
     * Disappears the shape with a roll-up animation effect.  
     * @param {int} Unit size of change
     */
    static RollUp(obj, unit := 1, delay := -1) {
        
        local v, str, pos

        for v in obj {
            pos := [v.w, v.h]
            str := v.str
            v.str := ""
            while (v.h > 0) {
                Draw(v.layerid)
                v.h -= (A_index * unit)	
                Sleep(delay)		
            }
            v.h := 1
            v.w := 1
            v.alpha := 0
            Draw(v.layerid)
            v.visible := 0
            v.str := str
            v.w := pos[1]
            v.h := pos[2]
        }
    }

    /**
     * Moves the shape to the specified position with a sliding effect.
     * @param {integer} x The X-coordinate position
     * @param {integer} y The Y-coordinate position
     * @param {integer} Unit unit size of the sliding increment
     */
    Shrink(Unit := 1) {
        local fake, w, h
        H := W := 1
        this.Text()
        fake := Rectangle(this.x, this.y, this.w, this.h, '0x00FFFFFF')
        loop {
            ; calculate w, h stepsize
            (this.h > this.w) ? w := this.w / this.h : 0
            (this.w > this.h) ? h := this.h / this.w : 0
            ; stop reducing the value if less !value
            (this.w > 0) ? (this.w -= Ceil(unit * W), this.x += Ceil(unit * W / 2)) : this.w := 0
            (this.h > 0) ? (this.h -= Ceil(unit * H), this.y += Ceil(unit * H / 2)) : this.h := 0
            if (!this.h || !this.w) {
                Draw(this.LayerId)
                this.Visible := 0
                return
            }
            Draw(this.LayerId)
        }
    }

    /**
     * Shrinks the object(s). This static method reduces the size of the specified object(s) by the given unit size. Only works on the same layer`!`
     * @param {number} unit - The unit size of the shrinkage.
     * @param {object} objects - The object(s) to be shrunk.
     */
    static Shrink(unit := 1, objects*) {

        local x1, y1, x2, y2, nulled, whichlayer, v, index, w, h

        for v in objects {
            if (A_index == 1) {
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
        nulled := 0
        whichlayer := ""

        loop {

            index := A_index
            nulled := 0

            for v in objects {

                if (!InStr(whichlayer, v.layerid))
                    whichlayer .= v.LayerId "|"

                if (index == 1)
                    v.str := ""

                H := W := 1
                (v.h > v.w) ? W := v.w / v.h : 0
                (v.w > v.h) ? H := v.h / v.w : 0

                (v.w > 0) ? (v.w -= Ceil(unit * W), v.x += Ceil(w / 2 * unit)) : v.w := 0
                (v.h > 0) ? (v.h -= Ceil(unit * H), v.y += Ceil(h / 2 * unit)) : v.h := 0

                if (0 >= v.h || 0 >= v.w) {
                    nulled += 1
                    v.visible := 0
                }
            }

            loop parse, whichlayer, "|" {
                if !A_LoopField
                    continue
                Draw(Integer(A_LoopField))
                if (nulled = objects.Length) { ;-1
                    for v in objects
                        v.Hide()
                    try Draw(A_LoopField)
                    return
                }
            }

        }
    }

    /**
     * Grows the object(s). This static method increases the size of the specified object(s) by the given unit size. Only works on the same layer`!`
     * @param {number} unit - The unit size of the growth.
     * @param {object} objects - The object(s) to be grown.
     */
    Grow(delay := 15.6) {
        local heightEnd
        heightEnd := this.h
        this.h := 0
        while (heightEnd > this.h) {
            this.h := heightEnd < this.h + A_Index ? heightEnd : this.h + A_Index
            Draw(this.LayerId)
            Sleep(delay)
        }	
    }

    /**
     * Grows the object(s). This static method increases the size of the specified object(s) by the given unit size.
     * @param {number} unit - The unit size of the growth.
     * @param {object} objects - The object(s) to be grown.
     */
    static Grow(delay := 15.6, Objects*) {
        local v, nulled, pos
        pos := []
        for v in Objects {
            pos.Push(v.SavePos())
            v.h := 0
        }

        loop {
            nulled := 0
            for v in Objects {
                if (pos[A_Index].h == v.h) {
                    Nulled += 1
                    v.Visible := 1
                }
                else {
                    v.h += 1
                }
            }
            Draw(objects[1].LayerId)
            if (Nulled == Objects.Length)
                return
            Sleep(delay)
        }
        ;for v in Objects
        ;    v.RestorePos(pos[A_Index])
    }
    ;}

    ; Required functions for constructing shapes.
    setMissingProp(&obj) {

        obj.colour := Color(obj.colour)
        
        if (!obj.HasProp("filled"))
            obj.filled := false
    
        if (!obj.HasProp("penwidth"))
            obj.penwidth := 1
    
        if (!obj.HasProp("x")) {
            obj.x := 0
            obj.y := 0
            obj.w := 0
            obj.h := 0
        }
        return
    }

    ; Set the values in the Shapes container.
    setReferenceObj(obj) {
        return Shapes.%this.Layerid%.%this.id% := {
            alpha: Shape.alpha,
            bitmap : {ptr:0},
            color: obj.colour,
            filled: obj.filled,
            font : Font.getStock(),
            id : this.id,
            penwidth : obj.penwidth,
            visible : Shape.visible
        }
    }

    ; Get the properties for the shape.
    getProperties(obj) {
        return {
            ; Base
            x: obj.x,
            y: obj.y,
            w: obj.w,
            h: obj.h,
            shape: obj.cls,
            hasSignal: false,
            ; String
            str: "",
            strX: 0,
            strY: 0,
            strH: Font.default.alignmentH,
            strV: Font.default.alignmentV,
            strQ: Font.default.quality,
            ; Bitmap
            pBitmap: 0,
            bmpX: 0,
            bmpY: 0,
            bmpW: 0,
            bmpH: 0,
            bmpSrcX: 0,
            bmpSrcY: 0,
            bmpSrcW: 0,
            bmpSrcH: 0,
            bmpW0: 0,
            bmpH0: 0,
            ; Bound function
            fn: "",
            fnParams: ""
        }
    }

    ; Add additional properties for the shape.
    addSupplementaryProps(&obj, &props) {
        local p := props
        switch obj.cls {
            case "Polygon", "FilledPolygon", "Triangle", "FilledTriangle", "Beziers", "Lines":
                p.pPoints := 0
                p.points := 0
                if !(obj.cls ~= "Beziers|Lines")
                    p.fillmode := obj.fillmode
            case "Arc", "Pie", "FilledPie":
                p.startangle := obj.startangle
                p.sweepangle := obj.sweepangle
            case "Bezier":
                p.x1 := obj.x1
                p.y1 := obj.y1
                p.x2 := obj.x2
                p.y2 := obj.y2
                p.x3 := obj.x3
                p.y3 := obj.y3
                p.x4 := obj.x4
                p.y4 := obj.y4
            case "Line":
                p.x1 := obj.x1
                p.y1 := obj.y1
                p.x2 := obj.x2
                p.y2 := obj.y2
        }
        return
    }

    ; Initialize the tool for the shape.
    InitializeTool(&obj) {

        local shp := Shapes.%this.layerid%.%this.id%
        
        obj.cls := this.base.__Class
        if (obj.filled == 1) {
            shp.Tool := SolidBrush(obj.colour)
            obj.cls := "Filled" obj.cls
        }
        else if ((!obj.filled || obj.filled > 1) ) {
            if (obj.filled == 0)
                obj.penwidth := 1
            else if (obj.filled > 1 && obj.penwidth <= 100) {
                obj.penwidth := obj.filled
            }
            else
                throw ValueError("[!] Invalid pen width value")
            shp.Tool := Pen(obj.colour, obj.penwidth)
        }
        else {
            throw ValueError("[!] Invalid value during tool initialization")
        }
        return
    }

    ; Set the base properties for the shape.
    setBaseProps(props) {
        for name, value in props.OwnProps() {
            this.DefineProp(name, {get: get_Shape.Bind(name), set: set_Shape.Bind(name)})
            this.%name% := value
        }
    }

    ; Set the unique properties for the shape if needed.
    setUniqueProps(obj) {

        local ref := Shapes.%this.Layerid%.%this.id%

        if (this.shape ~= "Triangle|Polygon|Beziers|Lines") {
            
            ; Create a buffer for the points struct, and store the pointer.
            this.points := obj.points.Length // 2
            this.bPoints := Buffer(8 * this.points)
            this.pPoints := this.bPoints.ptr

            ; Define the x, y properties for points.
            ; Special thanks to plankoe and evanamd for the explanation.
            loop this.points {
                xindex := A_Index * 2 - 1
                yindex := A_Index * 2
                xname := "x" A_Index
                yname := "y" A_Index

                this.DefineProp(xname, {
                    get: get_Shape.Bind(xname),
                    set: set_ShapePoint.Bind(xname, (xindex - 1) * 4)
                })
                this.DefineProp(yname, {
                    get: get_Shape.Bind(yname),
                    set: set_ShapePoint.Bind(yname, (yindex - 1) * 4)
                })

                this.%xname% := obj.points[xindex]
                this.%yname% := obj.points[yindex]
            }

            ; Bind a function to get the unique bounds.
            if (this.shape == "Triangle" || this.shape == "FilledTriangle") {
                ref.getBounds := getBoundsTriangle.Bind()
            }
            else {
                ref.getBounds := getBoundsPoints.Bind()
            }
        }
        else if (this.shape == "Bezier") {
            ref.getBounds := getBoundsBezier.Bind()
        }
        else if (this.shape == "Line") {
            ref.getBounds := getBoundsLine.Bind()
        }
        return
    }

    ; Keep track of the shape through the Layers and Shapes container.
    static id := 0

    /**
     * Initializes and constructs the shape, adding it to the Shapes container class.   
     */
    __New(obj) {

        ; Check if the active layer exists (user can delete it).
        if (!Layers.HasOwnProp(Layer.activeid))
            throw ValueError("[?] The current active layer doesn't exist.")

        this.layerid := Layer.activeid
        this.id := ++Shape.id
        
        ; Some properties depend on others during initialization.
        this.setMissingProp(&obj)
        this.setReferenceObj(obj)
        this.InitializeTool(&obj)

        ; Add unique properties and consruct.
        props := this.getProperties(obj)
        this.addSupplementaryProps(&obj, &props)       
        this.setBaseProps(props)
        this.setUniqueProps(obj)
        
        OutputDebug("[+] Shape " this.id " created on Layer " this.layerId "`n")  
    }

    ; Release resources (font, tool, bitmap)
    __Delete() {
        if (Shapes.HasProp(this.LayerId) && Shapes.%this.LayerId%.HasProp(this.id)) {
            Font.RemoveAccess(Shapes.%this.LayerId%.%this.id%.Font.id)
            Shapes.%this.Layerid%.DeleteProp(this.id)
            OutputDebug("[-] Shape " this.id " deleted from Layer " this.Layerid "`n") 
        }
    }

    /**
     * Removes `Prototype` and `__Init` methods for faster lookup
     * in the Shapes.OwnProps() enumeration.
     */
    static __New() {
        Shapes.DeleteProp("__Init")
        Shapes.DeleteProp("Prototype")
    }

    static __Delete() {
        ; It seems this could be removed, but it's better to keep it for now
        local i, j, lyr, shp
        for i, lyr in Shapes.OwnProps() {
            for j, shp in lyr.OwnProps() {
                if (shp.HasProp("Tool")) {
                    lyr.DeleteProp(j)
                    OutputDebug("[-] Shape " j " deleted from Layer " i "`n")
                } 
            }
        }
    }
}


/**
 * The following functions are just tests and examples and will be reworked later.
 */

; Normal parameter getter
getParamsNormal(x?, y?, w?, h?, colour?, filled?) {
    local obj
    obj := { x : (IsSet(x) ? x : 0),
             y : (IsSet(y) ? y : 0),
             w : (IsSet(w) ? w : 50),
             h : (IsSet(h) ? h : 50),
             colour : (IsSet(colour)) ? colour : "0xFFFFFFFF",
             filled : (IsSet(filled)) ? filled : true }
    return obj
}

; Sweep angle parameter getter
getParamsSweepAngle(x?, y?, w?, h?, colour?, filled?, startangle?, sweepangle?) {
    return {
        x : (IsSet(x) ? x : 0),
        y : (IsSet(y) ? y : 0),
        w : (IsSet(w) ? w : 50),
        h : (IsSet(h) ? h : 50),
        colour : (IsSet(colour)) ? colour : "0xFFFFFFFF",
        filled : (IsSet(filled)) ? filled : true,
        startangle : startangle,
        sweepangle : sweepangle
    }
}

; Get the parameters
getParam(x?, y?, w?, h?, colour?, filled?) {
    return {x : 0, y : 0, w : 50, h : 50, colour : "0xFFFFFFFF", filled : 1}
}

/** Creates a square.
 * @param {int} x coordinate on the layer
 * @param {int} y coordinate
 * @param {int} size width, height
 * @param {color} colour colour
 * @param {bool} filled filled
 */
class Square extends Shape { 
    __New(x?, y?, size := 1, colour?, filled?) {		
        super.__New(getParamsNormal(x?, y?, size?, size?, colour?, filled?))
    }
}

/** Creates a rectangle.
 * @param {int} x coordinate on the layer
 * @param {int} y coordinate
 * @param {int} w width
 * @param {int} h height
 * @param {color} colour colour
 * @param {bool} filled filled
 */
class Rectangle extends Shape {
    __New(x?, y?, w?, h?, colour?, filled?) {
        super.__New(getParamsNormal(x?, y?, w?, h?, colour?, filled?))
    }
}

/** Creates an ellipse.
 * @param {int} x coordinate on the layer
 * @param {int} y coordinate
 * @param {int} w width
 * @param {int} h height
 * @param {color} colour colour
 * @param {bool} filled filled
 */
class Ellipse extends Shape {
    __New(x?, y?, w?, h?, colour?, filled?) {
        super.__New(getParamsNormal(x?, y?, w?, h?, colour?, filled?))
    }
}

/**
 * Creates an Arc.
 * @param {int} x coordinate on the layer
 * @param {int} y coordinate
 * @param {int} w width
 * @param {int} h height
 * @param {color} colour colour
 * @param {int} Penwidth size of pen width
 * @param {int} Startangle start angle
 * @param {int} Sweepangle sweep angle
 */
class Arc extends Shape {
    __New(x?, y?, w?, h?, colour?, penwidth := 1, startangle := 1, sweepangle := 360) {
        super.__New(getParamsSweepangle(x?, y?, w?, h?, colour?, penwidth, startangle, sweepangle))
    }
}

/** Creates a pie shape.
 * @param {int} x coordinate on the layer
 * @param {int} y coordinate
 * @param {int} w width
 * @param {int} h height
 * @param {int} startangle start angle
 * @param {int} sweepangle sweep angle	
 * @param {color} colour colour
 * @param {bool} filled filled
 */
class Pie extends Shape { 
    __New(x?, y?, w ?, h?, startangle := 1, sweepangle := 360, colour?, filled?) {
        super.__New(getParamsSweepangle(x?, y?, w?, h?, colour?, filled?, startangle, sweepangle))
    }
}

;{ Boundaries
; Get the boundaries of a triangle by parameters or points.
getBoundsTriangle(this) {
    this.x := Min(this.x1, this.x2, this.x3)
    this.y := Min(this.y1, this.y2, this.y3)
    this.w := Max(this.x1, this.x2, this.x3) - this.x
    this.h := Max(this.y1, this.y2, this.y3) - this.y
    return
}

; Get the boundaries of the shape based on the points.
getBoundsPoints(this) {
    ; DIB max size is 32647 * 32647 (credit: Robodesign)
    static DIBsize := 32647
    x1 :=  DIBsize
    y1 :=  DIBsize 
    x2 := -DIBsize
    y2 := -DIBsize
    ; Get the boundaries from the points.
    local x, y
    loop this.points {
        x := this.%("x" A_Index)% 
        y := this.%("y" A_Index)%
        (x < x1) ? x1 := x : 0
        (y < y1) ? y1 := y : 0
        (x > x2) ? x2 := x : 0
        (y > y2) ? y2 := y : 0
    }
    ; Set the boundaries.
    this.x := x1
    this.y := y1
    this.w := x2 - x1
    this.h := y2 - y1
    return
}

; Get the boundaries of a bezier curve.
getBoundsBezier(this) {
    this.x := Min(this.x1, this.x2, this.x3, this.x4)
    this.y := Min(this.y1, this.y2, this.y3, this.y4)
    this.w := Max(this.x1, this.x2, this.x3, this.x4) - this.x
    this.h := Max(this.y1, this.y2, this.y3, this.y4) - this.y
    return
}

; Get the boundaries of a line.
getBoundsLine(this) {
    this.x := Min(this.x1, this.x2)
    this.y := Min(this.y1, this.y2)
    this.w := Max(this.x1, this.x2) - this.x
    this.h := Max(this.y1, this.y2) - this.y
    return
}
;}

/**
 * Creates a triangle.
 * @param {int} x1 x coordinate of the first point
 * @param {int} y1 y coordinate of the first point
 * @param {int} x2 x coordinate of the second point
 * @param {int} y2 y coordinate of the second point
 * @param {int} x3 x coordinate of the third point
 * @param {int} y3 y coordinate of the third point
 * @param {color} colour colour
 * @param {bool} filled filled
 */
class Triangle extends Shape {
    __New(x1 := 0, y1 := 0, x2 := 0, y2 := 0, x3 := 0, y3 := 0, colour?, filled?) {
        super.__New({points : [x1, y1, x2, y2, x3, y3], colour : colour, filled : filled, fillmode : 1})
    }
}

/** Creates a polygon.
 * @param {color} colour Colour
 * @param {bool} filled  filled	
 * @param {int} fillmode Fill mode, 1 = alternate, 2 = winding
 * @param {array} aPoints array of points
 */
class Polygon extends Shape {
    __New(colour?, filled?, fillmode := 1, aPoints?) {
        super.__New({points : aPoints, colour : colour, filled : filled, fillmode : fillmode, penwidth : 1})
    }
}

/**
 * Creates a Bezier curve.
 * @param {int} x1 x coordinate of the first point
 * @param {int} y1 y coordinate of the first point
 * @param {int} x2 x coordinate of the second point
 * @param {int} y2 y coordinate of the second point
 * @param {int} x3 x coordinate of the third point
 * @param {int} y3 y coordinate of the third point
 * @param {int} x4 x coordinate of the fourth point
 * @param {int} y4 y coordinate of the fourth point
 * @param {color} colour colour
 * @param {int} penwidth width
 */
class Bezier extends Shape {
    __New(x1?, y1?, x2?, y2?, x3?, y3?, x4?, y4?, colour?, penwidth := 1) {
        super.__New({x1:x1, y1:y1, x2:x2, y2:y2, x3:x3, y3:y3, x4:x4, y4:y4, colour : colour, penwidth : penwidth})
    }
}

/**
 * Creates a Bezier curve.
 * @param {color} colour colour
 * @param {int} penwidth pen width size
 * @param {array} aPoints array of points  
 * Note: it seems the array must contain 4 points or 7, 10, 13..
 */
class Beziers extends Shape {
    __New(colour?, penwidth := 1, aPoints?) {
        super.__New({points : aPoints, colour : colour, penWidth : penwidth})
    }
}

/**
 * Creates a line.
 * @param {int} x1 coordinate of first point
 * @param {int} y1 coordinate of first point
 * @param {int} x2 coordinate of second point
 * @param {int} y2 coordinate of second point
 * @param {color} colour colour
 * @param {int} penwidth pen width size
 */
class Line extends Shape { 
    __New(x1?, y1?, x2?, y2?, colour?, penwidth := 1) {
        super.__New({x1:x1, y1:y1, x2:x2, y2:y2, colour : colour, penwidth : penwidth})
    }
}

/**
 * Creates a line.
 * @param {color} colour colour
 * @param {int} penwidth pen width size
 * @param {array} aPoints array of points
 */
class Lines extends Shape {
    __New(colour?, penwidth := 1, aPoints?) {
        super.__New({points : aPoints, colour : colour, penwidth : penwidth})
    }
}

/**
 * Creates a point.
 * Using a line with a width of 1, a bitmap would be more appropriate, but it
 * needs some rework.
 * @param {int} x coordinate
 * @param {int} y coordinate
 * @param {color} colour
 */
class Point extends Shape {
    __New(x?, y?, colour?) {
        super.__New({x:x, y:y, colour : colour, w:1, h:1, penwidth : 1})
    }
}


/**
 * A class for color manipulation and generation.
 * @property ColorNames a list of color names
 * @example
 * ; The names are case insensitive.
 * c := Color()                     ; Random color
 * c := Color("Lime")               ; Color name by calling the color class
 * c := Color.Lime                  ; Direct access to value by name
 * c := Color("red|blue|green")     ; Random color from the list
 * c := Color("0xFF0000FF")         ; 0xARGB
 * c := Color("#FF0000FF")          ; #ARGB
 * c := Color("0x0000FF")           ; 0xRGB
 * c := Color("#0000FF")            ; #RGB
 * c := Color(0xFF000000)           ; Hex
 */
class Color {

    /**
     * Returns a random color, accepts multiple types of color inputs.
     * @param {str} c color name, ARGB, or a list of color names separated by "|"
     * @return {int} ARGB
     * 
     * @credit iseahound - Graphics, https://github.com/iseahound/Graphics  
     */
    static Call(c := "") {
        if (Type(c) == "String") {
            return (c == "") ? Random(0xFF000000, 0xFFFFFFFF)         ; random ARGB with max alpha
                : c ~= "^0x[a-fA-F0-9]{8}$" ? c                       ; correct 0xARGB 
                : c ~= "^0x[a-fA-F0-9]{6}$" ? "0xFF" SubStr(c, 3)     ; missing alpha channel (0xRGB)
                : c ~= "^#[a-fA-F0-9]{8}$"  ? "0x" SubStr(c, 2)       ; #ARGB
                : c ~= "^#[a-fA-F0-9]{6}$"  ? "0xFF" SubStr(c, 2)     ; #RGB
                : c ~= "^[a-fA-F0-9]{8}$"   ? "0x" c                  ; missing prefix (ARGB)
                : c ~= "^[a-fA-F0-9]{6}$"   ? "0xFF" c                ; missing 0xFF (RGB)
                : c ~= "\|"                 ? this.Random(c)          ; random ARGB
                : c ~= "^[a-zA-Z]{3,}"      ? this.%c% : ""           ; colorName
        }
        else if (Type(c) == "Integer" && c <= 0xFFFFFFFF && c >= 0x00000000) {
            return c
        }
        ; An invalid input.
        return this.red
    }

    /**
     * Sets the alpha channel of a color.
     * @param ARGB a valid ARGB
     * @param {int} A alpha channel value
     * @return {int} ARGB
     */
    static Alpha(ARGB, A := 255) {
        A := (A > 255 ? 255 : A < 0 ? 0 : A)
        return (A << 24) | (ARGB & 0x00FFFFFF)
    }

    /**
     * Sets the alpha channel of a color in float format.
     * @param ARGB a valid ARGB
     * @param {float} A alpha channel value
     * @return {int} ARGB
     */
    static AlphaF(ARGB, A := 1.0) {
        A := (A > 1.0 ? 255 : A < 0.0 ? 0 : Ceil(A * 255))
        return (A << 24) | (ARGB & 0x00FFFFFF)
    }

    /**
     * Swaps the color channels of an ARGB color.
     * @param colour 
     * @param {str} mode 
     * @return {int} ARGB
     */
    static ChannelSwap(colour, mode := "Rand") {
        
        static modes := ["RGB", "RBG", "BGR", "BRG", "GRB", "GBR"]
        
        local A, R, G, B, i, channel
        local c := 0x0

        if (mode ~= "i)^R(and(om)?)?$") {
            mode := modes[Random(1, modes.Length)]
        }
        else if !(mode ~= "i)^(?!.*(.).*\1)[RGB]{3}$") {
            throw ValueError("Invalid mode")
        }

        A := (0xff000000 & colour) >> 24
        R := (0x00ff0000 & colour) >> 16
        G := (0x0000ff00 & colour) >>  8
        B :=  0x000000ff & colour

        for i, channel in StrSplit(mode) {
            switch channel, 0 {
                case "R": c := c | R << 8 * (3 - i)
                case "G": c := c | G << 8 * (3 - i)
                case "B": c := c | B << 8 * (3 - i)
            }
        }
        return (A << 24) | c
    }

    /**
     * Returns an array of colors that transition from color1 to color2.
     * @param color1 starting color
     * @param color2 end color
     * @param backforth number of transitions * 100, 2 means back and forth (doubles the array size)
     * @return {array}
     */
    static GetTransition(color1, color2, backforth := false) {
        
        local clr, arr

        ; Validate.
        if (backforth !== 0 && backforth !== 1)
            throw ValueError("backforth must be bool")

        color1 := this.Call(color1)
        color2 := this.Call(color2)

        ; Prepare the return array.
        arr := []
        arr.Length := (backforth + 1) * 100

        ; Push the colors based on the color distance.
        loop 100 {
            clr := this.LinearInterpolation(color1, color2, A_Index)
            if (backforth) {
                arr[200 - A_Index + 1] := clr
            } 
            arr[A_Index] := clr
        }
        return arr
    }

    /**
     * Returns a color that transition from color1 to color2 on a given distance.
     * @param {int} color1 starting ARGB
     * @param {int} color2 end ARGB
     * @param {int|float} dist distance between the colors
     * @param {int} alpha alpha channel
     * @return {array}
     */
    static LinearInterpolation(color1, color2, dist, alpha := 255) {
        
        local p, c1, c2, R, G, B, R1, G1, B1, R2, G2, B2
        
        ; Convert integer and float to percentage
        if (Type(dist) == "Integer" && dist >= 0 && dist <= 100) {
            p := dist * .01
        }
        else if (Type(dist) == "Float" && dist >= 0 && dist <= 1) {
            p := dist * 100
        }
        else {
            throw ValueError("Distance must be an integer or float")
        }

        ; Get the R, G, B components of colors
        c1 := color1
        c2 := color2
    
        R1 := (0x00ff0000 & c1) >> 16
        G1 := (0x0000ff00 & c1) >>  8
        B1 :=  0x000000ff & c1
        
        R2 := (0x00ff0000 & c2) >> 16
        G2 := (0x0000ff00 & c2) >>  8
        B2 :=  0x000000ff & c2
        
        ; Calculate the new values
        R := R1 + Ceil(p * (R2 - R1)),
        G := G1 + Ceil(p * (G2 - G1)),
        B := B1 + Ceil(p * (B2 - B1))

        return (alpha << 24) | (R << 16) | (G << 8) | B
    }

    /**
     * Returns a random color, accepts multiple color names, and randomness.
     * @param {str} colorName single or multiple color names separated by "|"
     * @param {int} randomness adds a random factor to each channel
     * @return {int} ARGB
     */
    static Random(colorName := "", randomness := false) {
        
        local colors, rand

        if (colorName == "")
            return Random(0xFF000000, 0xFFFFFFFF)

        ; Check if the string contains multiple color names
        if (colorName ~= "i)^[a-zA-Z|]+$") {           ; <----- TODO simpler regex
            colors := StrSplit(colorName, "|")
        } else
            colors := [colorName]

        ; Select a random color from the list
        rand := Random(1, colors.Length)
        if (!this.HasProp(colors[rand])) {
            OutputDebug("[i] Color " colors[rand] " not found`n")
            ; or try regex search from here ...
            return Random(0xFF000000, 0xFFFFFFFF)
        }

        ; Apply randomness
        colors := this.%colors[rand]%
        if (randomness) {
            return this.Randomize(colors, randomness)
        }
        return colors
    }

    /**
     * Randomize a color with a given randomness.
     * @param {int} ARGB a valid ARGB
     * @param {int} rand the randomness value
     * @return {int} ARGB
     */
    static Randomize(ARGB, rand := 15) {

        local R := (0x00ff0000 & ARGB) >> 16
        local G := (0x0000ff00 & ARGB) >>  8
        local B :=  0x000000ff & ARGB

        R := Min(255, Max(0, R + Random(-rand, rand))),
        G := Min(255, Max(0, G + Random(-rand, rand))),
        B := Min(255, Max(0, B + Random(-rand, rand)))

        return 0xFF000000 | (R << 16) | (G << 8) | B
    }

    /**
     * Returns a random ARGB, also accessible as a function (RandomARGB).
     * @return {int} ARGB  
     */
    static RandomARGB() {
        return Random(0xFF000000, 0xFFFFFFFF)
    }

    /**
     * Returns a random color with a given alpha channel from a range.
     * @param {int} alpha alpha channel value or the range minimum
     * @param {int} max maximum range value
     * @return {int} ARGB
     */
    static RandomARGBAlphaMax(alpha := 0xFF, max := false) {
        if (alpha > 255 || alpha < 0 || max > 255 || max < 0)
            throw ValueError("Alpha must be between 0 and 255")
        alpha := (max) ? Random(alpha, max) : alpha
        return (alpha << 24) | Random(0x0, 0xFFFFFF)
    }

    /**
     * Returns a color that transition from color1 to color2 on a given distance.
     * Alias for LinearInterpolation.
     * @param color1 starting color
     * @param color2 end color
     * @param dist distance between the colors
     * @param alpha alpha channel
     * @return {int} ARGB
     */
    static Transition(color1, color2, dist := 1, alpha := 255) {
        if (Type(dist) == "Float")
            dist := dist * 100
        return this.LinearInterpolation(Color(color1), Color(color2), dist, alpha)
    }

    ; Color names
    ; User defined colors

    ; Github
    static GitHubBlue           := "0xFF0969DA", ; Links and branding elements
           GitHubGray900        := "0xFF0D1117", ; Dark mode background
           GitHubGray800        := "0xFF161B22"  ; Secondary background

    /**
     * @credit iseahound - TextRender v1.9.3, colormap
     * https://github.com/iseahound/TextRender/
     * 
     * José Roca Software, GDI+ Flat API Reference
     * Enumerations: http://www.jose.it-berater.org/gdiplus/iframe/index.htm
     */

    ;{ Get a colorname: ARGB := Color.MidnightBlue
    static Aliceblue            := "0xFFF0f8FF",
           AntiqueWhite         := "0xFFFAEBD7",
           Aqua                 := "0xFF00FFFF",
           Aquamarine           := "0xFF7FFFD4",
           Azure                := "0xFFF0FFFF",
           Beige                := "0xFFF5F5DC",
           Bisque               := "0xFFFFE4C4",
           Black                := "0xFF000000",
           BlanchedAlmond       := "0xFFFFEBCD",
           Blue                 := "0xFF0000FF",
           BlueViolet           := "0xFF8A2BE2",
           Brown                := "0xFFA52A2A",
           BurlyWood            := "0xFFDEB887",
           CadetBlue            := "0xFF5F9EA0",
           Chartreuse           := "0xFF7FFF00",
           Chocolate            := "0xFFD2691E",
           Coral                := "0xFFFF7F50",
           CornflowerBlue       := "0xFF6495ED",
           Cornsilk             := "0xFFFFF8DC",
           Crimson              := "0xFFDC143C",
           Cyan                 := "0xFF00FFFF",
           DarkBlue             := "0xFF00008B",
           DarkCyan             := "0xFF008B8B",
           DarkGoldenrod        := "0xFFB8860B",
           DarkGray             := "0xFFA9A9A9",
           DarkGreen            := "0xFF006400",
           DarkKhaki            := "0xFFBDB76B",
           DarkMagenta          := "0xFF8B008B",
           DarkOliveGreen       := "0xFF556B2F",
           DarkOrange           := "0xFFFF8C00",
           DarkOrchid           := "0xFF9932CC",
           DarkRed              := "0xFF8B0000",
           DarkSalmon           := "0xFFE9967A",
           DarkSeaGreen         := "0xFF8FBC8B",
           DarkSlateBlue        := "0xFF483D8B",
           DarkSlateGray        := "0xFF2F4F4F",
           DarkTurquoise        := "0xFF00CED1",
           DarkViolet           := "0xFF9400D3",
           DeepPink             := "0xFFFF1493",
           DeepSkyBlue          := "0xFF00BFFF",
           DimGray              := "0xFF696969",
           DodgerBlue           := "0xFF1E90FF",
           Firebrick            := "0xFFB22222",
           FloralWhite          := "0xFFFFFAF0",
           ForestGreen          := "0xFF228B22",
           Fuchsia              := "0xFFFF00FF",
           Gainsboro            := "0xFFDCDCDC",
           GhostWhite           := "0xFFF8F8FF",
           Gold                 := "0xFFFFD700",
           Goldenrod            := "0xFFDAA520",
           Gray                 := "0xFF808080",
           Green                := "0xFF008000",
           GreenYellow          := "0xFFADFF2F",
           Honeydew             := "0xFFF0FFF0",
           HotPink              := "0xFFFF69B4",
           IndianRed            := "0xFFCD5C5C",
           Indigo               := "0xFF4B0082",
           Ivory                := "0xFFFFFFF0",
           Khaki                := "0xFFF0E68C",
           Lavender             := "0xFFE6E6FA",
           LavenderBlush        := "0xFFFFF0F5",
           LawnGreen            := "0xFF7CFC00",
           LemonChiffon         := "0xFFFFFACD",
           LightBlue            := "0xFFADD8E6",
           LightCoral           := "0xFFF08080",
           LightCyan            := "0xFFE0FFFF",
           LightGoldenrodYellow := "0xFFFAFAD2",
           LightGray            := "0xFFD3D3D3",
           LightGreen           := "0xFF90EE90",
           LightPink            := "0xFFFFB6C1",
           LightSalmon          := "0xFFFFA07A",
           LightSeaGreen        := "0xFF20B2AA",
           LightSkyBlue         := "0xFF87CEFA",
           LightSlateGray       := "0xFF778899",
           LightSteelBlue       := "0xFFB0C4DE",
           LightYellow          := "0xFFFFFFE0",
           Lime                 := "0xFF00FF00",
           LimeGreen            := "0xFF32CD32",
           Linen                := "0xFFFAF0E6",
           Magenta              := "0xFFFF00FF",
           Maroon               := "0xFF800000",
           MediumAquamarine     := "0xFF66CDAA",
           MediumBlue           := "0xFF0000CD",
           MediumOrchid         := "0xFFBA55D3",
           MediumPurple         := "0xFF9370DB",
           MediumSeaGreen       := "0xFF3CB371",
           MediumSlateBlue      := "0xFF7B68EE",
           MediumSpringGreen    := "0xFF00FA9A",
           MediumTurquoise      := "0xFF48D1CC",
           MediumVioletRed      := "0xFFC71585",
           MidnightBlue         := "0xFF191970",
           MintCream            := "0xFFF5FFFA",
           MistyRose            := "0xFFFFE4E1",
           Moccasin             := "0xFFFFE4B5",
           NavajoWhite          := "0xFFFFDEAD",
           Navy                 := "0xFF000080",
           OldLace              := "0xFFFDF5E6",
           Olive                := "0xFF808000",
           OliveDrab            := "0xFF6B8E23",
           Orange               := "0xFFFFA500",
           OrangeRed            := "0xFFFF4500",
           Orchid               := "0xFFDA70D6",
           PaleGoldenrod        := "0xFFEEE8AA",
           PaleGreen            := "0xFF98FB98",
           PaleTurquoise        := "0xFFAFEEEE",
           PaleVioletRed        := "0xFFDB7093",
           PapayaWhip           := "0xFFFFEFD5",
           PeachPuff            := "0xFFFFDAB9",
           Peru                 := "0xFFCD853F",
           Pink                 := "0xFFFFC0CB",
           Plum                 := "0xFFDDA0DD",
           PowderBlue           := "0xFFB0E0E6",
           Purple               := "0xFF800080",
           Red                  := "0xFFFF0000",
           RosyBrown            := "0xFFBC8F8F",
           RoyalBlue            := "0xFF4169E1",
           SaddleBrown          := "0xFF8B4513",
           Salmon               := "0xFFFA8072",
           SandyBrown           := "0xFFF4A460",
           SeaGreen             := "0xFF2E8B57",
           SeaShell             := "0xFFFFF5EE",
           Sienna               := "0xFFA0522D",
           Silver               := "0xFFC0C0C0",
           SkyBlue              := "0xFF87CEEB",
           SlateBlue            := "0xFF6A5ACD",
           SlateGray            := "0xFF708090",
           Snow                 := "0xFFFFFAFA",
           SpringGreen          := "0xFF00FF7F",
           SteelBlue            := "0xFF4682B4",
           Tan                  := "0xFFD2B48C",
           Teal                 := "0xFF008080",
           Thistle              := "0xFFD8BFD8",
           Tomato               := "0xFFFF6347",
           Transparent          := "0x00FFFFFF",
           Turquoise            := "0xFF40E0D0",
           Violet               := "0xFFEE82EE",
           Wheat                := "0xFFF5DEB3",
           White                := "0xFFFFFFFF",
           WhiteSmoke           := "0xFFF5F5F5",
           Yellow               := "0xFFFFFF00",
           YellowGreen          := "0xFF9ACD32"
    ;}
}


/**
 * This function is responsible for rendering and refreshing the specified
 * layer, window on the display. Each layer has its own graphics object.
 * Contains: shapes, images, and texts.
 * @param {Layer} lyr layer object that needs to be drawn and updated
 */
Draw(lyr) {

    local x, y, w, h, x1, y1, v, val, gfx, ptr, pState, prepared
        , line, lines, lineWidth, lineHeight, chrWidth, RectF, testRectF
        , baseX, baseY, index, pos, oriColor, text, strRaw

    ; If the layer is an integer, get the layer object from the Layers container.
    if (Type(lyr) == "Integer" && Layers.HasOwnProp(lyr))
        lyr := Layers.%lyr%

    ; Save the layer's current dimensions and prepare the layer for drawing.
    x1 := lyr.x1
    y1 := lyr.y1
    w1 := lyr.w
    h1 := lyr.h
    prepared := Layer.Prepare(lyr.id)

    gfx := Graphics.%lyr.id%.gfx

    ; Clear the entire buffer if the layer is not persistent.
    if (!lyr.redraw) {
        
        ; Erasing only a region looked like a good idea, but it's slower. (see EraseRegion function)
        DllCall("RtlZeroMemory", "ptr", Graphics.%lyr.id%.pBits, "ptr", lyr.w * lyr.h * 4)

        ; Reset the world transform and perform a new translation if the layer has changed position.
        if (x1 !== lyr.x1 || y1 !== lyr.y1) {
            DllCall("gdiplus\GdipResetWorldTransform", "ptr", gfx),
            DllCall("gdiplus\GdipTranslateWorldTransform", "ptr", gfx, "float", -lyr.x1, "float", -lyr.y1, "int", 0)
        }
    }
    ; Overdraw but cropped to the layer boundaries.
    else {
        lyr.x1 := x1
        lyr.y1 := y1
        lyr.width := w1
        lyr.height := h1
    }

    ; Parse the visible shape list and draw.
    loop parse, prepared, "|" {

        v := Shapes.%lyr.id%.%A_LoopField%

        ; Crop if outside of the layer boundaries, assume it is inside.
        if !(v.Shape ~= "(Triangle|Polygon|Bezier|Line)$") {

            ; Horizontal
            if (v.x >= 0 && v.x + v.w <= lyr.w) {
                x := v.x
                w := v.w
            }
            else if (v.x < 0) {
                x := 0
                w := v.w + v.x
            }
            else if (v.x + v.w > lyr.w) {
                x := v.x
                w := lyr.w - v.x
            }

            ; Vertical
            if (v.y >= 0 && v.y + v.h <= lyr.h) {
                y := v.y
                h := v.h
            }
            else if (v.y < 0) {
                y := 0
                h := v.h + v.y
            }
            else if (v.y + v.h > lyr.h) {
                y := v.y
                h := lyr.h - v.y
            }

            ; If pen is used, reduce the shape width and height by 1 (may not appear)
            if (v.tool.type == 5) {
                w -= 1
                h -= 1
            }
        }

        ; Reference to the shape's tool. (Brush, Pen)
        ptr := Shapes.%lyr.id%.%v.id%.Tool.ptr

        ; Draw shape.
        switch v.shape {

            case "Arc":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawArc"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h
                    , "float", v.startangle
                    , "float", v.sweepangle)

            case "Bezier":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawBezier"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", v.x1
                    , "float", v.y1
                    , "float", v.x2
                    , "float", v.y2
                    , "float", v.x3
                    , "float", v.y3
                    , "float", v.x4
                    , "float", v.y4)

            case "Beziers":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawBeziers"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Ellipse":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawEllipse"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledRectangle", "FilledSquare":
                lyr.GraphicsQuality("Rectangle")
                DllCall("gdiplus\GdipFillRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "Rectangle", "Square":
                lyr.GraphicsQuality("Rectangle")
                DllCall("gdiplus\GdipDrawRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledEllipse":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipFillEllipse"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledPie":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipFillPie"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h
                    , "float", v.startangle
                    , "float", v.sweepangle)

            case "Pie":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawPie"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h
                    , "float", v.startangle
                    , "float", v.sweepangle)

            case "FilledTriangle", "FilledPolygon":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipFillPolygon"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points
                    , "int", v.fillMode)

            case "Triangle", "Polygon":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawPolygon"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Line":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawLine"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", v.x1
                    , "float", v.y1
                    , "float", v.x2
                    , "float", v.y2)

            case "Lines":
                lyr.GraphicsQuality("Curved")
                DllCall("gdiplus\GdipDrawLines"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)
        }

        ; Draw bitmap.
        if (v.Bitmap.ptr) {

            /**
             * The following code is partially based on:
             * @credit iseahound - TextRender v1.9.3, DrawOnGraphics
             * https://github.com/iseahound/TextRender
             */

            ; Save the current graphics settings and set the new settings for the bitmap drawing.
            DllCall("gdiplus\GdipSaveGraphics", "ptr", gfx, "ptr*", &pState := 0),
            DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7),     ; HighQualityBicubic
            DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 2),       ; Half pixel offset
            DllCall("gdiplus\GdipSetCompositingMode", "ptr", gfx, "int", 1),       ; Overwrite/SourceCopy
            DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 0),         ; No anti-alias
            DllCall("gdiplus\GdipSetCompositingQuality", "ptr", gfx, "int", 0)     ; AssumeLinear       

            ; Align the image to center inside the object.
            x2 := v.x + (v.w - v.Bitmap.w) // 2
            y2 := v.y + (v.h - v.Bitmap.h) // 2

            ; GdipDrawImage is faster than GdipDrawImageRectRect, but it doesn't support scaling.
            if (v.bmpW || v.bmpH || v.bmpSrcW || v.bmpSrcH || v.bmpSrcX || v.bmpSrcY) {

                ; Calculate the destination.
                x2 += v.bmpX
                y2 += v.bmpY
                w2 := v.Bitmap.w + v.bmpW
                h2 := v.Bitmap.h + v.bmpH

                ; And the source.
                x1 := v.bmpSrcX
                y1 := v.bmpSrcY
                w1 := v.bmpSrcW ? v.Bitmap.w + v.bmpSrcW - x1 : v.Bitmap.w - x1
                h1 := v.bmpSrcH ? v.Bitmap.h + v.bmpSrcH - y1 : v.Bitmap.h - y1

                DllCall("gdiplus\GdipDrawImageRectRectI"
                    , "ptr", gfx
                    , "ptr", v.Bitmap.ptr
                    , "int", x2, "int", y2, "int", w2, "int", h2     ; destination rectangle
                    , "int", x1, "int", y1, "int", w1, "int", h1     ; source rectangle
                    , "int", 2                                       ; UnitTypePixel
                    , "ptr", 0                                       ; imageAttributes
                    , "ptr", 0                                       ; callback
                    , "ptr", 0)                                      ; callbackData
            }
            else {
                DllCall("gdiplus\GdipDrawImage"
                    , "ptr", gfx
                    , "ptr", v.Bitmap.ptr
                    , "float", x2 + v.bmpX
                    , "float", y2 + v.bmpY)
            }

            ; Restore the saved graphics settings.
            DllCall("gdiplus\GdipRestoreGraphics", "ptr", gfx, "ptr", pState)
        }

        ; Draw string.
        if (v.str !== "") {

            ; Text rendering quality is a global setting for the layer.
            if (v.strQ !== Font.cache.%v.Font.id%.quality) {
                DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gfx, "int", v.strQ)
                Font.cache.%v.Font.id%.quality := v.strQ
                Font.quality := v.strQ
            }

            ; Handle multi-color string.
            if InStr(v.str, "{color:") {
                
                ; Split the string by the color tag.
                text := []
                text := StrSplit(v.str, '{color:'),
                text.RemoveAt(1)
                strRaw := ""

                ; Process the string segments.
                for val in text {
                    if val {
                        val := StrSplit(val, '}')
                        text[A_Index] := [val[1], val[2]]
                        strRaw .= val[2]
                    }
                }

                ; Split the raw text into lines to handle multi-line text properly
                if (InStr(strRaw, "`r`n"))
                    strRaw := StrReplace(strRaw, "`r`n", "`n")
                lines := StrSplit(strRaw, "`n")

                ; Create a map for character width and track max height.
                chrWidth := {}
                lineHeight := 0

                ; Prepare a test rect for measuring.
                testRectF := Buffer(16, 0),
                NumPut("float", v.w, testRectF, 8),
                NumPut("float", v.h, testRectF, 12),

                RectF := Buffer(16)

                ; Calculate width of each line for centering.
                lineWidth := []
                for line in lines {
                    lineW := 0
                    loop parse, line {
                        if (!chrWidth.HasOwnProp(A_LoopField)) {
                            ; GDI+ seems to have a bug with measuring a single character,
                            ; it adds extra space so we measure double characters.
                            DllCall("gdiplus\GdipMeasureString"
                                ,   "ptr", gfx
                                ,   "ptr", StrPtr((A_LoopField . A_LoopField))
                                ,   "int", -1
                                ,   "ptr", v.Font.hFont
                                ,   "ptr", testRectF
                                ,   "ptr", v.Font.hFormat
                                ,   "ptr", RectF
                                , "uint*", 0
                                , "uint*", 0)

                            ; Height is the same for all characters.
                            if (!lineHeight)
                                lineHeight := NumGet(RectF, 12, "float")
                            chrWidth.%A_LoopField% := NumGet(RectF, 8, "float") / 2
                        }
                        lineW += chrWidth.%A_LoopField%
                    }
                    lineWidth.Push(lineW)
                }

                ; Force left-top alignment, save brush color.
                DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", v.Font.hFormat, "int", 0),
                DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", v.Font.hFormat, "int", 0),
                DllCall("gdiplus\GdipGetSolidFillColor", "ptr", v.Font.pBrush, "int*", &oriColor := 0)

                ; Initial position.
                baseX := v.x + v.strX
                baseY := v.y + v.strY

                x := baseX + (v.w - lineWidth[1]) / 2
                y := baseY + (v.h - lineHeight * lines.Length) / 2
                index := 1
                line := 1
                pos := 1

                RectF := Buffer(16)

                ; Draw each character.
                loop parse, strRaw {
                    
                    ; Check if we need to move to the next line. (overflow)
                    if (pos > StrLen(text[index][2])) {
                        index += 1
                        pos := 1
                    }

                    ; Move to the next line if needed.
                    if (A_LoopField ~= "[\n\r]") {
                        line += 1
                        pos += 1
                        x := baseX + (v.w - lineWidth[line]) / 2
                        y += lineHeight
                        continue
                    }

                    ; Adjust brush color.
                    DllCall("gdiplus\GdipSetSolidFillColor", "ptr", v.Font.pBrush, "int", Color(text[index][1])),

                    ; Update the RectF structure for the current character.
                    NumPut("float", x, RectF, 0),
                    NumPut("float", y, RectF, 4),
                    NumPut("float", chrWidth.%A_LoopField%, RectF, 8),
                    NumPut("float", lineHeight, RectF, 12),

                    ; Draw the character.
                    DllCall("gdiplus\GdipDrawString"
                        ,  "ptr", gfx
                        , "wstr", A_LoopField
                        ,  "int", -1
                        ,  "ptr", v.Font.hFont
                        ,  "ptr", RectF
                        ,  "ptr", v.Font.hFormat
                        ,  "ptr", v.Font.pBrush)

                    ; Update positions.
                    x += chrWidth.%A_LoopField%
                    pos += 1
                }

                ; Restore original brush color.
                DllCall("gdiplus\GdipSetSolidFillColor", "ptr", v.Font.pBrush, "int", oriColor)
            }
            else {

                ; Each font has its own alignment settings.
                if (v.strH !== v.Font.alignmentH) {
                    DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", v.Font.hFormat, "int", v.Font.alignmentH)
                    v.Font.alignmentH := v.strH
                }
                if (v.strV !== v.Font.alignmentV) {
                    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", v.Font.hFormat, "int", v.Font.alignmentV)
                    v.Font.alignmentV := v.strV
                }

                ; Create a RectF structure to hold the bounding rectangle of the string.
                RectF := Buffer(16),
                NumPut("float", v.x + v.strX, RectF, 0),
                NumPut("float", v.y + v.strY, RectF, 4),
                NumPut("float", v.w, RectF, 8),
                NumPut("float", v.h, RectF, 12),

                ; Draw the string without any measurement.
                DllCall("gdiplus\GdipDrawString"
                    , "ptr", gfx            ; pointer to the graphics object
                    , "wstr", v.str         ; pointer to the string
                    , "int", -1             ; null terminated
                    , "ptr", v.Font.hFont   ; pointer to the font object
                    , "ptr", RectF          ; pointer to the bounding rectangle
                    , "ptr", v.Font.hFormat ; pointer to the string format object
                    , "ptr", v.Font.pBrush) ; pointer to the brush object
            }

        }

    }

    if (!Render.UpdateWindow)
        return

    x := lyr.x + lyr.x1
    y := lyr.y + lyr.y1
    w := lyr.width
    h := lyr.height

    ; Update the window
    ; credit: iseahound, TextRender v1.9.3, RenderOnScreen
    ; https://github.com/iseahound/TextRender
    
    DllCall("UpdateLayeredWindow"
        ,     "ptr", lyr.hwnd                  ; hWnd
        ,     "ptr", 0                         ; hdcDst
        , "uint64*", x | y << 32               ; *pptDst
        , "uint64*", w | h << 32               ; *psize
        ,     "ptr", Graphics.%lyr.id%.hdc     ; hdcSrc
        , "uint64*", 0                         ; *pptSrc
        ,    "uint", 0                         ; crKey
        ,   "uint*", lyr.alpha << 16 | 1 << 24 ; *pblend
        ,    "uint", 2)                        ; dwFlags
    return
}

/**
 * This class is responsible for rendering a single layer, or more layers.
 * The class calculates the elapsed time between two calls. It also update
 * the Fps object with the new frame data.
 */
class Render {

    ; Can be disable to only render the layer, but not display it on the screen.
    static UpdateWindow := true

    ; For a single layer rendering.
    static Layer(obj) {

        ; Start timer, draw layer.
        start := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf),
        Draw(obj),

        ; Calculate elapsed time in milliseconds since the last frame update.
        elapsed := ((DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf) - start) * 1000
            + (Fps.frames ? (start - Fps.lasttick) * 1000 : 0)

        ; Wait until the specified frame time is reached to sync drawing.
        waited := 0
        if (Fps.frametime && Fps.frametime > elapsed) {
            start := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)
            while (Fps.frametime >= elapsed + waited)
                waited := ((DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf) - start) * 1000
        }

        ; Update the Fps object with the new frame data.
        Fps.rendertime += elapsed + waited
        Fps.totaltime += elapsed + waited
        Fps.lastfps := 1000 / (elapsed + waited)
        Fps.totalrender += elapsed
        Fps.lastrender := 1000 / elapsed
        Fps.frames += 1

        ; Update the last tick, this helps to calculate the elapsed time between two render calls.
        Fps.lasttick := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)
    }

    ; For multiple layers rendering.
    static Layers(obj*) {

        ; Start with the timer.
        start := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)

        ; If Fps is set to persistent, push its layer to the array, so it's displayed during the render.
        if (Fps.persistent && Fps.Layer) {
            obj.Push(Fps.Layer)
        }

        loop obj.Length {

            ; If the object is hidden or set to update every n frames, skip drawing.
            if (!obj[A_Index].visible
            || (obj[A_Index].updatefreq && Mod(Fps.frames, obj[A_Index].updatefreq))) {
                continue
            }

            ; If Fps.Persistent is usually false, the first condition will be faster.
            if (Fps.persistent && A_Index == obj.length && obj[A_Index].id == Fps.id) {
                Fps.Update()
            }

            Draw(obj[A_Index])
        }

        elapsed := (((DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf) - start) * 1000)
            + (Fps.frames ? (start - Fps.lasttick) * 1000 : 0)

        waited := 0
        if (Fps.frametime && Fps.frametime > elapsed) {
            start := (DllCall("QueryPerformanceCounter", "Int64*", &qpc := 0), qpc / this.qpf)
            while (Fps.frametime >= elapsed + waited)
                waited := ((DllCall("QueryPerformanceCounter", "Int64*", &qpc := 0), qpc / this.qpf) - start) * 1000
        }

        Fps.rendertime += elapsed + waited
        Fps.totaltime += elapsed + waited
        Fps.lastfps := 1000 / (elapsed + waited)
        Fps.totalrender += elapsed
        Fps.lastrender := 1000 / elapsed
        Fps.frames += 1
        Fps.lasttick := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)
        return
    }

    ; Binds the QueryPerformanceFrequency function as a property.
    static __New() {
        this.DefineProp("qpf", { get: (*) => (DllCall("QueryPerformanceFrequency", "int64*", &qpf := 0), qpf) })
    }
}


/**
 * The Fps class provides a simple way to display the frames per second on the screen.
 * The class is designed to be used with the Render class, which will create a temporary
 * layer for the fps panel. The fps panel can be positioned on the screen and updated
 * with the latest values. The panel can be removed immediately or at the end of the script.
 * Important: if the panel is persistent, the user needs to call End() when the script ends.
 */
class Fps {

    ; Static variables
    static __New() {
        
        ; Hold the graphics object
        this.id := 2**63 - 1 ; largest integer in AutoHotkey
        this.Layer := 0
        this.Shape := 0
        
        ; Required for the fps calculation
        this.frames := 0
        this.frametime := 0
        this.lasttick := 0
        this.totaltime := 0.0001
        this.lastfps := 0.0001
        this.lastrender := 0.0001
        this.totalrender := 0.0001
        this.rendertime := 0.0001
        
        ; Positioning
        this.w := 200
        this.h := 100
        this.margin := 25
        this.pos := "topcenter"
    }

    /**
     * Using the Render class instead of the Draw function enables the fps
     * panel to be displayed on the screen. Creates a temporary layer.
     * @param {int|float} delay 
     */
    static Display(delay := 1000) {
        
        ; The Layer may not exist yet
        if (!this.Layer) {

            ; Store the active layer id, important where new shapes spawn
            activeid := Layer.activeid
            Layer.activeid := this.id

            ; Create layer and shape
            this.Layer := Layer(this.w, this.h)
            this.Shape := Rectangle(, , this.w, this.h, "black")

            ; Can be overridden via Fps.Position()
            this.Position(this.pos)

            ; Set back id
            Layer.activeid := activeid
        }

        ; Update fps panel text, draw fps layer
        this.Update()
        Draw(this.Layer)

        ; Add delay
        if (delay)
            Sleep(delay)
        
        ; Clean up
        if (!this.persistent)
            this.Remove()
    }
    
    /**
     * Set the position of the fps panel on the screen.
     * @param {int|str} pos string like "topright" or a number from 7 to 9
     * @param {int} x offset from calculated position
     * @param {int} y offset
     * the string is case insensitive
     */
    static Position(pos := "topRight", x?, y?) {
        if (pos ~= "\w+")
            pos := Format("{:L}", pos)
        switch pos, 0 {
            case 7, "topleft":
                this.Layer.x := this.margin
                this.layer.y := this.margin
            case 8, "topcenter":
                this.layer.x := (A_ScreenWidth - this.shape.w) // 2
                this.layer.y := this.margin
            case 9, "topright":
                this.layer.x := A_ScreenWidth - this.shape.w - this.margin
                this.layer.y := this.margin
        }
        if (IsSet(x))
            this.layer.x := x
        if (IsSet(y))
            this.layer.y := y
        return
    }

    /**
     * Update the fps panel string property with the latest values.
     * * The update triggered automatically by Display method or calling  
     * Render.Layer() instead of Draw().
     */
    static Update() {
        try	this.Shape.str :=
        "fps   " Round(Fps.lastfps, 2)                         "    " Round(Fps.lastrender, 2) "`n"
      . "avg   " Round(1000 / (Fps.totaltime / Fps.frames), 2) "    " Round(1000 / (Fps.totalrender / Fps.frames), 2) "`n"
      . "sec   " Round(Fps.rendertime / 1000, 2)               "    " "i " Fps.frames
    }

    /**
     * Set the update frequency of the fps panel.
     * @param {int} value The fps layer update frequency, default is 20.
     * * The value indicates the number of draw calls before the panel updates.
     */
    static UpdateFreq(value) {
        this.Layer.updatefreq := value
    }

    /**
     * Deletes the fps panel. If the panel is persistent, it will be removed
     * from the screen in the end, otherwise it will be removed immediately.
     * Display will take care of the removal.
     */
    static Remove(*) {
        if (Type(this.Layer) == "Layer") {
            this.Shape := ""
            this.Layer := ""
            OutputDebug("[i] Fps panel disposed`n")
        }
    }
    
    ; The fps target for rendering managed by calling Fps()
    static target  := 0

    ; The fps panel's persistence, managed by calling Fps()
    static persistent := false

    /**
     * Sets the Fps panel peristent during using the Render class
     * Chaining is allowed: Fps(144).UpdateFreq(100)
     * @param {int} target 
     * @param {str} position 
     * @param {int} w 
     * @param {int} h 
     * @param {int} margin
     */
    static Call(targetfps := 0, position := "topcenter", w := 200, h := 100, margin := 25) {

        this.w := w
        this.h := h
        this.margin := margin
        this.pos := position

        ; Create a new layer and shape
        if (!this.Layer) {
            
            ; Store the active layer id temporarily
            activeid := Layer.activeid
            Layer.activeid := this.id
            
            ; Create the layer and the shape
            this.Layer := Layer(, , this.w, this.h, "Fps")
            this.Shape := Rectangle(, , this.w, this.h, "Black")
            this.Shape.str := "?"
            this.Layer.updatefreq := 20
            this.id := this.Layer.id
            this.position(this.pos)

            ; This ensures the shapes constructed on the active layer again
            Layer.activeid := activeid
            this.persistent := 1
        }
        ; Allow repositioning
        else {
            if (w != this.Layer.w)
                this.Layer.w := w
            if (h != this.Layer.h)
                this.Layer.h := h
            if (margin != this.margin)
                this.margin := margin
            if (position != this.pos)
                this.position(position)
        }

        if (!targetfps || targetfps ~= "i)max(imum)?") {
            this.target := 2**32
        }
        else if (Type(targetfps) == "Integer") {
            this.target := targetfps
        }
        else if (Type(targetfps) == "Float") {
            this.target := Integer(targetfps)
        }
        else if (Type(targetfps) == "String") {
            try	this.target := Integer(targetfps)
            catch
                throw ValueError("Invalid Fps")
        }
        else {
            throw TypeError("Invalid Fps")
        }
                
        this.frametime := Round(1000 / this.target, 2)

        return this
    }

    /**
     * Removes the fps panel. If the panel is persistent End() will remove it,
     * otherwise it will hang the process.
     */
    static __Delete() {
        if (Type(Fps.Layer) == "Layer") {
            if (Fps.HasOwnProp("Remove"))
                this.Remove()
        }
    }
}


/**
 * Represents a Gdiplus Bitmap class that can be used for drawing images.
 */
class Bitmap {

    /**
     * Creates a bitmap with the specified width and height.
     * @param width the width of the bitmap
     * @param height the height of the bitmap
     * 
     * @credit iseahound - Textrender 1.9.3, DrawOnGraphics
     * https://github.com/iseahound/TextRender
     */
    CreateFromScan0(width := 1, height := 1) {
        DllCall("gdiplus\GdipCreateBitmapFromScan0"
                    ,  "int", width        ; width of the bitmap
                    ,  "int", height       ; height
                    ,  "int", 0            ; stride (width) in bytes
                    ,  "int", 0xE200B      ; PixelFormat32bppPARGB pre multiplied alpha
                    ,  "ptr", 0            ; scan0 pointer to the pixel data
                    , "ptr*", &pBitmap:=0) ; pointer to a pBitmap object
        this.ptr := pBitmap
        this.w := width
        this.h := height
        return
    }

    /**
     * Flips a bitmap by the specified flip mode.
     * @param {int} flip flip mode
     * @returns {int} Gdip error code
     */
    RotateFlip(flip := 1) {

        static flipmode := {
            0  : 0, 90   : 1, 180   : 2, 270   : 3,
            X  : 4, 90X  : 5, 180X  : 6, 270X  : 7,
            Y  : 6, 90Y  : 7, 180Y  : 4, 270Y  : 5,
            XY : 2, 90XY : 3, 180XY : 0, 270XY : 1 }

        if (!flipmode.HasProp(flip) || flip < 0 || flip > 7)
            throw ValueError("[!] .. " flip)

        return DllCall("gdiplus\GdipImageRotateFlip", "ptr", this.ptr, "int", flip)
    }

    /**
     * Loads a bitmap from a file and stores it in the class's instance variables.
     * It can also perform resizing and color matrix operations on the bitmap.
     * @param {str} filepath path to the image file
     * @param {int|str} option percentage or width and height of the new bitmap
     * @param {str} cmatrix color matrix to apply to the image
     */
    CreateFromFile(filepath, option := 0, cmatrix := 0) {
        DllCall("gdiplus\GdipCreateBitmapFromFile"
            ,  "ptr", StrPtr(filepath)     ; pointer to file path
            , "ptr*", &pBitmap:=0)         ; pointer to pBitmap object
        this.ptr := pBitmap
        this.w := this.Width
        this.h := this.Height
        if (option || cmatrix)
            this.Resize(option, cmatrix)
        return
    }

    /**
     * Resizes a bitmap, by specifying new width and height or by a percentage. Optionally applies color attributes.
     * @param {int|str} option percentage or width and height of the new bitmap
     * @param {str} cmatrix color matrix to apply to the image
     */
    Resize(option, cmatrix := 0) {
        
        local w, h, m, gfx, pBitmap, ImageAttr

        ; Calculate the new bitmap size.
        if (option ~= "i)w(\d+)\s*h(\d+)") {
            w := RegExReplace(option, ".*w(\d+).*", "$1"),
            h := RegExReplace(option, ".*h(\d+).*", "$1"),
            dstWidth := Ceil(w ? w : this.w * h / this.h),
            dstHeight := Ceil(h ? h : this.h * w / this.w)
        }
        else {
            dstWidth := Ceil(this.w * option * 0.01),
            dstHeight := Ceil(this.h * option * 0.01)
        }

        ; 0x26200A = PixelFormat32bppARGB
        ; 0xE200B = PixelFormat32bppPARGB
        
        ; Create the new bitmap, a graphics context, set the smoothing mode, interpolation mode.
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", dstWidth, "int", dstHeight, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &pBitmap:=0),
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pBitmap, "ptr*", &gfx:=0),
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4),         ; SmoothingModeAntiAlias
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7)     ; InterpolationModeHighQualityBicubic

        ; Apply image attributes.
        if ((m := cmatrix) ? 1 : ImageAttr := 0) {
            switch {
                case m ~= "i)^b{1}(right)?$"       : m := ColorMatrix.bright
                case m ~= "i)^g{1}(ray(scale)?)?$" : m := ColorMatrix.grayscale
                case m ~= "i)^i{1}(nvert)?$"       : m := ColorMatrix.invert
                case m ~= "i)^n{1}(eg(ative)?)?$"  : m := ColorMatrix.negative
                case m ~= "i)^s{1}(ep(ia)?)?$"     : m := ColorMatrix.sepia
                case m ~= "i)^blue(only)?$"        : m := ColorMatrix.blueonly
                case m ~= "i)^green(only)?$"       : m := ColorMatrix.greenonly
                case m ~= "i)^red(only)?$"         : m := ColorMatrix.redonly
                default: throw ValueError("Matrix: " m)
            }
            cmatrix := m

            ; Create a new image attributes object.
            DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &ImageAttr:=0),
            
            ; Set the image attributes color matrix.
            DllCall("gdiplus\GdipSetImageAttributesColorMatrix"
                    , "ptr", ImageAttr     ; pointer to the image attributes object
                    , "int", 1             ; ColorAdjustType type, specifies the type of color adjustment to apply
                    , "int", 1             ; enableFlag
                    , "ptr", cmatrix       ; buffer (.ptr not needed)
                    , "ptr", 0             ; pointer to a gray matrix object
                    , "int", 0)            ; ColorMatrixFlags flags
        }

        ; Draw the original bitmap on the new bitmap using GdipDrawImageRectRectI.
        DllCall("gdiplus\GdipDrawImageRectRectI"
                    , "ptr", gfx           ; pointer to the temp graphics
                    , "ptr", this.ptr      ; pointer to the orig bitmap
                    , "int", 0             ; dst x coordinate of the upper-left corner of dst rect
                    , "int", 0             ; dst y
                    , "int", dstWidth      ; dst width
                    , "int", dstHeight     ; dst height
                    , "int", 0             ; src x coordinate of the upper-left corner of src rect
                    , "int", 0             ; src y
                    , "int", this.w        ; src width
                    , "int", this.h        ; src height
                    , "int", 2             ; src Unit
                    , "ptr", ImageAttr     ; pointer to an image attributes object
                    , "ptr", 0             ; DrawImageAbort callback
                    , "ptr", 0)            ; callbackData
        
        ; Dispose ImageAttribute object.
        if (cmatrix)
            DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", ImageAttr)

        ; Dispose the original bitmap, delete the temporary graphics.
        DllCall("gdiplus\GdipDisposeImage", "ptr", this.ptr),
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)

        ; Set the new pointer and dimensions.
        this.ptr := pBitmap
        this.w := dstWidth
        this.h := dstHeight
        return
    }

    ; Gets the width of the bitmap.
    Width {
        get {
            local w
            return (DllCall("gdiplus\GdipGetImageWidth", "ptr", this.ptr, "int*", &w:=0), w)
        } 
    }
    
    ; Gets the height of the bitmap.
    Height {
        get {
            local h
            return (DllCall("gdiplus\GdipGetImageHeight", "ptr", this.ptr, "int*", &h:=0), h)
        }
    }

    ; No use for now.
    Size {
        get => this.w * this.h * 4
    }

    /**
     * Create a new image with the specified width and height or load an image from a file.
     * @param {int|str} width width of the bitmap or the path to an existing picture
     * @param {int} height height of the bitmap
     * @param {str} cmatrix color mode of the bitmap (see ColorMatrix class)
     */
    __New(width := 1, height := 1, cmatrix := 0) {
        if (width ~= "^\d{1,5}$" && height ~= "^\d{1,5}$") {
            this.CreateFromScan0(width, height)
        }
        else if (width ~= "i)\.(bmp|png|jpg|jpeg)$" && FileExist(width)) {
            filepath := width
            resize := height
            this.CreateFromFile(filepath, resize, cmatrix)
        }
    }

    /**
     * Dispose the Bitmap.
     */
    __Delete() {
        DllCall("gdiplus\GdipDisposeImage", "ptr", this.ptr)
        OutputDebug("[-] Bitmap deleted " this.ptr "`n")
    }
}

/**
 * Holds buffers for various color matrixes, effect.
 */
class ColorMatrix {

    static __New() {

        local colorMatrixes := {

            bright : [
                  1.5,     0,     0,     0,     0,
                    0,   1.5,     0,     0,     0,
                    0,     0,   1.5,     0,     0,
                    0,     0,     0,     1,     0,
                 0.05,  0.05,  0.05,     0,     1] ,
            
            grayscale : [
                0.299, 0.299, 0.299,     0,     0,
                0.587, 0.587, 0.587,     0,     0,
                0.114, 0.114, 0.114,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,

            negative : [
                   -1,     0,     0,     0,     0,
                    0,    -1,     0,     0,     0,
                    0,     0,    -1,     0,     0,
                    0,     0,     0,     1,     0,
                    1,     1,     1,     0,     1] ,

            sepia : [
                0.393, 0.349, 0.272,     0,     0,
                0.769, 0.686, 0.534,     0,     0,
                0.189, 0.168, 0.131,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,

            invert : [
                   -1,     0,     0,     0,     0,
                    0,    -1,     0,     0,     0,
                    0,     0,    -1,     0,     0,
                    0,     0,     0,     1,     0,
                    1,     1,     1,     0,     1] ,

            redonly : [
                    1,     0,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,
            
            greenonly : [ 
                    0,     0,     0,     0,     0,
                    0,     1,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,
            
            blueonly : [
                    0,     0,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     1,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1]
        }

        ; Allocate a total of 900 bytes to preload the color matrixes.
        local key, arr, buf

        for key, arr in colorMatrixes.OwnProps() {
            buf := Buffer(4 * arr.Length)
            loop 25 {
                NumPut("float", arr[A_Index], buf, (A_Index - 1) * 4)
            }
            this.%key% := buf
        }

        OutputDebug("[i] Color matrixes loaded successfully`n")
        return
    }
}


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
    ; TODO: implement later, currently just information
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
    
    ; Make style and othere flags accessible by value
    static __New() {
        local key, value
        for key, value in this.Style.OwnProps() {
            this.Style.%value% := key
        }
        for key, value in this.StringFormat.OwnProps() {
            this.StringFormat.%value% := key
        }
        for key, value in this.RenderingHint.OwnProps() {
            this.RenderingHint.%value% := key
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
    static Call(family?, size?, style?, colour?, quality?, alignmentH?, alignmentV?) {
        
        local id

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
            OutputDebug("[!] Invalid Font style`n")
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

        ; Quality
        if (!IsSet(quality)) {
            quality := Font.default.quality
        }
        else if (!Font.RenderingHint.HasOwnProp(quality)) {
            OutputDebug("[!] Invalid rendering quality`n")
            return
        }
        quality := Font.RenderingHint.%quality%
        
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
                ,  "ptr*", &hFamily:=0),   ; ptr to font family

        DllCall("gdiplus\GdipCreateFont"
                ,   "ptr", hFamily         ; ptr to font family
                , "float", size            ; font size
                ,   "int", style           ; font style
                ,   "int", 0               ; unit of measure
                ,  "ptr*", &hFont:=0),     ; ptr to font

        DllCall("gdiplus\GdipCreateStringFormat"
                ,   "int", 0x1000 | 0x4000 ; formatAttributes (NoWrap, NoClip)
                ,   "int", 0 			   ; language id default
                ,  "ptr*", &hFormat:=0),   ; ptr to string format

        ; Set string alignments, create the font own brush
        DllCall("gdiplus\GdipSetStringFormatAlign"    , "ptr", hFormat, "int", 1),
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", hFormat, "int", 1),
        DllCall("gdiplus\GdipCreateSolidFill"         , "int", colour, "ptr*", &pBrush:=0)

        OutputDebug("[+] Font " id " created`n")
        
        return Font.cache.%id% := {hFont:hFont, hFamily:hFamily, hFormat:hFormat, family:family
            , pBrush:pBrush, color:colour, id:id, alignmentH:alignmentH, alignmentV:alignmentV
            , used:1, style : style, quality : quality, size : size}
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

        local fnt

        ; Deleted already
        if !Font.cache.HasOwnProp(id)
            return

        ; Decrement access count
        if (!Font.dispose && (Font.cache.%id%.used -= 1 > 0))
            return

        ; Delete font resources
        fnt := Font.cache.%id%
        DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fnt.hFormat),
        DllCall("gdiplus\GdipDeleteFont", "ptr", fnt.hFont),
        DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fnt.hFamily),
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
        local id, f
        ; Dispose will override used count during deletion
        this.dispose := true
        OutputDebug("[i] Deleting all fonts...`n")
        for id, f in Font.cache.OwnProps() {
            this.RemoveAccess(id)
        }
    }
}


/**
 * Create a graphics context for drawing on a layered window.
 * Layers delete their Graphics on deletion.
 */
class Graphics {
    
    /**
     * Create a new graphics object.
     * @param {int} width width of the graphics
     * @param {int} height height of the graphics
     * @param {int} id id of the graphics (debugging purpose)
     * 
     * @credit iseahound - TextRender v1.9.3, RenderOnScreen
     * https://github.com/iseahound/TextRender
     */
    __New(width, height, id := 0) {

        local Graphics, bi, hdc, hbm, obm, pBits

        ; Create a new bitmap, and a graphics object.
        hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
        bi := Buffer(40, 0)                        ; sizeof(bi) = 40
               NumPut(  "uint",        40, bi,  0) ; Size
               NumPut(   "int",     width, bi,  4) ; Width
               NumPut(   "int",   -height, bi,  8) ; Height - Negative so (0, 0) is top-left.
               NumPut("ushort",         1, bi, 12) ; Planes
               NumPut("ushort",        32, bi, 14) ; BitCount / BitsPerPixel
        hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits:=0, "ptr", 0, "uint", 0, "ptr")
        obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &Graphics:=0)
        
        ; Store values.
        this.hdc := hdc
        this.hbm := hbm
        this.obm := obm
        this.gfx := Graphics
        this.w := width
        this.h := height
        this.pBits := pBits

        this.id := (id) ? id : Layer.activeid
        
        OutputDebug("[+] Graphics " this.id " created`n")
        return
    }

    /**
     * Delete the graphics object.
     */
    __Delete() {
        if (!this.gfx)
            return
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", this.gfx)
        DllCall("SelectObject", "ptr", this.hdc , "ptr", this.obm)
        DllCall("DeleteObject", "ptr", this.hbm)
        DllCall("DeleteDC"    , "ptr", this.hdc)
        this.gfx := 0
        OutputDebug("[-] Graphics " this.id " deleted`n")
        return
    }
}


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
 * @param  {str} filepath file path of output
 * @param  {int} x coordinate
 * @param  {int} y coordinate
 * @param  {int} w width
 * @param  {int} h height
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
IsAlphaValue(int) {
    return (Type(int) == "Integer" && int <= 0xFF && int >= 0x0) ? true : false
}

/**
 * Validate an ARGB value.
 * @param ARGB 
 */
IsARGB(ARGB) {
    if (Type(ARGB) == "String")
        return (RegExMatch(ARGB, "^(0x|#)?[0-9a-fA-F]{6,8}$")) ? true : false
    else if (Type(ARGB) == "Integer")
        return (ARGB >= 0x00000000 && ARGB <= 0xFFFFFFFF) ? true : false
    return false
}

/**
 * Convert an int to ARGB format.
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
 * Alias for itoARGB, convert an int to ARGB format.
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
    local p
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


; Region specific colors.
RAL_load() {
    local key, ARGB, RAL
    RAL := {
        RAL1000: "0xFFBEBD7F",
        RAL1001: "0xFFC2B078",
        RAL1002: "0xFFC6A664",
        RAL1003: "0xFFE5BE01",
        RAL1004: "0xFFFFD700",
        RAL1005: "0xFFFFAA1D",
        RAL1006: "0xFFFFA420",
        RAL1007: "0xFFFF8C00",
        RAL1011: "0xFF8A6642",
        RAL1012: "0xFFD7D7D7",
        RAL1013: "0xFFEAE6CA",
        RAL1014: "0xFFE1CC4F",
        RAL1015: "0xFFE6D690",
        RAL1016: "0xFFFFF700",
        RAL1017: "0xFFFFE600",
        RAL1018: "0xFFFFF200",
        RAL1019: "0xFF9E9764",
        RAL1020: "0xFF999950",
        RAL1021: "0xFFFFD700",
        RAL1023: "0xFFFFC000",
        RAL1024: "0xFFAEA04B",
        RAL1026: "0xFFFFE600",
        RAL1027: "0xFF9D9101",
        RAL1028: "0xFFFFA420",
        RAL1032: "0xFFFFD300",
        RAL1033: "0xFFFFA420",
        RAL1034: "0xFFFFE600",
        RAL1035: "0xFF6A5D4D",
        RAL1036: "0xFF705335",
        RAL1037: "0xFFFFA420",
        RAL2000: "0xFFED760E",
        RAL2001: "0xFFBE4D25",
        RAL2002: "0xFFB7410E",
        RAL2003: "0xFFFF7514",
        RAL2004: "0xFFFF5E00",
        RAL2005: "0xFFFF4F00",
        RAL2007: "0xFFFFB000",
        RAL2008: "0xFFF44611",
        RAL2009: "0xFFD84B20",
        RAL2010: "0xFFE55137",
        RAL2011: "0xFFF35C20",
        RAL2012: "0xFFD35831",
        RAL3000: "0xFFAF2B1E",
        RAL3001: "0xFFA52019",
        RAL3002: "0xFF9B111E",
        RAL3003: "0xFF75151E",
        RAL3004: "0xFF5E2129",
        RAL3005: "0xFF5E1A1B",
        RAL3007: "0xFF412227",
        RAL3009: "0xFF642424",
        RAL3011: "0xFF781F19",
        RAL3012: "0xFFC1876B",
        RAL3013: "0xFF9E2A2B",
        RAL3014: "0xFFD36E70",
        RAL3015: "0xFFEA899A",
        RAL3016: "0xFFB32821",
        RAL3017: "0xFFB44C43",
        RAL3018: "0xFFCC474B",
        RAL3020: "0xFFCC3333",
        RAL3022: "0xFFD36E70",
        RAL3024: "0xFFFF3F00",
        RAL3026: "0xFFFF2B2B",
        RAL3027: "0xFFB53389",
        RAL3028: "0xFFCB3234",
        RAL3031: "0xFFB32428",
        RAL4001: "0xFF6D3F5B",
        RAL4002: "0xFF922B3E",
        RAL4003: "0xFFDE4C8A",
        RAL4004: "0xFF641C34",
        RAL4005: "0xFF6C4675",
        RAL4006: "0xFF993366",
        RAL4007: "0xFF4A192C",
        RAL4008: "0xFF924E7D",
        RAL4009: "0xFFCF3476",
        RAL5000: "0xFF354D73",
        RAL5001: "0xFF1F4764",
        RAL5002: "0xFF00387B",
        RAL5003: "0xFF1D334A",
        RAL5004: "0xFF18171C",
        RAL5005: "0xFF1E2460",
        RAL5007: "0xFF3E5F8A",
        RAL5008: "0xFF26252D",
        RAL5009: "0xFF025669",
        RAL5010: "0xFF0E294B",
        RAL5011: "0xFF231A24",
        RAL5012: "0xFF3B83BD",
        RAL5013: "0xFF232C3F",
        RAL5014: "0xFF637D96",
        RAL5015: "0xFF2874A6",
        RAL5017: "0xFF063971",
        RAL5018: "0xFF3F888F",
        RAL5019: "0xFF1B5583",
        RAL5020: "0xFF1D334A",
        RAL5021: "0xFF256D7B",
        RAL5022: "0xFF282D3C",
        RAL5023: "0xFF3F3F4E",
        RAL5024: "0xFF5D9B9B",
        RAL6000: "0xFF327662",
        RAL6001: "0xFF287233",
        RAL6002: "0xFF2D572C",
        RAL6003: "0xFF424632",
        RAL6004: "0xFF1F3A3D",
        RAL6005: "0xFF2F4538",
        RAL6006: "0xFF3E3B32",
        RAL6007: "0xFF343B29",
        RAL6008: "0xFF39352A",
        RAL6009: "0xFF31372B",
        RAL6010: "0xFF35682D",
        RAL6011: "0xFF587246",
        RAL6012: "0xFF343E40",
        RAL6013: "0xFF6C7156",
        RAL6014: "0xFF47402E",
        RAL6015: "0xFF3B3C36",
        RAL6016: "0xFF1E5945",
        RAL6017: "0xFF4C9141",
        RAL6018: "0xFF57A639",
        RAL6019: "0xFFBDECB6",
        RAL6020: "0xFF2E3A23",
        RAL6021: "0xFF89AC76",
        RAL6022: "0xFF25221B",
        RAL6024: "0xFF308446",
        RAL6025: "0xFF3D642D",
        RAL6026: "0xFF015D52",
        RAL6027: "0xFF84C3BE",
        RAL6028: "0xFF2C5545",
        RAL6029: "0xFF20603D",
        RAL6032: "0xFF317F43",
        RAL6033: "0xFF497E76",
        RAL6034: "0xFF7FB5B5",
        RAL7000: "0xFF78858B",
        RAL7001: "0xFF8A9597",
        RAL7002: "0xFF817F68",
        RAL7003: "0xFF7D7F7D",
        RAL7004: "0xFF9C9C9C",
        RAL7005: "0xFF6C7059",
        RAL7006: "0xFF766A5A",
        RAL7008: "0xFF6A5F31",
        RAL7009: "0xFF4D5645",
        RAL7010: "0xFF4C514A",
        RAL7011: "0xFF434B4D",
        RAL7012: "0xFF4E5754",
        RAL7013: "0xFF464531",
        RAL7015: "0xFF51565C",
        RAL7016: "0xFF373F43",
        RAL7021: "0xFF2F353B",
        RAL7022: "0xFF4B4D46",
        RAL7023: "0xFF818479",
        RAL7024: "0xFF474A51",
        RAL7026: "0xFF374447",
        RAL7030: "0xFF939388",
        RAL7031: "0xFF5D6970",
        RAL7032: "0xFFB9B9A8",
        RAL7033: "0xFF7D8471",
        RAL7034: "0xFF8F8B66",
        RAL7035: "0xFFD7D7D7",
        RAL7036: "0xFF7F7679",
        RAL7037: "0xFF7D7F7D",
        RAL7038: "0xFFB8B8B1",
        RAL7039: "0xFF6C6E58",
        RAL7040: "0xFF9DA1AA",
        RAL7042: "0xFF8D948D",
        RAL7043: "0xFF4E5451",
        RAL7044: "0xFFCAC4B0",
        RAL7045: "0xFF909090",
        RAL7046: "0xFF82898F",
        RAL7047: "0xFFD0D0D0",
        RAL8000: "0xFF826C34",
        RAL8001: "0xFF955F20",
        RAL8002: "0xFF6C3B2A",
        RAL8003: "0xFF734222",
        RAL8004: "0xFF8E402A",
        RAL8007: "0xFF59351F",
        RAL8008: "0xFF6F4F28",
        RAL8011: "0xFF5B3A29",
        RAL8012: "0xFF592321",
        RAL8014: "0xFF382C1E",
        RAL8015: "0xFF633A34",
        RAL8016: "0xFF4C2F27",
        RAL8017: "0xFF45322E",
        RAL8019: "0xFF403A3A",
        RAL8022: "0xFF212121",
        RAL8023: "0xFFA65E2E",
        RAL8024: "0xFF79553D",
        RAL8025: "0xFF755C48",
        RAL8028: "0xFF4E3B31",
        RAL9001: "0xFFFDF4E3",
        RAL9002: "0xFFE7EBDA",
        RAL9003: "0xFFF4F4F4",
        RAL9004: "0xFF282828",
        RAL9005: "0xFF0A0A0A",
        RAL9006: "0xFFA5A5A5",
        RAL9007: "0xFF8F8F8F",
        RAL9010: "0xFFFFFFF4",
        RAL9011: "0xFF1C1C1C",
        RAL9016: "0xFFF6F6F6",
        RAL9017: "0xFF1E1E1E",
        RAL9018: "0xFFD7D7D7" }
    for key, ARGB in RAL.OwnProps() {
        Color.%key% := ARGB
    }
    return
}
