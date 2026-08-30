; Script:    visual_font_hints.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../../GpGFX.ahk

; Create a test layer showing all TextRenderingHint modes for default Segoe UI 10
lyr := Layer(600, 400)
Rectangle(0, 0, 600, 400, "0xEE1E1E2E", true) ; dark card background

hints := [
    [0, "Hint 0 (SystemDefault): The quick brown fox jumps over the lazy dog. 1234567890"],
    [1, "Hint 1 (SingleBitGridFit): The quick brown fox jumps over the lazy dog. 1234567890"],
    [3, "Hint 3 (AntiAliasGridFit): The quick brown fox jumps over the lazy dog. 1234567890"],
    [4, "Hint 4 (AntiAlias): The quick brown fox jumps over the lazy dog. 1234567890"],
    [5, "Hint 5 (ClearTypeGridFit): The quick brown fox jumps over the lazy dog. 1234567890"]
]

y := 20
for item in hints {
    hVal := item[1]
    hText := item[2]
    
    r := Rectangle(20, y, 560, 45, "0x00000000", true)
    r.Font := Font("Segoe UI", 10, "Regular", "White", hVal)
    r.strQ := hVal
    r.str := hText
    y += 70
}

Draw(lyr)
Sleep(5000)
