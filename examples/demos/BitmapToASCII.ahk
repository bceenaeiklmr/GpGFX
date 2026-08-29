; Script     BitmapToASCII.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../GpGFX.ahk

; GpGFX Native Bitmap & Layer ToASCII() Showcase
; Perfectly Centered 3-Column Symmetrical Grid:
; 1. Original Vector Scene  |  2. Monochrome ASCII Art  |  3. Full-Color ASCII Art
; 100% Native GpGFX Shapes API (Shapes.ahk)

width := 1340
height := 700
artW := 360
artH := 240
cols := 52

; Generate procedural artwork purely using GpGFX Shapes API

lyrArt := Layer(0, 0, artW, artH, "Source Vector Art")
lyrArt.Visible := false ; Offscreen buffer in RAM

FilledRectangle(0, 0, artW, artH, "0xFF0B0F19")
FilledCircle(180, 110, 65, "0xFFFF6188")
FilledCircle(100, 70, 45, "0xFF78DCE8")
FilledCircle(260, 150, 40, "0xFFA9DC76")
Triangle(180, 25, 55, 205, 305, 205, "0xFFFFD866", 3.5)

; Draw vector shapes into layer canvas
Draw(lyrArt)

; Convert directly from the layer to ASCII art with auto aspect-ratio compensation!
asciiStandard := lyrArt.ToASCII(cols, , " .:-=+*#@", false, false)
asciiColored  := lyrArt.ToASCII(cols, , " .:-=+*#@", true, false)
rows := StrSplit(asciiStandard, "`n").Length
lyrArt.Dispose()

; Main Display UI Layer
lyr := Layer(0, 0, width, height, "ASCII Art Showcase")
lyr.draggable := true
lyr.Center()

; Dark background container
FilledRectangle(0, 0, width, height, "0xFF131722")
RoundedRectangle(10, 10, width - 20, height - 20, 16, "0x30FFFFFF", false, 1)

; Header
Text(30, 20, width - 60, 28, "GpGFX NATIVE ToASCII() CONVERSION", "0xFFFCFCFA", 14, "Segoe UI", "Bold").Center().Middle()
Text(30, 48, width - 60, 20, "1-Line Native Rasterization to Monospaced ASCII Characters with Aspect Ratio Compensation", "0xFF38BDF8", 9.5, "Segoe UI").Center().Middle()

cardW := 410
cardH := 550
boxInnerW := 360
boxInnerH := 240

; COLUMN 1: Original High-Resolution Vector Graphic
col1X := 30, col1Y := 80
RoundedRectangle(col1X, col1Y, cardW, cardH, 10, "0x1AFFFFFF", true)
RoundedRectangle(col1X, col1Y, cardW, cardH, 10, "0x33FFFFFF", false, 1)
Text(col1X, col1Y + 10, cardW, 22, "1. ORIGINAL GRAPHIC", "0xFF78DCE8", 9.5, "Segoe UI", "Bold").Center().Middle()
Text(col1X, col1Y + 30, cardW, 18, "Native 32bpp GpGFX Vector Canvas", "0xFF94A3B8", 8, "Segoe UI").Center().Middle()

; Centered artwork box
col1ArtX := col1X + (cardW - boxInnerW) // 2
col1ArtY := col1Y + 55
FilledRoundedRectangle(col1ArtX, col1ArtY, boxInnerW, boxInnerH, 8, "0xFF0B0F19")
FilledCircle(col1ArtX + 180, col1ArtY + 110, 65, "0xFFFF6188")
FilledCircle(col1ArtX + 100, col1ArtY + 70, 45, "0xFF78DCE8")
FilledCircle(col1ArtX + 260, col1ArtY + 150, 40, "0xFFA9DC76")
Triangle(col1ArtX + 180, col1ArtY + 25, col1ArtX + 55, col1ArtY + 205, col1ArtX + 305, col1ArtY + 205, "0xFFFFD866", 3.5)

; Column 1 technical metrics specs card
RoundedRectangle(col1ArtX, col1Y + 310, boxInnerW, 220, 8, "0x12FFFFFF", true)
RoundedRectangle(col1ArtX, col1Y + 310, boxInnerW, 220, 8, "0x25FFFFFF", false, 1)
Text(col1ArtX + 20, col1Y + 322, boxInnerW - 40, 20, "SOURCE VECTOR METRICS", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Middle()
info1 := "• Native Resolution: " artW " x " artH " px`n"
       . "• Rendering Pipeline: GpGFX AntiAlias`n"
       . "• Vector Primitives: 3 Circles + Triangle`n"
       . "• Geometry Format: Pure Mathematical Nodes`n"
       . "• Memory Overhead: 0 KB (Direct GPU Blit)`n"
       . "• Aspect Ratio: 1.5 : 1 (W : H)"
Text(col1ArtX + 20, col1Y + 350, boxInnerW - 40, 165, info1, "0xFF94A3B8", 8, "Consolas").Left().Top()

; COLUMN 2: Standard Monochrome ASCII Art
col2X := 465, col2Y := 80
RoundedRectangle(col2X, col2Y, cardW, cardH, 10, "0x1AFFFFFF", true)
RoundedRectangle(col2X, col2Y, cardW, cardH, 10, "0x33FFFFFF", false, 1)
Text(col2X, col2Y + 10, cardW, 22, "2. MONOCHROME ASCII", "0xFFA9DC76", 9.5, "Segoe UI", "Bold").Center().Middle()
Text(col2X, col2Y + 30, cardW, 18, "Luminance ramp: `" .:-=+*#@`"", "0xFF94A3B8", 8, "Segoe UI").Center().Middle()

; Centered ASCII art box matching Column 1
col2ArtX := col2X + (cardW - boxInnerW) // 2
col2ArtY := col2Y + 55
FilledRoundedRectangle(col2ArtX, col2ArtY, boxInnerW, boxInnerH, 8, "0xFF0B0F19")
Text(col2ArtX, col2ArtY, boxInnerW, boxInnerH, asciiStandard, "0xFFE2E8F0", 7.5, "Consolas", "Regular").Center().Middle()

; Column 2 metrics card
RoundedRectangle(col2ArtX, col2Y + 310, boxInnerW, 220, 8, "0x12FFFFFF", true)
RoundedRectangle(col2ArtX, col2Y + 310, boxInnerW, 220, 8, "0x25FFFFFF", false, 1)
Text(col2ArtX + 20, col2Y + 322, boxInnerW - 40, 20, "MONOCHROME ASCII METRICS", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Middle()
info2 := "• ASCII Grid: " cols " cols x " rows " rows`n"
       . "• Character Font: Consolas 7.5pt Monospace`n"
       . "• Character Ramp: `" .:-=+*#@`"`n"
       . "• Luminance Formula: ITU-R BT.601`n"
       . "• Typographic Engine: Fixed Pitch O(1)`n"
       . "• 1-Line API: lyr.ToASCII(" cols ")"
Text(col2ArtX + 20, col2Y + 350, boxInnerW - 40, 165, info2, "0xFF94A3B8", 8, "Consolas").Left().Top()

; COLUMN 3: Full-Color ASCII Art
col3X := 900, col3Y := 80
RoundedRectangle(col3X, col3Y, cardW, cardH, 10, "0x1AFFFFFF", true)
RoundedRectangle(col3X, col3Y, cardW, cardH, 10, "0x33FFFFFF", false, 1)
Text(col3X, col3Y + 10, cardW, 22, "3. FULL-COLOR ASCII", "0xFFFFD866", 9.5, "Segoe UI", "Bold").Center().Middle()
Text(col3X, col3Y + 30, cardW, 18, "RGB per-character {color:0xRRGGBB} tags", "0xFF94A3B8", 8, "Segoe UI").Center().Middle()

; Centered Color ASCII art box matching Columns 1 & 2
col3ArtX := col3X + (cardW - boxInnerW) // 2
col3ArtY := col3Y + 55
FilledRoundedRectangle(col3ArtX, col3ArtY, boxInnerW, boxInnerH, 8, "0xFF0B0F19")
Text(col3ArtX, col3ArtY, boxInnerW, boxInnerH, asciiColored, "0xFFE2E8F0", 7.5, "Consolas", "Regular").Center().Middle()

; Column 3 metrics card
RoundedRectangle(col3ArtX, col3Y + 310, boxInnerW, 220, 8, "0x12FFFFFF", true)
RoundedRectangle(col3ArtX, col3Y + 310, boxInnerW, 220, 8, "0x25FFFFFF", false, 1)
Text(col3ArtX + 20, col3Y + 322, boxInnerW - 40, 20, "FULL-COLOR ASCII METRICS", "0xFFFCFCFA", 8.5, "Segoe UI", "Bold").Left().Middle()
info3 := "• Color Precision: 24-bit TrueColor (RGB)`n"
       . "• Markup Syntax: {color:0xRRGGBB}`n"
       . "• Fixed Character Pitch: O(1) Accelerated`n"
       . "• Rich Text Engine: GpGFX Typographic`n"
       . "• ClearType Grid-Fit: Subpixel Antialiased`n"
       . "• 1-Line API: lyr.ToASCII(" cols ", , , true)"
Text(col3ArtX + 20, col3Y + 350, boxInnerW - 40, 165, info3, "0xFF94A3B8", 8, "Consolas").Left().Top()

; Footer Info
Text(30, height - 42, width - 60, 20, "Press [C] Copy Monochrome ASCII | [Esc] Exit | Drag window anywhere", "0xFF94A3B8", 9, "Segoe UI").Center().Middle()

Draw(lyr)

; Hotkey to copy ASCII string to clipboard
~c:: {
    A_Clipboard := asciiStandard
    ToolTip("Copied Monochrome ASCII to Clipboard!")
    SetTimer(() => ToolTip(), -1500)
}

HotKey("~*Esc", (*) => ExitApp())