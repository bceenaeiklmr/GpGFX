; Script:    QualityPresetDemo.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../GpGFX.ahk

; Window Dimensions
width := 840
height := 440

lyr := Layer(0, 0, width, height, "Quality Preset Showcase")
lyr.draggable := true
lyr.Center()

; Preset state: "low", "mid", "high"
currentPreset := "mid"
lyr.Quality := currentPreset

; Background
bg := FilledRectangle(0, 0, width, height, "0xFF181824")
border := RoundedRectangle(10, 10, width - 20, height - 20, 14, "0x30FFFFFF", false, 1)

; Header
title := Text(30, 25, width - 60, 30, "GRAPHICS QUALITY PRESET DEMO", "0xFFFCFCFA", 13, "Segoe UI", "Bold").Center().Middle()
desc := Text(30, 52, width - 60, 20, "Interactive Low / Mid / High Antialiasing & Subpixel Vector Rendering", "0xFF78DCE8", 9.5, "Segoe UI").Center().Middle()

; Column 1: Low Preset Box
boxLow := RoundedRectangle(40, 95, 230, 250, 8, "0x15FFFFFF", true)
boxLowBorder := RoundedRectangle(40, 95, 230, 250, 8, "0x40FFFFFF", false, 1)
Text(40, 105, 230, 22, "1. LOW (Fast / Benchmarks)", "0xFFFF6188", 9.5, "Segoe UI", "Bold").Center().Middle()
Text(40, 125, 230, 18, "Smoothing: None | Offset: Default", "0xFF939293", 7.5, "Segoe UI").Center().Middle()

; Column 2: Mid Preset Box (Default)
boxMid := RoundedRectangle(305, 95, 230, 250, 8, "0x15FFFFFF", true)
boxMidBorder := RoundedRectangle(305, 95, 230, 250, 8, "0x40FFFFFF", false, 1)
Text(305, 105, 230, 22, "2. MID (Balanced Default)", "0xFFA9DC76", 9.5, "Segoe UI", "Bold").Center().Middle()
Text(305, 125, 230, 18, "Smoothing: AntiAlias | Offset: Default", "0xFF939293", 7.5, "Segoe UI").Center().Middle()

; Column 3: High Preset Box
boxHigh := RoundedRectangle(570, 95, 230, 250, 8, "0x15FFFFFF", true)
boxHighBorder := RoundedRectangle(570, 95, 230, 250, 8, "0x40FFFFFF", false, 1)
Text(570, 105, 230, 22, "3. HIGH (Ultra Smooth)", "0xFF78DCE8", 9.5, "Segoe UI", "Bold").Center().Middle()
Text(570, 125, 230, 18, "Smoothing: AntiAlias | Offset: Half", "0xFF939293", 7.5, "Segoe UI").Center().Middle()

; Render test shapes in all 3 columns
CreateTestShapes(40)
CreateTestShapes(305)
CreateTestShapes(570)

CreateTestShapes(colX) {
    ; Diagonal crossing lines
    Line(colX + 25, 155, colX + 205, 195, "0xFFFF6188", 2)
    Line(colX + 25, 205, colX + 205, 165, "0xFFA9DC76", 2)
    
    ; Circle & Ellipse
    Ellipse(colX + 35, 225, 55, 55, "0xFF78DCE8", 2)
    FilledEllipse(colX + 135, 225, 55, 55, "0xFFAB9DF2")
    
    ; Triangle / Polygon
    Triangle(colX + 45, 330, colX + 115, 290, colX + 185, 330, "0xFFFFD866", 2)
}

; Footer Info
status := Text(30, height - 55, width - 60, 22, "Active Layer Quality: " . StrUpper(lyr.Quality) . "  |  Press [1] Low  [2] Mid  [3] High  [Esc] Exit", "0xFFFFD866", 9, "Segoe UI", "Bold").Center().Middle()
hint := Text(30, height - 32, width - 60, 18, "Drag window anywhere | High quality uses subpixel half-pixel offset for ultra smooth diagonal lines", "0xFF727072", 8, "Segoe UI").Center().Middle()

Draw(lyr)

; Hotkeys to switch layer graphics quality live
1:: SetPreset("low")
2:: SetPreset("mid")
3:: SetPreset("high")

SetPreset(q) {
    lyr.Quality := q
    status.str := "Active Layer Quality: " . StrUpper(lyr.Quality) . "  |  Press [1] Low  [2] Mid  [3] High  [Esc] Exit"
    Draw(lyr)
}

HotKey("~*Esc", (*) => ExitApp())
