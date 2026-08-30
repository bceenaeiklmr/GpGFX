; Script:    TextRangeMeasureDemo.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; GpGFX Pure-Math Text Range & Word Bounding Box Demo
; Interactive Hover & Click Hyperlinks with 0 GDI+ DllCalls!

lyr := Layer(100, 100, 680, 480, "TextRangeMeasureDemo")
lyr.draggable := true

; 1. Window Frame & Background
RoundedRectangle(10, 10, 660, 460, 16, "0xF014141E", true)
RoundedRectangle(10, 10, 660, 460, 16, "0x40FCFCFA", false)

; 2. Title Bar
Rectangle(30, 24, 620, 36, "0x00000000", true)
    .Text("{#78DCE8}GpGFX{} Interactive Pure-Math Text Range & Hyperlink Demo", "0xFFFCFCFA", 13, "Segoe UI", "Bold")

; 3. Multiline Paragraph with Rich Color Tags
sampleParagraph := 
(
    "GpGFX features high-performance native text rendering.`n"
    . "Using pure arithmetic, we can calculate the exact pixel {color:#FFD866}bounding box{color} "
    . "of any word, character index, or inline phrase with 0 GDI+ DllCalls!`n`n"
    . "Try clicking or hovering over words like {#FF6188}Hyperlink{}, {#78DCE8}Zero-Copy{}, or {#A9DC76}100% Math{}."
)

txtShape := Rectangle(40, 80, 600, 200, "0x00000000", true)
txtShape.lineSpacing := 1.55
txtShape.Text(sampleParagraph, "0xFFD8D8E0", 11.5, "Segoe UI", "Regular").Left().Top()

; 4. Words to measure and turn into interactive clickable/hoverable pills
wordsToHighlight := [
    { word: "GpGFX",            color: "0x3378DCE8", stroke: "0xFF78DCE8" },
    { word: "bounding box",     color: "0x33FFD866", stroke: "0xFFFFD866" },
    { word: "0 GDI+ DllCalls",  color: "0x33A9DC76", stroke: "0xFFA9DC76" },
    { word: "Hyperlink",        color: "0x33FF6188", stroke: "0xFFFF6188" },
    { word: "Zero-Copy",        color: "0x3378DCE8", stroke: "0xFF78DCE8" },
    { word: "100% Math",        color: "0x33A9DC76", stroke: "0xFFA9DC76" }
]

; 5. Telemetry Card
telemetryY := 310
RoundedRectangle(40, telemetryY, 600, 110, 8, "0x66000000", true)
RoundedRectangle(40, telemetryY, 600, 110, 8, "0x22FCFCFA", false)

defaultTelemetryStr := 
(
      "INTERACTIVE TEXT TELEMETRY (0 DllCalls / Sub-microsecond Math):`n`n"
    . " • Hover your mouse over any glowing word badge above.`n"
    . " • Click on any word to trigger an instant native onClick action!`n"
    . " • Bounding boxes calculated dynamically with exact font kerning."
)

telemetryTxt := Rectangle(55, telemetryY + 14, 570, 85, "0x00000000", true)
telemetryTxt.Text(defaultTelemetryStr, "0xFFAB9DF2", 9.5, "Consolas", "Regular").Left().Top()

; 6. Create interactive word pill badges and bind OnEvent handlers
for item in wordsToHighlight {
    box := txtShape.GetWordRect(item.word)
    if (box.found && box.w > 0) {
        padX := 5, padY := 2
        bg := RoundedRectangle(box.x - padX, box.y - padY, box.w + (padX * 2), box.h + (padY * 2), 4, item.color, true)
        border := RoundedRectangle(box.x - padX, box.y - padY, box.w + (padX * 2), box.h + (padY * 2), 4, item.stroke, false)

        wordName := item.word
        normalBg := item.color
        hoverBg := "0x77" . SubStr(item.stroke, 3)
        normalBorder := item.stroke
        hoverBorder := "0xFFFFFFFF"
        wBox := box

        bg.OnEvent("MouseEnter", ((w, b, br, hbg, hbr, bx, *) => OnWordHover(w, b, br, hbg, hbr, bx, true)).Bind(wordName, bg, border, hoverBg, hoverBorder, wBox))
        bg.OnEvent("MouseLeave", ((w, b, br, nbg, nbr, bx, *) => OnWordHover(w, b, br, nbg, nbr, bx, false)).Bind(wordName, bg, border, normalBg, normalBorder, wBox))
        bg.OnEvent("Click", ((w, b, br, bx, *) => OnWordClick(w, b, br, bx)).Bind(wordName, bg, border, wBox))

        border.OnEvent("MouseEnter", ((w, b, br, hbg, hbr, bx, *) => OnWordHover(w, b, br, hbg, hbr, bx, true)).Bind(wordName, bg, border, hoverBg, hoverBorder, wBox))
        border.OnEvent("MouseLeave", ((w, b, br, nbg, nbr, bx, *) => OnWordHover(w, b, br, nbg, nbr, bx, false)).Bind(wordName, bg, border, normalBg, normalBorder, wBox))
        border.OnEvent("Click", ((w, b, br, bx, *) => OnWordClick(w, b, br, bx)).Bind(wordName, bg, border, wBox))
    }
}

OnWordHover(word, bgShape, borderShape, newBg, newBorder, box, isHovered) {
    bgShape.color := newBg
    borderShape.color := newBorder
    if (isHovered) {
        telemetryTxt.Text(Format(
              "HOVERING WORD: '{}'`n"
            . "  • Position :  x: {:0.1f},  y: {:0.1f}`n"
            . "  • Size     :  w: {:0.1f} px,  h: {:0.1f} px`n"
            . "  • Layout   :  Line {}, pure sub-microsecond math (0 DllCalls)!`n"
            . "  • Action   :  Click word to trigger hyperlink action!",
            word, box.x, box.y, box.w, box.h, box.line
        ), "0xFF00FF66", 9.5, "Consolas", "Regular").Left().Top()
    } else {
        telemetryTxt.Text(defaultTelemetryStr, "0xFFAB9DF2", 9.5, "Consolas", "Regular").Left().Top()
    }
    Draw(lyr)
}

OnWordClick(word, bgShape, borderShape, box) {
    bgShape.color := "0xAAFFFFFF"
    borderShape.color := "0xFFFFFFFF"
    telemetryTxt.Text(Format(
          "CLICKED HYPERLINK: '{}'`n"
        . "  • Bounding box hit-test: SUCCESS`n"
        . "  • Coordinates: ({:0.1f}, {:0.1f})`n"
        . "  • Event: custom onClick handler executed with 0 GDI+ overhead!",
        word, box.x, box.y
    ), "0xFFFFD866", 9.5, "Consolas", "Bold").Left().Top()
    Draw(lyr)
}

Rectangle(40, 435, 600, 25, "0x00000000", true)
    .Text("Click and drag anywhere to move window • Esc to exit", "0xFF72707E", 9, "Segoe UI", "Regular", 5, "center", "middle")

; Draw single layer
Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())