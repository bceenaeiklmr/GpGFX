; Script     ColorTagShowcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; Test all color tag formats
lyr := Layer(150, 150, 560, 360, "ColorTagFormats").Center()
lyr.draggable := true

RoundedRectangle(10, 10, 540, 340, 14, "0xF0181822", true)
RoundedRectangle(10, 10, 540, 340, 14, "0x33FCFCFA", false)

Rectangle(30, 25, 500, 30, "0x00000000", true)
    .Text("{#78DCE8}GpGFX{} Rich Text Color Tag Showcase", "0xFFFCFCFA", 13, "Segoe UI", "Bold")

showcaseText := 
(
      "1. Direct Hex Tag: {#FFD866}Golden {#FF6188}Pink {#A9DC76}Green{} (Reset)`n"
    . "2. Compact: {c:hex} {c:#78DCE8}Cyan {c:#AB9DF2}Purple{c} (Reset)`n"
    . "3. Semantic: {clr:name} {clr:Red}Red {clr:Lime}Lime {clr:Yellow}Yellow{/clr}`n"
    . "4. Full Tag: {color:#78DCE8}Custom Hex{color} and {colour:Orange}Orange{/colour}`n"
    . "5. 0x Format: {0xFFD866}0xFFD866 Gold{} and {0xFF6188}0xFF6188 Rose{}`n"
    . "6. Direct Name: {Cyan}Direct Cyan{} and {Lime}Direct Lime{}`n"
    . "7. Safe literal: {non_color_braces} stays intact as text!"
)

rectTxt := Rectangle(30, 70, 500, 230, "0x00000000", true)
rectTxt.lineSpacing := 1.45
rectTxt.Text(showcaseText, "0xFFD8D8E0", 11.5, "Segoe UI", "Regular").Left().Top()

Rectangle(30, 310, 500, 25, "0x00000000", true)
    .Text("Press Escape to exit", "0xFF72707E", 9.5, "Segoe UI", "Regular", 5, "center", "middle")

Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())
