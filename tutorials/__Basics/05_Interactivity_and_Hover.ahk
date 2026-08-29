; Script     05_Interactivity_and_Hover.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

; Example:    05_Interactivity_and_Hover.ahk
; Description: Demonstrates interactive mouse events, hover color feedback, and custom vector buttons.
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; Create canvas window
lyr := Layer(640, 420).Center()
RoundedRectangle(640, 420, 14, "0xFF1E1E2E")

; Header
Text(25, 20, 590, 30, "GpGFX Interactivity & Mouse Events", "0xFFCDD6F4", 15, "Segoe UI", "Bold").Left()
Text(25, 55, 590, 20, "High-speed native vector hit-testing without Win32 child control overhead.", "0xFFA6ADC8", 10).Left()

; Status Feedback Label (Updates when elements are clicked)
statusText := Text(25, 95, 590, 25, "Click any button below to see event routing in action...", "0xFFFAB387", 10, "Segoe UI", "Bold").Left()

; 1. 1-Line Button Component
; Button(x, y, w, h, label, onClick, hoverColor, bgColor)
btn1 := Button(40, 140, 160, 42, "Primary Action", (*) => OnButtonClick("Primary Action Clicked!"), "0xFF89B4FA", "0xFF313244")

; 2. Success Action Button with Green Accent
btn2 := Button(220, 140, 160, 42, "Confirm Action", (*) => OnButtonClick("Success Button Triggered!"), "0xFFA6E3A1", "0xFF313244")

; 3. Danger Action Button with Red Accent
btn3 := Button(400, 140, 160, 42, "Danger Action", (*) => OnButtonClick("Danger Button Fired!"), "0xFFF38BA8", "0xFF313244")

; 4. Custom Hover Alpha on Shapes
; HoverAlpha(hoverOpacity, normalOpacity)
card := RoundedRectangle(40, 210, 520, 100, 10, "0xFF89B4FA")
card.HoverAlpha(255, 140) ; Fades from 140 (semi-transparent) to 255 (opaque) on hover!
Text(40, 235, 520, 25, "Hover Over This Card (Dynamic Alpha Feedback)", "0xFF1E1E2E", 12, "Segoe UI", "Bold").Center()
Text(40, 265, 520, 20, "Hovering alters the shape's alpha channel with zero GDI+ re-allocation.", "0xFF1E1E2E", 9).Center()

; Click Handler
OnButtonClick(msg) {
    statusText.str := "{#A6E3A1}Event:{} " msg
    lyr.Draw()
    SoundBeep(800, 50)
}

; Footer
Text(25, 375, 590, 25, "Press ESC to exit • Click and drag window to move", "0xFF6C7086", 10).Center()
lyr.Drag().Draw()

Esc::ExitApp()
