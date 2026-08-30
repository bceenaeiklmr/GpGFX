; Script:    TabAndLineHeightDemo.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; Create layer for testing tabs and line spacing
lyr := Layer(100, 100, 580, 420, "TabAndLineHeight")
lyr.draggable := true

; Background card
RoundedRectangle(10, 10, 560, 400, 14, "0xF0181822", true)
RoundedRectangle(10, 10, 560, 400, 14, "0x33FCFCFA", false)

; Title
Rectangle(30, 25, 520, 30, "0x00000000", true)
    .Text("{color:#78DCE8}GpGFX{color} Automatic Multi-Column Tab Stops & Spacing", "0xFFFCFCFA", 13, "Segoe UI", "Bold")

; Multi-column table with a SINGLE \t between columns (auto-aligned!)
tableText := 
(
    "{color:#A9DC76}NAME`tSTATUS`tPING{color}`n"
    . "{color:#FCFCFA}RenderCore`t{color:#78DCE8}Running`t{#FFD866}0.4 ms{color}`n"
    . "{color:#FCFCFA}MemoryDC`t{color:#78DCE8}Active`t{color:#FFD866}0.1 ms{color}`n"
    . "{color:#FCFCFA}WorkerPool`t{color:#A9DC76}Idle`t{color:#FFD866}1.2 ms{color}`n"
    . "{color:#FCFCFA}VsyncHook`t{color:#FF6188}Disabled`t{color:#FFD866}0.0 ms{color}"
)

rectTable := Rectangle(30, 70, 520, 180, "0x00000000", true)
rectTable.lineSpacing := 1.5
rectTable.Text(tableText, "0xFFD8D8E0", 11.5, "Consolas", "Regular").Left().Top()

; Paragraph with custom line spacing and automatic word wrapping
paraText := "{color:#B0B0B8}Note: Columns auto-align with just {color:#FFD866}a single \t tab character{color}, and line spacing is fully configurable via {color:#78DCE8}shp.lineSpacing{color} or {color:#78DCE8}shp.lineHeight{color}.{color}"
rectPara := Rectangle(30, 270, 520, 80, "0x00000000", true)
rectPara.lineSpacing := 1.4
rectPara.Text(paraText, "0xFFB0B0B8", 11, "Segoe UI", "Regular").Left().Top()

; Hint
Rectangle(30, 365, 520, 25, "0x00000000", true)
    .Text("Click and drag window anywhere • Press Escape to exit", "0xFF72707E", 9.5, "Segoe UI", "Regular", 5, "center", "middle")

Draw(lyr)

; Non-blocking Escape hotkey (typing in other windows is never blocked)
HotKey("~*Esc", (*) => ExitApp())
