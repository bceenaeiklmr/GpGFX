; Script     BitmapToASCII.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025

#include ../GpGFX.ahk

/**
 * A simple example of converting a bitmap to ASCII string and displaying it.
 * @example: how to use GdipBitmapLockBits
 */

; Create a FHD layer
lyr := Layer(1920, 1080)

; Create a rectangle with an image and text
rect := Rectangle(0, 0, 200, 200)
rect.AddImage(A_ScriptDir "\pic\texture.png", 400, "Grayscale")
rect.str := "{color:red}Hello, {color:lime}World!"

; Draw the layer once
lyr.Draw()
Sleep(1000)

; Create a new layer with a background
lyr2 := Layer(1920, 1080)
txt := Rectangle(0, 0, 1920, 1080, "black")

; Create a rectangle that specifies the area of the image to lock
RectI := Buffer(16, 0)
NumPut("UInt", rect.imageWidth, RectI, 8)
NumPut("UInt", rect.imageHeight, RectI, 12)

; Create a buffer to hold the bitmap data and lock the bits
BitmapData := Buffer(16+2*A_PtrSize, 0)
DllCall("Gdiplus\GdipBitmapLockBits", "ptr", rect.pBitmap, "ptr", RectI, "uint", 3, "int", 0x26200a, "ptr", BitmapData)

; Get the Stride and Scan0 from the bitmap data
Stride := NumGet(BitmapData, 8, "int")
Scan0 := NumGet(BitmapData, 16, "ptr")

; Find the top, left, bottom, and right edges of the image
VarSetStrCapacity(&strg, rect.imageWidth * rect.imageHeight * 2)

loop rect.imageHeight {
    y := A_Index - 1
    loop rect.imageWidth {

        ARGB := NumGet(Scan0+0, (A_Index-1)*4 + y*Stride, "uint")
        
        ; Extract the grayscale intensity (R, G, and B are the same in grayscale mode)
        ; B, G, R same
        gray := (ARGB & 0xFF)

        ; Map the grayscale intensity (0-255) to the range of the array (1-10)
        index := Max(1, Ceil(gray / 25.5))

        ; Get the corresponding character from the array and double it to fill the space
        char := getCharacterFromGrayScale(index)
        strg .= char . char
    }
    strg .= "`n"
}

; Unlock the bits
DllCall("Gdiplus\GdipBitmapUnlockBits", "UPtr", rect.pBitmap, "UPtr", BitmapData.Ptr)

;A_Clipboard := strg
txt.Text(SubStr(strg, 1, -1), "White", 7, "Consolas")

; Draw the ASCII art
lyr2.Draw()
Sleep(3000)

End()


getCharacterFromGrayScale(index) {
    static chrs := [" ", ".", ",", ":", "-", "=", "+", "*", "#", "@"]
    if (index < 1 || index > 10)
        return chrs[1]
    return chrs[index]
}
