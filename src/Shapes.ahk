; Script     Shapes.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       13.04.2025
; Version    0.7.3

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