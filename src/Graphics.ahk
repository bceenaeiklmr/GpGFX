; Script     Graphics.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025
; Version    0.7.2

/**
 * Create a graphics context for drawing on a layered window.
 * Layers delete their Graphics on deletion.
 */
class Graphics {
    
    /**
     * Create a new graphics object.
     * @param {int} width width of the graphics
     * @param {int} height height of the graphics
     * @param {int} id id of the graphics (debugging purpose)
     * 
     * @credit iseahound - TextRender v1.9.3, RenderOnScreen
     * https://github.com/iseahound/TextRender
     */
    __New(width, height, id := 0) {

        local Graphics, bi, hdc, hbm, obm, pBits

        ; Create a new bitmap, and a graphics object.
        hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
        bi := Buffer(40, 0)                        ; sizeof(bi) = 40
               NumPut(  "uint",        40, bi,  0) ; Size
               NumPut(   "int",     width, bi,  4) ; Width
               NumPut(   "int",   -height, bi,  8) ; Height - Negative so (0, 0) is top-left.
               NumPut("ushort",         1, bi, 12) ; Planes
               NumPut("ushort",        32, bi, 14) ; BitCount / BitsPerPixel
        hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits:=0, "ptr", 0, "uint", 0, "ptr")
        obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &Graphics:=0)
        
        ; Store values.
        this.hdc := hdc
        this.hbm := hbm
        this.obm := obm
        this.gfx := Graphics
        this.w := width
        this.h := height
        this.pBits := pBits

        this.id := (id) ? id : Layer.activeid
        
        OutputDebug("[+] Graphics " this.id " created`n")
        return
    }

    /**
     * Delete the graphics object.
     */
    __Delete() {
        if (!this.gfx)
            return
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", this.gfx)
        DllCall("SelectObject", "ptr", this.hdc , "ptr", this.obm)
        DllCall("DeleteObject", "ptr", this.hbm)
        DllCall("DeleteDC"    , "ptr", this.hdc)
        this.gfx := 0
        OutputDebug("[-] Graphics " this.id " deleted`n")
        return
    }
}
