; Script     Shape.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025
; Version    0.7.2

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
        
        local obj := Shapes.%this.Layerid%.%this.id%

        ; String.
        if (IsSet(str))
            this.str := str
        
        ; Colour.
        if (IsSet(colour))
            colour := Color(colour)
        else
            colour := Font.default.colour

        ; Size.
        if (IsSet(size)) {
            if (size < 1)
                throw ValueError("[!] Invalid font size")
        }  
        else
            size := Font.default.size

        ; Family.
        if (IsSet(family) && family ~= "^\d+$")
            throw ValueError("[!] Invalid font family")
        else if (!IsSet(family))
            family := Font.default.family

        ; Style.
        if (IsSet(style) && !Font.style.HasOwnProp(style))
            throw ValueError("[!] Invalid font style")
        else if (!IsSet(style))
            style := Font.default.style

        ; Quality.
        if (IsSet(quality)) {
            if (quality < 0 || quality > 4)
                throw ValueError("[!] Invalid rendering quality value")
        }
        else if (!IsSet(quality))
            quality := Font.quality
        this.quality := quality

        ; Get a new or an existing font
        if (obj.Font.id !== (family "|" size "|" style "|" colour)) {
            if (obj.Font.id !== Font.stockid)
                Font.RemoveAccess(obj.Font.id)
            obj.Font := Font(family, size, style, colour)
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

    ;} Visibility position

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
    ;}

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
            id : this.id,
            alpha: 0xFF,
            Bitmap : {ptr:0},
            color: obj.colour,
            filled: obj.filled,
            Font : Font.getStock()
        }
    }

    ; Get the properties for the shape.
    getProperties(obj) {
        return {
            1 : {
            ; Base
                x : obj.x,
                y : obj.y,
                w : obj.w,
                h : obj.h,
                shape : obj.cls,
                hasSignal : false,
            ; String
                str : "",
                strX : 0,
                strY : 0,
                strH : Font.default.alignmentH, 
                strV : Font.default.alignmentV,
                strQ : Font.default.quality,
            ; Bitmap
                pBitmap : 0,
                bmpX : 0,
                bmpY : 0,
                bmpW : 0,
                bmpH : 0,
                bmpSrcX : 0,
                bmpSrcY : 0,
                bmpSrcW : 0,
                bmpSrcH : 0,
                bmpW0 : 0,
                bmpH0 : 0,
            ; Bound function
                fn : "",
                fnParams : ""
            },
            2 : {
            ; Unique setters
                alpha : 0xFF,
                color : 0,
                filled : obj.filled,
                penwidth : obj.penwidth,
                visible : true
            }
        }
    }

    ; Add additional properties for the shape.
    addSupplementaryProps(&obj, &props) {
        local p := props
        switch obj.cls {
            case "Polygon", "FilledPolygon", "Triangle", "FilledTriangle", "Beziers", "Lines":
                p.1.pPoints := 0
                p.1.points := 0
                if !(obj.cls ~= "Beziers|Lines")
                    p.1.fillmode := obj.fillmode
            case "Arc", "Pie", "FilledPie":
                p.1.startangle := obj.startangle
                p.1.sweepangle := obj.sweepangle
            case "Bezier":
                p.1.x1 := obj.x1
                p.1.y1 := obj.y1
                p.1.x2 := obj.x2
                p.1.y2 := obj.y2
                p.1.x3 := obj.x3
                p.1.y3 := obj.y3
                p.1.x4 := obj.x4
                p.1.y4 := obj.y4
            case "Line":
                p.1.x1 := obj.x1
                p.1.y1 := obj.y1
                p.1.x2 := obj.x2
                p.1.y2 := obj.y2
        }
        return
    }

    ; Initialize the tool for the shape.
    InitializeTool(&obj) {

        local shp := Shapes.%this.layerid%.%this.id%
        
        obj.cls := this.base.__Class
        if (obj.HasOwnProp("Filled") && obj.filled) {
            shp.Tool := SolidBrush(obj.colour)
            obj.cls := "Filled" obj.cls
        }
        else if (obj.penwidth >= 1 && obj.penwidth <= 100) {
            shp.Tool := Pen(obj.colour, obj.penwidth)
            obj.filled := 0
        }
        else {
            throw ValueError("[!] Invalid value during tool initialization")
        }
        return
    }

    ; Set the base properties for the shape.
    setBaseProps(props) {
        loop 2 {
            i := A_Index
            for name, value in props.%i%.OwnProps() {
                getter := get_Shape.Bind(name)
                switch i {
                    case 1: setter := set_Shape.Bind(name)
                    case 2: setter := this.%("set_" name)%
                }
                this.DefineProp(name, {get : getter, set : setter})
                this.%name% := value
            }
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
        this.id := id := ++Shape.id

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

    /**
     * Removes `Prototype` and `__Init` methods for faster lookup
     * in the Shapes.OwnProps() enumeration.
     */
    static __New() {
        Shapes.DeleteProp("__Init")
        Shapes.DeleteProp("Prototype")
    }

    ; Release resources (font, tool, bitmap)
    __Delete() {
        if (Shapes.HasProp(this.LayerId) && Shapes.%this.LayerId%.HasProp(this.id)) {
            Font.RemoveAccess(Shapes.%this.LayerId%.%this.id%.Font.id)
            Shapes.%this.Layerid%.DeleteProp(this.id)
            OutputDebug("[-] Shape " this.id " deleted from Layer " this.Layerid "`n") 
        }
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

    ;{ Property setters

    set_PenWidth(value) {
        if (value >= 1 && value <= 100) {
            Shapes.%this.Layerid%.%this.id%.Tool.Width := value
            return
        }
        throw ValueError("[!] Invalid value for PenWidth property")
    }

    set_Visible(value) {
        if !(IsBool(value)) {
            if (value !== -1 || value != "Toggle")
                return
            Shapes.%this.Layerid%.%this.id%.Visible ^= 1
            return
        }
        Shapes.%this.Layerid%.%this.id%.Visible := value
    }

    set_Alpha(value) {
        local obj, c
        if (!isAlphaNum(value))
            return
        
        ; Return if no change in alpha value
        obj := Shapes.%this.Layerid%.%this.id%
        if (obj.Alpha == value)
            return

        ; Set the new tool color and alpha value
        if (obj.Tool.Type == 0 || obj.Tool.Type == 5) {
            obj.Tool.Color := (obj.Color & 0x00FFFFFF) | (value << 24)
        }
        else if (obj.Tool.Type == 4) {
            c :=  obj.Tool.Color
            c[1] := (c[1] & 0x00FFFFFF) | (value << 24)
            c[2] := (c[2] & 0x00FFFFFF) | (value << 24)
            obj.Tool.Color := c
        }
        ; TODO: finish the implementation for the other tool types
        
        obj.Alpha := value
    }

    set_Color(value) {

        local obj
        
        if (value && Type(value) == "Integer" || (Type(value) == "String")) {

            obj := Shapes.%this.Layerid%.%this.id%
            
            value := Color(value)

            ; Erase the current tool if the shape is not a brush or pen
            if (!obj.Tool || obj.Tool.Type !== 0 && obj.Tool.Type !== 5) {
                obj.Tool := ""
                if (obj.Filled)
                    obj.Tool := SolidBrush(value)
                else
                    obj.Tool := Pen(value, obj.PenWidth)
            }
    
            ; Set the color
            obj.Tool.Color := value
            return
        }
        else if (Type(value) == "Array") {

            obj := Shapes.%this.Layerid%.%this.id%

            tooltype := obj.Tool.Type

            ; The name not defined, default Linear Gradient Mode
            if (value.Length == 2) {

                value[1] := Color(value[1])
                value[2] := Color(value[2])

                ; It's gradient
                if (tooltype == 4) {
                    obj.Tool.color := [value[1], value[2]]
                    return
                }

                value.InsertAt(1, "")
                    tooltype := 4
            }
            else {
                switch value[1], 0 {
                    case "Gradient": tooltype := 4
                    case "Hatch":    tooltype := 1
                    case "Texture":  tooltype := 2
                    default: throw ValueError("[!]")
                }
            }

            ; Destroy the current tool.
            obj.Tool := ""

            switch tooltype {
                case 1:
                ; Hatch
                    value[2] := Color(value[2])
                    value[3] := Color(value[3])
                    obj.Tool := HatchBrush(value[2], value[3], value[4])
                case 2:
                ; Texture
                    obj.Tool := TextureBrush(value[2]
                    , value.has(3) ? value[3] : 0
                    , value.has(4) ? value[4] : 100)     ; TODO: implement fit to shape
                case 3:
                ; PathGradient (not implemented yet)
                    return
                ; Gradient
                case 4:
                    LinearGradientMode := (value.Has(4)) ? value[4] : 0
                    WrapMode := (value.Has(5)) ? value[5] : 1
                    RectF := Buffer(16)
                    NumPut("float", this.x, RectF, 0)
                    NumPut("float", this.y, RectF, 4)
                    NumPut("float", this.w, RectF, 8)
                    NumPut("float", this.h, RectF, 12)
                    obj.tool := LinearGradientBrush(value[2], value[3]
                        , LinearGradientMode, WrapMode, RectF.ptr)
            }
        }
        return
    }

    /**
    * Changes the tool between a pen and a brush based on the filled status.
    * @param {bool} value indicating whether the shape should be filled or not.  
     */
    set_Filled(value) {
        
        local obj, tooltype
        
        if (!IsBool(value))
            return

        ; Get the shape reference
        obj := Shapes.%this.Layerid%.%this.id%
        if (obj.Filled == value) ; && (obj.Tool.Type == 0 || obj.Tool.Type == 5)
            return

        ; Save the current color and tool type before deleting the tool
        tooltype := obj.Tool.Type
        clr := obj.Tool.Color
        obj.Tool := ""

        ; It's a switchback from gradient to pen
        if (Type(clr) == "Array") {
            clr := Random(0xFF000000, 0xFFFFFFFF)
        }

        ; Change the shape tool type
        if (tooltype == 5) {
            obj.Tool := SolidBrush(clr)
            this.Shape := "Filled" this.Shape
        }
        else if (tooltype == 0) {
            obj.Tool := Pen(clr, 1)
            this.Shape := SubStr(this.Shape, 7)
        } else
            return
    }
    ;}
}
