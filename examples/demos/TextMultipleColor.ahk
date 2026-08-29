; Script     TextMultipleColor.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#include ../../GpGFX.ahk

/**
 * How to use colored text.
 */

; Create a layer
lyr := Layer(2560, 1440)

; Create a rectangle
rect := Rectangle(0, 0, 2560, 1440, "20000000")

; Use {color:colorname} to change the color of the text within a string
str := "{color:red}Hello`nW{color:lime}orld!"
rect.Text(str, , 192)
rect.strQ := 4

lyr.Draw()
Sleep(500)

; You can shorten the color tag to {c:colorname} as well
str := "{c:red}He{c:yellow}llo, {c:lime}World!"
rect.str := str
lyr.Draw()
Sleep(500)

; Let's create random colored text just adding curly brackets with the color name or ARGB value
str := "Hello`nworld!"
rect.str := ""
loop parse, str {
    rect.str .= "{" . Color.Random("Red|Yellow|Violet|Blue|Lime") . "}" . A_LoopField
}
lyr.Draw()
Sleep(500)

End()
