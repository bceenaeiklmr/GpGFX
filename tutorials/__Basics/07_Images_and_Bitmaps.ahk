; Script:    07_Images_and_Bitmaps.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

; Example:    07_Images_and_Bitmaps.ahk
; Description: Demonstrates image rendering, color matrix filters (Grayscale, Invert), and pixel manipulation.
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; Create canvas window
lyr := Layer(700, 480).Center()
RoundedRectangle(700, 480, 14, "0xFF1E1E2E")

; Header
Text(25, 20, 650, 30, "GpGFX Image & Bitmap Processing", "0xFFCDD6F4", 15, "Segoe UI", "Bold").Left()
Text(25, 55, 650, 20, "Render image files, apply real-time color filters, and manipulate pixel buffers.", "0xFFA6ADC8", 10).Left()

; Sample image asset path
assetPath := A_LineFile "\..\..\assets\example_wp.png"

; 1. Normal Scaled Image
RoundedRectangle(40, 95, 180, 140, 8, "0xFF313244")
pic1 := Picture(40, 95, 180, 140, assetPath)
Text(40, 245, 180, 20, "Original (Auto-Fit)", "0xFFCDD6F4", 9).Center()

; 2. Image with Grayscale Filter
RoundedRectangle(260, 95, 180, 140, 8, "0xFF313244")
pic2 := Picture(40, 95, 180, 140, assetPath, 0, "grayscale")
pic2.Move(260, 95)
Text(260, 245, 180, 20, "Grayscale Filter", "0xFFCDD6F4", 9).Center()

; 3. Image with Color Inversion Filter
RoundedRectangle(480, 95, 180, 140, 8, "0xFF313244")
pic3 := Picture(40, 95, 180, 140, assetPath, 0, "invert")
pic3.Move(480, 95)
Text(480, 245, 180, 20, "Invert Filter", "0xFFCDD6F4", 9).Center()

; 4. Direct In-Memory Pixel Drawing (Scan0 SetPixel)
Text(25, 285, 650, 20, "Direct In-Memory Bitmap Pixel Generation", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

; Create an in-memory 100x100 GdipBitmap
bmp := GdipBitmap(120, 80)
loop 80 {
    yIdx := A_Index - 1
    loop 120 {
        xIdx := A_Index - 1
        ; Generate procedural gradient pattern
        rVal := Integer((xIdx / 120) * 255)
        bVal := Integer((yIdx / 80) * 255)
        pixelClr := 0xFF000000 | (rVal << 16) | (120 << 8) | bVal
        bmp.SetPixel(xIdx, yIdx, pixelClr)
    }
}

; Attach generated bitmap to canvas
customPic := Picture(40, 315, 180, 100)
customPic.AddImage(bmp)
Text(40, 425, 180, 20, "Procedural Scan0", "0xFFCDD6F4", 9).Center()

; 5. Clipboard Integration
Text(260, 315, 400, 70, "Clipboard Integration:`n• Picture.FromClipboard() pastes images directly.`n• layer.ToClipboard() copies rendered frames.`n• shp.ToFile('output.png') exports to disk.", "0xFFCDD6F4", 10, "Segoe UI").Left()

; Enable dragging & draw
lyr.Drag().Draw()

Esc::ExitApp()
