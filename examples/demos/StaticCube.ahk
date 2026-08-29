; Script     StaticCube.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#include ../../GpGFX.ahk

/**
 * Static 3D Wireframe Cube with Polygon Shading
 * Demonstrates combining vector Lines and Polygons to construct isometric 3D geometry.
 */

; Create a centered 600x600 transparent layer
lyr := Layer(600, 600).Center()

; Dark background canvas
RoundedRectangle(600, 600, 16, "0xFF181825")
RoundedRectangle(600, 600, 16, "0xFF313244", false)

; Header
Text("3D Isometric Wireframe Cube", "0xFFCDD6F4", 13, "Segoe UI", "Bold").Center().Shift(0, -260)
Text("Press ESC to exit • Click and drag window to move", "0xFFA6ADC8", 9).Center().Shift(0, -238)

; Margins and vertex dimensions
margin := 180
size := 420

; Front Face 2D Vertices
FTL := [margin, margin + 40]
FTR := [size, margin + 40]
FBL := [margin, size + 40]
FBR := [size, size + 40]

; Back Face 2D Vertices (offset by 60px)
BTL := [margin + 60, margin - 20]
BTR := [size + 60, margin - 20]
BBL := [margin + 60, size - 20]
BBR := [size + 60, size - 20]

; 1. Shaded Top Polygon Face
polyTop := Polygon("0x3389B4FA", 1, 0, [FTL[1], FTL[2], BTL[1], BTL[2], BTR[1], BTR[2], FTR[1], FTR[2]])

; 2. Shaded Right Polygon Face
polyRight := Polygon("0x2289B4FA", 1, 0, [FTR[1], FTR[2], BTR[1], BTR[2], BBR[1], BBR[2], FBR[1], FBR[2]])

; 3. Draw Back Face (Dotted / Dark outline)
Line(BTL[1], BTL[2], BTR[1], BTR[2], "0xFF45475A", 1)
Line(BTL[1], BTL[2], BBL[1], BBL[2], "0xFF45475A", 1)
Line(BTR[1], BTR[2], BBR[1], BBR[2], "0xFF45475A", 1)
Line(BBL[1], BBL[2], BBR[1], BBR[2], "0xFF45475A", 1)

; 4. Connecting Depth Lines
Line(FTL[1], FTL[2], BTL[1], BTL[2], "0xFF89B4FA", 2)
Line(FTR[1], FTR[2], BTR[1], BTR[2], "0xFF89B4FA", 2)
Line(FBL[1], FBL[2], BBL[1], BBL[2], "0xFF45475A", 1)
Line(FBR[1], FBR[2], BBR[1], BBR[2], "0xFF89B4FA", 2)

; 5. Draw Front Face (Bright Cyan Accent)
Line(FTL[1], FTL[2], FTR[1], FTR[2], "0xFF89DCEB", 2)
Line(FTL[1], FTL[2], FBL[1], FBL[2], "0xFF89DCEB", 2)
Line(FTR[1], FTR[2], FBR[1], FBR[2], "0xFF89DCEB", 2)
Line(FBL[1], FBL[2], FBR[1], FBR[2], "0xFF89DCEB", 2)

; Enable dragging and render
lyr.Drag().Draw()

Esc::ExitApp()
