; Script:    Draw.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

/**
 * GpGFX Drawing and Rendering
 *
 * Core rasterization pipeline and frame timing:
 * - Draw(lyr): Rasterizes layer shapes (rectangles, paths, text, bitmaps) to an offscreen buffer and presents them on screen via UpdateLayeredWindow.
 * - Render: Manages frame pacing, FPS capping, and multi-layer frame synchronization.
 *
 * @credit Tariq Porter & Marius Șucan - Gdip2 / Object.ahk (Rounded rectangle path generation)
 * @credit iseahound - TextRender v1.9.3, RenderOnScreen / DrawOnGraphics (Typography & Window Update)
 */

/**
 * Renders all visible shapes registered on a layer and updates the window display.
 *
 * @param {Layer|Integer} lyr Layer instance, layer ID, or raw layer pointer
 * @returns {void}
 *
 * @example
 * ; 1. Draw a layer directly
 * lyr := Layer(400, 300)
 * RoundedRectangle(20, 20, 360, 260, 12, "0xFF1E1E2E", true)
 * Draw(lyr)
 *
 * ; 2. Draw using layer method syntax
 * lyr.Draw()
 */
Draw(lyr) {

    static RectF := Buffer(16, 0)
    local x, y, w, h, x1, y1, x2, y2, lyrW, lyrH, prevX, prevY, prevW, prevH, v, gfx, ptr, pState
        , dstX, dstY, line, lines, lineWidth, lineHeight, chrWidth, pPath, d, r
        , baseX, baseY, index, pos, oriColor, text, strRaw, curQuality := "", freeRef := false
        , rawSegments, val, lineW, ch, lineH, cw, seg, pw, penW, offset, winW, winH, textClr

    ; 1. Pointer and layer resolution
    if (lyr is Integer) {
        lyr := ObjFromPtrAddRef(LayerStack.pointers.Get(lyr, lyr))
        if (!IsObject(lyr) || !lyr.HasProp("gfx"))
            return
        freeRef := true
    }

    ; Cache gfx pointer once at start (avoids repeated property lookups)
    gfx := lyr.gfx.ptr

    ; 2. Previous dirty region clearing
    prevX := lyr.x1
    prevY := lyr.y1
    prevW := lyr.width
    prevH := lyr.height

    ; Erase previous frame's dirty region from the DC (once)
    if (!lyr.redraw && prevW && prevH) {
        DllCall("gdiplus\GdipSetClipRect", "ptr", gfx, "float", prevX, "float", prevY, "float", prevW, "float", prevH, "int", 0),
        DllCall("gdiplus\GdipGraphicsClear", "ptr", gfx, "uint", 0x00FFFFFF),
        DllCall("gdiplus\GdipResetClip", "ptr", gfx)
    }

    ; 3. Shape preparation and bounds synchronization
    if (!lyr.Prepare()) {

        ; If normal draw mode and previous frame had visible content, reset layer bounds and clean up
        if (!lyr.redraw && prevW && prevH)
            lyr.Clean()
        if (freeRef)
            lyr := ""
        return
    }

    ; Cache new frame bounds in fast locals
    x1 := lyr.x1
    y1 := lyr.y1
    lyrW := lyr.width
    lyrH := lyr.height

    ; Overdraw mode: expand cumulative bounding box to encompass all drawn frames
    if (lyr.redraw && prevW && prevH) {
        lyr.x1 := x1 := Min(prevX, x1)
        lyr.y1 := y1 := Min(prevY, y1)
        x2 := Max(prevX + prevW, lyr.x2)
        y2 := Max(prevY + prevH, lyr.y2)
        lyr.width := lyrW := x2 - x1
        lyr.height := lyrH := y2 - y1
    }

    ; 4. Shape dispatch and vector rasterization
    for v in lyr.drawSequence {

        ; Direct bypass for invisible dummy shapes without text or bitmap
        if (v.shape == "Dummy" && (v.str == "" || v.str == 0) && (!v.Bitmap || !v.Bitmap.ptr))
            continue

        ; Get reference to the shape's tool (Brush, Pen, or raw pointer)
        ptr := (IsObject(v.Tool) && v.Tool.HasProp("ptr")) ? v.Tool.ptr : (IsInteger(v.Tool) ? v.Tool : 0)

        ; Crop if outside of the layer boundaries, assume it is inside.
        if !(v.shape ~= "(Triangle|Polygon|Bezier|Beziers|Line|Lines|Curve|ClosedCurve|Picture|Text)$") {

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

            ; If PenMode is Outset/Outside (2), expand coordinates outward so
            ; stroke lies outside shape bounds.
            if (IsObject(v.tool) && v.tool.HasProp("type") && v.tool.type == 5 && v.tool.HasProp("Mode") && v.tool.Mode == 2) {
                pw := v.tool.width
                x -= pw / 2
                y -= pw / 2
                w += pw
                h += pw
            }
        }

        ; Draw the shape based on its type
        switch v.shape {

            case "Text", "Picture", "Bitmap", "Image", "Container", "Dummy":
                ; Pure container/text/picture/bitmap - bypass shape geometry rasterization

            case "Arc":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
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
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
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
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawBeziers"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Ellipse", "Circle":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawEllipse"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", (x + w >= lyr.w) ? (w - 1) : w
                    , "float", (y + h >= lyr.h) ? (h - 1) : h)

            case "FilledRectangle", "FilledSquare":
                (curQuality != "Rectangle") ? (curQuality := "Rectangle", lyr.GraphicsQuality("Rectangle")) : 0,
                DllCall("gdiplus\GdipFillRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "Rectangle", "Square":
                (curQuality != "Rectangle") ? (curQuality := "Rectangle", lyr.GraphicsQuality("Rectangle")) : 0,
                DllCall("gdiplus\GdipDrawRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", (x + w >= lyr.w) ? (w - 1) : w
                    , "float", (y + h >= lyr.h) ? (h - 1) : h)

            case "FilledRoundedRectangle", "FilledRoundRect":
                ; Adapted from Tariq Porter & Marius Șucan (Gdip2 / Object.ahk)
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                r := Max(1, Min(v.r, w / 2, h / 2))
                d := 2 * r
                DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath:=0),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x, "float", y, "float", d, "float", d, "float", 180, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + r, "float", y, "float", x + w - r, "float", y),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + w - d, "float", y, "float", d, "float", d, "float", 270, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + w, "float", y + r, "float", x + w, "float", y + h - r),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + w - d, "float", y + h - d, "float", d, "float", d, "float", 0, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + w - r, "float", y + h, "float", x + r, "float", y + h),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x, "float", y + h - d, "float", d, "float", d, "float", 90, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x, "float", y + h - r, "float", x, "float", y + r),
                DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath),
                DllCall("gdiplus\GdipFillPath", "ptr", gfx, "ptr", ptr, "ptr", pPath),
                DllCall("gdiplus\GdipDeletePath", "ptr", pPath)

            case "RoundedRectangle", "RoundRect":
                ; Adapted from Tariq Porter & Marius Șucan (Gdip2 / Object.ahk)
                ; Insets stroke by half penWidth (pw) so outer edges never clip or bleed
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                penW := Float(v.penwidth)
                pw := penW / 2.0
                r := Float(v.r)
                (w <= h && (r + pw > w / 2)) ? (r := (w / 2 > pw) ? w / 2 - pw : 0)
                    : (h < w && r + pw > h / 2) ? (r := (h / 2 > pw) ? h / 2 - pw : 0)
                    : (r < pw / 2) ? (r := pw / 2) : 0
                d := 2 * r
                DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath:=0),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + pw, "float", y + pw, "float", d, "float", d, "float", 180, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + pw + r, "float", y + pw, "float", x + w - r - pw, "float", y + pw),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + w - d - pw, "float", y + pw, "float", d, "float", d, "float", 270, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + w - pw, "float", y + r + pw, "float", x + w - pw, "float", y + h - r - pw),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + w - d - pw, "float", y + h - d - pw, "float", d, "float", d, "float", 0, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + w - r - pw, "float", y + h - pw, "float", x + r + pw, "float", y + h - pw),
                DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + pw, "float", y + h - d - pw, "float", d, "float", d, "float", 90, "float", 90),
                DllCall("gdiplus\GdipAddPathLine", "ptr", pPath, "float", x + pw, "float", y + h - r - pw, "float", x + pw, "float", y + r + pw),
                DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath),
                DllCall("gdiplus\GdipDrawPath", "ptr", gfx, "ptr", ptr, "ptr", pPath),
                DllCall("gdiplus\GdipDeletePath", "ptr", pPath)

            case "FilledEllipse", "FilledCircle":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipFillEllipse"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", w
                    , "float", h)

            case "FilledPie":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
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
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
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
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipFillPolygon"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points
                    , "int", v.fillmode)

            case "Triangle", "Polygon":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawPolygon"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Line":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawLine"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", v.x1
                    , "float", v.y1
                    , "float", v.x2
                    , "float", v.y2)

            case "Lines":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawLines"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points)

            case "Curve":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawCurve2"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points
                    , "float", v.tension)

            case "FilledClosedCurve":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipFillClosedCurve2"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points
                    , "float", v.tension
                    , "int", v.fillmode)

            case "ClosedCurve":
                (curQuality != "Curved") ? (curQuality := "Curved", lyr.GraphicsQuality("Curved")) : 0,
                DllCall("gdiplus\GdipDrawClosedCurve2"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "ptr", v.pPoints
                    , "int", v.points
                    , "float", v.tension)

            case "Point", "FilledPoint":      ; "Filled" is required for tool switching
                (curQuality != "Rectangle") ? (curQuality := "Rectangle", lyr.GraphicsQuality("Rectangle")) : 0,
                DllCall("gdiplus\GdipFillRectangle"
                    , "ptr", gfx
                    , "ptr", ptr
                    , "float", x
                    , "float", y
                    , "float", Max(1, w)
                    , "float", Max(1, h))
        }

        ; 1.5 BITMAP & TEXTURE BLITTING
        if (v.Bitmap && v.Bitmap.ptr) {

            /**
             * The following code is partially based on:
             * @credit iseahound - TextRender v1.9.3, DrawOnGraphics
             * https://github.com/iseahound/TextRender
             */

            ; Save the current graphics settings and set the new settings for the bitmap drawing
            DllCall("gdiplus\GdipSaveGraphics", "ptr", gfx, "ptr*", &pState:=0),
            DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7),     ; HighQualityBicubic
            DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 2),       ; Half pixel offset
            DllCall("gdiplus\GdipSetCompositingMode", "ptr", gfx, "int", 0),       ; SourceOver (alpha blend over underlying shape)
            DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 0),         ; No anti-alias
            DllCall("gdiplus\GdipSetCompositingQuality", "ptr", gfx, "int", 0)     ; AssumeLinear       

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
                w1 := (v.bmpSrcW) ? v.Bitmap.w + v.bmpSrcW - x1 : v.Bitmap.w - x1
                h1 := (v.bmpSrcH) ? v.Bitmap.h + v.bmpSrcH - y1 : v.Bitmap.h - y1

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
                ; GdipDrawImage is faster than GdipDrawImageRectRect, but it doesn't support scaling
                DllCall("gdiplus\GdipDrawImage"
                    , "ptr", gfx
                    , "ptr", v.Bitmap.ptr
                    , "float", x2 + v.bmpX
                    , "float", y2 + v.bmpY)
            }

            ; Restore the saved graphics settings
            DllCall("gdiplus\GdipRestoreGraphics", "ptr", gfx, "ptr", pState)
        }

        ; 1.6 TYPOGRAPHIC RICH TEXT & EMOJI RENDERING
        if (v.str !== "" && v.str !== 0) {
            if (!IsObject(v.Font) || !v.Font.HasProp("hFont") || !v.Font.hFont) {
                v.Font := Font.getStock()
            }
            if (IsObject(v.Font) && v.Font.HasProp("hFont") && v.Font.hFont) {

                ; Ensure text is ALWAYS drawn with integer pixel grid alignment (resets curved shape half-pixel shift)
                if (curQuality == "Curved") {
                    DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 0)
                    curQuality := "Text"
                }

                ; Text rendering quality resolution
                targetQuality := (v.HasProp("strQ") && v.strQ !== "") ? v.strQ : (v.Font.HasProp("quality") ? v.Font.quality : 5)
                if (targetQuality !== lyr.textQuality) {
                    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gfx, "int", targetQuality)
                    lyr.textQuality := targetQuality
                }

                ; Handle multi-color formatted text (Pre-tokenized by Shape.PrepareTextLayout)
                if (v.__isRichText) {
                    text := v.__textRuns
                    strRaw := v.__textRaw
                    lines := v.__textLines
                    lineWidth := (v.HasOwnProp("__lineWidths")) ? v.__lineWidths : [v.w]

                    hFmt := (v.Font.HasProp("hFormatTypo") && v.Font.hFormatTypo) ? v.Font.hFormatTypo : (v.Font.HasProp("hFormat") ? v.Font.hFormat : 0)
                    oriColor := 0
                    if (v.Font.HasProp("pBrush") && v.Font.pBrush) {
                        DllCall("gdiplus\GdipGetSolidFillColor", "ptr", v.Font.pBrush, "int*", &oriColor:=0)
                    }

                    ; Initial position respecting horizontal and vertical alignment
                    baseX := v.x + v.strX
                    baseY := v.y + v.strY
                    lineH := (v.HasProp("lineHeight") && v.lineHeight > 0) ? v.lineHeight 
                           : (((v.Font.HasProp("lineHeight") && v.Font.lineHeight > 0) ? v.Font.lineHeight : (v.Font.HasProp("size") ? v.Font.size : 10)) * (v.HasProp("lineSpacing") && v.lineSpacing > 0 ? v.lineSpacing : 1.35))

                    x := (v.strH == 0 || v.strH == "left" || v.strH == "near") ? baseX
                       : (v.strH == 2 || v.strH == "right" || v.strH == "far") ? (baseX + v.w - (lineWidth.Length ? lineWidth[1] : 0))
                       : baseX + (v.w - (lineWidth.Length ? lineWidth[1] : 0)) / 2

                    y := (v.strV == 0 || v.strV == "top" || v.strV == "near") ? baseY
                       : (v.strV == 2 || v.strV == "bottom" || v.strV == "far") ? (baseY + v.h - lineH * lines.Length)
                       : baseY + (v.h - lineH * lines.Length) / 2

                    index := 1
                    line := 1
                    pos := 1
                    colIdx := 1
                    tabStops := (v.HasProp("_tabStops") && IsObject(v._tabStops)) ? v._tabStops : []

                    ; Draw each character with zero-margin typographic format
                    local strPos := 1, strRawLen := StrLen(strRaw), c1, cLen, lastClr := -1
                    while (strPos <= strRawLen) {
                        c1 := SubStr(strRaw, strPos, 1)
                        oVal := Ord(c1)
                        if (oVal >= 0xD800 && oVal <= 0xDBFF && strPos < strRawLen) {
                            ch := SubStr(strRaw, strPos, 2)
                            cLen := 2
                            oVal := Ord(ch)
                        } else {
                            ch := c1
                            cLen := 1
                        }
                        
                        ; Check if we need to advance to the next text run
                        while (index <= text.Length && pos > StrLen(text[index][2])) {
                            index += 1
                            pos := 1
                        }

                        ; Move to the next line if newline character
                        if (ch ~= "[\n\r]") {
                            line += 1
                            pos += cLen
                            strPos += cLen
                            colIdx := 1
                            x := (v.strH == 0 || v.strH == "left" || v.strH == "near") ? baseX
                               : (v.strH == 2 || v.strH == "right" || v.strH == "far") ? (baseX + v.w - (line <= lineWidth.Length ? lineWidth[line] : 0))
                               : baseX + (v.w - (line <= lineWidth.Length ? lineWidth[line] : 0)) / 2
                            y += lineH
                            continue
                        }

                        ; Tab stop snapping (multi-column grid alignment or custom tab stop)
                        if (ch == "`t") {
                            colIdx += 1
                            if (colIdx <= tabStops.Length) {
                                x := baseX + tabStops[colIdx]
                            } else {
                                spcW := (v.Font.HasProp("chrWidth") && v.Font.chrWidth.Has(" ")) ? v.Font.chrWidth[" "] : (v.Font.HasProp("size") ? (v.Font.size * 0.3) : 3)
                                tabSpaces := (v.HasProp("tabSize") && v.tabSize > 0) ? v.tabSize : 4
                                tabW := spcW * tabSpaces
                                offset := x - baseX
                                x := baseX + Ceil((offset + 1) / tabW) * tabW
                            }
                            pos += cLen
                            strPos += cLen
                            continue
                        }

                        ; Get the specific font instance and color for active text run
                        runObj := (index <= text.Length) ? text[index] : 0
                        runFont := (runObj && runObj.Length >= 4 && runObj[4]) ? runObj[4] : v.Font
                        if (!IsObject(runFont))
                            runFont := Font.getStock()
                        curClr := (runObj) ? Color(runObj[1]) : oriColor

                        ; Emoji detection: preserve neutral/base color and use Segoe UI Emoji with Regular style (0) to eliminate tofus / [][]
                        isEmojiGlyph := (oVal >= 0x1F000 || (oVal >= 0x2600 && oVal <= 0x27BF) || (oVal >= 0x2300 && oVal <= 0x23FF))
                        drawClr := (isEmojiGlyph && !(v.HasProp("colorizeEmoji") && v.colorizeEmoji)) ? oriColor : curClr

                        drawFont := runFont
                        if (isEmojiGlyph) {
                            drawFont := Font("Segoe UI Emoji", runFont.size, 0, drawClr, runFont.quality)
                        }

                        ; Exact typographic glyph advance width for this font/style (or fixed pitch for monospaced fonts)
                        if (drawFont.HasProp("isMonospace") && drawFont.isMonospace && drawFont.monoWidth > 0 && !isEmojiGlyph) {
                            cw := drawFont.monoWidth
                        } else {
                            cw := (drawFont.HasProp("chrWidth") && drawFont.chrWidth.Has(ch)) ? drawFont.chrWidth[ch] : Font.MeasureChar(drawFont, ch)
                        }

                        ; Adjust brush color only if changed (eliminates redundant DllCalls)
                        if (drawClr !== lastClr && drawFont.HasProp("pBrush") && drawFont.pBrush) {
                            DllCall("gdiplus\GdipSetSolidFillColor", "ptr", drawFont.pBrush, "int", drawClr)
                            lastClr := drawClr
                        }

                        ; Update the RectF structure for the current character
                        NumPut("float", x, RectF, 0),
                        NumPut("float", y, RectF, 4),
                        NumPut("float", cw + 1.0, RectF, 8),
                        NumPut("float", lineH, RectF, 12)

                        ; Draw the character using zero-margin typographic format
                        if (drawFont.HasProp("hFont") && drawFont.hFont && drawFont.HasProp("pBrush") && drawFont.pBrush && hFmt) {
                            DllCall("gdiplus\GdipDrawString"
                                ,  "ptr", gfx
                                , "wstr", ch
                                ,  "int", -1
                                ,  "ptr", drawFont.hFont
                                ,  "ptr", RectF
                                ,  "ptr", hFmt
                                ,  "ptr", drawFont.pBrush)
                        }

                        ; Update positions
                        x += cw
                        pos += cLen
                        strPos += cLen
                    }

                    ; Restore original brush color
                    if (lastClr !== oriColor && v.Font.HasProp("pBrush") && v.Font.pBrush)
                        DllCall("gdiplus\GdipSetSolidFillColor", "ptr", v.Font.pBrush, "int", oriColor)
                }
                else {
                    
                    ; Each font has its own alignment settings
                    if (v.Font.HasProp("hFormat") && v.Font.hFormat) {
                        if (v.HasProp("strH") && v.Font.HasProp("alignmentH") && v.strH !== v.Font.alignmentH) {
                            DllCall("gdiplus\GdipSetStringFormatAlign"
                                , "ptr", v.Font.hFormat
                                , "int", (v.Font.alignmentH := (v.strH is Integer ? v.strH : 1)))
                        }
                        if (v.HasProp("strV") && v.Font.HasProp("alignmentV") && v.strV !== v.Font.alignmentV) {
                            DllCall("gdiplus\GdipSetStringFormatLineAlign"
                                , "ptr", v.Font.hFormat
                                , "int", (v.Font.alignmentV := (v.strV is Integer ? v.strV : 1)))
                        }
                    }

                    ; Populate static RectF structure with string bounding rectangle
                    NumPut("float", v.x + v.strX, RectF, 0),
                    NumPut("float", v.y + v.strY, RectF, 4),
                    NumPut("float", v.w, RectF, 8),
                    NumPut("float", v.h, RectF, 12),

                    ; Ensure the shared font brush uses this specific shape's designated text color
                    textClr := (v.HasProp("__textColor") && v.__textColor !== "") ? v.__textColor 
                             : ((v.Font.HasProp("colour")) ? v.Font.colour : 0xFFFFFFFF)
                    if (v.Font.HasProp("pBrush") && v.Font.pBrush) {
                        DllCall("gdiplus\GdipSetSolidFillColor", "ptr", v.Font.pBrush, "int", textClr)
                    }

                    ; Draw the string without any measurement
                    if (v.Font.HasProp("hFont") && v.Font.hFont && v.Font.HasProp("hFormat") && v.Font.HasProp("pBrush")) {
                        DllCall("gdiplus\GdipDrawString"
                            , "ptr", gfx               ; ptr to graphics
                            , "wstr", v.str            ; ptr to string
                            , "int", -1                ; null terminated
                            , "ptr", v.Font.hFont      ; ptr to font
                            , "ptr", RectF             ; ptr to bounding rectangle
                            , "ptr", v.Font.hFormat    ; ptr to string format
                            , "ptr", v.Font.pBrush)    ; ptr to brush
                    }
                }
            }
        }

        ; Free the references after drawing
        ptr := ""
        v := ""
    }

    ; 5. Window presentation
    if (!Render.UpdateWindow) {
        if (freeRef)
            lyr := ""
        return
    }

    ; Destination and source coordinates (exact screen position without offset jumping)
    dstX := Integer(lyr.x)
    dstY := Integer(lyr.y)
    winW := Max(1, Integer(lyr.w))
    winH := Max(1, Integer(lyr.h))
    srcX := 0
    srcY := 0

    ; Update the window
    ; @credit iseahound - TextRender v1.9.3, RenderOnScreen (https://github.com/iseahound/TextRender)
    DllCall("UpdateLayeredWindow"
        ,     "ptr", lyr.hwnd                                             ; hWnd
        ,     "ptr", 0                                                    ; hdcDst
        , "uint64*", (dstX & 0xFFFFFFFF) | ((dstY & 0xFFFFFFFF) << 32)    ; *pptDst (Screen destination)
        , "uint64*", (winW & 0xFFFFFFFF) | ((winH & 0xFFFFFFFF) << 32)    ; *psize (Layer cropped size)
        ,     "ptr", lyr.gfx.hdc                                          ; hdcSrc (Source DC)
        , "uint64*", (srcX & 0xFFFFFFFF) | ((srcY & 0xFFFFFFFF) << 32)    ; *pptSrc (DC source point)
        ,    "uint", 0                                                    ; crKey
        ,   "uint*", lyr.alpha << 16 | 0x01000000                         ; *pblend (Alpha blend)
        ,    "uint", 2)                                                   ; dwFlags (ULW_ALPHA)
    
    ; Free the reference to the layer object
    if (freeRef)
        lyr := ""
    return
}

/**
 * Manages frame timing, FPS limits, and multi-layer rendering synchronization.
 *
 * @example
 * ; Render single layer in a loop
 * loop 60 {
 *     Render.Layer(mainLayer)
 * }
 *
 * ; Render multiple layers together in sync
 * loop 60 {
 *     Render.Layers(bgLayer, gameLayer, uiLayer)
 * }
 */
class Render {

    ; When false, renders to memory DC without presenting to screen (useful for benchmarks)
    static UpdateWindow := true

    ; Pacing dispatch configuration (bound once at startup - zero runtime branching)
    static coarseSleepFn := 0
    static coarseThreshold := 0.6
    static coarseMargin := 0.3
    static timerMode := "HiRes"

    /**
     * Initializes the optimal frame pacing and sleep strategy during startup.
     * Evaluates OS timer capabilities once. Zero branching in the hot render loop.
     */
    static __New() {
        local isHiRes := false
        try {
            isHiRes := MCode.InitHiResTimer()
        } catch {
            isHiRes := false
        }

        if (isHiRes) {
            this.coarseSleepFn := (ms) => MCode.HiResWait(ms)
            this.coarseThreshold := 0.6  ; Can sleep for sub-millisecond durations
            this.coarseMargin := 0.3     ; 300 microsecond spin margin
            this.timerMode := "HiRes"
        } else {
            ; Legacy fallback for older Windows versions (Win7/Win8/Win10 < 1803)
            try DllCall("winmm\timeBeginPeriod", "uint", 1)
            this.coarseSleepFn := (ms) => DllCall("Sleep", "uint", Floor(ms))
            this.coarseThreshold := 1.5
            this.coarseMargin := 0.5
            this.timerMode := "Legacy"
        }
    }

    /**
     * Renders a single layer with frame pacing and diagnostic timing.
     *
     * @param {Layer|Integer} lyr Layer instance, ID, or pointer to render
     * @returns {void}
     *
     * @example
     * ; Call directly as Render(lyr) or Render.Call(lyr)
     * Render(lyr)
     */
    static Call(lyr) {

        local qpc, start, now, frameElapsed, remaining, targetTick

        ; Record start of frame
        DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
        start := qpc / this.qpf
        Draw(lyr)

        ; If Fps is set to persistent, draw its layer only on the update frequency interval
        if (Fps.persistent && Fps.Layer && Fps.Layer.visible) {
            if (!Mod(Fps.frames, Fps.Layer.updatefreq)) {
                Fps.Update()
                Draw(Fps.Layer)
            }
        }

        ; Target frame pacing (if FPS cap is set)
        if (Fps.frametime > 0) {
            DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
            now := qpc / this.qpf
            remaining := Fps.frametime - ((now - start) * 1000)

            ; Coarse sleep for the bulk of the wait time (zero branching, pre-bound method)
            if (remaining > this.coarseThreshold)
                (this.coarseSleepFn)(remaining - this.coarseMargin)

            ; High-precision zero-overhead native MCode QPC spin for final microsecond remainder
            targetTick := Integer((start + (Fps.frametime / 1000)) * this.qpf)
            MCode.QpcSpinWait(targetTick)
        }

        ; Total frame time
        DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
        frameElapsed := ((qpc / this.qpf) - start) * 1000

        ; Update Fps metrics cleanly
        Fps.totalrender += frameElapsed
        Fps.lastrender := frameElapsed > 0 ? 1000 / frameElapsed : 0
        Fps.rendertime += frameElapsed
        Fps.totaltime += frameElapsed
        Fps.lastfps := frameElapsed > 0 ? 1000 / frameElapsed : 0
        Fps.frames += 1
    }

    ; Backward-compatibility alias
    static Layer(lyr) => this.Call(lyr)

    ; For multiple layers rendering
    static Layers(lyrs*) {

        local qpc, start, now, frameElapsed, remaining, targetTick, lyr

        ; Record start of frame
        DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
        start := qpc / this.qpf

        for lyr in lyrs {
            ; If the layer is hidden or skipped by update frequency
            if (!lyr.visible || (lyr.updateFreq && Mod(Fps.frames, lyr.updateFreq)))
                continue

            Draw(lyr)
        }

        ; If Fps is set to persistent, draw its layer only on the update frequency interval
        if (Fps.persistent && Fps.Layer && Fps.Layer.visible) {
            if (!Mod(Fps.frames, Fps.Layer.updateFreq)) {
                Fps.Update()
                Draw(Fps.Layer)
            }
        }

        ; Target frame pacing (if FPS cap is set)
        if (Fps.frameTime > 0) {
            DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
            now := qpc / this.qpf
            remaining := Fps.frameTime - ((now - start) * 1000)

            ; Coarse sleep for the bulk of the wait time (zero branching, pre-bound method)
            if (remaining > this.coarseThreshold)
                (this.coarseSleepFn)(remaining - this.coarseMargin)

            ; High-precision zero-overhead native MCode QPC spin for final microsecond remainder
            targetTick := Integer((start + (Fps.frameTime / 1000)) * this.qpf)
            MCode.QpcSpinWait(targetTick)
        }

        ; Total frame time
        DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
        frameElapsed := ((qpc / this.qpf) - start) * 1000

        Fps.totalrender += frameElapsed
        Fps.lastrender := frameElapsed > 0 ? 1000 / frameElapsed : 0
        Fps.rendertime += frameElapsed
        Fps.totaltime += frameElapsed
        Fps.lastfps := frameElapsed > 0 ? 1000 / frameElapsed : 0
        Fps.frames += 1
    }
    
    static qpf := (DllCall("QueryPerformanceFrequency", "int64*", &freq:=0), freq)
}