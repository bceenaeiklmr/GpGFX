; Script     Draw.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       13.04.2025
; Version    0.7.3

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