; Script:    03_Colors_and_Gradients.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

; Example:    03_Colors_and_Gradients.ahk
; Description: Demonstrates color parsing formats, linear gradients, and pre-computed design palettes.
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; 1. Create transparent window canvas
lyr := Layer(740, 480).Center()
RoundedRectangle(740, 480, 14, "0xFF1E1E2E") ; Base card

; Header
Text(25, 20, 690, 30, "GpGFX Colors, Gradients & Palettes", "0xFFCDD6F4", 15, "Segoe UI", "Bold").Left()

; Section 1: Color Parsing Formats
Text(25, 60, 690, 20, "1. Color Formats (Named, Hex #RGB, #ARGB, 0xARGB)", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

; Named color
RoundedRectangle(30, 90, 90, 50, 8, "Crimson")
Text(30, 105, 90, 20, "Crimson", "White", 9).Center()

; Hex 6-digit (#RRGGBB)
RoundedRectangle(130, 90, 90, 50, 8, "#3B82F6")
Text(130, 105, 90, 20, "#3B82F6", "White", 9).Center()

; Hex 8-digit with Alpha (#AARRGGBB - semi-transparent emerald)
RoundedRectangle(230, 90, 90, 50, 8, "#CC10B981")
Text(230, 105, 90, 20, "Alpha 80%", "White", 9).Center()

; Standard 0xARGB integer
RoundedRectangle(330, 90, 90, 50, 8, 0xFF8B5CF6")
Text(330, 105, 90, 20, "0xFF8B5CF6", "White", 9).Center()

; Section 2: Linear Gradients
Text(25, 160, 690, 20, "2. Linear Gradients (Horizontal, Vertical, Diagonal)", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

; Horizontal Gradient: [startColor, endColor, mode (0=Horizontal)]
g1 := RoundedRectangle(30, 190, 190, 60, 8)
g1.Color := ["Gradient", "#FF5E36", "#FFAE34", 0]
Text(30, 210, 190, 20, "Horizontal Sunset", "White", 9, "Segoe UI", "Bold").Center()

; Vertical Gradient: mode 1
g2 := RoundedRectangle(230, 190, 190, 60, 8)
g2.Color := ["Gradient", "#00F0FF", "#7122FA", 1]
Text(230, 210, 190, 20, "Vertical Cyber", "White", 9, "Segoe UI", "Bold").Center()

; Forward Diagonal: mode 2
g3 := RoundedRectangle(430, 190, 190, 60, 8)
g3.Color := ["Gradient", "#FF007F", "#7800A8", 2]
Text(430, 210, 190, 20, "Diagonal Neon", "White", 9, "Segoe UI", "Bold").Center()

; Section 3: Built-in Design Palettes
Text(25, 270, 690, 20, "3. Built-in Palettes (Nord, Dracula, TokyoNight, Monokai, Cyberpunk)", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

palettes := [Palette.Nord, Palette.Dracula, Palette.TokyoNight, Palette.Monokai, Palette.Cyberpunk]
palNames := ["Nord", "Dracula", "TokyoNight", "Monokai", "Cyberpunk"]

for i, pal in palettes {
    pX := 30 + (i - 1) * 135
    
    ; Palette Name
    Text(pX, 300, 125, 20, palNames[i], "0xFFCDD6F4", 10, "Segoe UI", "Bold").Left()
    
    ; 4 Core Swatch Colors
    loop 4 {
        Circle(pX + (A_Index - 1) * 28 + 12, 335, 11, pal[A_Index])
    }
    
    ; Pre-computed Continuous Gradient Bar (~2 ns LUT sampling)
    bar := RoundedRectangle(pX, 360, 115, 16, 4)
    bar.Color := ["Gradient", pal[1], pal[4], 0]
}

; Footer
Text(25, 430, 690, 25, "Press ESC to close window • Drag window anywhere", "0xFF6C7086", 10).Center()
lyr.Drag().Draw()

Esc::ExitApp()
