; Script     PathGradientShowcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

width := 860
height := 620

lyr := Layer((A_ScreenWidth - width) // 2, (A_ScreenHeight - height) // 2, width, height, "GpGFX PathGradient & Radial Showcase")
lyr.draggable := true

; Dark Background
RoundedRectangle(10, 10, width - 20, height - 20, 16, "0xFF181825", true)
RoundedRectangle(10, 10, width - 20, height - 20, 16, "0x33FCFCFA", false)

; Header
Text(30, 25, width - 60, 30, "PATH GRADIENT & RADIAL GRADIENT ENGINE", "0xFFFCFCFA", 13, "Segoe UI", "Bold").Center().Middle()
Text(30, 52, width - 60, 20, "GDI+ PathGradientBrush, Radial Presets, FocusScales & Multi-Stop Blends", "0xFF78DCE8", 9.5, "Segoe UI").Center().Middle()

; Card 1: Pure Circular Radial Glow (Center Hotspot)
cx1 := 140, cy1 := 190, r1 := 80 
card1 := RoundedRectangle(40, 90, 200, 210, 12, "0xFF1E1E2E", true)
RoundedRectangle(40, 90, 200, 210, 12, "0x20FCFCFA", false)
Text(40, 95, 200, 24, "1. Radial Glow", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()

glow1 := Circle(cx1 - r1, cy1 - r1, r1 * 2, "0x00000000", true)
glow1.Tool := PathGradientBrush.Radial(cx1, cy1, r1, "0xFFFF6188", "0x001E1E2E")

; Card 2: Focused Radial Spot (FocusScales = 0.5)
cx2 := 360, cy2 := 190, r2 := 80
card2 := RoundedRectangle(260, 90, 200, 210, 12, "0xFF1E1E2E", true)
RoundedRectangle(260, 90, 200, 210, 12, "0x20FCFCFA", false)
Text(260, 95, 200, 24, "2. FocusScales (Neon)", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()

glow2 := Circle(cx2 - r2, cy2 - r2, r2 * 2, "0x00000000", true)
brush2 := PathGradientBrush.Radial(cx2, cy2, r2, "0xFF00F0FF", "0x001E1E2E")
brush2.FocusScales := [0.45, 0.45]
glow2.Tool := brush2

; Card 3: Multi-Stop Radial Sunburst (SetPresetBlend)
cx3 := 580, cy3 := 190, r3 := 80
card3 := RoundedRectangle(480, 90, 200, 210, 12, "0xFF1E1E2E", true)
RoundedRectangle(480, 90, 200, 210, 12, "0x20FCFCFA", false)
Text(480, 95, 200, 24, "3. Multi-Stop Blend", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()

glow3 := Circle(cx3 - r3, cy3 - r3, r3 * 2, "0x00000000", true)
brush3 := PathGradientBrush.Radial(cx3, cy3, r3, "0xFFFFFFFF", "0x001E1E2E")
brush3.SetPresetBlend(["#FFFFFF", "#FFD866", "#FF6188", "#78DCE8", "0x001E1E2E"], [0.0, 0.25, 0.55, 0.85, 1.0])
glow3.Tool := brush3

; Card 4: Polygonal Star / Diamond Path Gradient
cx4 := 750, cy4 := 190, r4 := 80
card4 := RoundedRectangle(700, 90, 120, 210, 12, "0xFF1E1E2E", true)
RoundedRectangle(700, 90, 120, 210, 12, "0x20FCFCFA", false)
Text(700, 95, 120, 24, "4. Diamond", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()

diamondPts := [
    [cx4, cy4 - r4],
    [cx4 + r4 * 0.7, cy4],
    [cx4, cy4 + r4],
    [cx4 - r4 * 0.7, cy4]
]
diamondShape := Polygon(diamondPts, "0x00000000", true)
brush4 := PathGradientBrush(diamondPts, "0xFFA9DC76", "0x001E1E2E")
diamondShape.Tool := brush4

; Bottom Row: Rectangular Vignette / Studio Backdrop
card5 := RoundedRectangle(40, 320, width - 80, 240, 12, "0xFF11111B", true)
RoundedRectangle(40, 320, width - 80, 240, 12, "0x20FCFCFA", false)
Text(55, 330, 300, 24, "5. Rectangular Studio Spotlight", "0xFFFCFCFA", 10.5, "Segoe UI", "Bold").Left().Middle()

studioRect := RoundedRectangle(55, 360, width - 110, 185, 10, "0x00000000", true)
brushStudio := PathGradientBrush.FromRect(55, 360, width - 110, 185, "0x8078DCE8", "0xFF11111B")
brushStudio.FocusScales := [0.3, 0.1]
brushStudio.SetCenter(55 + (width - 110) // 2, 360 + 70)
studioRect.Tool := brushStudio

Text(55, 430, width - 110, 30, "Smooth Hardware-Accelerated Path Gradients", "0xFFFCFCFA", 12, "Segoe UI", "Bold").Center().Middle()
Text(55, 460, width - 110, 20, "PathGradientBrush.Radial | PathGradient.FromRect | SetPresetBlend", "0xFFAB9DF2", 9.5, "Segoe UI").Center().Middle()

Text(30, height - 35, width - 60, 20, "Drag window anywhere | Press [Esc] to exit", "0xFF727072", 8.5, "Segoe UI").Center().Middle()

Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())
