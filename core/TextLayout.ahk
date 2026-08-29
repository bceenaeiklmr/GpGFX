; Script     TextLayout.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2

/**
 * GpGFX Rich-Text Layout & Typographic Formatting Engine
 *
 * Provides subpixel typographic layout, tokenization of rich-text markup tags,
 * paragraph word wrapping, multi-column tab stops, and exact character bounding box measurement.
 *
 * Features:
 * - Tagged Rich-Text: Inline color tags `{#FFD866}`, `{Red}`, `<#78DCE8>`, styles `<b>`, `<i>`, `<u>`, `<s>`, `<reset>`.
 * - Zero Allocation Font Runs: Font styles are reused across segments without redundant GDI+ font allocations.
 * - Automatic Paragraph Word-Wrapping: Wraps text at word boundaries to fit shape bounding width `shape.w`.
 * - Multi-Column Tab Stops: Dynamic column grid alignment for tabulated strings (`\t`).
 * - Pure-Math Character Measurement: `GetRangeRect` calculates exact pixel bounding boxes for carets/selection with 0 GDI+ DllCalls.
 */
class TextLayout {

    /**
     * Pre-tokenizes formatted multi-color strings to eliminate parsing and regex inside the Draw render loop.
     * Populates `shape.__isRichText`, `shape.__textRuns`, `shape.__textLines`, `shape.__lineWidths`, `shape.__tabStops`, `shape.__textRaw`.
     *
     * @param {Shape} shape The shape instance holding the text
     * @returns {void}
     *
     * @example
     * ; Internal invocation triggered on shape.str setter
     * TextLayout.Prepare(shape)
     */
    static Prepare(shape) {
        local val, rawSegments, seg, strRaw, defaultClr, currentClr, currentStyle, baseStyle, baseFnt, runFont, pos, textLen, strInput, tagPos, chunk, closeBrace, tagContent, clrSpec, m, matchedClr, mTag, mClr, parts, part, foundAny

        if (shape.__str == "" || shape.__str == 0) {
            shape.__isRichText := false
            shape.__textRuns := []
            shape.__textLines := []
            shape.__lineWidths := []
            shape.__tabStops := []
            shape.__textRaw := ""
            return
        }

        ; Check if formatted rich text or monospaced multiline layout (Array of [Color, Text] OR String with tags {...}, <...>, `t, or multiline monospaced text)
        if (Type(shape.__str) == "Array" || (Type(shape.__str) == "String" && (InStr(shape.__str, "{") || InStr(shape.__str, "<") || InStr(shape.__str, "`t") || (shape.Font && shape.Font.HasProp("isMonospace") && shape.Font.isMonospace && InStr(shape.__str, "`n"))))) {
            shape.__isRichText := true
            shape.__textRuns := []
            strRaw := ""
            defaultClr := (shape.HasProp("__textColor") && shape.__textColor !== "") ? Color(shape.__textColor) : ((shape.Font && shape.Font.HasProp("color")) ? Color(shape.Font.color) : ((shape.Font && shape.Font.HasProp("colour")) ? Color(shape.Font.colour) : 0xFFFCFCFA))
            baseStyle := (shape.Font && shape.Font.HasProp("style")) ? shape.Font.style : 0
            baseFnt := shape.Font
            currentClr := defaultClr
            currentStyle := baseStyle

            if (Type(shape.__str) == "Array") {
                for seg in shape.__str {
                    if (IsObject(seg) && seg.Length >= 2) {
                        currentClr := Color(seg[1])
                        currentStyle := (seg.Length >= 3) ? seg[3] : baseStyle
                        chunk := String(seg[2])
                        runFont := (!baseFnt) ? 0 : (currentStyle == baseStyle ? baseFnt : Font(baseFnt.family, baseFnt.size, currentStyle, currentClr, baseFnt.quality))
                        shape.__textRuns.Push([currentClr, chunk, currentStyle, runFont])
                        strRaw .= chunk
                    }
                }
            } else {
                pos := 1
                strInput := shape.__str
                textLen := StrLen(strInput)

                while (pos <= textLen) {
                    if (!RegExMatch(strInput, "\{([^{}]*)\}|\<([a-zA-Z0-9_\/#\:\,\s\*\.\-]+)\>", &mTag, pos)) {
                        chunk := SubStr(strInput, pos)
                        if (chunk != "") {
                            runFont := (!baseFnt) ? 0 : (currentStyle == baseStyle ? baseFnt : Font(baseFnt.family, baseFnt.size, currentStyle, currentClr, baseFnt.quality))
                            shape.__textRuns.Push([currentClr, chunk, currentStyle, runFont])
                            strRaw .= chunk
                        }
                        break
                    }

                    tagPos := mTag.Pos(0)
                    if (tagPos > pos) {
                        chunk := SubStr(strInput, pos, tagPos - pos)
                        if (chunk != "") {
                            runFont := (!baseFnt) ? 0 : (currentStyle == baseStyle ? baseFnt : Font(baseFnt.family, baseFnt.size, currentStyle, currentClr, baseFnt.quality))
                            shape.__textRuns.Push([currentClr, chunk, currentStyle, runFont])
                            strRaw .= chunk
                        }
                    }

                    tagContent := Trim((mTag[1] != "") ? mTag[1] : mTag[2])
                    isTag := false

                    ; 1. Full Reset: {}, <reset>, {reset}, {/}, </>, <color>, {color}, etc.
                    if (tagContent == "" || RegExMatch(tagContent, "i)^/?(reset|all|color|colour|clr|c)$") || tagContent == "/") {
                        currentClr := defaultClr
                        currentStyle := baseStyle
                        isTag := true
                    }
                    ; 2. Style Closing Tags: </b>, </i>, </u>, </s>, {/b}, {/i}, {/u}, {/s}, etc.
                    else if (RegExMatch(tagContent, "i)^/(b|bold|strong)$")) {
                        currentStyle &= ~1
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^/(i|italic|em)$")) {
                        currentStyle &= ~2
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^/(u|underline|ins|under)$")) {
                        currentStyle &= ~4
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^/(s|strike|strikeout|del)$")) {
                        currentStyle &= ~8
                        isTag := true
                    }
                    ; 3. Style Opening Tags: <b>, <i>, <u>, <s>, {b}, {i}, {u}, {s}, {bold}, {italic}, etc.
                    else if (RegExMatch(tagContent, "i)^(\*?b|bold|strong)$")) {
                        currentStyle |= 1
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^(\*?i|italic|em)$")) {
                        currentStyle |= 2
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^(\*?u|underline|ins|under)$")) {
                        currentStyle |= 4
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^(\*?s|strike|strikeout|del)$")) {
                        currentStyle |= 8
                        isTag := true
                    }
                    else if (RegExMatch(tagContent, "i)^(bi|ib|bolditalic)$")) {
                        currentStyle |= 3
                        isTag := true
                    }
                    ; 4. Prefixed Color Tags: {color:#FFD866}, <color:Red>, {color:4294901760}, {c:hex}
                    else if (RegExMatch(tagContent, "i)^(?:color|colour|clr|c)\s*:\s*(.+)$", &mClr)) {
                        try {
                            currentClr := Color(mClr[1])
                            isTag := true
                        }
                    }
                    ; 5. Direct Hex / ARGB / Numeric codes: {#FFD866}, {0xFFFFD866}, {4294901760}, {-65536}, <#78DCE8>
                    else if (RegExMatch(tagContent, "i)^(?:#|0x)[0-9a-fA-F]{3,8}$") || (IsNumber(tagContent) && Abs(Number(tagContent)) > 100)) {
                        try {
                            currentClr := Color(tagContent)
                            isTag := true
                        }
                    }
                    ; 6. Direct Named Colors & Random Pipe Tokens: {Red}, {Lime}, {Cyan}, <Yellow>, {Red|Blue|Lime}
                    else if (Color.HasOwnProp(tagContent) || (Color.HasProp("Map") && Color.Map.Has(tagContent)) || InStr(tagContent, "|")) {
                        try {
                            currentClr := Color(tagContent)
                            isTag := true
                        }
                    }
                    ; 7. Combined Color + Style Tags: {#FFD866, b}, {Red, bold, italic}, {#78DCE8:b}, {clr:#FFD866, i, u}
                    else if (InStr(tagContent, ",") || InStr(tagContent, ":")) {
                        parts := StrSplit(tagContent, [",", ":", " "])
                        foundAny := false
                        for part in parts {
                            part := Trim(part)
                            if (part == "")
                                continue

                            if (RegExMatch(part, "i)^(b|bold|strong|\*b)$")) {
                                currentStyle |= 1, foundAny := true
                            }
                            else if (RegExMatch(part, "i)^(i|italic|em|\*i)$")) {
                                currentStyle |= 2, foundAny := true
                            }
                            else if (RegExMatch(part, "i)^(u|underline|ins|\*u)$")) {
                                currentStyle |= 4, foundAny := true
                            }
                            else if (RegExMatch(part, "i)^(s|strike|strikeout|del|\*s)$")) {
                                currentStyle |= 8, foundAny := true
                            }
                            else if (RegExMatch(part, "i)^(regular|normal)$")) {
                                currentStyle := 0, foundAny := true
                            }
                            else {
                                try (currentClr := Color(part), foundAny := true)
                            }
                        }
                        if (foundAny)
                            isTag := true
                    }

                    ; 8. If unrecognized (e.g. {literal_braces}), treat as visible text
                    if (!isTag) {
                        chunk := mTag[0]
                        runFont := (!baseFnt) ? 0 : (currentStyle == baseStyle ? baseFnt : Font(baseFnt.family, baseFnt.size, currentStyle, currentClr, baseFnt.quality))
                        shape.__textRuns.Push([currentClr, chunk, currentStyle, runFont])
                        strRaw .= chunk
                    }

                    pos := tagPos + StrLen(mTag[0])
                }
            }

            if (InStr(strRaw, "`r`n"))
                strRaw := StrReplace(strRaw, "`r`n", "`n")

            ; Word-wrap paragraphs at whitespace to fit shape bounding width shape.w
            local fnt := shape.Font
            local maxW := (shape.w > 0) ? shape.w : 10000
            local spcW := Font.MeasureChar(fnt, " ")
            local tabSpaces := (shape.HasProp("tabSize") && shape.tabSize > 0) ? shape.tabSize : 4
            local tabW := spcW * tabSpaces

            local rawParagraphs := StrSplit(strRaw, "`n")
            shape.__textLines := []
            shape.__lineWidths := []
            shape.__tabStops := []

            ; Check if text contains tabs for automatic multi-column grid alignment
            if (InStr(strRaw, "`t")) {
                if (shape.HasProp("tabStops") && IsObject(shape.tabStops) && shape.tabStops.Length) {
                    shape.__tabStops := shape.tabStops
                }
                else {
                    local colMaxWidth := Map()
                    local pLine, pCells, cIdx, cCell, cWidth
                    for pLine in rawParagraphs {
                        pCells := StrSplit(pLine, "`t")
                        if (pCells.Length < 2)
                            continue
                        for cIdx, cCell in pCells {
                            cWidth := 0
                            loop parse, cCell {
                                cWidth += Font.MeasureChar(fnt, A_LoopField)
                            }
                            if (!colMaxWidth.Has(cIdx) || cWidth > colMaxWidth[cIdx])
                                colMaxWidth[cIdx] := cWidth
                        }
                    }

                    local colGap := spcW * tabSpaces
                    local runningX := 0
                    shape.__tabStops := [0]
                    local totalCols := colMaxWidth.Count
                    local colNum := 1
                    while (colNum < totalCols) {
                        runningX += (colMaxWidth.Has(colNum) ? colMaxWidth[colNum] : (tabW * 2)) + colGap
                        shape.__tabStops.Push(runningX)
                        colNum++
                    }
                }

                local paraLine, rowCells, lastCol, lastCellW, totalRowW
                for paraLine in rawParagraphs {
                    shape.__textLines.Push(paraLine)
                    rowCells := StrSplit(paraLine, "`t")
                    lastCol := rowCells.Length
                    lastCellW := 0
                    if (lastCol > 0) {
                        loop parse, rowCells[lastCol] {
                            lastCellW += Font.MeasureChar(fnt, A_LoopField)
                        }
                    }
                    totalRowW := (lastCol <= shape.__tabStops.Length ? shape.__tabStops[lastCol] : ((lastCol - 1) * tabW)) + lastCellW
                    shape.__lineWidths.Push(totalRowW)
                }

                shape.__textRaw := strRaw
            }
            else {
                ; Standard paragraph whitespace word-wrapping
                local pIndex, para, cIdx, pLen, ch, cw, curLineW, lastSpaceIdx, lastSpaceLineW, curLineStart, curLineStr

                for pIndex, para in rawParagraphs {
                    if (para == "") {
                        shape.__textLines.Push("")
                        shape.__lineWidths.Push(0)
                        continue
                    }

                    pLen := StrLen(para)
                    curLineW := 0
                    lastSpaceIdx := 0
                    lastSpaceLineW := 0
                    curLineStart := 1

                    cIdx := 1
                    while (cIdx <= pLen) {
                        ch := SubStr(para, cIdx, 1)
                        cw := Font.MeasureChar(fnt, ch)

                        if (ch == A_Space) {
                            lastSpaceIdx := cIdx
                            lastSpaceLineW := curLineW
                        }

                        if (curLineW + cw > maxW && curLineStart < cIdx) {
                            if (lastSpaceIdx > curLineStart) {
                                curLineStr := SubStr(para, curLineStart, lastSpaceIdx - curLineStart)
                                shape.__textLines.Push(curLineStr)
                                shape.__lineWidths.Push(lastSpaceLineW)

                                curLineStart := lastSpaceIdx + 1
                                curLineW := 0
                                loop cIdx - curLineStart + 1 {
                                    curLineW += Font.MeasureChar(fnt, SubStr(para, curLineStart + A_Index - 1, 1))
                                }
                                lastSpaceIdx := 0
                            }
                            else {
                                curLineStr := SubStr(para, curLineStart, cIdx - curLineStart)
                                shape.__textLines.Push(curLineStr)
                                shape.__lineWidths.Push(curLineW)
                                curLineStart := cIdx
                                curLineW := cw
                                lastSpaceIdx := 0
                            }
                        }
                        else {
                            curLineW += cw
                        }

                        cIdx++
                    }

                    if (curLineStart <= pLen) {
                        curLineStr := SubStr(para, curLineStart)
                        shape.__textLines.Push(curLineStr)
                        shape.__lineWidths.Push(curLineW)
                    }
                }

                shape.__textRaw := strRaw
            }
        }
        else {
            shape.__isRichText := false
            shape.__lineWidths := []
            shape.__textLines := []
            shape.__tabStops := []
            shape.__textRaw := ""
        }
    }

    /**
     * Calculates the exact pixel bounding box of a character range with zero GDI+ DllCalls (pure math).
     *
     * @param {Shape} shape The shape instance holding the text
     * @param {Integer} startChar 1-based character index in visible text
     * @param {Integer} [charLen=1] Number of characters to measure
     * @returns {Object} { x, y, w, h, line, found, rects }
     *
     * @example
     * ; Get bounding box of first 5 characters for custom highlight / caret
     * rect := TextLayout.GetRangeRect(myTextShape, 1, 5)
     */
    static GetRangeRect(shape, startChar, charLen := 1) {
        local baseX, baseY, fnt, lineH, lines, lineWidths, totalLines, totalTextH, startY
        local curLine, curX, curY, colIdx, tabStops, spcW, tabSpaces, tabW
        local endChar, inRange, targetX, targetY, targetW, lineRects, idx, ch, chrW, offset
        local lineStartIdx, lineWAccum, lineStartX, nextX

        baseX := shape.x + shape.strX
        baseY := shape.y + shape.strY
        fnt := shape.Font
        if (!fnt || shape.__textRaw == "")
            return { x: 0, y: 0, w: 0, h: 0, line: 0, found: false, rects: [] }

        lineH := (shape.HasProp("lineHeight") && shape.lineHeight > 0) ? shape.lineHeight 
               : ((fnt.lineHeight > 0 ? fnt.lineHeight : fnt.size) * (shape.HasProp("lineSpacing") && shape.lineSpacing > 0 ? shape.lineSpacing : 1.35))
        
        lines := shape.__textLines
        lineWidths := shape.__lineWidths
        totalLines := lines.Length ? lines.Length : 1
        totalTextH := lineH * totalLines

        startY := (shape.strV == 0) ? baseY
                : (shape.strV == 2) ? (baseY + shape.h - totalTextH)
                : baseY + (shape.h - totalTextH) / 2

        curLine := 1
        curX := (shape.strH == 0) ? baseX
              : (shape.strH == 2) ? (baseX + shape.w - (lineWidths.Length ? lineWidths[1] : 0))
              : baseX + (shape.w - (lineWidths.Length ? lineWidths[1] : 0)) / 2
        curY := startY

        colIdx := 1
        tabStops := (shape.HasProp("__tabStops") && IsObject(shape.__tabStops)) ? shape.__tabStops : []
        spcW := Font.MeasureChar(fnt, " ")
        tabSpaces := (shape.HasProp("tabSize") && shape.tabSize > 0) ? shape.tabSize : 4
        tabW := spcW * tabSpaces

        endChar := startChar + charLen - 1
        targetX := 0, targetY := 0, targetW := 0
        lineRects := []
        lineStartIdx := 0, lineWAccum := 0, lineStartX := 0

        local textRuns := shape.__textRuns
        local runIdx := 1, runPos := 1, activeFnt := fnt

        idx := 1
        loop parse, shape.__textRaw {
            ch := A_LoopField

            while (runIdx <= textRuns.Length && runPos > StrLen(textRuns[runIdx][2])) {
                runIdx += 1
                runPos := 1
            }
            activeFnt := (runIdx <= textRuns.Length && textRuns[runIdx].Length >= 4 && textRuns[runIdx][4]) ? textRuns[runIdx][4] : fnt

            inRange := (idx >= startChar && idx <= endChar)

            if (idx == startChar) {
                targetX := curX
                targetY := curY
                lineStartX := curX
                lineStartIdx := curLine
            }

            if (ch ~= "[\n\r]") {
                if (inRange && lineWAccum > 0) {
                    lineRects.Push({ x: lineStartX, y: curY, w: lineWAccum, h: lineH, line: curLine })
                    lineWAccum := 0
                }

                curLine += 1
                colIdx := 1
                curX := (shape.strH == 0) ? baseX
                      : (shape.strH == 2) ? (baseX + shape.w - (curLine <= lineWidths.Length ? lineWidths[curLine] : 0))
                      : baseX + (shape.w - (curLine <= lineWidths.Length ? lineWidths[curLine] : 0)) / 2
                curY := startY + (curLine - 1) * lineH

                if (idx + 1 <= endChar && idx + 1 >= startChar) {
                    lineStartX := curX
                }

                idx += 1
                runPos += 1
                continue
            }

            if (ch == "`t") {
                colIdx += 1
                if (colIdx <= tabStops.Length) {
                    nextX := baseX + tabStops[colIdx]
                }
                else {
                    offset := curX - baseX
                    nextX := baseX + (Floor(offset / tabW) + 1) * tabW
                }
                chrW := nextX - curX
            }
            else {
                chrW := Font.MeasureChar(activeFnt, ch)
            }

            if (inRange) {
                targetW += chrW
                lineWAccum += chrW
            }

            if (idx == endChar) {
                if (lineWAccum > 0) {
                    lineRects.Push({ x: lineStartX, y: curY, w: lineWAccum, h: lineH, line: curLine })
                }
                return { x: targetX, y: targetY, w: targetW, h: lineH,
                    line: lineStartIdx, found: true, rects: lineRects }
            }

            curX += chrW
            idx += 1
            runPos += 1
        }

        if (lineWAccum > 0) {
            lineRects.Push({ x: lineStartX, y: curY, w: lineWAccum, h: lineH, line: curLine })
        }

        return { x: targetX, y: targetY, w: targetW, h: lineH, line: lineStartIdx,
            found: (targetX != 0 || targetY != 0), rects: lineRects }
    }
}
