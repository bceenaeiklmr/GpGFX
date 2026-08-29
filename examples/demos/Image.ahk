; Script     Image.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#include ../../GpGFX.ahk

/**
 * Image Demonstration: Procedural in-memory bitmap generation,
 * shape texture embedding, and animated layered window movement.
 */

; Create a centered layer
w := 500, h := 380
lyr := Layer(w, h).Center()
lyr.draggable := true

; Card backdrop
RoundedRectangle(w, h, 16, "0xEE1E1E2E")
RoundedRectangle(w, h, 16, "0x4089B4FA", false)

Text(20, 20, w - 40, 26, "Procedural Bitmap & Texture Embedding", "0xFFCDD6F4", 13, "Segoe UI", "Bold").Center()
Text(20, 48, w - 40, 18, "Catppuccin Blue -> Pink Diagonal Gradient Surface", "0xFFBAC2DE", 9.5, "Segoe UI").Center()

; Create a procedural in-memory bitmap with a diagonal gradient
size := 200
bmp := GdipBitmap(size, size)
bd := bmp.LockBits(0, 0, size, size, 0x26200A, 2)
if (bd) {
    pScan0 := bd.Scan0
    stride := bd.Stride
    clr1 := 0xFF89B4FA  ; Catppuccin Blue
    clr2 := 0xFFF38BA8  ; Catppuccin Pink
    a1 := (clr1 >> 24) & 0xFF, r1 := (clr1 >> 16) & 0xFF, g1 := (clr1 >> 8) & 0xFF, b1 := clr1 & 0xFF
    a2 := (clr2 >> 24) & 0xFF, r2 := (clr2 >> 16) & 0xFF, g2 := (clr2 >> 8) & 0xFF, b2 := clr2 & 0xFF

    loop size {
        y := A_Index - 1
        rowPtr := pScan0 + y * stride
        loop size {
            x := A_Index - 1
            weight := (x + y) / (size * 2)
            invW := 1.0 - weight
            a := Round(a1 * invW + a2 * weight)
            r := Round(r1 * invW + r2 * weight)
            g := Round(g1 * invW + g2 * weight)
            b := Round(b1 * invW + b2 * weight)
            NumPut("uint", (a << 24) | (r << 16) | (g << 8) | b, rowPtr, x * 4)
        }
    }
    bmp.UnlockBits(bd)
}

; Shape displaying the embedded bitmap
sq := RoundedRectangle((w - size) // 2, 80, size, size, 12, "0x00000000", true)
sq.AddImage(bmp)
RoundedRectangle((w - size) // 2, 80, size, size, 12, "0x50FCFCFA", false)

Text(20, 310, w - 40, 20, "Click and drag anywhere to move • Press ESC to exit", "0xFF6C7086", 9, "Segoe UI").Center()

; Draw layer
Draw(lyr)

Esc::ExitApp()

