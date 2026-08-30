; Script:    RichTextStyleShowcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; GpGFX Rich Text Styling Showcase
; Demonstrates Bold (b), Italic (i), Underline (u), Strikeout (s), 
; nested styles, and combined Color + Style tags

lyr := Layer(100, 80, 680, 560, "RichTextStyleShowcase")
lyr.draggable := true

; 1. Window Frame & Background
RoundedRectangle(10, 10, 660, 540, 16, "0xF014141E", true)
RoundedRectangle(10, 10, 660, 540, 16, "0x40FCFCFA", false)

; 2. Title Bar
Rectangle(30, 24, 620, 36, "0x00000000", true)
    .Text("{#78DCE8}GpGFX{} Rich Text Styling Showcase (Bold, Italic, Underline, Strike)", "0xFFFCFCFA", 13, "Segoe UI", "Bold")

; 3. Multiline Showcase Text with all style combinations
showcaseText := 
(
    "1. <b>Basic Styles:</b> <b>Bold</b>, <i>Italic</i>, <u>Underline</u>, and <s>Strikeout</s>`n"
    . "2. <b>Nested Combinations:</b> <b><i>Bold Italic</i></b>, <b><u>Bold Underline</u></b>, <i><u>Italic Underline</u></i>`n"
    . "3. <b>Combined Color + Style:</b> {#FFD866, b}Bold Gold{}, {#78DCE8, i}Italic Cyan{}, {#FF6188, u}Underline Rose{}`n"
    . "4. <b>Multi-Attribute Tags:</b> {#A9DC76, b, i}Bold Italic Lime{} and {#AB9DF2, b, u}Bold Underline Purple{}`n"
    . "5. <b>Tag Syntax Parity:</b> <b>HTML Style</b> and {b}Brace Style{/b} work identically`n"
    . "6. <b>Safe Text:</b> {literal_braces} and non-tag text are 100% preserved!"
)

rectTxt := Rectangle(35, 75, 610, 280, "0x00000000", true)
rectTxt.lineSpacing := 1.65
rectTxt.Text(showcaseText, "0xFFD8D8E0", 11, "Segoe UI", "Regular").Left().Top()

; 4. Pure-Math Word Bounding Boxes on Styled Words (0 DllCalls!)
wordsToHighlight := [
    { word: "Bold Gold",        color: "0x33FFD866", stroke: "0xFFFFD866" },
    { word: "Italic Cyan",      color: "0x3378DCE8", stroke: "0xFF78DCE8" },
    { word: "Underline Rose",   color: "0x33FF6188", stroke: "0xFFFF6188" },
    { word: "Bold Italic Lime", color: "0x33A9DC76", stroke: "0xFFA9DC76" }
]

for item in wordsToHighlight {
    box := rectTxt.GetWordRect(item.word)
    if (box.found && box.w > 0) {
        padX := 5, padY := 2
        RoundedRectangle(box.x - padX, box.y - padY, box.w + (padX * 2), box.h + (padY * 2), 4, item.color, true)
        RoundedRectangle(box.x - padX, box.y - padY, box.w + (padX * 2), box.h + (padY * 2), 4, item.stroke, false)
    }
}

; 5. Telemetry Card
telemetryY := 375
RoundedRectangle(35, telemetryY, 610, 130, 8, "0x66000000", true)
RoundedRectangle(35, telemetryY, 610, 130, 8, "0x22FCFCFA", false)

box1 := rectTxt.GetWordRect("Bold Gold")
box2 := rectTxt.GetWordRect("Italic Cyan")
box3 := rectTxt.GetWordRect("Bold Italic Lime")

telemetryStr := Format(
    "STYLED WORD MEASUREMENTS (Pure-Math / Cached Glyphs):`n"
    . "  • 'Bold Gold'         →  x: {:0.1f},  y: {:0.1f},  w: {:0.1f},  h: {:0.1f}  (Line {})`n"
    . "  • 'Italic Cyan'       →  x: {:0.1f},  y: {:0.1f},  w: {:0.1f},  h: {:0.1f}  (Line {})`n"
    . "  • 'Bold Italic Lime'  →  x: {:0.1f},  y: {:0.1f},  w: {:0.1f},  h: {:0.1f}  (Line {})`n"
    . "  [✓] All bold & italic glyph widths measured with exact font metrics.",
    box1.x, box1.y, box1.w, box1.h, box1.line,
    box2.x, box2.y, box2.w, box2.h, box2.line,
    box3.x, box3.y, box3.w, box3.h, box3.line
)

Rectangle(50, telemetryY + 12, 580, 105, "0x00000000", true)
    .Text(telemetryStr, "0xFFAB9DF2", 9.5, "Consolas", "Regular").Left().Top()

Rectangle(35, 518, 610, 25, "0x00000000", true)
    .Text("Click and drag anywhere to move window • Esc to exit", "0xFF72707E", 9, "Segoe UI", "Regular", 5, "center", "middle")

; Draw single layer
Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())
