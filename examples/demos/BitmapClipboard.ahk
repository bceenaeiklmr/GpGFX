; Script:    BitmapClipboard.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

lyr := Layer(950, 550, "Bitmap Clipboard & Clone Suite")

; Background
bg := RoundedRectangle(10, 10, 930, 530, 25, "0xFF181825", true)

; Title & Info Header
header := Rectangle(30, 25, 890, 60, "0x00000000", true)
header.Text("Bitmap Cloning, Cropping & Clipboard Demo`n[C] Copy Layer to Clipboard   |   [V] Paste from Clipboard   |   [ESC] Exit", "White", 12, "Segoe UI", "Bold", 5, "center", "middle")

; 1. Generate an original colorful target Bitmap
origBmp := GdipBitmap(180, 180)
loop 180 {
    y := A_Index - 1
    loop 180 {
        x := A_Index - 1
        ; Concentric color rings
        dist := Sqrt((x - 90)**2 + (y - 90)**2)
        r := Integer(128 + 127 * Sin(dist / 10.0))
        g := Integer(128 + 127 * Cos(dist / 15.0))
        b := Integer(128 + 127 * Sin((x + y) / 25.0))
        origBmp.SetPixel(x, y, (0xFF << 24) | (r << 16) | (g << 8) | b)
    }
}

; 2. Clone the Bitmap
clonedBmp := origBmp.Clone()

; 3. Crop center sub-region (60x60 out of 180x180)
croppedBmp := origBmp.Crop(60, 60, 60, 60)

; Card 1: Original
card1 := RoundedRectangle(30, 90, 200, 260, 15, "0xFF252538", true)
lbl1 := Rectangle(30, 100, 200, 30, "0x00000000", true)
lbl1.Text("1. Original (180x180)", "Cyan", 10, "Segoe UI", "Bold", 5, "center", "middle")
box1 := RoundedRectangle(40, 140, 180, 180, 10, "Black", true)
box1.AddImage(origBmp)

; Card 2: Clone
card2 := RoundedRectangle(250, 90, 200, 260, 15, "0xFF252538", true)
lbl2 := Rectangle(250, 100, 200, 30, "0x00000000", true)
lbl2.Text("2. Cloned (Clone())", "LightGreen", 10, "Segoe UI", "Bold", 5, "center", "middle")
box2 := RoundedRectangle(260, 140, 180, 180, 10, "Black", true)
box2.AddImage(clonedBmp)

; Card 3: Crop
card3 := RoundedRectangle(470, 90, 200, 260, 15, "0xFF252538", true)
lbl3 := Rectangle(470, 100, 200, 30, "0x00000000", true)
lbl3.Text("3. Cropped (60x60 Center)", "Gold", 10, "Segoe UI", "Bold", 5, "center", "middle")
box3 := RoundedRectangle(480, 140, 180, 180, 10, "Black", true)
box3.AddImage(croppedBmp)

; Card 4: Clipboard Slot
card4 := RoundedRectangle(690, 90, 230, 260, 15, "0xFF252538", true)
lbl4 := Rectangle(690, 100, 230, 30, "0x00000000", true)
lbl4.Text("4. Clipboard Slot [V]", "Magenta", 10, "Segoe UI", "Bold", 5, "center", "middle")
box4 := RoundedRectangle(705, 140, 200, 180, 10, "Black", true)
box4Text := Rectangle(705, 140, 200, 180, "0x00000000", true)
box4Text.Text("Copy an image (Ctrl+C`nor Win+Shift+S)`nthen press [V] to paste!", "Gray", 10, "Segoe UI", "", 5, "center", "middle")

; Bottom Status Banner
statusBanner := RoundedRectangle(30, 370, 890, 140, 15, "0xFF1F1F30", true)
statusText := Rectangle(50, 385, 850, 110, "0x00000000", true)
statusText.Text("Status: Ready.`n`n* Press [C] to copy this entire rendered window to the Windows Clipboard.`n* Press [V] to paste any copied image into Card 4.`n* Press [ESC] to close this window.", "White", 11, "Segoe UI", "", 5, "left", "top")

Draw(lyr)

; [C] Hotkey - Copy entire layer to Clipboard
~c::
{
    if (lyr.ToClipboard()) {
        statusText.str := "Status: [SUCCESS] Layer copied to Windows Clipboard as CF_DIB!`nYou can now paste (Ctrl+V) into Paint, Discord, Photoshop, etc.`n`nPress [ESC] to exit."
        Draw(lyr)
    }
}

; [V] Hotkey - Paste from Clipboard into Card 4
~v::
{
    clipBmp := GdipBitmap.FromClipboard()
    if (clipBmp) {
        box4Text.str := ""
        box4.AddImage(clipBmp)
        statusText.str := "Status: [SUCCESS] Image successfully retrieved from Windows Clipboard (" clipBmp.w "x" clipBmp.h ") and embedded into Card 4!`n`nPress [ESC] to exit."
        Draw(lyr)
    } else {
        statusText.str := "Status: [INFO] No image currently found on Windows Clipboard. Copy an image first (Win+Shift+S or Ctrl+C) and press [V] again."
        Draw(lyr)
    }
}

Esc::ExitApp()
