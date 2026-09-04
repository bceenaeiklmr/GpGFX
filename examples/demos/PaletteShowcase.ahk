; Script:    PaletteShowcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include ../../GpGFX.ahk

; Curated theme registry
themes := [
    { name: "Catppuccin", obj: Palette.Catppuccin, desc: "Soothing pastel theme for high productivity" },
    { name: "Nord",       obj: Palette.Nord,       desc: "Arctic, north-bluish clean color palette" },
    { name: "Gruvbox",    obj: Palette.Gruvbox,    desc: "Retro groove warm color scheme" },
    { name: "TokyoNight", obj: Palette.TokyoNight, desc: "Clean dark theme celebrating downtown Tokyo neon" },
    { name: "Dracula",    obj: Palette.Dracula,    desc: "Famous dark theme with vibrant gothic accents" },
    { name: "Solarized",  obj: Palette.Solarized,  desc: "Precision-engineered solarized dark palette" },
    { name: "Cyberpunk",  obj: Palette.Cyberpunk,  desc: "High-contrast electric neon aesthetics" },
    { name: "Monokai",    obj: Palette.Monokai,    desc: "Classic vibrant developer palette" }
]

global currentThemeIdx := 1

winW := 820
winH := 660

lyr := Layer((A_ScreenWidth - winW) // 2, (A_ScreenHeight - winH) // 2, winW, winH, "GpGFX Palette Engine Showcase")
lyr.draggable := true

; Background card
bgCard := RoundedRectangle(10, 10, winW - 20, winH - 20, 18, "0xFF181825", true)
bgBorder := RoundedRectangle(10, 10, winW - 20, winH - 20, 18, "0x33FFFFFF", false)

; Header title
titleText := Text(35, 26, 500, 28, "GpGFX PALETTE ENGINE", "0xFFFFFFFF", 14, "Segoe UI", "Bold")
subtitleText := Text(35, 54, 700, 20, "Theme Explorer | Press [1-8] or [Space] to switch themes | [Esc] Exit", "0xFF888899", 9.5, "Segoe UI")

; Current theme banner card
bannerCard := RoundedRectangle(35, 84, winW - 70, 75, 12, "0xFF222230", true)
themeTitle := Text(55, 96, 400, 26, "Catppuccin Mocha", "0xFFFFFFFF", 13, "Segoe UI", "Bold")
themeDesc := Text(55, 124, 700, 20, "Soothing pastel theme for high productivity", "0xFFAAAAAA", 9.5, "Segoe UI")

; Section 1: Semantic Roles
roleHeader := Text(35, 175, 400, 20, "SEMANTIC COLOR ROLES", "0xFFCCCCCC", 10, "Segoe UI", "Bold")

semanticChips := []
semanticLabels := [
    { key: "bg",        label: "Background" },
    { key: "surface",   label: "Surface" },
    { key: "primary",   label: "Primary" },
    { key: "secondary", label: "Secondary" },
    { key: "accent",    label: "Accent" },
    { key: "highlight", label: "Highlight" }
]

chipX := 35
chipW := 115
chipH := 46
chipGap := 12

for item in semanticLabels {
    chipBg := RoundedRectangle(chipX, 200, chipW, chipH, 8, "0xFF333344", true)
    chipBorder := RoundedRectangle(chipX, 200, chipW, chipH, 8, "0x44FFFFFF", false)
    chipRole := Text(chipX + 8, 206, chipW - 16, 16, item.label, "0xFFFFFFFF", 8.5, "Segoe UI", "Bold")
    chipHex := Text(chipX + 8, 224, chipW - 16, 16, "#000000", "0xFFCCCCCC", 8.0, "Consolas")
    semanticChips.Push({ bg: chipBg, border: chipBorder, roleText: chipRole, hexText: chipHex, key: item.key })
    chipX += chipW + chipGap
}

; Section 2: Continuous Gradient LUT (Sampled from pal.Sample(t))
lutHeader := Text(35, 262, 500, 20, "CONTINUOUS GRADIENT LOOKUP TABLE (pal.Sample(t))", "0xFFCCCCCC", 10, "Segoe UI", "Bold")
lutSteps := 100
lutBars := []
lutStartX := 35
lutY := 288
lutW := winW - 70
lutH := 20
lutStepW := lutW / Float(lutSteps)

loop lutSteps {
    idx := A_Index - 1
    barX := lutStartX + Round(idx * lutStepW)
    bar := Rectangle(barX, lutY, Ceil(lutStepW) + 1, lutH, "0xFF888888", true)
    lutBars.Push(bar)
}
lutBorder := RoundedRectangle(lutStartX, lutY, lutW, lutH, 4, "0x33FFFFFF", false)

; Section 3: Live Themed UI Component Mockup
uiHeader := Text(35, 326, 500, 20, "LIVE THEMED UI COMPONENTS", "0xFFCCCCCC", 10, "Segoe UI", "Bold")

; Mock Card 1: Themed Dialog Box
mockCard := RoundedRectangle(35, 352, 360, 220, 14, "0xFF222230", true)
mockBorder := RoundedRectangle(35, 352, 360, 220, 14, "0x33FFFFFF", false)
mockCardTitle := Text(55, 370, 320, 24, "System Performance", "0xFFFFFFFF", 11, "Segoe UI", "Bold")
mockCardBody := Text(55, 398, 320, 36, "Hardware acceleration enabled.`nLatency is optimal across all layers.", "0xFFAAAAAA", 9.0, "Segoe UI")

; Themed Progress Bar
mockProgBg := RoundedRectangle(55, 446, 320, 16, 8, "0xFF181825", true)
mockProgFill := RoundedRectangle(55, 446, 220, 16, 8, "0xFF8888FF", true)

; Themed Action Buttons
mockBtnPrimary := RoundedRectangle(55, 482, 150, 36, 8, "0xFF8888FF", true)
mockBtnPrimaryText := Text(55, 482, 150, 36, "Primary Action", "0xFFFFFFFF", 9.5, "Segoe UI", "Bold").Center().Middle()

mockBtnSecondary := RoundedRectangle(220, 482, 155, 36, 8, "0xFF333344", true)
mockBtnSecondaryBorder := RoundedRectangle(220, 482, 155, 36, 8, "0x44FFFFFF", false)
mockBtnSecondaryText := Text(220, 482, 155, 36, "Secondary Action", "0xFFFFFFFF", 9.5, "Segoe UI").Center().Middle()

; Mock Card 2: Palette Swatches Grid
swatchCard := RoundedRectangle(415, 352, 370, 220, 14, "0xFF222230", true)
swatchBorder := RoundedRectangle(415, 352, 370, 220, 14, "0x33FFFFFF", false)
swatchCardTitle := Text(435, 370, 330, 24, "Swatches (pal[1..N])", "0xFFFFFFFF", 11, "Segoe UI", "Bold")

swatchChips := []
sRow := 0, sCol := 0
loop 8 {
    sIndex := A_Index
    sX := 435 + (sCol * 85)
    sY := 405 + (sRow * 68)
    sChip := RoundedRectangle(sX, sY, 75, 40, 6, "0xFF444455", true)
    sText := Text(sX, sY + 44, 75, 16, "Swatch " sIndex, "0xFF888899", 7.5, "Segoe UI").Center().Top()
    swatchChips.Push({ chip: sChip, label: sText })
    sCol++
    if (sCol >= 4) {
        sCol := 0
        sRow++
    }
}

; Footer Info
footerText := Text(35, winH - 42, winW - 70, 20, "GpGFX Curated Palettes: Catppuccin [1], Nord [2], Gruvbox [3], TokyoNight [4], Dracula [5], Solarized [6], Cyberpunk [7], Monokai [8]", "0xFF777788", 8.5, "Segoe UI").Center().Middle()

; Apply initial theme
ApplyTheme(currentThemeIdx)
Draw(lyr)

ApplyTheme(idx) {
    global themes, currentThemeIdx
    local tInfo, pal, cKey, clr, hexStr, chip, bIndex, tVal, sIndex

    currentThemeIdx := idx
    tInfo := themes[idx]
    pal := tInfo.obj

    ; Update background and banner
    bgCard.color := pal.bg
    bannerCard.color := pal.surface
    themeTitle.str := tInfo.name
    themeTitle.color := pal.primary
    themeDesc.str := tInfo.desc

    ; Update semantic chips
    for chip in semanticChips {
        cKey := chip.key
        clr := pal.HasOwnProp(cKey) ? pal.%cKey% : pal.primary
        chip.bg.color := clr
        hexStr := Format("0x{:08X}", clr)
        chip.hexText.str := SubStr(hexStr, 3)

        ; Compute text contrast
        chip.roleText.color := (Color.Luminance(clr) > 0.5) ? "0xFF111118" : "0xFFFFFFFF"
        chip.hexText.color  := (Color.Luminance(clr) > 0.5) ? "0xFF222230" : "0xFFDDDDDD"
    }

    ; Update gradient LUT strip
    loop lutSteps {
        bIndex := A_Index - 1
        tVal := bIndex / Float(lutSteps - 1)
        lutBars[A_Index].color := pal.Sample(tVal)
    }

    ; Update live UI components
    mockCard.color := pal.surface
    mockCardTitle.color := pal.text
    mockProgBg.color := pal.bg
    mockProgFill.color := pal.accent
    mockBtnPrimary.color := pal.primary
    mockBtnSecondary.color := pal.surface

    swatchCard.color := pal.surface
    swatchCardTitle.color := pal.text

    ; Update swatch chips
    loop swatchChips.Length {
        sIndex := A_Index
        if (sIndex <= pal.swatches.Length) {
            swatchChips[sIndex].chip.visible := true
            swatchChips[sIndex].chip.color := pal.swatches[sIndex]
            swatchChips[sIndex].label.visible := true
            swatchChips[sIndex].label.str := SubStr(Format("0x{:06X}", pal.swatches[sIndex] & 0xFFFFFF), 3)
        } else {
            swatchChips[sIndex].chip.visible := false
            swatchChips[sIndex].label.visible := false
        }
    }
}

; Keyboard Shortcuts
1::SwitchTheme(1)
2::SwitchTheme(2)
3::SwitchTheme(3)
4::SwitchTheme(4)
5::SwitchTheme(5)
6::SwitchTheme(6)
7::SwitchTheme(7)
8::SwitchTheme(8)
Space::SwitchTheme(Mod(currentThemeIdx, themes.Length) + 1)

SwitchTheme(idx) {
    ApplyTheme(idx)
    Draw(lyr)
}

Esc::ExitApp()
