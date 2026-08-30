; Script:    ColorBufferShowcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include ../../GpGFX.ahk

width := 640
height := 740

lyr := Layer((A_ScreenWidth - width) // 2, (A_ScreenHeight - height) // 2, width, height, "GpGFX ColorBuffer & Palette Engine")
lyr.draggable := true

RoundedRectangle(10, 10, width - 20, height - 20, 16, "0xFF1E1E24", true)
RoundedRectangle(10, 10, width - 20, height - 20, 16, "0x33FCFCFA", false)

Text(30, 25, width - 60, 30, "COLOR.BUFFER & PALETTES", "0xFFFCFCFA", 13, "Segoe UI", "Bold").Center().Middle()
Text(30, 52, width - 60, 20, "Binary LUT Sampling & Multi-Stop Gradients", "0xFF78DCE8", 10.5, "Segoe UI").Center().Middle()

; List of gradient ramps to render
ramps := [
    { title: "Google Turbo (Perceptually Uniform)", buf: Color.Buf.Turbo },
    { title: "Viridis (Matplotlib Standard)",       buf: Color.Buf.Viridis },
    { title: "Plasma (High-Contrast Vibrant)",      buf: Color.Buf.Plasma },
    { title: "Magma (Dark to Bright White)",        buf: Color.Buf.Magma },
    { title: "Inferno (Thermal Radiation)",         buf: Color.Buf.Inferno },
    { title: "Spectral Rainbow (7 Stops)",          buf: Color.Buf.Rainbow },
    { title: "Thermal Heatmap (Black->Red->White)", buf: Color.Buf.Heatmap },
    { title: "CoolWarm Diverging",                  buf: Color.Buf.CoolWarm },
    { title: "Cyber Neon (Cyan->Pink->Gold)",       buf: Color.Buf.Neon },
    { title: "Sunset Horizon (6 Custom Stops)",     buf: Color.Buf.Sunset },
    { title: "Custom 3-Stop (Lime -> Blue -> Red)", buf: Color.Buf("Lime", "Blue", "Red") },
    { title: "Palette.Monokai (UI & Shader LUT)",   buf: Palette.Monokai.buffer }
]

yPos := 85
stripW := width - 60
numSteps := 120

for r in ramps {
    ; Title
    Text(30, yPos, stripW, 16, r.title, "0xFFE0E0E6", 10, "Segoe UI", "Bold").Left().Middle()
    yPos += 18

    ; Render continuous gradient stripe using ColorBuffer.Sample
    xStep := stripW / Float(numSteps)
    loop numSteps {
        t := (A_Index - 1) / Float(numSteps - 1)
        clr := r.buf.Sample(t)
        Rectangle(30 + Round((A_Index - 1) * xStep), yPos, Ceil(xStep) + 1, 14, clr, true)
    }
    yPos += 24
}

Text(30, height - 42, width - 60, 20, "Drag window anywhere | Press [Esc] to exit", "0xFF939293", 8.5, "Segoe UI").Center().Middle()

Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())
