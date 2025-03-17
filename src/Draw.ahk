; Script     Draw.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025
; Version    0.7.1

/**
 * This function is responsible for rendering and refreshing the specified
 * layer, window on the display. Each layer has its own graphics object,
 * and the function draws the shapes, images, and texts on the layer.
 * @param {Layer} lyr - The layer object that needs to be drawn and updated.
 * 
 * @credit all DllCall functions are from iseahound work (Graphics, Textrender, ImagePut)
 * 		   https://github.com/iseahound
 */
Draw(lyr) {

    local x, y, w, h, x1, y1, gfx, ptr, RectF, pState

    ; Save the layer's current dimensions and prepare the layer for drawing
    x1 := lyr.x1
    y1 := lyr.y1
    w1 := lyr.w
    h1 := lyr.h
    lyr.Prepare()

    gfx := Graphics.%lyr.id%.gfx

    ; Clear the entire buffer if the layer is not persistent
    if (!lyr.redraw) {
        
        ; Erasing only a region looked like a good idea, but it's slower (see EraseRegion function)
        DllCall("RtlZeroMemory", "ptr", Graphics.%lyr.id%.ppvBits, "ptr", lyr.w * lyr.h * 4)

        ; Reset the world transform and perform a new translation if the layer has changed position
        if (x1 !== lyr.x1 || y1 !== lyr.y1) {
            DllCall("gdiplus\GdipResetWorldTransform", "ptr", gfx)
            DllCall("gdiplus\GdipTranslateWorldTransform", "ptr", gfx, "float", -lyr.x1, "float", -lyr.y1, "int", 0)
        }
    }
    else {
        ; Cropped
        lyr.x1 := x1
        lyr.y1 := y1
        lyr.width := w1
        lyr.height := h1
        ; For full DIB size:
        ;lyr.x1 := 0
        ;lyr.y1 := 0
        ;lyr.width := Graphics.%lyr.id%.w
        ;lyr.height := Graphics.%lyr.id%.h
    }

    ; Parse the visible shape list and draw
    loop parse, lyr.prepared, "|" {

        v := Shapes.%lyr.id%.%A_LoopField%

        ; Crop if outside of the layer boundaries, assume it is inside
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

        ; Reference to the shape's tool (Brush, Pen)
        ptr := Shapes.%lyr.id%.%v.id%.Tool.ptr

        ; Draw shape
        switch v.shape {
            ; TODO: reimplement graphics settings, currently commented out

            case "Arc":
                ;DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 0)
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
                DllCall("gdiplus\GdipDrawBeziers"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Ellipse":
                DllCall("gdiplus\GdipDrawEllipse"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledRectangle", "FilledSquare":
                DllCall("gdiplus\GdipFillRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "Rectangle", "Square":
                DllCall("gdiplus\GdipDrawRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledEllipse":
                DllCall("gdiplus\GdipFillEllipse"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledPie":
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
                DllCall("gdiplus\GdipFillPolygon"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points
                    , "int", v.fillMode)

            case "Triangle", "Polygon":
                DllCall("gdiplus\GdipDrawPolygon"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Line":
                DllCall("gdiplus\GdipDrawLine"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", v.x1
                    , "float", v.y1
                    , "float", v.x2
                    , "float", v.y2)

            case "Lines":
                DllCall("gdiplus\GdipDrawLines"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)
        }

        ; Draw bitmap
        if (v.Bitmap.ptr) {

            ; Save the current graphics settings and set the new settings for the bitmap drawing
            DllCall("gdiplus\GdipSaveGraphics", "ptr", gfx, "ptr*", &pState := 0)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 2) ; Half pixel offset
            DllCall("gdiplus\GdipSetCompositingMode", "ptr", gfx, "int", 0) ; Overwrite/SourceCopy
            DllCall("gdiplus\GdipSetCompositingQuality", "ptr", gfx, "int", 0) ; AssumeLinear
            DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 0) ; No anti-alias
            DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7) ; HighQualityBicubic

            ; Align the image to center inside the object
            x2 := v.x + (v.w - v.Bitmap.w) // 2
            y2 := v.y + (v.h - v.Bitmap.h) // 2

            ; GdipDrawImage is faster than GdipDrawImageRectRect, but it doesn't support scaling
            if (v.bmpW || v.bmpH || v.bmpSrcW || v.bmpSrcH || v.bmpSrcX || v.bmpSrcY) {

                ; Calculate the destination
                x2 += v.bmpX
                y2 += v.bmpY
                w2 := v.Bitmap.w + v.bmpW
                h2 := v.Bitmap.h + v.bmpH

                ; And the source
                x1 := v.bmpSrcX
                y1 := v.bmpSrcY
                w1 := v.bmpSrcW ? v.Bitmap.w + v.bmpSrcW - x1 : v.Bitmap.w - x1
                h1 := v.bmpSrcH ? v.Bitmap.h + v.bmpSrcH - y1 : v.Bitmap.h - y1

                DllCall("gdiplus\GdipDrawImageRectRectI"
                    , "ptr", gfx
                    , "ptr", v.Bitmap.ptr
                    , "int", x2, "int", y2, "int", w2, "int", h2 ; dest
                    , "int", x1, "int", y1, "int", w1, "int", h1 ; src
                    , "int", 2
                    , "ptr", 0
                    , "ptr", 0
                    , "ptr", 0)
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

        ; Draw string
        if (v.str !== "") {

            ; Rendering quality is a global setting for the layer(!), so only change if it's different
            ; TODO: fix
            if (v.strQ !== Font.quality) {
                DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gfx, "int", v.strQ)
                Font.quality := v.strQ
            }

            ; Each font has its own alignment settings
            if (v.strH !== v.Font.alignmentH) {
                DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", v.Font.hFormat, "int", v.Font.alignmentH)
                v.Font.alignmentH := v.strH
            }
            if (v.strV !== v.Font.alignmentV) {
                DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", v.Font.hFormat, "int", v.Font.alignmentV)
                v.Font.alignmentV := v.strV
            }

            ; Save the current graphics settings
            ; TODO: investiagate if this is required
            DllCall("gdiplus\GdipSaveGraphics", "ptr", gfx, "ptr*", &pState := 0)

            ; Set the text vertical and horizontal string format alignment. ; -> TODO check if switch required
            DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", v.Font.hFormat, "int", v.font.AlignmentH)
            DllCall("Gdiplus\GdipSetStringFormatLineAlign", "ptr", v.Font.hFormat, "int", v.font.AlignmentV)

            ; Create a RectF structure to hold the bounding rectangle of the string
            RectF := Buffer(16)
            NumPut("float", v.x + v.strX, RectF, 0)
            NumPut("float", v.y + v.strY, RectF, 4)
            NumPut("float", v.w, RectF, 8)
            NumPut("float", v.h, RectF, 12)

            ; Draw the string without any measurement.
            DllCall("gdiplus\GdipDrawString"
                , "ptr", gfx            ; pointer to the graphics object
                , "wstr", v.str         ; pointer to the string
                , "int", -1             ; null terminated
                , "ptr", v.Font.hFont   ; pointer to the font object
                , "ptr", RectF          ; pointer to the bounding rectangle
                , "ptr", v.Font.hFormat ; pointer to the string format object
                , "ptr", v.Font.pBrush) ; pointer to the brush object

            ; Restore the original graphics settings, and Font color. (Brush)
            DllCall("gdiplus\GdipRestoreGraphics", "ptr", gfx, "ptr", pState)
        }

    }

    if (!Render.UpdateWindow)
        return

    ; Update the window
    DllCall("UpdateLayeredWindow"
        , "ptr", lyr.hwnd
        , "ptr", 0
        , "uint64*", (lyr.x + lyr.x1) | (lyr.y + lyr.y1) << 32
        , "uint64*", lyr.width | lyr.height << 32 ; TODO: calculate the update region
        , "ptr", Graphics.%lyr.id%.hdc
        , "uint64*", 0
        , "uint", 0
        , "uint*", lyr.alpha << 16 | 1 << 24
        , "uint", 2)
    return
}

/**
 * This class is responsible for rendering a single layer, or more layers.
 * The class calculates the elapsed time between two calls. It also update
 * the Fps object with the new frame data.
 */
class Render {

    ; Will be important to not update the window automatically (e.g.: saving)
    static UpdateWindow := true

    ; For a single layer rendering
    static Layer(obj) {

        ; Start timer, draw layer
        start := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)
        Draw(obj)

        ; Calculate elapsed time in milliseconds since the last frame update
        elapsed := ((DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf) - start) * 1000
            + (Fps.frames ? (start - Fps.lasttick) * 1000 : 0)

        ; Wait until the specified frame time is reached to sync drawing
        waited := 0
        if (Fps.frametime && Fps.frametime > elapsed) {
            start := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)
            while (Fps.frametime >= elapsed + waited) {
                waited := ((DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf) - start) * 1000
            }
        }

        ; Update the Fps object with the new frame data
        Fps.rendertime += elapsed + waited
        Fps.totaltime += elapsed + waited
        Fps.lastfps := 1000 / (elapsed + waited)
        Fps.totalrender += elapsed
        Fps.lastrender := 1000 / elapsed
        Fps.frames += 1

        ; Update the last tick, this helps to calculate the elapsed time between two render calls
        Fps.lasttick := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)
    }

    ; For multiple layers rendering
    static Layers(obj*) {

        ; Start with the timer
        start := (DllCall("QueryPerformanceCounter", "int64*", &qpc := 0), qpc / this.qpf)

        ; If Fps is set to persistent, push its layer to the array, so it's displayed during the render
        if (Fps.persistent && Fps.Layer) {
            obj.Push(Fps.Layer)
        }

        loop obj.Length {

            ; If the object is hidden or set to update every n frames, skip drawing
            if (!obj[A_Index].visible
            || (obj[A_Index].updatefreq && Mod(Fps.frames, obj[A_Index].updatefreq))) {
                continue
            }

            ; If Fps.Persistent is usually false, the first condition will be faster
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

    ; Binds the QueryPerformanceFrequency function as a property
    static __New() {
        this.DefineProp("qpf", { get: (*) => (DllCall("QueryPerformanceFrequency", "int64*", &qpf := 0), qpf) })
    }
}
