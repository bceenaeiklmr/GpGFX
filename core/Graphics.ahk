; Script:    Graphics.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

/**
 * GpGFX GDI+ Graphics Context & 32-bit DIB Surface Manager
 *
 * Creates and manages drawing contexts paired with memory bitmap backing stores:
 * - Graphics(w, h): Creates a 32-bit top-down ARGB DIBSection (hdc, hbm, pBits) with a configured GDI+ Graphics context.
 * - FromHWND(hwnd): Wraps an existing window handle in a GDI+ Graphics context.
 * - FromHDC(hdc): Wraps an existing Device Context in a GDI+ Graphics context.
 * - Disposal: Safely restores GDI objects, deletes DIBs, and frees GDI+ handles (Dispose, __Delete).
 */
class Graphics {

    /**
     * Creates a GDI+ Graphics context directly from a Window handle (HWND).
     *
     * @param {Integer} hwnd Window handle
     * @param {Integer} [useICM=0] 1 for International Color Management, 0 otherwise
     * @returns {Integer} Pointer to GDI+ Graphics handle (must be deleted via GdipDeleteGraphics)
     *
     * @example
     * pGfx := Graphics.FromHWND(myHwnd)
     * ; Draw with pGfx...
     * DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGfx)
     */
    static FromHWND(hwnd, useICM := 0) {
        local gfx := 0
        local fn := (useICM == 1) ? "GdipCreateFromHWNDICM" : "GdipCreateFromHWND"
        DllCall("gdiplus\" fn, "ptr", hwnd, "ptr*", &gfx:=0)
        return gfx
    }

    /**
     * Creates a GDI+ Graphics context directly from a Device Context handle (HDC).
     *
     * @param {Integer} hdc Device context handle
     * @param {Integer} [hDevice=0] Optional handle to an output device
     * @returns {Integer} Pointer to GDI+ Graphics handle (must be deleted via GdipDeleteGraphics)
     *
     * @example
     * pGfx := Graphics.FromHDC(myHdc)
     * ; Draw with pGfx...
     * DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGfx)
     */
    static FromHDC(hdc, hDevice := 0) {
        local gfx := 0
        if (hDevice)
            DllCall("gdiplus\GdipCreateFromHDC2", "ptr", hdc, "ptr", hDevice, "ptr*", &gfx:=0)
        else
            DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &gfx:=0)
        return gfx
    }
    
    /**
     * Creates a new Graphics object backed by a 32-bit ARGB DIBSection.
     *
     * @param {Integer} width Width of the drawing surface in pixels
     * @param {Integer} height Height of the drawing surface in pixels
     *
     * @credit iseahound - TextRender v1.9.3, RenderOnScreen (https://github.com/iseahound/TextRender)
     *
     * @example
     * ; Create an offscreen 800x600 drawing surface
     * gfxObj := Graphics(800, 600)
     * ; Access handles: gfxObj.ptr, gfxObj.hdc, gfxObj.hbm, gfxObj.pBits
     * gfxObj.Dispose()
     */
    __New(width, height) {
        local gfx := 0, bi, hdc, hbm, obm, pBits := 0

        ; Create a new memory DC and 32-bit top-down DIB section
        hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
        bi := Buffer(40, 0)                         ; sizeof(BITMAPINFOHEADER) = 40
        NumPut("uint",         40, bi,  0)          ; biSize
        NumPut("int",       width, bi,  4)          ; biWidth
        NumPut("int",     -height, bi,  8)          ; biHeight (negative = top-down DIB)
        NumPut("ushort",        1, bi, 12)          ; biPlanes
        NumPut("ushort",       32, bi, 14)          ; biBitCount = 32-bit ARGB
        hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits:=0, "ptr", 0, "uint", 0, "ptr")
        obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &gfx:=0)
        
        ; Enable smooth vector anti-aliasing and subpixel ClearType text rendering
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)        ; SmoothingModeAntiAlias (4)
        DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gfx, "int", 5)    ; TextRenderingHintClearTypeGridFit (5)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 0)      ; PixelOffsetModeDefault (0)
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7)    ; HighQualityBicubic (7)

        ; Store values as direct primitive fields for instant access
        this.hdc   := hdc
        this.hbm   := hbm
        this.obm   := obm
        this.ptr   := gfx
        this.gfx   := gfx ; Direct field alias for ptr
        this.w     := width
        this.h     := height
        this.pBits := pBits

        GpGFX.DebugLog("[+] Graphics created (" this.w "x" this.h ")`n")
    }

    /**
     * Deletes and disposes the GDI+ Graphics handle, restores GDI selections, and frees memory.
     *
     * @returns {void}
     *
     * @example
     * gfxObj.Dispose()
     */
    Dispose() {
        if (!this.ptr && !this.hdc)
            return

        ; Delete GDI+ Graphics context
        if (this.ptr) {
            if (Gdip.pToken)
                DllCall("gdiplus\GdipDeleteGraphics", "ptr", this.ptr)
            this.ptr := 0
            this.gfx := 0
        }

        ; Restore old bitmap, delete DIB section, and delete DC
        if (this.hdc) {
            if (this.obm) {
                DllCall("SelectObject", "ptr", this.hdc, "ptr", this.obm)
                this.obm := 0
            }
            if (this.hbm) {
                DllCall("DeleteObject", "ptr", this.hbm)
                this.hbm := 0
            }
            DllCall("DeleteDC", "ptr", this.hdc)
            this.hdc := 0
        }

        if (Gdip.pToken) {
            GpGFX.DebugLog("[-] Graphics disposed (" this.w "x" this.h ")`n")
        }
    }

    /**
     * Destructor to ensure resources are freed when garbage collected.
     */
    __Delete() {
        this.Dispose()
    }
}