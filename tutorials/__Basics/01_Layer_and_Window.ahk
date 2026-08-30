; Script:    01_Layer_and_Window.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

; Example:    01_Layer_and_Window.ahk
; Description: How to create a transparent, hardware-accelerated GpGFX layered window.
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; 1. Create a transparent Layer (Width: 600, Height: 400)
; By default, layers are layered (per-pixel alpha transparent) and topmost.
myLayer := Layer(600, 400)

; 2. Center the window on the primary monitor
myLayer.Center()

; 3. Add a dark rounded background card (Width: 600, Height: 400, Radius: 16)
; Catppuccin Mocha Base color: 0xFF1E1E2E
RoundedRectangle(600, 400, 16, "0xFF1E1E2E")

; 4. Add a subtle 1px border stroke around the card
RoundedRectangle(600, 400, 16, "0xFF313244", false) ; filled: false -> Pen outline stroke

; 5. Add centered title text
Text("GpGFX Layered Window", "0xFFCDD6F4", 16, "Segoe UI", "Bold").Center().Shift(0, -20)
Text("Press ESC to exit or click anywhere to drag", "0xFFA6ADC8", 10, "Segoe UI").Center().Shift(0, 20)

; 6. Enable left-click window dragging across the transparent surface
myLayer.Drag()

; 7. Render everything to the screen with a single hardware flush
myLayer.Draw()

; Press Escape to close the application
Esc::ExitApp()
