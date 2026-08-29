; Script     NewFeatures_Showcase.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#include %A_LineFile%\..\..\..\GpGFX.ahk

/**
 * GpGFX New Core Features Interactive Showcase
 * Tests and demonstrates:
 * 1. HSL <-> ARGB conversions & Color.Mix linear blending
 * 2. IStream In-Memory Bitmaps (Zero Disk I/O)
 * 3. LockBits & RAM PixelSearch
 * 4. High-Precision Time & Animation Easing
 * 5. System Font Enumeration & Per-Monitor DPI
 * 6. Native Custom WindowClass & Non-Blocking Draggable Layer
 */

Main()

Main() {
    winW := 680
    winH := 520
    lyr := Layer(winW, winH, "NewFeaturesShowcase")
    lyr.Draggable := true

    fontCount := Font.GetInstalledFonts().Length

    ; 1. Generate an In-Memory Bitmap using IStream
    srcBmp := GdipBitmap(80, 80)
    loop 80 {
        x := A_Index - 1
        loop 80 {
            y := A_Index - 1
            c := Color.FromHSL((x / 80.0) * 360.0, 0.9, (y / 80.0) * 0.7 + 0.15)
            srcBmp.SetPixel(x, y, c)
        }
    }
    ; Plant target pixel
    targetClr := "0xFFFF0055"
    srcBmp.SetPixel(42, 35, targetClr)

    ; Encode to PNG in RAM (Zero Disk I/O!)
    pngMemoryBuffer := srcBmp.ToMemory("PNG")
    ; Decode back from RAM memory buffer
    memBmp := GdipBitmap.FromMemory(pngMemoryBuffer)

    ; Perform high-speed RAM PixelSearch
    tSearchStart := Time.Now()
    searchResult := memBmp.PixelSearch(targetClr)
    searchMs := Time.Since(tSearchStart)

    ; Construct UI Shapes ONCE (Retained Mode Architecture)

    ; Window Backdrop & Border
    bg := RoundedRectangle(0, 0, winW, winH, 16, "0xEE1E1D22", true)
    border := RoundedRectangle(0, 0, winW, winH, 16, "0x33FFFFFF", false)

    ; Header Bar
    headerBg := RoundedRectangle(0, 0, winW, 55, 16, "0xFF27252C", true)
    titleTxt := Rectangle(25, 15, 380, 25, "0x00000000", true)
        .Text("GpGFX Core Features Showcase", "0xFFFFFFFF", 13, "Segoe UI", "Bold", 5, "left", "middle")
    dpiTxt := Rectangle(420, 18, 230, 20, "0x00000000", true)
        .Text(Format("DPI: {} ({:.2f}x) | Fonts: {}", lyr.Dpi, lyr.DpiScale, fontCount), "0xFF78DCE8", 9.5, "Segoe UI", "", 5, "right", "middle")

    ; Section 1: HSL & Color Mixing
    sec1Bg := RoundedRectangle(20, 70, 310, 190, 10, "0xFF25232A", true)
    sec1Border := RoundedRectangle(20, 70, 310, 190, 10, "0x22FFFFFF", false)
    sec1Title := Rectangle(35, 78, 280, 20, "0x00000000", true)
        .Text("1. HSL & Color.Mix (Linear Blending)", "0xFFFFD866", 10.5, "Segoe UI", "Bold", 5, "left", "middle")

    ; 10 HSL Animated Palette Stripes
    stripes := []
    loop 10 {
        s := Rectangle(35 + (A_Index - 1) * 27, 105, 25, 28, "0xFFFFFFFF", true)
        stripes.Push(s)
    }

    ; Color.Mix Interpolation Bar
    mixTrack := RoundedRectangle(35, 145, 270, 22, 6, "0xFF18171C", true)
    mixFill := RoundedRectangle(37, 147, 130, 18, 5, "0xFFFF6188", true)
    mixLabel := Rectangle(35, 175, 280, 20, "0x00000000", true)
        .Text("Color.Mix(Pink, Cyan, 0.50)", "0xFFA9DC76", 8.5, "Segoe UI", "", 5, "left", "middle")
    mixSub := Rectangle(35, 195, 280, 20, "0x00000000", true)
        .Text("Pure RGB linear interpolation in RAM", "0xFF72707D", 8, "Segoe UI", "", 5, "left", "middle")

    ; Section 2: IStream & RAM PixelSearch
    sec2Bg := RoundedRectangle(350, 70, 310, 190, 10, "0xFF25232A", true)
    sec2Border := RoundedRectangle(350, 70, 310, 190, 10, "0x22FFFFFF", false)
    sec2Title := Rectangle(365, 78, 280, 20, "0x00000000", true)
        .Text("2. IStream & RAM PixelSearch", "0xFFA9DC76", 10.5, "Segoe UI", "Bold", 5, "left", "middle")

    ; Display memory-decoded bitmap
    bmpBox := Rectangle(365, 105, 75, 75, "0x00000000", true)
    bmpBox.AddImage(memBmp, 75)
    bmpBorder := RoundedRectangle(365, 105, 75, 75, 4, "0x44FFFFFF", false)

    ; Target Crosshair
    if (searchResult && searchResult.x > 0) {
        targetScreenX := 365 + Round(searchResult.x * (75 / 80))
        targetScreenY := 105 + Round(searchResult.y * (75 / 80))
        targetDot := Ellipse(targetScreenX - 5, targetScreenY - 5, 10, 10, "0xFFFF0055", true)
        targetRing := Ellipse(targetScreenX - 7, targetScreenY - 7, 14, 14, "0xFFFFFFFF", false)
    }

    txtStream := Rectangle(450, 105, 200, 16, "0x00000000", true)
        .Text("Encoded: ToMemory('PNG')", "0xFFFC9867", 9, "Segoe UI", "Bold", 5, "left", "middle")
    txtSize := Rectangle(450, 122, 200, 16, "0x00000000", true)
        .Text(Format("Stream Size: {} bytes (0 disk I/O)", pngMemoryBuffer.size), "0xFF908E9D", 8, "Segoe UI", "", 5, "left", "middle")
    txtSearch := Rectangle(450, 142, 200, 16, "0x00000000", true)
        .Text(Format("PixelSearch: Found ({}, {})", searchResult.x, searchResult.y), "0xFFFF6188", 9, "Segoe UI", "Bold", 5, "left", "middle")
    txtLat := Rectangle(450, 160, 200, 16, "0x00000000", true)
        .Text(Format("Search Latency: {:.3f} ms in RAM", searchMs), "0xFFA9DC76", 8, "Segoe UI", "", 5, "left", "middle")

    ; Section 3: Time.Ease Animation
    sec3Bg := RoundedRectangle(20, 280, 310, 215, 10, "0xFF25232A", true)
    sec3Border := RoundedRectangle(20, 280, 310, 215, 10, "0x22FFFFFF", false)
    sec3Title := Rectangle(35, 288, 280, 20, "0x00000000", true)
        .Text("3. Time.Ease (High-Precision Timing)", "0xFF78DCE8", 10.5, "Segoe UI", "Bold", 5, "left", "middle")

    ; Track Labels & Bars
    lblLin := Rectangle(35, 320, 75, 16, "0x00000000", true).Text("Linear:", "0xFF72707D", 8, "Segoe UI", "", 5, "left", "middle")
    trkLin := RoundedRectangle(95, 323, 210, 8, 4, "0xFF18171C", true)
    sphLin := Ellipse(95, 319, 16, 16, "0xFF72707D", true)

    lblQuad := Rectangle(35, 350, 75, 16, "0x00000000", true).Text("InOutQuad:", "0xFFFFD866", 8, "Segoe UI", "", 5, "left", "middle")
    trkQuad := RoundedRectangle(95, 353, 210, 8, 4, "0xFF18171C", true)
    sphQuad := Ellipse(95, 349, 16, 16, "0xFFFFD866", true)

    lblCubic := Rectangle(35, 380, 75, 16, "0x00000000", true).Text("OutCubic:", "0xFFAB9DF2", 8, "Segoe UI", "", 5, "left", "middle")
    trkCubic := RoundedRectangle(95, 383, 210, 8, 4, "0xFF18171C", true)
    sphCubic := Ellipse(95, 379, 16, 16, "0xFFAB9DF2", true)

    lblSmooth := Rectangle(35, 410, 75, 16, "0x00000000", true).Text("SmoothStep:", "0xFF78DCE8", 8, "Segoe UI", "", 5, "left", "middle")
    trkSmooth := RoundedRectangle(95, 413, 210, 8, 4, "0xFF18171C", true)
    sphSmooth := Ellipse(95, 409, 16, 16, "0xFF78DCE8", true)

    txtQpc := Rectangle(35, 445, 280, 16, "0x00000000", true)
        .Text("QPC microsecond precision delta timing", "0xFF72707D", 8, "Segoe UI", "", 5, "left", "middle")

    ; Section 4: System DPI & Controls
    sec4Bg := RoundedRectangle(350, 280, 310, 215, 10, "0xFF25232A", true)
    sec4Border := RoundedRectangle(350, 280, 310, 215, 10, "0x22FFFFFF", false)
    sec4Title := Rectangle(365, 288, 280, 20, "0x00000000", true)
        .Text("4. Native WindowClass & Controls", "0xFFAB9DF2", 10.5, "Segoe UI", "Bold", 5, "left", "middle")

    txtArch := Rectangle(365, 325, 280, 20, "0x00000000", true)
        .Text("iseahound WindowClass Architecture", "0xFFFC9867", 9, "Segoe UI", "Bold", 5, "left", "middle")
    txtSubArch := Rectangle(365, 345, 280, 35, "0x00000000", true)
        .Text("0 ns Object binding via GetWindowLongPtr.`nDirect Win32 WindowProc message dispatch.", "0xFF908E9D", 8, "Segoe UI", "", 5, "left", "top")

    txtDpiVal := Rectangle(365, 395, 280, 20, "0x00000000", true)
        .Text(Format("Per-Monitor V2 DPI: {} dpi ({:.1f}x)", lyr.Dpi, lyr.DpiScale), "0xFFFFD866", 9, "Segoe UI", "Bold", 5, "left", "middle")
    txtFontVal := Rectangle(365, 415, 280, 20, "0x00000000", true)
        .Text(Format("System Fonts Enumerated: {} fonts", fontCount), "0xFF78DCE8", 8.5, "Segoe UI", "", 5, "left", "middle")

    txtDrag := Rectangle(365, 455, 280, 20, "0x00000000", true)
        .Text("Drag anywhere to move (0% CPU)", "0xFFA9DC76", 9, "Segoe UI", "Bold", 5, "center", "middle")

    ; Initial Draw
    Draw(lyr)

    ; 60 FPS Animation Update (Pure Property Mutation)
    animT := 0.0
    SetTimer(UpdateAnimation, 16)

    UpdateAnimation() {
        animT += 0.025
        if (animT > 6.28318)
            animT -= 6.28318

        ; 1. Update HSL palette stripes
        loop 10 {
            stripeHue := Mod(A_Index * 36.0 + (animT * 50.0), 360.0)
            stripes[A_Index].Color := Color.FromHSL(stripeHue, 0.85, 0.55)
        }

        ; 2. Update Color.Mix bar
        mixWeight := (Sin(animT * 2.0) + 1.0) / 2.0
        activeMixClr := Color.Mix("0xFFFF6188", "0xFF78DCE8", mixWeight)
        mixFill.w := Max(10, Round(266 * mixWeight))
        mixFill.Color := activeMixClr
        mixLabel.Text(Format("Color.Mix(Pink, Cyan, {:.2f}) -> 0x{:08X}", mixWeight, activeMixClr), "0xFFA9DC76", 8.5, "Segoe UI", "", 5, "left", "middle")

        ; 3. Update Eased Spheres
        rawT := Mod(animT * 0.7, 2.0)
        normT := (rawT > 1.0) ? (2.0 - rawT) : rawT

        easedQuad := Time.Ease.InOutQuad(normT)
        easedCubic := Time.Ease.OutCubic(normT)
        easedSmooth := Time.Ease.SmoothStep(normT)

        sphLin.x := 95 + Round(194 * normT)
        sphQuad.x := 95 + Round(194 * easedQuad)
        sphCubic.x := 95 + Round(194 * easedCubic)
        sphSmooth.x := 95 + Round(194 * easedSmooth)

        ; Single high-speed frame rasterization
        Draw(lyr)
    }

    ; Close on Escape key
    HotKey("Escape", (*) => ExitApp())
}
