; Script     Shapes.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2

/**
 * GpGFX Vector Shape Primitives & Layout Factory
 *
 * Provides ready-to-use vector shapes, layout helpers, bounding box calculators,
 * and high-level UI components:
 *
 * Vector Shapes:
 * - Rectangles & Squares: Rectangle, FilledRectangle, RoundedRectangle, RoundRect, Square, FilledSquare.
 * - Curves & Ellipses: Ellipse, FilledEllipse, Circle, FilledCircle, Arc, Pie, FilledPie, Curve, ClosedCurve.
 * - Splines & Paths: Line, Lines, Bezier, Beziers, Polygon, FilledPolygon, Triangle, FilledTriangle, Point.
 * - Components & Content: Text, Picture, Bitmap, Image, Container, Dummy, Button.
 *
 * Features:
 * - Auto-centering and layer dimension inheritance when (w, h) or (x, y) are omitted.
 * - Multi-signature overloading: color names, ARGB hex, gradient arrays, and pixel coordinates.
 * - Vectorized and spline bounding box calculators with pen alignment compensation.
 */

/**
 * Resolves default layer dimensions, falling back to static screen dimensions if no active layer exists.
 *
 * @param {Integer} w Output variable for width
 * @param {Integer} h Output variable for height
 * @returns {void}
 */
getDefLayerDim(&w, &h) {
    local lyr := LayerStack.ActiveLayer
    w := (lyr) ? lyr.w : Layer.w
    h := (lyr) ? lyr.h : Layer.h
}

getDefLayerW() => (LayerStack.ActiveLayer ? LayerStack.ActiveLayer.w : Layer.w)
getDefLayerH() => (LayerStack.ActiveLayer ? LayerStack.ActiveLayer.h : Layer.h)

; Bounding Box Calculators

/**
 * Calculates axis-aligned bounds for a triangle shape.
 *
 * @param {Shape} shp Triangle shape instance
 * @returns {void}
 */
getBoundsTriangle(shp) {
    shp.x := Min(shp.x1, shp.x2, shp.x3)
    shp.y := Min(shp.y1, shp.y2, shp.y3)
    shp.w := Max(1, Max(shp.x1, shp.x2, shp.x3) - shp.x)
    shp.h := Max(1, Max(shp.y1, shp.y2, shp.y3) - shp.y)
}

/**
 * Calculates axis-aligned bounds for multi-point shapes (Polygons, Lines, Curves).
 *
 * @param {Shape} shp Point-based shape instance
 * @returns {void}
 */
getBoundsPoints(shp) {
    local x, y, x1, y1, x2, y2, pad
    static DIBsize := 32767
    x1 :=  DIBsize
    y1 :=  DIBsize
    x2 := -DIBsize
    y2 := -DIBsize

    loop shp.points {
        x := shp.%("x" A_Index)% 
        y := shp.%("y" A_Index)%
        (x < x1) && x1 := x
        (y < y1) && y1 := y
        (x > x2) && x2 := x
        (y > y2) && y2 := y
    }
    shp.x := (x1 <= x2) ? x1 : 0
    shp.y := (y1 <= y2) ? y1 : 0
    shp.w := Max(1, x2 - x1)
    shp.h := Max(1, y2 - y1)

    ; Account for curve tension and pen width extension beyond control points
    if (shp.HasProp("tension") && shp.tension > 0) {
        pad := Ceil(Max(shp.w, shp.h) * shp.tension * 0.5 + (shp.HasProp("penwidth") ? shp.penwidth : 2) + 8)
        shp.x := Max(0, shp.x - pad)
        shp.y := Max(0, shp.y - pad)
        shp.w += pad * 2
        shp.h += pad * 2
    }
}

/**
 * Calculates axis-aligned bounds for a cubic Bezier curve.
 *
 * @param {Shape} shp Bezier shape instance
 * @returns {void}
 */
getBoundsBezier(shp) {
    shp.x := Min(shp.x1, shp.x2, shp.x3, shp.x4)
    shp.y := Min(shp.y1, shp.y2, shp.y3, shp.y4)
    shp.w := Max(1, Max(shp.x1, shp.x2, shp.x3, shp.x4) - shp.x)
    shp.h := Max(1, Max(shp.y1, shp.y2, shp.y3, shp.y4) - shp.y)
}

/**
 * Calculates axis-aligned bounds for a straight line segment.
 *
 * @param {Shape} shp Line shape instance
 * @returns {void}
 */
getBoundsLine(shp) {
    shp.x := Min(shp.x1, shp.x2)
    shp.y := Min(shp.y1, shp.y2)
    shp.w := Max(1, Max(shp.x1, shp.x2) - shp.x)
    shp.h := Max(1, Max(shp.y1, shp.y2) - shp.y)
}

/**
 * Detects whether a parameter value represents a colour (string name/hex, array gradient, or 32-bit ARGB integer).
 *
 * @param {Any} [val] Parameter value to test
 * @returns {Boolean}
 */
isColourParam(val?) {
    if (!IsSet(val))
        return false
    if (val is String || val is Array)
        return true
    if (IsInteger(val) && (val > 0xFFFFFF || val < 0))
        return true
    return false
}

/**
 * Normalizes multi-overload constructor parameters for axis-aligned box shapes with automatic centering.
 *
 * @param {Any} [x] X coordinate, width, or colour
 * @param {Any} [y] Y coordinate, height, or filled flag
 * @param {Any} [w] Width or colour
 * @param {Any} [h] Height or filled flag
 * @param {Any} [colour] Colour descriptor
 * @param {Any} [filled] Filled boolean
 * @returns {Object} { x, y, w, h, colour, filled }
 */
getParamsNormal(x?, y?, w?, h?, colour?, filled?) {
    local posX, posY, width, height, clr, isFilled, defW, defH
    getDefLayerDim(&defW, &defH)

    ; 0 params: Rectangle() -> Full layer area, white, filled
    if (!IsSet(x) && !IsSet(y) && !IsSet(w) && !IsSet(h)) {
        posX := 0
        posY := 0
        width := defW
        height := defH
        clr := IsSet(colour) ? colour : 0xFFFFFFFF
        isFilled := IsSet(filled) ? filled : true
    }
    ; 1-2 params: Rectangle(colour, [filled]) -> Full layer area
    else if (isColourParam(x?) && !IsSet(w) && !IsSet(h)) {
        posX := 0
        posY := 0
        width := defW
        height := defH
        clr := x
        isFilled := IsSet(y) ? y : (IsSet(filled) ? filled : true)
    }
    ; 2-4 params: Rectangle(w, h, [colour, filled]) -> Auto-centered
    else if (IsSet(x) && IsSet(y) && (!IsSet(w) || isColourParam(w?)) && !IsSet(h)) {
        width := x
        height := y
        posX := (defW - width) // 2
        posY := (defH - height) // 2
        clr := IsSet(w) ? w : (IsSet(colour) ? colour : 0xFFFFFFFF)
        isFilled := IsSet(colour) ? colour : (IsSet(filled) ? filled : true)
    }
    ; Explicit: Rectangle(x, y, w, h, [colour, filled])
    else {
        width := IsSet(w) ? w : defW
        height := IsSet(h) ? h : defH
        posX := IsSet(x) ? x : (defW - width) // 2
        posY := IsSet(y) ? y : (defH - height) // 2
        clr := IsSet(colour) ? colour : 0xFFFFFFFF
        isFilled := IsSet(filled) ? filled : true
    }

    return { x: posX, y: posY, w: width, h: height, colour: clr, filled: isFilled }
}

; Shape Class Definitions

class Rectangle extends Shape {
    /**
     * Creates a rectangle shape.
     * 
     * @constructor
     * @overload Rectangle() - Full layer area, default white, filled
     * @overload Rectangle(colour, filled?) - Full layer area with specified color
     * @overload Rectangle(w, h, colour?, filled?) - Centered rectangle of size w×h
     * @overload Rectangle(x, y, w, h, colour?, filled?) - Rectangle at explicit coordinates
     * 
     * @param {Integer|String|Array} [x] X position, width (if 2 args), or colour string/ARGB int (if 1 arg)
     * @param {Integer|Boolean} [y] Y position, height (if 2 args), or filled boolean
     * @param {Integer|String|Array} [w] Width or colour
     * @param {Integer|Boolean} [h] Height or filled boolean
     * @param {String|Integer|Array} [colour=0xFFFFFFFF] Fill/stroke colour
     * @param {Boolean} [filled=true] True for SolidBrush fill, false for Pen outline stroke
     *
     * @example
     * ; Full-layer dark background
     * Rectangle("0xFF181824", true)
     * 
     * ; Centered card of size 300x200
     * Rectangle(300, 200, "Red", true)
     * 
     * ; Explicit bounding box at (20, 40)
     * Rectangle(20, 40, 160, 36, "0xFF78DCE8", false)
     */
    __New(x?, y?, w?, h?, colour?, filled?) {
        super.__New(getParamsNormal(x?, y?, w?, h?, colour?, filled?))
    }
}

class FilledRectangle extends Rectangle {
    /**
     * Creates a filled rectangle.
     * 
     * @constructor
     * @overload FilledRectangle() - Full layer area, default white, filled
     * @overload FilledRectangle(colour) - Full layer area with specified color
     * @overload FilledRectangle(w, h, colour?) - Centered rectangle of size w×h
     * @overload FilledRectangle(x, y, w, h, colour?) - Rectangle at explicit coordinates
     *
     * @param {Integer|String|Array} [x] X position, width, or colour
     * @param {Integer|Boolean} [y] Y position, height, or colour
     * @param {Integer|String|Array} [w] Width or colour
     * @param {Integer|Boolean} [h] Height or colour
     * @param {String|Integer|Array} [colour=0xFFFFFFFF] Fill colour
     */
    __New(x?, y?, w?, h?, colour?) {
        super.__New(x?, y?, w?, h?, colour?, true)
    }
}

class RoundedRectangle extends Shape {
    /**
     * Creates a rounded rectangle shape.
     * 
     * @constructor
     * @overload RoundedRectangle() - Full layer area, radius 10, default white, filled
     * @overload RoundedRectangle(colour, filled?) - Full layer area with colour and radius 10
     * @overload RoundedRectangle(r, colour?, filled?) - Full layer area with corner radius r
     * @overload RoundedRectangle(w, h, r?, colour?, filled?) - Centered rounded rectangle of size w×h
     * @overload RoundedRectangle(x, y, w, h, r?, colour?, filled?) - Explicit bounding box with radius r
     * 
     * @param {Integer|String|Array} [x] X position, width, corner radius r, or colour
     * @param {Integer|String|Boolean} [y] Y position, height, colour, or filled boolean
     * @param {Integer|String|Array} [w] Width, corner radius r, or colour
     * @param {Integer|String|Boolean} [h] Height, colour, or filled boolean
     * @param {Integer} [r=10] Corner radius in pixels
     * @param {String|Integer|Array} [colour=0xFFFFFFFF] Fill/stroke colour
     * @param {Boolean} [filled=true] True for SolidBrush fill, false for Pen outline
     * @param {Any} [extraParams*] Additional parameter spread
     */
    __New(x?, y?, w?, h?, r?, colour?, filled?, extraParams*) {
        local args, v, defW, defH, posX, posY, width, height, radius, clr, isFilled, aLen
        
        args := []
        IsSet(x) && args.Push(x)
        IsSet(y) && args.Push(y)
        IsSet(w) && args.Push(w)
        IsSet(h) && args.Push(h)
        IsSet(r) && args.Push(r)
        IsSet(colour) && args.Push(colour)
        IsSet(filled) && args.Push(filled)
        if (extraParams.Length) {
            for v in extraParams {
                args.Push(v)
            }
        }

        getDefLayerDim(&defW, &defH)
        
        if ((aLen := args.Length) == 0) {
            super.__New({ x: 0, y: 0, w: defW, h: defH, r: 10, colour: 0xFFFFFFFF, filled: true })
            return
        }

        posX := 0
        posY := 0
        width := defW
        height := defH
        radius := 10
        clr := 0xFFFFFFFF
        isFilled := true

        if (aLen == 1) {
            if (isColourParam(args[1]))
                clr := args[1]
            else
                radius := args[1]
        }
        else if (aLen == 2) {
            if (isColourParam(args[1])) {
                clr := args[1]
                isFilled := args[2]
            } else if (isColourParam(args[2])) {
                radius := args[1]
                clr := args[2]
            } else {
                width := args[1], height := args[2]
                posX := (defW - width) // 2
                posY := (defH - height) // 2
            }
        }
        else if (aLen == 3) {
            if (isColourParam(args[2])) {
                radius := args[1]
                clr := args[2]
                isFilled := args[3]
            } else if (isColourParam(args[3])) {
                width := args[1], height := args[2]
                posX := (defW - width) // 2
                posY := (defH - height) // 2
                clr := args[3]
            } else {
                width := args[1], height := args[2]
                posX := (defW - width) // 2
                posY := (defH - height) // 2
                radius := args[3]
            }
        }
        else if (aLen <= 5 && !isColourParam(args[3]) && (aLen < 4 || isColourParam(args[4]))) {
            width := args[1], height := args[2]
            posX := (defW - width) // 2
            posY := (defH - height) // 2
            radius := args[3]
            args.Has(4) && clr := args[4]
            args.Has(5) && isFilled := args[5]
        }
        else {
            args.Has(1) && posX := args[1]
            args.Has(2) && posY := args[2]
            args.Has(3) && width := args[3]
            args.Has(4) && height := args[4]
            args.Has(5) && radius := args[5]
            args.Has(6) && clr := args[6]
            args.Has(7) && isFilled := args[7]
        }

        super.__New({ x: posX, y: posY, w: width, h: height, r: radius, colour: clr, filled: isFilled })
    }
}

class RoundRect extends RoundedRectangle {   
}
class RoundRectangle extends RoundedRectangle {
}

class FilledRoundedRectangle extends RoundedRectangle {
    /**
     * Creates a filled rounded rectangle.
     */
    __New(x?, y?, w?, h?, r?, colour?, extraParams*) {
        super.__New(x?, y?, w?, h?, r?, colour?, true, extraParams*)
    }
}

class FilledRoundRect extends FilledRoundedRectangle {
}

class Square extends Shape {
    /**
     * Creates a square shape.
     * 
     * @constructor
     * @overload Square() - Full centered square fitting layer bounds
     * @overload Square(colour, filled?) - Centered square with colour
     * @overload Square(size, colour?, filled?) - Centered square of given size
     * @overload Square(x, y, size, colour?, filled?) - Square at explicit (x, y) coordinates
     * 
     * @param {Integer|String|Array} [x] X position, size, or colour
     * @param {Integer|String|Array} [y] Y position, colour, or filled flag
     * @param {Integer} [size] Size (width & height) in pixels
     * @param {String|Integer|Array} [colour=0xFFFFFFFF] Fill/stroke colour
     * @param {Boolean} [filled=true] True for SolidBrush fill, false for Pen outline
     */
    __New(x?, y?, size?, colour?, filled?) {
        local posX, posY, sz, col, fil, defW, defH
        getDefLayerDim(&defW, &defH)

        if (!IsSet(x)) {
            sz := Min(defW, defH)
            posX := (defW - sz) // 2
            posY := (defH - sz) // 2
            col := 0xFFFFFFFF
            fil := true
        }
        else if (isColourParam(x?) && !IsSet(size)) {
            sz := Min(defW, defH)
            posX := (defW - sz) // 2
            posY := (defH - sz) // 2
            col := x
            fil := IsSet(y) ? y : true
        }
        else if (IsSet(x) && (!IsSet(y) || isColourParam(y?))) {
            sz := x
            posX := (defW - sz) // 2
            posY := (defH - sz) // 2
            col := IsSet(y) ? y : 0xFFFFFFFF
            fil := IsSet(size) ? size : true
        }
        else {
            posX := x
            posY := y
            sz := IsSet(size) ? size : Min(defW, defH)
            col := IsSet(colour) ? colour : 0xFFFFFFFF
            fil := IsSet(filled) ? filled : true
        }
        super.__New({ x: posX, y: posY, w: sz, h: sz, colour: col, filled: fil })
    }
}

class FilledSquare extends Square {
    /**
     * Creates a filled square.
     */
    __New(x?, y?, size?, colour?) {
        super.__New(x?, y?, size?, colour?, true)
    }
}

class Ellipse extends Shape {
    /**
     * Creates an ellipse shape.
     * 
     * @constructor
     * @overload Ellipse() - Full layer area, default white, filled
     * @overload Ellipse(colour, filled?) - Full layer area with colour
     * @overload Ellipse(w, h, colour?, filled?) - Centered ellipse of size w×h
     * @overload Ellipse(x, y, w, h, colour?, filled?) - Ellipse at explicit (x, y) coordinates
     */
    __New(x?, y?, w?, h?, colour?, filled?) {
        super.__New(getParamsNormal(x?, y?, w?, h?, colour?, filled?))
    }
}

class FilledEllipse extends Ellipse {
    /**
     * Creates a filled ellipse.
     */
    __New(x?, y?, w?, h?, colour?) {
        super.__New(x?, y?, w?, h?, colour?, true)
    }
}

class Circle extends Ellipse {
    /**
     * Creates a circle shape (equal-radius ellipse).
     * 
     * @constructor
     * @overload Circle() - Centered circle fitting layer bounds
     * @overload Circle(colour, filled?) - Centered circle with colour
     * @overload Circle(r, colour?, filled?) - Centered circle of radius r (diameter = 2*r)
     * @overload Circle(x, y, r, colour?, filled?) - Circle at explicit (x, y) with radius r
     * 
     * @param {Integer|String|Array} [x] Center X position, radius r, or colour
     * @param {Integer|String|Array} [y] Center Y position, colour, or filled flag
     * @param {Integer} [r] Circle radius in pixels
     * @param {String|Integer|Array} [colour=0xFFFFFFFF] Fill/stroke colour
     * @param {Boolean} [filled=true] True for SolidBrush fill, false for Pen outline
     */
    __New(x?, y?, r?, colour?, filled?) {
        local cx, cy, rad, col, fil, defW, defH
        getDefLayerDim(&defW, &defH)

        if (!IsSet(x)) {
            rad := Min(defW, defH) // 2
            cx := (defW - rad * 2) // 2
            cy := (defH - rad * 2) // 2
            col := 0xFFFFFFFF
            fil := true
        }
        else if (isColourParam(x?) && !IsSet(r)) {
            rad := Min(defW, defH) // 2
            cx := (defW - rad * 2) // 2
            cy := (defH - rad * 2) // 2
            col := x
            fil := IsSet(y) ? y : true
        }
        else if (IsSet(x) && (!IsSet(y) || isColourParam(y?))) {
            rad := x
            cx := (defW - rad * 2) // 2
            cy := (defH - rad * 2) // 2
            col := IsSet(y) ? y : 0xFFFFFFFF
            fil := IsSet(r) ? r : true
        }
        else {
            rad := IsSet(r) ? r : (Min(defW, defH) // 2)
            cx := x - rad
            cy := y - rad
            col := IsSet(colour) ? colour : 0xFFFFFFFF
            fil := IsSet(filled) ? filled : true
        }
        super.__New(cx, cy, rad * 2, rad * 2, col, fil)
    }
}

class FilledCircle extends Circle {
    /**
     * Creates a filled circle.
     */
    __New(x?, y?, r?, colour?) {
        super.__New(x?, y?, r?, colour?, true)
    }
}

class Arc extends Shape {
    /**
     * Creates an arc stroke shape.
     * 
     * @constructor
     * @overload Arc() - Full layer area, 0° to 360° arc
     * @overload Arc(colour, penwidth?) - Full layer arc with colour
     * @overload Arc(w, h, colour?, penwidth?, startangle?, sweepangle?) - Centered arc of size w×h
     * @overload Arc(x, y, w, h, colour?, penwidth?, startangle?, sweepangle?) - Arc at explicit coordinates
     */
    __New(x?, y?, w?, h?, colour?, penwidth := 1, startangle := 0, sweepangle := 360) {
        local posX, posY, width, height, clr, pw, startA, sweepA

        posX := 0
        posY := 0
        getDefLayerDim(&width, &height)
        clr := "0xFFFFFFFF"
        pw := 1
        startA := 0
        sweepA := 360

        if (isColourParam(x?) && !IsSet(w) && !IsSet(h)) {
            clr := x
            pw := IsSet(y) ? y : 1
        } else {
            posX := IsSet(x) ? x : 0
            posY := IsSet(y) ? y : 0
            width := IsSet(w) ? w : 50
            height := IsSet(h) ? h : 50
            clr := IsSet(colour) ? colour : 0xFFFFFFFF
            pw := penwidth
            startA := startangle
            sweepA := sweepangle
        }

        super.__New({
            x: posX,
            y: posY,
            w: width,
            h: height,
            colour: clr,
            filled: false,
            penwidth: pw,
            startangle: startA,
            sweepangle: sweepA
        })
    }
}

class Pie extends Shape {
    /**
     * Creates a pie (wedge) shape.
     * 
     * @constructor
     * @overload Pie() - Full layer area, 0° to 360° pie wedge, filled
     * @overload Pie(colour, filled?) - Full layer pie with colour
     * @overload Pie(w, h, startangle?, sweepangle?, colour?, filled?) - Centered pie wedge
     * @overload Pie(x, y, w, h, startangle?, sweepangle?, colour?, filled?) - Pie wedge at explicit (x, y)
     */
    __New(x?, y?, w?, h?, startangle := 0, sweepangle := 360, colour?, filled := true) {
        local posX, posY, width, height, actualStart, actualSweep, actualColour, actualFilled, defW, defH
        
        getDefLayerDim(&defW, &defH)
        posX := 0
        posY := 0
        width := defW
        height := defH
        
        actualStart := 0
        actualSweep := 360
        actualColour := 0xFFFFFFFF
        actualFilled := true
        
        if (isColourParam(x?) && !IsSet(w) && !IsSet(h)) {
            actualColour := x
            actualFilled := IsSet(y) ? y : true
        }
        else if (IsSet(startangle) && isColourParam(startangle)) {
            posX := IsSet(x) ? x : 0
            posY := IsSet(y) ? y : 0
            width := IsSet(w) ? w : 50
            height := IsSet(h) ? h : 50
            actualColour := startangle
            actualFilled := IsSet(sweepangle) ? sweepangle : true
            actualStart := IsSet(colour) ? colour : 0
            actualSweep := IsSet(filled) ? filled : 360
        } else {
            posX := IsSet(x) ? x : 0
            posY := IsSet(y) ? y : 0
            width := IsSet(w) ? w : 50
            height := IsSet(h) ? h : 50
            actualStart := IsSet(startangle) ? startangle : 0
            actualSweep := IsSet(sweepangle) ? sweepangle : 360
            actualColour := IsSet(colour) ? colour : 0xFFFFFFFF
            actualFilled := IsSet(filled) ? filled : true
        }

        super.__New({
            x: posX,
            y: posY,
            w: width,
            h: height,
            colour: actualColour,
            filled: actualFilled,
            startangle: actualStart,
            sweepangle: actualSweep
        })
    }
}

class FilledPie extends Pie {
    /**
     * Creates a filled pie (wedge).
     */
    __New(x?, y?, w?, h?, startangle := 0, sweepangle := 360, colour?) {
        super.__New(x?, y?, w?, h?, startangle, sweepangle, colour?, true)
    }
}

class Triangle extends Shape {
    /**
     * Creates a triangle shape.
     * 
     * @constructor
     * @overload Triangle() - Default centered triangle
     * @overload Triangle(colour, filled?) - Default centered triangle with colour
     * @overload Triangle(x1, y1, x2, y2, x3, y3, colour?, filled?) - Triangle with explicit vertex coordinates
     */
    __New(x1 := 0, y1 := 0, x2 := 0, y2 := 0, x3 := 0, y3 := 0, colour?, filled?) {
        local pts, clr, fld, defW, defH
        getDefLayerDim(&defW, &defH)
        
        if (isColourParam(x1)) {
            pts := [0, 0, defW // 2, defH, defW, 0]
            clr := x1
            fld := IsSet(y1) ? y1 : true
        } else {
            pts := [x1, y1, x2, y2, x3, y3]
            clr := IsSet(colour) ? colour : 0xFFFFFFFF
            fld := IsSet(filled) ? filled : true
        }
        super.__New({ points: pts, colour: clr, filled: fld, fillmode: 1 })
    }
}

class FilledTriangle extends Triangle {
    /**
     * Creates a filled triangle.
     */
    __New(x1 := 0, y1 := 0, x2 := 0, y2 := 0, x3 := 0, y3 := 0, colour?) {
        super.__New(x1, y1, x2, y2, x3, y3, colour?, true)
    }
}

class Polygon extends Shape {
    /**
     * Creates a polygon shape from a flat array of points `[x1,y1, x2,y2, ...]`.
     * 
     * @constructor
     * @overload Polygon(pointsArray, colour?, filled?, fillmode?)
     * @overload Polygon(colour?, filled?, fillmode?, pointsArray?)
     */
    __New(colour?, filled := true, fillmode := 1, aPoints?) {
        local pts, clr, fld, fmode
        if (IsSet(colour) && colour is Array) {
            pts := colour
            clr := IsSet(filled) ? filled : 0xFFFFFFFF
            fld := IsSet(fillmode) ? fillmode : true
            fmode := IsSet(aPoints) ? aPoints : 1
        } else {
            clr := IsSet(colour) ? colour : 0xFFFFFFFF
            fld := filled
            fmode := fillmode
            pts := IsSet(aPoints) ? aPoints : []
        }
        super.__New({ points: pts, colour: clr, filled: fld, fillmode: fmode, penwidth: 1 })
    }
}

class FilledPolygon extends Polygon {
    /**
     * Creates a filled polygon.
     */
    __New(colour?, fillmode := 1, aPoints?) {
        super.__New(colour?, true, fillmode, aPoints?)
    }
}

class Bezier extends Shape {
    /**
     * Creates a cubic Bezier curve stroke between start (x1,y1) and end (x4,y4) with two control points.
     */
    __New(x1 := 0, y1 := 0, x2 := 0, y2 := 0, x3 := 0, y3 := 0, x4 := 0, y4 := 0, colour?, penwidth := 1) {
        super.__New({
            x1: x1, y1: y1,
            x2: x2, y2: y2,
            x3: x3, y3: y3,
            x4: x4, y4: y4,
            colour: (IsSet(colour) ? colour : 0xFFFFFFFF),
            penwidth: penwidth,
            filled: false
        })
    }
}

class Beziers extends Shape {
    /**
     * Creates multiple connected Bezier spline curves from a point array.
     */
    __New(colour?, penwidth := 1, aPoints?) {
        local pts, clr, pw
        if (IsSet(colour) && colour is Array) {
            pts := colour
            clr := IsSet(penwidth) ? penwidth : 0xFFFFFFFF
            pw := IsSet(aPoints) ? aPoints : 1
        } else {
            clr := IsSet(colour) ? colour : 0xFFFFFFFF
            pw := penwidth
            pts := IsSet(aPoints) ? aPoints : []
        }
        super.__New({ points: pts, colour: clr, penwidth: pw, filled: false })
    }
}

class Line extends Shape {
    /**
     * Creates a straight line stroke between two points (x1,y1) and (x2,y2).
     */
    __New(x1 := 0, y1 := 0, x2 := 0, y2 := 0, colour?, penwidth := 1) {
        super.__New({
            x1: x1, y1: y1,
            x2: x2, y2: y2,
            colour: (IsSet(colour) ? colour : 0xFFFFFFFF),
            penwidth: penwidth,
            filled: false
        })
    }
}

class Lines extends Shape {
    /**
     * Creates connected polyline segments from a flat vertex array `[x1,y1, x2,y2, ...]`.
     */
    __New(colour?, penwidth := 1, aPoints?) {
        local pts, clr, pw
        if (IsSet(colour) && (colour is Array)) {
            pts := colour
            clr := IsSet(penwidth) ? penwidth : 0xFFFFFFFF
            pw := IsSet(aPoints) ? aPoints : 1
        } else {
            clr := IsSet(colour) ? colour : 0xFFFFFFFF
            pw := penwidth
            pts := IsSet(aPoints) ? aPoints : []
        }
        super.__New({ points: pts, colour: clr, penwidth: pw, filled: false })
    }
}

class Point extends Shape {
    /**
     * Creates a single pixel dot shape.
     */
    __New(x := 0, y := 0, colour?, size := 1) {
        super.__New({
            x: x, y: y,
            colour: (IsSet(colour) ? colour : 0xFFFFFFFF),
            w: size, h: size,
            penwidth: 1,
            filled: true
        })
    }
}

class Curve extends Shape {
    /**
     * Creates an open cardinal spline passing smoothly through a given point array.
     */
    __New(pointsOrColour?, colourOrPenwidth?, penwidthOrTension := 1, tensionOrPoints := 0.5) {
        local pts := [], clr := 0xFFFFFFFF, pw := 1, t := 0.5

        if (IsSet(pointsOrColour) && (pointsOrColour is Array)) {
            pts := pointsOrColour
            clr := IsSet(colourOrPenwidth) ? colourOrPenwidth : 0xFFFFFFFF
            pw := IsSet(penwidthOrTension) ? penwidthOrTension : 1
            t := IsSet(tensionOrPoints) ? tensionOrPoints : 0.5
        } else {
            clr := IsSet(pointsOrColour) ? pointsOrColour : 0xFFFFFFFF
            pw := IsSet(colourOrPenwidth) ? colourOrPenwidth : 1
            t := IsSet(penwidthOrTension) ? penwidthOrTension : 0.5
            pts := IsSet(tensionOrPoints) && (tensionOrPoints is Array) ? tensionOrPoints : []
        }
        super.__New({ points: pts, colour: clr, penwidth: pw, tension: t, filled: false })
    }
}

class ClosedCurve extends Shape {
    /**
     * Creates a closed cardinal spline passing smoothly through a given point array.
     */
    __New(pointsOrColour?, colourOrFilled?, filledOrTension := true, tensionOrFillmode := 0.5, fillmodeOrPoints := 0) {
        local pts := [], clr := 0xFFFFFFFF, fld := true, t := 0.5, fmode := 0

        if (IsSet(pointsOrColour) && (pointsOrColour is Array)) {
            pts := pointsOrColour
            clr := IsSet(colourOrFilled) ? colourOrFilled : 0xFFFFFFFF
            fld := IsSet(filledOrTension) ? filledOrTension : true
            t := IsSet(tensionOrFillmode) ? tensionOrFillmode : 0.5
            fmode := IsSet(fillmodeOrPoints) ? fillmodeOrPoints : 0
        } else {
            clr := IsSet(pointsOrColour) ? pointsOrColour : 0xFFFFFFFF
            fld := IsSet(colourOrFilled) ? colourOrFilled : true
            t := IsSet(filledOrTension) ? filledOrTension : 0.5
            fmode := IsSet(tensionOrFillmode) ? tensionOrFillmode : 0
            pts := IsSet(fillmodeOrPoints) && (fillmodeOrPoints is Array) ? fillmodeOrPoints : []
        }
        super.__New({ points: pts, colour: clr, filled: fld, tension: t, fillmode: fmode, penwidth: 1 })
    }
}

; Container, Typography & UI Components

class Container extends Shape {
    /**
     * Invisible bounding box container for grouping shapes, attaching text/images, or defining mouse hit-test zones.
     */
    __New(x?, y?, w?, h?) {
        local defW, defH
        getDefLayerDim(&defW, &defH)
        super.__New({
            x: (IsSet(x) ? x : 0),
            y: (IsSet(y) ? y : 0),
            w: (IsSet(w) ? w : defW),
            h: (IsSet(h) ? h : defH),
            shape: "Dummy",
            isDummy: true
        })
    }
}

class Dummy extends Container {
}

class Text extends Shape {
    /**
     * Standalone rich-text typography shape with automatic word wrapping, tagged inline formatting, and subpixel ClearType support.
     *
     * @example
     * ; Centered header
     * Text("Hello GpGFX!", "White", 16, "Segoe UI", "Bold").MiddleCenter()
     *
     * ; Multi-color tagged text
     * Text("{#78DCE8}CPU:{} <b>12%</b>  |  {#FF6188}RAM:{} <b>4.2 GB</b>", "White", 11).TopLeft().Shift(20, 15)
     */
    __New(str?, colour?, size?, family?, style?, quality?, alignmentH?, alignmentV?, lineSpacing?, lineHeight?, extraParams*) {
        local args, v, posX, posY, width, height, defW, defH
            , sText, sColour, sSize, sFamily, sStyle, sQuality
            , sAlignH, sAlignV, sSpacing, sLineH, aLen, firstSetIdx
        
        args := []
        IsSet(str) && args.Push(str)
        IsSet(colour) && args.Push(colour)
        IsSet(size) && args.Push(size)
        IsSet(family) && args.Push(family)
        IsSet(style) && args.Push(style)
        IsSet(quality) && args.Push(quality)
        IsSet(alignmentH) && args.Push(alignmentH)
        IsSet(alignmentV) && args.Push(alignmentV)
        IsSet(lineSpacing) && args.Push(lineSpacing)
        IsSet(lineHeight) && args.Push(lineHeight)
        
        if (extraParams.Length) {
            loop extraParams.Length {
                if (extraParams.Has(A_Index))
                    args.Push(extraParams[A_Index])
            }
        }

        getDefLayerDim(&defW, &defH)
        posX := 0
        posY := 0
        width := defW
        height := defH
        aLen := args.Length
        firstSetIdx := 0

        loop aLen {
            if (args.Has(A_Index)) {
                firstSetIdx := A_Index
                break
            }
        }

        if (firstSetIdx == 0) {
            super.__New({ x: posX, y: posY, w: width, h: height, shape: "Text", isDummy: true })
            return
        }

        if (firstSetIdx == 1 && (args[1] is String || args[1] is Array)) {
            sText := args[1]
            args.Has(2)  && sColour  := args[2]
            args.Has(3)  && sSize    := args[3]
            args.Has(4)  && sFamily  := args[4]
            args.Has(5)  && sStyle   := args[5]
            args.Has(6)  && sQuality := args[6]
            args.Has(7)  && sAlignH  := args[7]
            args.Has(8)  && sAlignV  := args[8]
            args.Has(9)  && sSpacing := args[9]
            args.Has(10) && sLineH   := args[10]
        }
        else if (args.Has(3) && (args[3] is String || args[3] is Array)) {
            posX := args.Has(1) ? args[1] : 0
            posY := args.Has(2) ? args[2] : 0
            width := defW - posX
            height := defH - posY
            sText := args[3]
            args.Has(4)  && sColour  := args[4]
            args.Has(5)  && sSize    := args[5]
            args.Has(6)  && sFamily  := args[6]
            args.Has(7)  && sStyle   := args[7]
            args.Has(8)  && sQuality := args[8]
            args.Has(9)  && sAlignH  := args[9]
            args.Has(10) && sAlignV  := args[10]
            args.Has(11) && sSpacing := args[11]
            args.Has(12) && sLineH   := args[12]
        }
        else {
            args.Has(1) && posX   := args[1]
            args.Has(2) && posY   := args[2]
            args.Has(3) && width  := args[3]
            args.Has(4) && height := args[4]
            args.Has(5) && sText  := args[5]
            args.Has(6) && sColour  := args[6]
            args.Has(7) && sSize    := args[7]
            args.Has(8) && sFamily  := args[8]
            args.Has(9) && sStyle   := args[9]
            args.Has(10) && sQuality := args[10]
            args.Has(11) && sAlignH  := args[11]
            args.Has(12) && sAlignV  := args[12]
            args.Has(13) && sSpacing := args[13]
            args.Has(14) && sLineH   := args[14]
        }

        super.__New({ x: posX, y: posY, w: width, h: height, shape: "Text", isDummy: true })
        if (IsSet(sText))
            this.Text(sText?, sColour?, sSize?, sFamily?, sStyle?, sQuality?, sAlignH?, sAlignV?, sSpacing?, sLineH?)
    }
}

class Picture extends Shape {
    /**
     * Standalone image/picture shape accepting file paths, URLs, HBITMAPs, HICONs, or GdipBitmap instances.
     *
     * @example
     * ; Display logo in top-left
     * Picture(20, 20, 48, 48, "assets/logo.png")
     */
    __New(source?, option?, effect?, extraParams*) {
        local args, v, posX, posY, width, height, sSource, sOpt, sEff, aLen, firstSetIdx, defW, defH

        args := []
        IsSet(source) && args.Push(source)
        IsSet(option) && args.Push(option)
        IsSet(effect) && args.Push(effect)
        if (extraParams.Length) {
            loop extraParams.Length {
                if (extraParams.Has(A_Index))
                    args.Push(extraParams[A_Index])
            }
        }

        getDefLayerDim(&defW, &defH)
        posX := 0
        posY := 0
        width := defW
        height := defH
        aLen := args.Length
        firstSetIdx := 0

        loop aLen {
            if (args.Has(A_Index)) {
                firstSetIdx := A_Index
                break
            }
        }

        if (firstSetIdx == 0) {
            super.__New({ x: posX, y: posY, w: width, h: height, shape: "Picture", isDummy: true })
            return
        }

        isImg(val) => (val is String || (IsInteger(val) && val > 100000) || (IsObject(val) && (val.HasProp("pBitmap") || val.HasProp("ptr"))))

        if (firstSetIdx == 1 && isImg(args[1])) {
            sSource := args[1]
            args.Has(2) && sOpt := args[2]
            args.Has(3) && sEff := args[3]
        }
        else if (args.Has(3) && isImg(args[3])) {
            posX := args.Has(1) ? args[1] : 0
            posY := args.Has(2) ? args[2] : 0
            width := defW - posX
            height := defH - posY
            sSource := args[3]
            args.Has(4) && sOpt := args[4]
            args.Has(5) && sEff := args[5]
        }
        else if (aLen <= 2) {
            width  := args.Has(1) ? args[1] : defW
            height := args.Has(2) ? args[2] : defH
            posX   := 0
            posY   := 0
        }
        else {
            args.Has(1) && posX   := args[1]
            args.Has(2) && posY   := args[2]
            args.Has(3) && width  := args[3]
            args.Has(4) && height := args[4]
            args.Has(5) && sSource := args[5]
            args.Has(6) && sOpt   := args[6]
            args.Has(7) && sEff   := args[7]
        }

        super.__New({ x: posX, y: posY, w: width, h: height, shape: "Picture", isDummy: true })
        if (IsSet(sSource))
            this.AddImage(sSource, sOpt?, sEff?)
    }

    static FromClipboard(x?, y?, w?, h?, opt?, eff?) {
        local gdipBmp := GdipBitmap.FromClipboard()
        if (!gdipBmp)
            return 0
        local posX := IsSet(x) ? x : 0
        local posY := IsSet(y) ? y : 0
        local width := IsSet(w) ? w : gdipBmp.w
        local height := IsSet(h) ? h : gdipBmp.h
        local shp := this(posX, posY, width, height)
        shp.AddImage(gdipBmp, opt?, eff?)
        return shp
    }

    static FromFile(fp) => GdipBitmap.FromFile(fp)
    static FromScreen(x?, y?, w?, h?) => GdipBitmap.FromScreen(x?, y?, w?, h?)
    static FromHWND(hwnd) => GdipBitmap.FromHWND(hwnd)
    static FromHBITMAP(hbm) => GdipBitmap.FromHBITMAP(hbm)
    static FromHICON(hicon) => GdipBitmap.FromHICON(hicon)
    static FromStream(pStream) => GdipBitmap.FromStream(pStream)
    static FromMemory(pData, size) => GdipBitmap.FromMemory(pData, size)
}

class Bitmap extends Picture {
}
class Image extends Picture {
}

class Button extends RoundedRectangle {
    /**
     * Interactive Button component with automatic hover glow, click routing, and centered label.
     *
     * @example
     * ; 1-line interactive button with callback
     * Button(20, 210, 160, 36, "Launch", () => MsgBox("Launched!"))
     */
    __New(label?, onClick?, hoverColour?, bgColour?, r := 8, extraParams*) {
        local args, v, posX, posY, width, height, radius
        local sLabel, fnClick, clrHover, clrBg, clrText, aLen, firstArg
        
        args := []
        IsSet(label) && args.Push(label)
        IsSet(onClick) && args.Push(onClick)
        IsSet(hoverColour) && args.Push(hoverColour)
        IsSet(bgColour) && args.Push(bgColour)
        IsSet(r) && args.Push(r)
        if (extraParams.Length) {
            for v in extraParams {
                args.Push(v)
            }
        }

        posX := 0
        posY := 0
        width := 160
        height := 36
        radius := 8
        
        sLabel := ""
        clrBg := 0xFF2D2A3E
        clrText := 0xFFFFFFFF
        aLen := args.Length

        if (aLen == 0) {
            super.__New(posX, posY, width, height, radius, clrBg, true)
            this.Button()
            return
        }

        firstArg := (args.Has(1)) ? args[1] : unset

        if (IsSet(firstArg) && (firstArg is String || firstArg is Array)) {
            sLabel := firstArg
            (aLen >= 2 && args.Has(2)) && fnClick := args[2]
            (aLen >= 3 && args.Has(3)) && clrHover := args[3]
            (aLen >= 4 && args.Has(4)) && clrBg := args[4]
            (aLen >= 5 && args.Has(5)) && radius := args[5]
        }
        else if (aLen >= 3 && args.Has(3) && (args[3] is String || args[3] is Array)) {
            posX := args.Has(1) ? args[1] : 0
            posY := args.Has(2) ? args[2] : 0
            sLabel := args[3]
            (aLen >= 4 && args.Has(4)) && fnClick := args[4]
            (aLen >= 5 && args.Has(5)) && clrHover := args[5]
            (aLen >= 6 && args.Has(6)) && clrBg := args[6]
            (aLen >= 7 && args.Has(7)) && radius := args[7]
        }
        else {
            args.Has(1) && posX   := args[1]
            args.Has(2) && posY   := args[2]
            args.Has(3) && width  := args[3]
            args.Has(4) && height := args[4]
            args.Has(5) && sLabel := args[5]
            args.Has(6) && fnClick := args[6]
            args.Has(7) && clrHover := args[7]
            args.Has(8) && clrBg  := args[8]
            args.Has(9) && radius := args[9]
        }

        super.__New(posX, posY, width, height, radius, clrBg, true)
        this.Button(sLabel, fnClick?, clrHover?, clrText)
    }
}