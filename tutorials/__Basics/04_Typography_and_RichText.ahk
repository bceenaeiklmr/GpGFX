; Script:    04_Typography_and_RichText.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

; Example:    04_Typography_and_RichText.ahk
; Description: Demonstrates rich-text inline markup, paragraph word wrapping, and multi-column tab stops.
; Requirement: AutoHotkey v2

#Requires AutoHotkey v2
#include ..\..\GpGFX.ahk

; Create canvas window
lyr := Layer(740, 520).Center()
RoundedRectangle(740, 520, 14, "0xFF1E1E2E")

; 1. Header with Font Styling
Text(25, 20, 690, 30, "GpGFX Typography & Rich-Text Layout", "0xFFCDD6F4", 15, "Segoe UI", "Bold").Left()

; 2. Inline Color Tags & Formatting Styles
; Tags: {#HEX}, {ColorName}, <b>Bold</b>, <i>Italic</i>, <u>Underline</u>, <s>Strike</s>, <reset>
Text(25, 65, 690, 20, "1. Inline Color & Formatting Tags", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

card1 := RoundedRectangle(25, 90, 690, 75, 8, "0xFF252538")
richStr := "System Status: {#A6E3A1}<b>ONLINE</b>{reset}  |  " .
           "CPU: {#89B4FA}<b>14.2%</b>{reset}  |  " .
           "RAM: {#F38BA8}<b>6.4 / 16 GB</b>{reset}`n" .
           "Styles: <b>Bold</b>, <i>Italic</i>, <u>Underline</u>, <s>Strikeout</s>, {#FAB387}<b><i>Combined Style</i></b>"
Text(40, 105, 660, 50, richStr, "0xFFCDD6F4", 10, "Segoe UI").Left()

; 3. Automatic Multi-Column Tab Grid Alignment (\t)
; Tab characters `\t` dynamically compute column widths for perfectly aligned HUD tables!
Text(25, 185, 690, 20, "2. Tabulated Multi-Column Grid Alignment (Tabs: \t)", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

card2 := RoundedRectangle(25, 210, 690, 110, 8, "0xFF252538")
tableStr := "<b>PROCESS`tPID`tCPU`tMEMORY`tSTATUS</b>`n" .
            "AutoHotkey64.exe`t4188`t0.2%`t14.2 MB`t{#A6E3A1}Active{reset}`n" .
            "GpGFX_Worker_1.exe`t8920`t3.8%`t28.4 MB`t{#89B4FA}Rendering{reset}`n" .
            "GpGFX_Worker_2.exe`t8924`t4.1%`t27.9 MB`t{#89B4FA}Rendering{reset}"
Text(40, 222, 660, 90, tableStr, "0xFFBAC2DE", 10, "Consolas").Left()

; 4. Automatic Paragraph Word-Wrapping
; Text automatically wraps at word boundaries to fit the shape width (e.g. 660px)
Text(25, 340, 690, 20, "3. Automatic Paragraph Word-Wrapping", "0xFFA6ADC8", 10, "Segoe UI", "Bold").Left()

card3 := RoundedRectangle(25, 365, 690, 90, 8, "0xFF252538")
wrapStr := "GpGFX includes a pure-math typographic word-wrapping engine that formats multiline " .
           "paragraphs without making slow GDI+ calls during render loops. It supports custom line " .
           "heights, character measurement for custom carets, and seamless window scaling."
Text(40, 380, 660, 65, wrapStr, "0xFFCDD6F4", 10, "Segoe UI").Left()

; Footer
Text(25, 480, 690, 25, "Press ESC to exit • Click and drag window to move", "0xFF6C7086", 10).Center()
lyr.Drag().Draw()

Esc::ExitApp()
