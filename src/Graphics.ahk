; Script     Graphics.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025
; Version    0.7.1

/**
 * It allows for the creation of graphics for windows and layers,
 * enabling advanced drawing and rendering capabilities.
 * Layer creates its own GdiplusGraphics object to draw on the layer.
 * Layers also delete their Graphics on deletion.
 */
class Graphics {
    
    /**
     * Create a new graphics object.
     * @param {int} width width of the graphics object
     * @param {int} height height of the graphics object
     * @param {int} id id of the graphics object (debuggin purpose)
     */
    __New(width, height, id := 0) {

        this.id := (id) ? id : Layer.activeid
        
        ; Create a device-independent bitmap and graphics
        hdc := DllCall("GetDC", "ptr", 0) ; handle to the device context
        bi := Buffer(40, 0)               ; Bitmap info struct
        NumPut("uint", 40, "uint", width, "uint", height, "ushort", 1, "ushort", 32, bi)
        hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "int", 0, "ptr*", &ppvBits:=0, "ptr", 0, "int", 0, "ptr")
        
        ; Create the graphics object
        hdc := DllCall("CreateCompatibleDC", "ptr", hdc)
        obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm)
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &pGraphics:=0)
        
        ; Store for drawing
        this.hdc := hdc
        this.hbm := hbm
        this.obm := obm
        this.gfx := pGraphics
        this.w := width
        this.h := height
        this.ppvBits := ppvBits
        
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
