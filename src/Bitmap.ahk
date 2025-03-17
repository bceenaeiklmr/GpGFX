; Script     Bitmap.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025
; Version    0.7.1

/**
 * Represents a Gdiplus Bitmap class that can be used for drawing images.
 */
class Bitmap {

    /**
     * Creates a bitmap with the specified width and height.
     * @param width the width of the bitmap
     * @param height the height of the bitmap 
     */
    CreateFromScan0(width := 1, height := 1) {
        DllCall("gdiplus\GdipCreateBitmapFromScan0"
                    ,  "int", width        ; width of the bitmap
                    ,  "int", height       ; height
                    ,  "int", 0            ; stride (width) in bytes
                    ,  "int", 0xE200B      ; PixelFormat32bppPARGB pre multiplied alpha
                    ,  "ptr", 0            ; scan0 pointer to the pixel data
                    , "ptr*", &pBitmap:=0) ; pointer to a pBitmap object
        this.ptr := pBitmap
        this.w := width
        this.h := height
        return
    }

    /**
     * Flips a bitmap by the specified flip mode.
     * @param {int} flip flip mode
     * @returns {int} error code
     */
    RotateFlip(flip := 1) {

        static flipmode := {
            0  : 0, 90   : 1, 180   : 2, 270   : 3,
            X  : 4, 90X  : 5, 180X  : 6, 270X  : 7,
            Y  : 6, 90Y  : 7, 180Y  : 4, 270Y  : 5,
            XY : 2, 90XY : 3, 180XY : 0, 270XY : 1 }

        if (!flipmode.HasProp(flip) || flip < 0 || flip > 7)
            throw ValueError("[!] .. " flip)

        return DllCall("gdiplus\GdipImageRotateFlip", "ptr", this.ptr, "int", flip)
    }

    /**
     * Loads a bitmap from a file and stores it in the class's instance variables.
     * It can also perform resizing and color matrix operations on the bitmap if requested.
     * @param {str} filepath path to the image file
     * @param {int|str} option percentage or width and height of the new bitmap
     * @param {str} cmatrix color matrix to apply to the image
     */
    CreateFromFile(filepath, option := 0, cmatrix := 0) {
        DllCall("gdiplus\GdipCreateBitmapFromFile"
            ,  "ptr", StrPtr(filepath) ; pointer to file path
            , "ptr*", &pBitmap:=0)     ; pointer to pBitmap object
        this.ptr := pBitmap
        this.w := this.Width
        this.h := this.Height
        if (option || cmatrix)
            this.Resize(option, cmatrix)
        return
    }

    /**
     * Resizes a bitmap, by specifying new width and height or by a percentage. Optionally applies color attributes.
     * @param {int|str} option percentage or width and height of the new bitmap
     * @param {str} cmatrix color matrix to apply to the image
     */
    Resize(option, cmatrix := 0) {
        
        local w, h, m, gfx, pBitmap, ImageAttr

        ; Calculate the new bitmap size (width, height)
        if (option ~= "i)w(\d*)h(\d*)") {
            w := RegExReplace(option, ".*w(\d+).*", "$1")
            h := RegExReplace(option, ".*h(\d+).*", "$1")
            dstWidth := Ceil(w ? w : this.w * h / this.h)
            dstHeight := Ceil(h ? h : this.h * w / this.w)
        } else {
            dstWidth := Ceil(this.w * option * 0.01)
            dstHeight := Ceil(this.h * option * 0.01)
        }

        ; 0x26200A = PixelFormat32bppARGB
        ; 0xE200B = PixelFormat32bppPARGB
        
        ; Create the new bitmap, a graphics context, set the smoothing mode, interpolation mode
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", dstWidth, "int", dstHeight, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &pBitmap:=0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pBitmap, "ptr*", &gfx:=0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)     ; SmoothingModeAntiAlias
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7) ; InterpolationModeHighQualityBicubic

        ; Apply image attributes
        if ((m := cmatrix) ? 1 : ImageAttr := 0) {
            switch {
                case m ~= "i)^b{1}(right)?$"       : m := ColorMatrix.bright
                case m ~= "i)^g{1}(ray(scale)?)?$" : m := ColorMatrix.grayscale
                case m ~= "i)^i{1}(nvert)?$"       : m := ColorMatrix.invert
                case m ~= "i)^n{1}(eg(ative)?)?$"  : m := ColorMatrix.negative
                case m ~= "i)^s{1}(ep(ia)?)?$"     : m := ColorMatrix.sepia
                case m ~= "i)^blue(only)?$"        : m := ColorMatrix.blueonly
                case m ~= "i)^green(only)?$"       : m := ColorMatrix.greenonly
                case m ~= "i)^red(only)?$"         : m := ColorMatrix.redonly
                default: throw ValueError("Matrix: " m)
            }
            cmatrix := m

            ; Create a new image attributes object
            DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &ImageAttr:=0)
            
            ; Set the image attributes color matrix
            DllCall("gdiplus\GdipSetImageAttributesColorMatrix"
                    , "ptr", ImageAttr  ; pointer to the image attributes object
                    , "int", 1          ; ColorAdjustType type, specifies the type of color adjustment to apply
                    , "int", 1          ; enableFlag
                    , "ptr", cmatrix    ; buffer (.ptr not needed)
                    , "ptr", 0          ; pointer to a gray matrix object
                    , "int", 0)         ; ColorMatrixFlags flags
        }

        ; Draw the original bitmap on the new bitmap using GdipDrawImageRectRectI
        DllCall("gdiplus\GdipDrawImageRectRectI"
                    , "ptr", gfx        ; pointer to the temp graphics
                    , "ptr", this.ptr   ; pointer to the orig bitmap
                    , "int", 0          ; dst x coordinate of the upper-left corner of dst rect
                    , "int", 0          ; dst y
                    , "int", dstWidth   ; dst width
                    , "int", dstHeight  ; dst height
                    , "int", 0          ; src x coordinate of the upper-left corner of src rect
                    , "int", 0          ; src y
                    , "int", this.w     ; src width
                    , "int", this.h     ; src height
                    , "int", 2          ; src Unit
                    , "ptr", ImageAttr  ; pointer to an image attributes object
                    , "ptr", 0          ; DrawImageAbort callback
                    , "ptr", 0)         ; callbackData
        
        ; Dispose ImageAttribute object
        if (cmatrix)
            DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", ImageAttr)

        ; Dispose the original bitmap, delete the temporary graphics
        DllCall("gdiplus\GdipDisposeImage", "ptr", this.ptr)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)

        ; Set the new pointer and dimensions
        this.ptr := pBitmap
        this.w := dstWidth
        this.h := dstHeight
        return
    }

    ; Gets the width of the bitmap
    Width {
        get {
            local w
            return (DllCall("gdiplus\GdipGetImageWidth", "ptr", this.ptr, "int*", &w:=0), w)
        } 
    }
    
    ; Gets the height of the bitmap
    Height {
        get {
            local h
            return (DllCall("gdiplus\GdipGetImageHeight", "ptr", this.ptr, "int*", &h:=0), h)
        }
    }

    ; No use for now
    Size {
        get => this.w * this.h * 4
    }

    /**
     * Create a new image with the specified width and height or load an image from a file.
     * @param {int|str} width width of the bitmap or the path to an existing picture
     * @param {int} height height of the bitmap
     * @param {str} cmatrix color mode of the bitmap
     */
    __New(width := 1, height := 1, cmatrix := 0) {
        static DIBmax := 32767
        if (width ~= "^\d{1,5}$" && height ~= "^\d{1,5}$") {
            this.CreateFromScan0(width, height)
        }
        else if (width ~= "i)\.(bmp|png|jpg|jpeg)$" && FileExist((filepath := width))) {
            this.CreateFromFile(filepath, (resize := height), cmatrix)
        }
    }

    /**
     * Dispose the Bitmap.
     */
    __Delete() {
        DllCall("gdiplus\GdipDisposeImage", "ptr", this.ptr)
        OutputDebug("[-] Bitmap deleted " this.ptr "`n")
    }
}

/**
 * A Class the holds buffers for various color matrixes.
 * Required for applying color effects to images.
 */
class ColorMatrix {

    static __New() {

        local colorMatrixes := {

            bright : [
                  1.5,     0,     0,     0,     0,
                    0,   1.5,     0,     0,     0,
                    0,     0,   1.5,     0,     0,
                    0,     0,     0,     1,     0,
                 0.05,  0.05,  0.05,     0,     1] ,
            
            grayscale : [
                0.299, 0.299, 0.299,     0,     0,
                0.587, 0.587, 0.587,     0,     0,
                0.114, 0.114, 0.114,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,

            negative : [
                   -1,     0,     0,     0,     0,
                    0,    -1,     0,     0,     0,
                    0,     0,    -1,     0,     0,
                    0,     0,     0,     1,     0,
                    1,     1,     1,     0,     1] ,

            sepia : [
                0.393, 0.349, 0.272,     0,     0,
                0.769, 0.686, 0.534,     0,     0,
                0.189, 0.168, 0.131,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,

            invert : [
                   -1,     0,     0,     0,     0,
                    0,    -1,     0,     0,     0,
                    0,     0,    -1,     0,     0,
                    0,     0,     0,     1,     0,
                    1,     1,     1,     0,     1] ,

            redonly : [
                    1,     0,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,
            
            greenonly : [ 
                    0,     0,     0,     0,     0,
                    0,     1,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1] ,
            
            blueonly : [
                    0,     0,     0,     0,     0,
                    0,     0,     0,     0,     0,
                    0,     0,     1,     0,     0,
                    0,     0,     0,     1,     0,
                    0,     0,     0,     0,     1]
        }

        ; Allocate a total of 900 bytes to preload the color matrixes
        local key, arr, buf

        for key, arr in colorMatrixes.OwnProps() {
            buf := Buffer(4 * arr.Length)
            loop 25 {
                NumPut("float", arr[A_Index], buf, (A_Index - 1) * 4)
            }
            this.%key% := buf
        }

        OutputDebug("[i] Color matrixes loaded successfully`n")
        return
    }
}
