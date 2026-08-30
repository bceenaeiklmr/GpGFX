; Script:    EmojiShowcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; Standalone Emoji & Unicode Visual Inspector
; Extra-large glyphs for visual feedback on emoji rendering

cardW := 800, cardH := 560
cardX := (A_ScreenWidth - cardW) // 2
cardY := (A_ScreenHeight - cardH) // 2

lyr := Layer(cardX, cardY, cardW, cardH, "EmojiInspector")

; 1. Dark Background Card
RoundedRectangle(0, 0, cardW, cardH, 18, "0xF0181824", true)
RoundedRectangle(0, 0, cardW, cardH, 18, "0xFF78DCE8", false)

; 2. Header
Text(30, 20, cardW - 60, 35, "{#78DCE8}GpGFX{} Emoji & Unicode Visual Inspector", "0xFFFFFFFF", 16, "Segoe UI", "Bold").Left()
Text(30, 55, cardW - 60, 20, "Testing GDI+ glyph rendering across fonts and sizes", "0xFFA0A0B0", 10, "Segoe UI", "Regular").Left()

; 3. Section 1: Extra Large Emojis (64pt) in Segoe UI Emoji
RoundedRectangle(30, 85, cardW - 60, 110, 10, "0x40000000", true)
Text(45, 95, cardW - 90, 25, "1. Segoe UI Emoji (Size 52pt):", "0xFFFFD866", 11, "Segoe UI", "Bold").Left()
Text(45, 120, cardW - 90, 70, "⚡ 🎨 🚀 💻 🎮 💾 🌟 💡", "0xFFFFFFFF", 42, "Segoe UI Emoji", "Regular").Left()

; 4. Section 2: Standard Unicode Symbols (32pt) in Segoe UI Symbol
RoundedRectangle(30, 210, cardW - 60, 110, 10, "0x40000000", true)
Text(45, 220, cardW - 90, 25, "2. Segoe UI Symbol (Size 32pt):", "0xFFFFD866", 11, "Segoe UI", "Bold").Left()
Text(45, 250, cardW - 90, 60, "✔ ✖ ➜ ⚙ 🔒 🔔 📁 📈 ☕ ⚡", "0xFF78DCE8", 28, "Segoe UI Symbol", "Regular").Left()

; 5. Section 3: Mixed Rich Text with Emojis & Colors
RoundedRectangle(30, 335, cardW - 60, 110, 10, "0x40000000", true)
Text(45, 345, cardW - 90, 25, "3. Mixed Rich Text with Formatting:", "0xFFFFD866", 11, "Segoe UI", "Bold").Left()
Text(45, 375, cardW - 90, 60, "{#FF6188, b}⚡ Power{} • {#A9DC76, b}✔ Online{} • {#78DCE8, b}🚀 Speed: 120 FPS{} • {#AB9DF2, b}🎨 Theme{}", "0xFFFCFCFA", 16, "Segoe UI Emoji", "Regular").Left()

; 6. Section 4: Individual Standalone Shapes
Text(45, 465, 350, 40, "4. Interactive Hover:", "0xFFFFD866", 11, "Segoe UI", "Bold").Left()
btnBg := RoundedRectangle(45, 495, 200, 45, 8, "0xFF2D2A3E", true)
btnTx := Text(45, 495, 200, 45, "Click Me", "0xFFFFD866", 12, "Segoe UI Emoji", "Bold").Center()

btnBg.OnEvent("MouseEnter", (*) => (btnBg.colour := "0xFF403C58", Draw(lyr)))
btnBg.OnEvent("MouseLeave", (*) => (btnBg.colour := "0xFF2D2A3E", Draw(lyr)))
btnTx.OnEvent("MouseEnter", (*) => (btnBg.colour := "0xFF403C58", Draw(lyr)))
btnTx.OnEvent("MouseLeave", (*) => (btnBg.colour := "0xFF2D2A3E", Draw(lyr)))

btnTx.OnEvent("Click", (*) => (
    btnTx.str := "✨ ✨  Click'd   🌟 🌟",
    btnBg.colour := "0xff2a6944",
    Draw(lyr),
    SetTimer(() => (btnTx.str := "Click Me", btnBg.colour := "0xFF2D2A3E", Draw(lyr)), -1500)
))

; Footer
Text(cardW - 250, 510, 220, 30, "Press Esc to Close", "0xFF707080", 10, "Segoe UI", "Regular").Right()

Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())
