; Script:    Bitmap.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

/**
 * GdipBitmap class manages 32-bit ARGB offscreen pixel buffers and image processing in GpGFX.
 *
 * Core Capabilities:
 * - Creation: Files on disk, screen regions, window handles (HWND), clipboard, raw RAM buffers, icons, and HBITMAPs.
 * - Transformations: Scaling, resizing, 90/180/270 rotation, flipping, color matrices (sepia, grayscale, invert), and 256-entry LUTs.
 * - Pixel Operations: GetPixel/SetPixel, direct memory LockBits/UnlockBits, and MCode-accelerated PixelSearch.
 * - Export: Saving to disk (PNG, JPEG, BMP, GIF, TIFF), binary memory buffers, Windows clipboard, and colored ASCII art.
 * - Acceleration: CachedBitmap provides pre-compiled blitting to DC surfaces (~2x - 3x faster than standard draw calls).
 */
class GdipBitmap {

    ptr := 0
    w   := 0
    h   := 0

    ; Gets the width of the bitmap in pixels
    Width {
        get {
            local w := 0
            if (!this.ptr)
                return 0
            DllCall("gdiplus\GdipGetImageWidth", "ptr", this.ptr, "int*", &w:=0)
            return w
        }
    }

    ; Gets the height of the bitmap in pixels
    Height {
        get {
            local h := 0
            if (!this.ptr)
                return 0
            DllCall("gdiplus\GdipGetImageHeight", "ptr", this.ptr, "int*", &h:=0)
            return h
        }
    }

    ; Gets the bounding rectangle of the bitmap
    Bounds {
        get {
            local rectBuf := Buffer(16, 0)
            local unit := 0
            if (!this.ptr)
                return { x: 0, y: 0, w: 0, h: 0 }
            DllCall("gdiplus\GdipGetImageBounds", "ptr", this.ptr, "ptr", rectBuf.ptr, "int*", &unit:=0)
            return {
                x: NumGet(rectBuf,  0, "float"),
                y: NumGet(rectBuf,  4, "float"),
                w: NumGet(rectBuf,  8, "float"),
                h: NumGet(rectBuf, 12, "float")
            }
        }
    }

    ; Gets the uncompressed raw pixel memory size in bytes (width * height * 4 for 32bpp ARGB)
    Size {
        get => this.w * this.h * 4
    }

    /**
     * Universal GdipBitmap constructor.
     * Automatically detects and loads from file paths, clipboard, pixel dimensions, window handles (HWND), icons, or screen regions.
     *
     * @constructor
     * @param {String|Integer|Object} [source=1] Image source:
     *   - File path: "image.png", "assets/photo.jpg"
     *   - Clipboard keyword: "clipboard" or "clip"
     *   - Pixel width: 800 (creates blank 800x600 canvas when paired with height)
     *   - Window handle (HWND): WinExist("Notepad")
     *   - Screen region object: { x: 0, y: 0, w: 1920, h: 1080 }
     *   - GDI handle: HBITMAP or HICON pointer
     * @param {Integer|String} [height] Canvas height, resize percentage (50), geometry string ("w200 h100"), or color matrix effect ("grayscale")
     * @param {String|Buffer} [cmatrix=0] Optional color matrix filter ("sepia", "grayscale", "invert", "bright", "redonly", etc.)
     *
     * @example
     * ; Load an image from file
     * bmp := GdipBitmap("photo.png")
     *
     * ; Load from file and scale to 50% size with sepia filter
     * bmp := GdipBitmap("photo.png", 50, "sepia")
     *
     * ; Create a blank 400x300 canvas in memory
     * bmp := GdipBitmap(400, 300)
     *
     * ; Capture an image from the Windows clipboard
     * bmp := GdipBitmap("clipboard")
     *
     * ; Capture a window by handle
     * bmp := GdipBitmap(WinExist("ahk_exe notepad.exe"))
     *
     * ; Capture a region of the screen
     * bmp := GdipBitmap({ x: 100, y: 100, w: 500, h: 400 })
     */
    __New(source := 1, height?, cmatrix := 0) {
        local bmpTemp, sx, sy, option := 0, hVal

        ; File path on disk or "clipboard" keyword
        if (source is String) {
            if (source ~= "i)^(cb|clip(board)?)$") {
                bmpTemp := GdipBitmap.FromClipboard()
                if (bmpTemp) {
                    this.ptr := bmpTemp.ptr
                    this.w := bmpTemp.w
                    this.h := bmpTemp.h
                    bmpTemp.ptr := 0
                }
            }
            else if (FileExist(source)) {
                if (IsSet(height)) {
                    if (height is String && height ~= "i)^(bright|grayscale|invert|negative|sepia|blueonly|greenonly|redonly)$")
                        cmatrix := height, option := 0
                    else
                        option := height
                }
                this.CreateFromFile(source, option, cmatrix)
            }
            else if (source ~= "^\d{1,5}$" && IsSet(height) && height ~= "^\d{1,5}$") {
                this.CreateFromScan0(Integer(source), Integer(height))
            }
            else {
                throw ValueError("[!] Image file not found: " source)
            }
        }
        ; Numerical dimensions or integer handles
        else if (IsInteger(source)) {
            ; Window Handle (HWND): GdipBitmap(hwnd)
            if (DllCall("IsWindow", "ptr", source)) {
                bmpTemp := GdipBitmap.FromHWND(source)
                if (bmpTemp) {
                    this.ptr := bmpTemp.ptr
                    this.w := bmpTemp.w
                    this.h := bmpTemp.h
                    bmpTemp.ptr := 0
                }
            }
            ; Width and Height dimensions: GdipBitmap(800, 600) or GdipBitmap(50) (square)
            else if (source > 0 && source <= 32767 && (!IsSet(height) || (IsInteger(height) && height > 0 && height <= 32767))) {
                hVal := IsSet(height) ? height : source
                this.CreateFromScan0(source, hVal)
            }
            ; GDI Bitmap or Icon handle (HBITMAP / HICON)
            else {
                bmpTemp := GdipBitmap.FromHBITMAP(source)
                if (!bmpTemp)
                    bmpTemp := GdipBitmap.FromHICON(source)
                if (bmpTemp) {
                    this.ptr := bmpTemp.ptr
                    this.w := bmpTemp.w
                    this.h := bmpTemp.h
                    bmpTemp.ptr := 0
                }
            }
        }
        ; Screen region object: GdipBitmap({ x: 0, y: 0, w: 400, h: 300 })
        else if (IsObject(source) && source.HasProp("w") && source.HasProp("h")) {
            sx := source.HasProp("x") ? source.x : 0
            sy := source.HasProp("y") ? source.y : 0
            bmpTemp := GdipBitmap.FromScreen(sx, sy, source.w, source.h)
            if (bmpTemp) {
                this.ptr := bmpTemp.ptr
                this.w := bmpTemp.w
                this.h := bmpTemp.h
                bmpTemp.ptr := 0
            }
        }
    }

    /**
     * Creates a blank 32-bit premultiplied ARGB bitmap buffer with the specified dimensions.
     *
     * @param {Integer} [width=1] Canvas width in pixels
     * @param {Integer} [height=1] Canvas height in pixels
     * @returns {void}
     *
     * @example
     * bmp := GdipBitmap()
     * bmp.CreateFromScan0(1920, 1080)
     * 
     * @credit iseahound - Textrender 1.9.3, DrawOnGraphics
     * https://github.com/iseahound/TextRender
     */
    CreateFromScan0(width := 1, height := 1) {
        local pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0"
            ,  "int", width        ; width of the bitmap
            ,  "int", height       ; height
            ,  "int", 0            ; stride in bytes (auto-calculated)
            ,  "int", 0xE200B      ; PixelFormat32bppPARGB (premultiplied alpha)
            ,  "ptr", 0            ; scan0 pointer to pixel data
            , "ptr*", &pBitmap:=0)
        this.ptr := pBitmap
        this.w := width
        this.h := height
    }

    /**
     * Loads a bitmap from an image file on disk with optional resizing and color filters.
     *
     * @param {String} filepath Absolute or relative path to the image file
     * @param {Integer|String} [option=0] Resize option: percentage (50), dimension string ("w400 h300"), or 0 for original size
     * @param {String|Buffer} [cmatrix=0] Optional color matrix filter ("grayscale", "sepia", "invert", "bright")
     * @returns {void}
     *
     * @example
     * ; Load original dimensions
     * bmp := GdipBitmap()
     * bmp.CreateFromFile("banner.png")
     *
     * ; Load and scale down to 50%
     * bmp.CreateFromFile("banner.png", 50)
     *
     * ; Load with specific width/height and grayscale filter
     * bmp.CreateFromFile("banner.png", "w300 h200", "grayscale")
     */
    CreateFromFile(filepath, option := 0, cmatrix := 0) {
        local pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile"
            ,  "ptr", StrPtr(filepath)
            , "ptr*", &pBitmap:=0)
        this.ptr := pBitmap
        this.w := this.Width
        this.h := this.Height
        if (option || cmatrix)
            this.Resize(option, cmatrix)
    }

    /**
     * Captures a rectangular region of the desktop screen.
     *
     * @param {Integer} [x=0] Left screen coordinate
     * @param {Integer} [y=0] Top screen coordinate
     * @param {Integer} [w=0] Width to capture (0 = full primary screen width)
     * @param {Integer} [h=0] Height to capture (0 = full primary screen height)
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     *
     * @example
     * ; Capture entire primary screen
     * screenBmp := GdipBitmap.FromScreen()
     *
     * ; Capture a 300x300 area around the mouse cursor
     * MouseGetPos(&mx, &my)
     * cropBmp := GdipBitmap.FromScreen(mx - 150, my - 150, 300, 300)
     */
    static FromScreen(x := 0, y := 0, w := 0, h := 0) {
        local hdcScreen, hdcMem, hbm, obm, pBitmap, bmp
        if (!w)
            w := A_ScreenWidth
        if (!h)
            h := A_ScreenHeight

        hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
        hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
        obm := DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")

        DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020) ; SRCCOPY

        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap:=0)

        DllCall("SelectObject", "ptr", hdcMem, "ptr", obm)
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)

        if (!pBitmap)
            return 0
        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pBitmap
        bmp.w := w
        bmp.h := h
        return bmp
    }

    /**
     * Captures a window or control into a Bitmap using its window handle (HWND).
     *
     * @param {Integer} hwnd Window or control handle
     * @param {Boolean} [clientOnly=false] Capture only the client area if true; captures full window frame if false
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     *
     * @example
     * ; Capture full Notepad window
     * notepadBmp := GdipBitmap.FromHWND(WinExist("ahk_exe notepad.exe"))
     *
     * ; Capture only client area (excluding title bar and borders)
     * clientBmp := GdipBitmap.FromHWND(WinExist("ahk_exe notepad.exe"), true)
     */
    static FromHWND(hwnd, clientOnly := false) {
        local rc := Buffer(16, 0)
        local w, h, hdcTarget, hdcMem, hbm, obm, pBitmap, bmp, vRect
        if (clientOnly) {
            DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
            w := NumGet(rc, 8, "int")
            h := NumGet(rc, 12, "int")
            hdcTarget := DllCall("GetDC", "ptr", hwnd, "ptr")
        }
        else {
            vRect := WinGetVisiblePos(hwnd)
            w := vRect.w
            h := vRect.h
            hdcTarget := DllCall("GetWindowDC", "ptr", hwnd, "ptr")
        }

        if (w <= 0 || h <= 0) {
            if (hdcTarget)
                DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdcTarget)
            return 0
        }

        hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcTarget, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", hdcTarget, "int", w, "int", h, "ptr")
        obm := DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")

        ; Try PrintWindow first (2 = PW_RENDERFULLCONTENT), fallback to BitBlt
        if (!DllCall("PrintWindow", "ptr", hwnd, "ptr", hdcMem, "uint", 2))
            DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdcTarget, "int", 0, "int", 0, "uint", 0x00CC0020)

        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap:=0)

        DllCall("SelectObject", "ptr", hdcMem, "ptr", obm)
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdcTarget)

        if (!pBitmap)
            return 0
        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pBitmap
        bmp.w := w
        bmp.h := h
        return bmp
    }

    /**
     * Creates a Bitmap from an image currently copied to the Windows Clipboard (CF_DIB / CF_BITMAP).
     *
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     *
     * @example
     * ; Paste an image from clipboard and save to disk
     * clipBmp := GdipBitmap.FromClipboard()
     * if (clipBmp) {
     *     clipBmp.SaveToFile("pasted.png")
     * }
     */
    static FromClipboard() {
        local hBitmap, hDIB, pdib, pBits, pBitmap, biSize, biBitCount, clrUsed, bmp

        if (!DllCall("OpenClipboard", "ptr", 0))
            return 0

        pBitmap := 0

        ; Try CF_BITMAP (2)
        if (DllCall("IsClipboardFormatAvailable", "uint", 2)) {
            hBitmap := DllCall("GetClipboardData", "uint", 2, "ptr")
            if (hBitmap) {
                DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", 0, "ptr*", &pBitmap:=0)
            }
        }

        ; Try CF_DIB (8) if CF_BITMAP was not available or failed
        if (!pBitmap && DllCall("IsClipboardFormatAvailable", "uint", 8)) {
            hDIB := DllCall("GetClipboardData", "uint", 8, "ptr")
            if (hDIB) {
                pdib := DllCall("GlobalLock", "ptr", hDIB, "ptr")
                if (pdib) {
                    biSize := NumGet(pdib, 0, "uint")
                    biBitCount := NumGet(pdib, 14, "ushort")
                    clrUsed := NumGet(pdib, 32, "uint")
                    if (clrUsed == 0 && biBitCount <= 8)
                        clrUsed := 1 << biBitCount
                    pBits := pdib + biSize + (clrUsed * 4)
                    DllCall("gdiplus\GdipCreateBitmapFromGdiDib", "ptr", pdib, "ptr", pBits, "ptr*", &pBitmap:=0)
                    DllCall("GlobalUnlock", "ptr", hDIB)
                }
            }
        }

        DllCall("CloseClipboard")

        if (!pBitmap)
            return 0

        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pBitmap
        bmp.w := bmp.Width
        bmp.h := bmp.Height
        return bmp
    }

    /**
     * Loads a Bitmap directly from an in-memory binary Buffer or memory address without disk I/O.
     *
     * @param {Buffer|Ptr} buf Memory Buffer or raw pointer containing image bytes (PNG, JPEG, BMP, GIF)
     * @param {Integer} [size=0] Size of the buffer in bytes (required if buf is a raw pointer)
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     *
     * @example
     * ; Load from a downloaded or generated buffer
     * memBmp := GdipBitmap.FromMemory(imageBuffer)
     */
    static FromMemory(buf, size := 0) {
        local pData, dataSize, pStream, bmp
        if (IsObject(buf) && buf.HasProp("ptr")) {
            pData := buf.ptr
            dataSize := buf.size
        }
        else {
            pData := buf
            dataSize := size
        }

        if (!pData || dataSize <= 0)
            return 0

        pStream := DllCall("shlwapi\SHCreateMemStream", "ptr", pData, "uint", dataSize, "ptr")
        if (!pStream)
            return 0

        bmp := GdipBitmap.FromStream(pStream)
        ObjRelease(pStream)
        return bmp
    }

    /**
     * Loads a Bitmap directly from an IStream COM interface pointer.
     *
     * @param {Ptr} pStream Pointer to IStream COM interface
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     */
    static FromStream(pStream) {
        local pBitmap := 0, bmp
        if (!pStream)
            return 0
        DllCall("gdiplus\GdipCreateBitmapFromStream", "ptr", pStream, "ptr*", &pBitmap:=0)
        if (!pBitmap)
            return 0
        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pBitmap
        bmp.w := bmp.Width
        bmp.h := bmp.Height
        return bmp
    }

    /**
     * Creates a Bitmap from a Windows GDI Bitmap handle (HBITMAP).
     *
     * @param {Integer} hBitmap Windows GDI bitmap handle
     * @param {Integer} [hPalette=0] Optional palette handle
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     */
    static FromHBITMAP(hBitmap, hPalette := 0) {
        local pBitmap := 0, bmp
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", hPalette, "ptr*", &pBitmap:=0)
        if (!pBitmap)
            return 0
        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pBitmap
        bmp.w := bmp.Width
        bmp.h := bmp.Height
        return bmp
    }

    /**
     * Creates a Bitmap from a Windows Icon handle (HICON).
     *
     * @param {Integer} hIcon Windows icon handle
     * @returns {GdipBitmap|Integer} New GdipBitmap instance on success, or 0 on failure
     */
    static FromHICON(hIcon) {
        local pBitmap := 0, bmp
        DllCall("gdiplus\GdipCreateBitmapFromHICON", "ptr", hIcon, "ptr*", &pBitmap:=0)
        if (!pBitmap)
            return 0
        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pBitmap
        bmp.w := bmp.Width
        bmp.h := bmp.Height
        return bmp
    }

    /**
     * Resizes the bitmap and optionally applies a color matrix filter.
     *
     * @param {Integer|String} [option=0] Dimension option:
     *   - Percentage integer: 50 (scales to 50%), 200 (scales to 200%)
     *   - Dimension string: "w800 h600", "w400" (auto-aspect height), "h300" (auto-aspect width)
     *   - Filter name: "sepia", "grayscale", "invert", "bright", "redonly", "greenonly", "blueonly"
     * @param {String|Buffer} [cmatrix=0] Optional color matrix filter when option is used for dimensions
     * @returns {void}
     *
     * @example
     * ; Scale to half resolution
     * bmp.Resize(50)
     *
     * ; Resize to fixed width and height
     * bmp.Resize("w640 h480")
     *
     * ; Apply sepia filter without changing size
     * bmp.Resize("sepia")
     *
     * ; Scale to 75% size and apply grayscale filter
     * bmp.Resize(75, "grayscale")
     */
    Resize(option := 0, cmatrix := 0) {
        local w, h, m, gfx, pBitmap, ImageAttr, dstWidth, dstHeight

        ; If option is a color matrix name (e.g. "sepia", "grayscale")
        if (option is String && option ~= "i)^(bright|grayscale|invert|negative|sepia|blueonly|greenonly|redonly)$") {
            cmatrix := option
            option := 0
        }

        ; Calculate new dimensions
        if (option is String && option ~= "i)w(\d+)\s*h(\d+)") {
            w := RegExReplace(option, ".*w(\d+).*", "$1")
            h := RegExReplace(option, ".*h(\d+).*", "$1")
            dstWidth := Ceil(w ? w : this.w * h / this.h)
            dstHeight := Ceil(h ? h : this.h * w / this.w)
        } else if (IsNumber(option) && option > 0 && option != 100) {
            dstWidth := Max(1, Ceil(this.w * option * 0.01))
            dstHeight := Max(1, Ceil(this.h * option * 0.01))
        } else {
            dstWidth := this.w
            dstHeight := this.h
        }

        ; Create the new bitmap and graphics context
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", dstWidth, "int", dstHeight, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &pBitmap:=0)
        if (!pBitmap)
            return

        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pBitmap, "ptr*", &gfx:=0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7)

        DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &ImageAttr:=0)
        DllCall("gdiplus\GdipSetImageAttributesWrapMode", "ptr", ImageAttr, "int", 3)

        ; Apply color matrix if provided
        if (cmatrix) {
            if (IsObject(cmatrix) && cmatrix.HasProp("ptr")) {
                m := cmatrix
            }
            else if (cmatrix is String) {
                switch {
                    case cmatrix ~= "i)^b(right)?$"       : m := ColorMatrix.bright
                    case cmatrix ~= "i)^g(ray(scale)?)?$" : m := ColorMatrix.grayscale
                    case cmatrix ~= "i)^i(nvert)?$"       : m := ColorMatrix.invert
                    case cmatrix ~= "i)^n(eg(ative)?)?$"  : m := ColorMatrix.negative
                    case cmatrix ~= "i)^s(ep(ia)?)?$"     : m := ColorMatrix.sepia
                    case cmatrix ~= "i)^blue(only)?$"     : m := ColorMatrix.blueonly
                    case cmatrix ~= "i)^green(only)?$"    : m := ColorMatrix.greenonly
                    case cmatrix ~= "i)^red(only)?$"      : m := ColorMatrix.redonly
                    default: m := 0
                }
            }
            else {
                m := 0
            }

            if (m) {
                DllCall("gdiplus\GdipSetImageAttributesColorMatrix"
                    , "ptr", ImageAttr
                    , "int", 1
                    , "int", 1
                    , "ptr", m
                    , "ptr", 0
                    , "int", 0)
            }
        }

        ; Draw the original bitmap onto the new bitmap
        DllCall("gdiplus\GdipDrawImageRectRectI"
            , "ptr", gfx
            , "ptr", this.ptr
            , "int", 0, "int", 0, "int", dstWidth, "int", dstHeight
            , "int", 0, "int", 0, "int", this.w,   "int", this.h
            , "int", 2, "ptr", ImageAttr, "ptr", 0, "ptr", 0)

        ; Cleanup
        DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", ImageAttr)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
        DllCall("gdiplus\GdipDisposeImage", "ptr", this.ptr)

        this.ptr := pBitmap
        this.w := dstWidth
        this.h := dstHeight
    }

    /**
     * Flips or rotates the bitmap in 90-degree increments and updates width/height.
     *
     * @param {Integer|String} [flipMode=1] Rotation and flip mode:
     *   - Degree numbers: 90, 180, 270 (or strings "90", "180", "270")
     *   - Axis flips: "X" (horizontal), "Y" (vertical), "XY" / "Both" (180 + mirror)
     *   - Combined: "90X", "180X", "270X", "90Y", "180Y", "270Y"
     *   - GDI+ RotateFlipType: 0=None, 1=90, 2=180, 3=270, 4=FlipX, 5=90FlipX, 6=FlipY, 7=270FlipX
     * @returns {Integer} GDI+ status code (0 = OK)
     *
     * @example
     * ; Rotate 90 degrees clockwise
     * bmp.RotateFlip(90)
     *
     * ; Flip horizontally across X axis
     * bmp.RotateFlip("X")
     *
     * ; Rotate 270 degrees and flip vertically
     * bmp.RotateFlip("270Y")
     */
    RotateFlip(flipMode := 1) {
        local mode := 0, tmp := 0
        static flipMap := Map(
            0, 0, 90, 1, 180, 2, 270, 3,
            "0", 0, "90", 1, "180", 2, "270", 3,
            "x", 4, "90x", 5, "180x", 6, "270x", 7,
            "y", 6, "90y", 7, "180y", 4, "270y", 5,
            "xy", 2, "90xy", 3, "180xy", 0, "270xy", 1,
            "h", 4, "v", 6, "hv", 2, "vh", 2, "both", 2,
            "horizontal", 4, "vertical", 6, "flipx", 4, "flipy", 6
        )

        if (flipMode is Integer && flipMode >= 0 && flipMode <= 7) {
            mode := flipMode
        } else if (flipMap.Has((flipMode is String) ? StrLower(Trim(flipMode)) : flipMode)) {
            mode := flipMap[(flipMode is String) ? StrLower(Trim(flipMode)) : flipMode]
        } else {
            throw ValueError("[!] Invalid RotateFlip mode: " . String(flipMode))
        }

        ; If rotation was 90 or 270 degrees (odd modes 1, 3, 5, 7), swap width and height
        if (mode & 1) {
            tmp := this.w
            this.w := this.h
            this.h := tmp
        }

        return DllCall("gdiplus\GdipImageRotateFlip", "ptr", this.ptr, "int", mode)
    }

    /**
     * Duplicates the entire bitmap or extracts a sub-region into a new independent GdipBitmap.
     *
     * @param {Float} [x] Sub-region left coordinate (optional)
     * @param {Float} [y] Sub-region top coordinate (optional)
     * @param {Float} [w] Sub-region width (optional)
     * @param {Float} [h] Sub-region height (optional)
     * @returns {GdipBitmap|Integer} Cloned GdipBitmap instance or 0 on failure
     *
     * @example
     * ; Clone the entire bitmap
     * copyBmp := bmp.Clone()
     *
     * ; Extract a 100x100 sub-image from (50, 50)
     * subBmp := bmp.Clone(50, 50, 100, 100)
     */
    Clone(x?, y?, w?, h?) {
        local pDest := 0, bmp
        if (!this.ptr)
            return 0

        if (IsSet(x) && IsSet(y) && IsSet(w) && IsSet(h)) {
            ; 0x26200A = PixelFormat32bppARGB
            DllCall("gdiplus\GdipCloneBitmapArea", "float", x, "float", y, "float", w, "float", h, "int", 0x26200A, "ptr", this.ptr, "ptr*", &pDest:=0)
        } else {
            DllCall("gdiplus\GdipCloneImage", "ptr", this.ptr, "ptr*", &pDest:=0)
        }

        if (!pDest)
            return 0

        bmp := {base: GdipBitmap.Prototype}
        bmp.ptr := pDest
        bmp.w := (IsSet(w) && w > 0) ? Integer(w) : bmp.Width
        bmp.h := (IsSet(h) && h > 0) ? Integer(h) : bmp.Height
        return bmp
    }

    /**
     * Crops a sub-region from the bitmap and returns it as a new GdipBitmap.
     *
     * @param {Float} x Sub-region left coordinate
     * @param {Float} y Sub-region top coordinate
     * @param {Float} w Sub-region width
     * @param {Float} h Sub-region height
     * @returns {GdipBitmap|Integer} Cropped GdipBitmap instance
     *
     * @example
     * iconBmp := fullImage.Crop(10, 10, 64, 64)
     */
    Crop(x, y, w, h) => this.Clone(x, y, w, h)

    /**
     * Applies a 256-entry Color Lookup Table (LUT) color transformation directly to this bitmap.
     *
     * @param {Array|Buffer} lutB 256-byte table for Blue channel
     * @param {Array|Buffer} lutG 256-byte table for Green channel
     * @param {Array|Buffer} lutR 256-byte table for Red channel
     * @param {Array|Buffer} [lutA] Optional 256-byte table for Alpha channel
     * @returns {GdipBitmap} this (for method chaining)
     *
     * @example
     * ; Apply high-speed color grading LUT
     * bmp.ApplyLUT(lutBlue, lutGreen, lutRed)
     */
    ApplyLUT(lutB, lutG, lutR, lutA?) {
        ColorLUT.Apply(this, lutB, lutG, lutR, lutA?)
        return this
    }

    /**
     * Reads the 32-bit ARGB pixel color at coordinate (x, y).
     *
     * @param {Integer} x Horizontal pixel coordinate (0-indexed)
     * @param {Integer} y Vertical pixel coordinate (0-indexed)
     * @param {String} [outFormat="hex"] Output format:
     *   - "hex": "0xAARRGGBB" formatted hex string
     *   - "rgb": "0xRRGGBB" formatted hex string
     *   - "int" / "uint": Raw 32-bit ARGB integer
     *   - "rgba" / "obj": { a: 255, r: 255, g: 0, b: 0 } component object
     *   - "bgr": "0xBBGGRR" formatted string
     * @returns {Integer|String|Object} Pixel color value
     *
     * @example
     * ; Get hex color string
     * hexClr := bmp.GetPixel(50, 50) ; "0xFF78DCE8"
     *
     * ; Get RGBA component object
     * clrObj := bmp.GetPixel(50, 50, "rgba") ; { a: 255, r: 120, g: 220, b: 232 }
     */
    GetPixel(x, y, outFormat := "hex") {
        local argb := 0, a, r, g, b
        if (!this.ptr || x < 0 || y < 0 || x >= this.w || y >= this.h)
            return 0

        DllCall("gdiplus\GdipBitmapGetPixel", "ptr", this.ptr, "int", x, "int", y, "uint*", &argb:=0)

        switch (StrLower(outFormat)) {
            case "hex", "1":
                return Format("0x{:08X}", argb)
            case "int", "uint", "0":
                return argb
            case "rgb", "4":
                return Format("0x{:06X}", argb & 0xFFFFFF)
            case "bgr", "3":
                a := (argb >> 24) & 0xFF
                r := (argb >> 16) & 0xFF
                g := (argb >> 8) & 0xFF
                b := argb & 0xFF
                return Format("0x{:02X}{:02X}{:02X}", b, g, r)
            case "rgba", "obj", "2":
                return {
                    a: (argb >> 24) & 0xFF,
                    r: (argb >> 16) & 0xFF,
                    g: (argb >> 8) & 0xFF,
                    b: argb & 0xFF
                }
            default:
                return Format("0x{:08X}", argb)
        }
    }

    /**
     * Sets the 32-bit ARGB pixel color at coordinate (x, y).
     *
     * @param {Integer} x Horizontal pixel coordinate (0-indexed)
     * @param {Integer} y Vertical pixel coordinate (0-indexed)
     * @param {String|Integer} clr Color name ("Red"), hex string ("0xFFFF0000"), or ARGB integer
     * @returns {Integer} GDI+ status code (0 = success)
     *
     * @example
     * ; Set individual pixel colors
     * bmp.SetPixel(10, 10, "Lime")
     * bmp.SetPixel(10, 11, "0xFFFF6188")
     * bmp.SetPixel(10, 12, 0xFF00FF00)
     */
    SetPixel(x, y, clr) {
        if (!this.ptr || x < 0 || y < 0 || x >= this.w || y >= this.h)
            return 2 ; InvalidParameter
        return DllCall("gdiplus\GdipBitmapSetPixel", "ptr", this.ptr, "int", x, "int", y, "uint", Color(clr))
    }

    /**
     * Locks a rectangular area of the bitmap for high-speed direct RAM pixel read/write access.
     *
     * @param {Integer} [x=0] Left coordinate
     * @param {Integer} [y=0] Top coordinate
     * @param {Integer} [w] Width (defaults to bitmap width)
     * @param {Integer} [h] Height (defaults to bitmap height)
     * @param {Integer} [format=0x26200A] GDI+ PixelFormat (0x26200A = 32bppARGB)
     * @param {Integer} [mode=3] Access mode: 1 = Read, 2 = Write, 3 = ReadWrite
     * @returns {Object|Integer} BitmapData object { scan0, stride, width, height, format, dataBuffer } or 0 on failure
     *
     * @example
     * ; High-speed direct RAM pixel loop
     * bmData := bmp.LockBits()
     * if (bmData) {
     *     scan0 := bmData.scan0
     *     stride := bmData.stride
     *     ; Direct memory write: NumPut("uint", 0xFFFF0000, scan0, x * 4 + y * stride)
     *     bmp.UnlockBits(bmData)
     * }
     */
    LockBits(x := 0, y := 0, w?, h?, format := 0x26200A, mode := 3) {
        local actualH, actualW, status

        if (!this.ptr)
            return 0

        static rectBuf := Buffer(16, 0)
        static dataBuf := Buffer(32, 0)

        actualW := IsSet(w) ? w : this.w
        actualH := IsSet(h) ? h : this.h

        NumPut("int", x, rectBuf, 0)
        NumPut("int", y, rectBuf, 4)
        NumPut("int", actualW, rectBuf, 8)
        NumPut("int", actualH, rectBuf, 12)

        status := DllCall("gdiplus\GdipBitmapLockBits"
            , "ptr", this.ptr
            , "ptr", rectBuf
            , "uint", mode
            , "int", format
            , "ptr", dataBuf)

        if (status != 0)
            return 0

        return {
            width:  NumGet(dataBuf,  0, "uint"),
            height: NumGet(dataBuf,  4, "uint"),
            stride: NumGet(dataBuf,  8, "int"),
            format: NumGet(dataBuf, 12, "int"),
            scan0:  NumGet(dataBuf, 16, "ptr"),
            dataBuffer: dataBuf
        }
    }

    /**
     * Unlocks pixel memory previously locked with LockBits.
     *
     * @param {Object} bmData BitmapData object returned from LockBits
     * @returns {Integer} GDI+ status code (0 = success)
     */
    UnlockBits(bmData) {
        if (this.ptr && IsObject(bmData) && bmData.HasProp("dataBuffer")) {
            return DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", this.ptr, "ptr", bmData.dataBuffer)
        }
        return 2
    }

    static __pMCodePixelSearch := 0

    /**
     * Fast memory-based PixelSearch across the bitmap surface in RAM (Native MCode).
     *
     * @param {Integer|String} targetColor Target ARGB integer or hex string to locate
     * @param {Integer} [x1=0] Left search boundary
     * @param {Integer} [y1=0] Top search boundary
     * @param {Integer} [x2] Right search boundary (defaults to bitmap width - 1)
     * @param {Integer} [y2] Bottom search boundary (defaults to bitmap height - 1)
     * @param {Integer} [variation=0] Color variation tolerance (0 - 255)
     * @returns {Object|Boolean} { found: true, x: Integer, y: Integer, color: Integer, hex: String } or false if not found
     *
     * @example
     * ; Find red pixel with tolerance
     * match := bmp.PixelSearch("0xFFFF0000", 0, 0, 800, 600, 10)
     * if (match) {
     *     MsgBox("Found at (" match.x ", " match.y ") with color " match.hex)
     * }
     */
    static __pMCodePatternSearch := 0

    /**
     * Searches for a sparse multi-pixel relative pattern across the bitmap surface in RAM (Native MCode).
     *
     * @param {Array} pattern Array of `{dx, dy, argb}` objects or `[dx, dy, argb]` arrays
     * @param {Integer} [x1=0] Left search boundary
     * @param {Integer} [y1=0] Top search boundary
     * @param {Integer} [x2] Right search boundary (defaults to bitmap width - 1)
     * @param {Integer} [y2] Bottom search boundary (defaults to bitmap height - 1)
     * @param {Integer} [variation=10] Color channel variation tolerance (0 - 255)
     * @returns {Object|Boolean} `{ found: true, x: Integer, y: Integer }` or `false`
     */
    PatternSearch(pattern, x1 := 0, y1 := 0, x2?, y2?, variation := 10) {
        local var, bmData, startX, startY, endX, endY, numPts, ptsBuf, ctxBuf, found, fx, fy, idx, pt, off, pDx, pDy, ptClr

        if (!IsObject(pattern) || pattern.Length = 0)
            return false

        if (!GdipBitmap.__pMCodePatternSearch) {
            GdipBitmap.__pMCodePatternSearch := MCode(
                "U1ZXQVRBVUFWQVdVSInlSIPsMEiFyQ+EQAIAAEiJTfhIiwFIhcAPhDACAABEi0" .
                "EoRYXAD44jAgAATItJME2FyQ+EFgIAAESLYRhIi034RDthIA+P+QEAAEhjQQhJ" .
                "D6/ESAMBSIlF8ESLaRRIi034RDtpHA+P0AEAAEiLRfBGizSoQYHm////AEyLST" .
                "BFi3kIQYHn////AItxJIX2dQtFOf4PhZoBAADreESJ8MHoECX/AAAARIn6weoQ" .
                "geL/AAAAKdCJwsH6HzHQKdA58A+PbgEAAESJ8MHoCCX/AAAARIn6weoIgeL/AA" .
                "AAKdCJwsH6HzHQKdA58A+PRAEAAESJ8CX/AAAARIn6geL/AAAAKdCJwsH6HzHQ" .
                "KdA58A+PIAEAAEiLTfiLeSiD/wEPjvYAAAC7AQAAADn7D43pAAAATItJMEiJ2E" .
                "jB4ARJAcFFiehFAwFFieJFA1EERYXAD4jfAAAARDtBDA+N1QAAAEWF0g+IzAAA" .
                "AEQ7URAPjcIAAABIY0EISQ+vwkgDAUaLNIBBgeb///8ARYt5CEGB5////wCLcS" .
                "SF9nUNRTn+D4WRAAAA/8PrgkSJ8MHoECX/AAAARIn6weoQgeL/AAAAKdCJwsH6" .
                "HzHQKdA58H9nRInwwegIJf8AAABEifrB6giB4v8AAAAp0InCwfofMdAp0Dnwf0" .
                "FEifAl/wAAAESJ+oHi/wAAACnQicLB+h8x0CnQOfB/If/D6Q////9Ii034x0E4" .
                "AQAAAESJaTxEiWFAuAEAAADrHUH/xeki/v//Qf/E6fn9//9Ii034x0E4AAAAAD" .
                "HASIPEMF1BX0FeQV1BXF9eW8M=")
        }

        var    := Max(0, Min(255, Integer(variation)))
        numPts := pattern.Length

        ptsBuf := Buffer(numPts * 16, 0)
        for idx, pt in pattern {
            off := (idx - 1) * 16
            if (pt is Array && pt.Length >= 3) {
                pDx := pt[1], pDy := pt[2], ptClr := pt[3]
            } else {
                pDx := pt.HasProp("dx") ? pt.dx : 0
                pDy := pt.HasProp("dy") ? pt.dy : 0
                ptClr := pt.HasProp("argb") ? pt.argb : (pt.HasProp("color") ? pt.color : 0xFFFFFFFF)
            }
            NumPut("int", pDx, ptsBuf, off + 0)
            NumPut("int", pDy, ptsBuf, off + 4)
            NumPut("uint", Color(ptClr), ptsBuf, off + 8)
        }

        bmData := this.LockBits(0, 0, this.w, this.h, 0x26200A, 1)
        if (!bmData)
            return false

        startX := Max(0, Min(this.w - 1, Integer(x1)))
        startY := Max(0, Min(this.h - 1, Integer(y1)))
        endX   := IsSet(x2) ? Max(0, Min(this.w - 1, Integer(x2))) : (this.w - 1)
        endY   := IsSet(y2) ? Max(0, Min(this.h - 1, Integer(y2))) : (this.h - 1)

        ctxBuf := Buffer(72, 0)
        NumPut("ptr",  bmData.scan0, ctxBuf, 0)
        NumPut("int",  bmData.stride, ctxBuf, 8)
        NumPut("int",  this.w,       ctxBuf, 12)
        NumPut("int",  this.h,       ctxBuf, 16)
        NumPut("int",  startX,       ctxBuf, 20)
        NumPut("int",  startY,       ctxBuf, 24)
        NumPut("int",  endX,         ctxBuf, 28)
        NumPut("int",  endY,         ctxBuf, 32)
        NumPut("int",  var,          ctxBuf, 36)
        NumPut("int",  numPts,       ctxBuf, 40)
        NumPut("ptr",  ptsBuf.ptr,   ctxBuf, 48)

        DllCall(GdipBitmap.__pMCodePatternSearch, "ptr", ctxBuf.ptr, "int")

        found := NumGet(ctxBuf, 56, "int")
        fx    := NumGet(ctxBuf, 60, "int")
        fy    := NumGet(ctxBuf, 64, "int")

        this.UnlockBits(bmData)

        if (found)
            return {found: true, x: fx, y: fy}
        return false
    }

    PixelSearch(targetColor, x1 := 0, y1 := 0, x2?, y2?, variation := 0) {
        local target, var, bmData, startX, startY, endX, endY, found, fx, fy, fClr

        target := Color(targetColor)
        var := Max(0, Min(255, Integer(variation)))

        bmData := this.LockBits(0, 0, this.w, this.h, 0x26200A, 1)
        if (!bmData)
            return false

        startX := Max(0, Min(this.w - 1, Integer(x1)))
        startY := Max(0, Min(this.h - 1, Integer(y1)))
        endX   := IsSet(x2) ? Max(0, Min(this.w - 1, Integer(x2))) : (this.w - 1)
        endY   := IsSet(y2) ? Max(0, Min(this.h - 1, Integer(y2))) : (this.h - 1)

        if (!GdipBitmap.__pMCodePixelSearch) {
            GdipBitmap.__pMCodePixelSearch := MCode(
                "SIXJD4T3AQAAQVdBVkFVQVRVV1ZTSInLSIPsGEyLGU2F2w+EeAEAAItzEItRC" . 
                "ESLcxSLSQxEi2MYRItTHESLeyBMi2sohfYPhZMAAABFOfwPj0MBAABMY8JBD6" . 
                "/USGPSTAHaTYXtD4RZAQAAQYtFAIXAD4UoAQAARTnWD4+CAQAASWPG6xdmLg8" . 
                "fhAAAAAAASIPAAUE5wg+MEwEAADkMgnXux0MwAQAAAIlDNESJYziJSzxNhe10" . 
                "CEHHRQABAAAAuAEAAABIg8QYW15fXUFcQV1BXkFfw2YuDx+EAAAAAACJzw+27" . 
                "UQPtsnB7xBAD7b/RTn8D4+gAAAASGPCQQ+v1ESJfCQMSGPSSQHTSInCTYXtdA" . 
                "xBi0UAhcAPhYEAAABFOdZ/Y0SJdCQITWPGDx9AAEOLDIOJyMHoEA+2wCn4QYn" . 
                "HQfffRA9I+A+2xSnoQYnG99hBD0jGRA+28UE5x0EPTcdFKc5FifdB999FD0j+" . 
                "RDn4QQ9MxznwfmdJg8ABRTnCfa5Ei3QkCEGDxAFJAdNEOWQkDA+Ndf///8dDM" . 
                "AAAAAAxwOke////Zg8fhAAAAAAAQYPEAUwBwkU553zdTYXtD4Wn/v//RTnWD4" . 
                "6z/v//QYPEAUwBwkU5/H7r670PH0AAx0MwAQAAAESJQzREiWM4iUs8TYXtD4W" . 
                "9/v//6cD+//8xwMNBg8QBTAHCRTn8D45Z/v//64QxwMM=")
        }

        static ctxBuf := Buffer(64, 0)
        NumPut("ptr",  bmData.scan0,  ctxBuf, 0)
        NumPut("int",  bmData.stride, ctxBuf, 8)
        NumPut("uint", target,        ctxBuf, 12)
        NumPut("int",  var,           ctxBuf, 16)
        NumPut("int",  startX,        ctxBuf, 20)
        NumPut("int",  startY,        ctxBuf, 24)
        NumPut("int",  endX,          ctxBuf, 28)
        NumPut("int",  endY,          ctxBuf, 32)
        NumPut("ptr",  0,             ctxBuf, 40)

        DllCall(GdipBitmap.__pMCodePixelSearch, "ptr", ctxBuf, "int")

        found := NumGet(ctxBuf, 48, "int")
        fx    := NumGet(ctxBuf, 52, "int")
        fy    := NumGet(ctxBuf, 56, "int")
        fClr  := NumGet(ctxBuf, 60, "uint")

        this.UnlockBits(bmData)

        if (found)
            return {found: true, x: fx, y: fy, color: fClr, hex: itoARGB(fClr)}
        return false
    }

    /**
     * Saves the bitmap to an image file on disk (PNG, JPEG, BMP, GIF, TIFF).
     *
     * @param {String} filepath Destination file path (e.g. "output.png", "screenshots/capture.jpg")
     * @param {String} [format=""] Format override ("PNG", "JPEG", "BMP", "GIF", "TIFF"); auto-detected from file extension if empty
     * @param {Integer} [quality=100] JPEG compression quality (0 - 100)
     * @returns {Boolean} True on success, False on failure
     *
     * @example
     * ; Save as PNG
     * bmp.SaveToFile("output.png")
     *
     * ; Save as compressed JPEG with 85% quality
     * bmp.SaveToFile("photo.jpg", "JPEG", 85)
     */
    SaveToFile(filepath, format := "", quality := 100) {
        local ext := "", clsid, encParams, status
        if (!this.ptr)
            return false
        if (format == "") {
            SplitPath(filepath, , , &ext)
            format := (ext != "") ? ext : "PNG"
        }
        clsid := GdipBitmap.GetEncoderClsid(format)
        encParams := GdipBitmap.GetEncoderParams(format, quality)
        status := DllCall("gdiplus\GdipSaveImageToFile", "ptr", this.ptr, "wstr", filepath, "ptr", clsid, "ptr", encParams)
        return (status == 0)
    }

    ; Convenient alias for SaveToFile
    ToFile(filepath, format := "", quality := 100) => this.SaveToFile(filepath, format, quality)

    /**
     * Exports the bitmap to a binary memory Buffer in the specified format (PNG, JPEG, BMP, GIF, TIFF).
     *
     * @param {String} [format="PNG"] Compressed format: "PNG", "JPEG", "BMP", "GIF", "TIFF"
     * @param {Integer} [quality=100] JPEG compression quality (0 - 100)
     * @returns {Buffer|Integer} Memory Buffer containing compressed file bytes, or 0 on failure
     *
     * @example
     * ; Export to PNG buffer in RAM
     * pngBuf := bmp.ToMemory("PNG")
     * FileOpen("saved.png", "w").RawWrite(pngBuf)
     */
    ToMemory(format := "PNG", quality := 100) {
        local pStream := 0, hGlobal := 0, pMem, size, outBuf, clsid, encParams
        if (!this.ptr)
            return 0

        DllCall("ole32\CreateStreamOnHGlobal", "ptr", 0, "int", 1, "ptr*", &pStream:=0)
        if (!pStream)
            return 0

        clsid := GdipBitmap.GetEncoderClsid(format)
        if (!clsid) {
            ObjRelease(pStream)
            return 0
        }
        encParams := GdipBitmap.GetEncoderParams(format, quality)

        DllCall("gdiplus\GdipSaveImageToStream", "ptr", this.ptr, "ptr", pStream, "ptr", clsid, "ptr", encParams)

        hGlobal := 0
        DllCall("ole32\GetHGlobalFromStream", "ptr", pStream, "ptr*", &hGlobal:=0)
        if (!hGlobal) {
            ObjRelease(pStream)
            return 0
        }

        size := DllCall("GlobalSize", "ptr", hGlobal, "uptr")
        pMem := DllCall("GlobalLock", "ptr", hGlobal, "ptr")

        outBuf := Buffer(size, 0)
        DllCall("RtlMoveMemory", "ptr", outBuf.ptr, "ptr", pMem, "uptr", size)

        DllCall("GlobalUnlock", "ptr", hGlobal)
        ObjRelease(pStream)

        return outBuf
    }

    /**
     * Copies the Bitmap to the Windows Clipboard in standard CF_DIB and CF_BITMAP formats.
     *
     * @returns {Boolean} True on success, False on failure
     *
     * @example
     * ; Capture screen and copy directly to clipboard
     * GdipBitmap.FromScreen().ToClipboard()
     */
    ToClipboard() {
        local hBitmap := 0, oi, hdib, pdib, off1, off2, imgSize, pBits
        if (!this.ptr)
            return false

        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", this.ptr, "ptr*", &hBitmap:=0, "uint", 0x00FFFFFF)
        if (!hBitmap)
            return false

        if (!DllCall("OpenClipboard", "ptr", 0)) {
            DllCall("DeleteObject", "ptr", hBitmap)
            return false
        }

        DllCall("EmptyClipboard")

        off1 := 52
        off2 := 32
        oi := Buffer(104, 0)
        DllCall("GetObject", "ptr", hBitmap, "int", oi.size, "ptr", oi)

        imgSize := NumGet(oi, off1, "uint")
        if (!imgSize) {
            ; Fallback: compute stride * height
            imgSize := NumGet(oi, 12, "uint") * Abs(NumGet(oi, 8, "int"))
        }

        pBits := NumGet(oi, off2 - A_PtrSize, "ptr")

        hdib := DllCall("GlobalAlloc", "uint", 2, "uptr", 40 + imgSize, "ptr") ; GMEM_MOVEABLE = 2
        if (hdib) {
            pdib := DllCall("GlobalLock", "ptr", hdib, "ptr")
            if (pdib) {
                DllCall("RtlMoveMemory", "ptr", pdib, "ptr", oi.ptr + off2, "uptr", 40)
                NumPut("uint", imgSize, pdib, 20) ; Ensure biSizeImage is set
                if (pBits && imgSize > 0)
                    DllCall("RtlMoveMemory", "ptr", pdib + 40, "ptr", pBits, "uptr", imgSize)
                DllCall("GlobalUnlock", "ptr", hdib)
                DllCall("SetClipboardData", "uint", 8, "ptr", hdib) ; CF_DIB = 8
            }
        }

        ; Place CF_BITMAP on clipboard for universal compatibility across Windows apps
        DllCall("SetClipboardData", "uint", 2, "ptr", hBitmap) ; CF_BITMAP = 2

        DllCall("CloseClipboard")
        return true
    }

    /**
     * Converts the bitmap into formatted ASCII art text.
     *
     * @param {Integer} [targetW=80] Output character columns / width
     * @param {Integer} [targetH] Output character rows / height (auto aspect-corrected if omitted)
     * @param {String}  [ramp=" .:-=+*#@"] Luminance character brightness ramp (darkest to brightest)
     * @param {Boolean} [colored=false] If true, embeds GpGFX/Console rich text color tags: {color:0xRRGGBB}
     * @param {Boolean} [doubleChar=false] If true, doubles each character horizontally (e.g. "@@")
     * @returns {String} Formatted ASCII art string
     *
     * @example
     * ; Generate 80-column ASCII art string
     * asciiText := bmp.ToASCII(80)
     *
     * ; Generate colored ASCII art for rich text display
     * coloredAscii := bmp.ToASCII(60, , " .:-=+*#@", true, true)
     */
    ToASCII(targetW := 80, targetH?, ramp := " .:-=+*#@", colored := false, doubleChar := false) {
        local outW, outH, srcBmp, bmData, scan0, stride, rampLen, strOut := ""
        local y, x, ARGB, a, r, g, b, lum, idx, ch, row, isCloned := false
        local pSmallBmp := 0, pGfx := 0

        if (!this.ptr || this.w <= 0 || this.h <= 0)
            return ""

        outW := Max(1, Integer(targetW))
        if (IsSet(targetH)) {
            outH := Max(1, Integer(targetH))
        }
        else {
            ; Monospace characters in standard fonts are ~2:1 vertical-to-horizontal aspect ratio
            outH := Max(1, Round(outW * (this.h / this.w) * (doubleChar ? 1.0 : 0.5)))
        }

        ; If dimensions match, sample directly; otherwise create downscaled working bitmap
        if (outW == this.w && outH == this.h) {
            srcBmp := this
        }
        else {
            DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", outW, "int", outH, "int", outW * 4, "int", 0x26200A, "ptr", 0, "ptr*", &pSmallBmp:=0)
            if (!pSmallBmp)
                return ""
            DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pSmallBmp, "ptr*", &pGfx:=0)
            DllCall("gdiplus\GdipSetInterpolationMode", "ptr", pGfx, "int", 7) ; HighQualityBicubic
            DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", pGfx, "ptr", this.ptr, "int", 0, "int", 0, "int", outW, "int", outH, "int", 0, "int", 0, "int", this.w, "int", this.h, "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGfx)

            srcBmp := { base: GdipBitmap.Prototype, ptr: pSmallBmp, w: outW, h: outH }
            isCloned := true
        }

        bmData := srcBmp.LockBits(0, 0, outW, outH, 0x26200A, 1) ; 32bppARGB, Read mode
        if (!bmData) {
            if (isCloned)
                srcBmp.Dispose()
            return ""
        }

        scan0 := bmData.scan0
        stride := bmData.stride
        rampLen := StrLen(ramp)

        loop outH {
            y := A_Index - 1
            row := ""
            loop outW {
                x := A_Index - 1
                ARGB := NumGet(scan0, x * 4 + y * stride, "uint")
                a := (ARGB >> 24) & 0xFF
                if (a < 32) {
                    ch := doubleChar ? "  " : " "
                }
                else {
                    r := (ARGB >> 16) & 0xFF
                    g := (ARGB >> 8) & 0xFF
                    b := ARGB & 0xFF
                    ; Standard ITU-R BT.601 perceptual luminance
                    lum := (r * 299 + g * 587 + b * 114) // 1000
                    idx := Max(1, Min(rampLen, Ceil((lum + 1) * rampLen / 256.0)))
                    ch := SubStr(ramp, idx, 1)
                    if (doubleChar)
                        ch := ch . ch
                    if (colored)
                        ch := "{color:" . Format("0xFF{:02X}{:02X}{:02X}", r, g, b) . "}" . ch
                }
                row .= ch
            }
            strOut .= (strOut == "" ? "" : "`n") . row
        }

        srcBmp.UnlockBits(bmData)
        if (isCloned)
            srcBmp.Dispose()

        return strOut
    }

    /**
     * Resolves the static GDI+ image encoder CLSID buffer for the requested format.
     *
     * @param {String} [format="PNG"] Image format name: "PNG", "JPEG", "JPG", "BMP", "GIF", "TIFF"
     * @returns {Buffer} 16-byte CLSID struct buffer
     */
    static GetEncoderClsid(format := "PNG") {
        local fmt, buf
        static clsids := Map(
            "BMP",  "{557cf400-1a04-11d3-9a73-0000f81ef32e}",
            "JPEG", "{557cf401-1a04-11d3-9a73-0000f81ef32e}",
            "JPG",  "{557cf401-1a04-11d3-9a73-0000f81ef32e}",
            "GIF",  "{557cf402-1a04-11d3-9a73-0000f81ef32e}",
            "TIFF", "{557cf405-1a04-11d3-9a73-0000f81ef32e}",
            "PNG",  "{557cf406-1a04-11d3-9a73-0000f81ef32e}"
        )
        fmt := StrUpper(format)
        if (!clsids.Has(fmt))
            fmt := "PNG"
        buf := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", clsids[fmt], "ptr", buf)
        return buf
    }

    /**
     * Packs an EncoderParameters struct buffer for JPEG compression quality.
     * Returns 0 for non-JPEG formats where quality parameters are not applicable.
     *
     * @param {String} [format="PNG"] Image format name ("JPEG", "JPG", "PNG", etc.)
     * @param {Integer} [quality=100] JPEG compression quality (0 - 100)
     * @returns {Buffer|Integer} Packed EncoderParameters buffer or 0
     */
    static GetEncoderParams(format := "PNG", quality := 100) {
        local fmt, guidOffset, valOffset, buf, q
        fmt := StrUpper(format)
        if (fmt != "JPEG" && fmt != "JPG")
            return 0
        guidOffset := A_PtrSize
        valOffset := guidOffset + 24 + A_PtrSize
        buf := Buffer(valOffset + 8, 0)
        NumPut("uint", 1, buf, 0) ; Count = 1
        DllCall("ole32\CLSIDFromString", "wstr", "{1D5BE4B5-FA4A-452D-9CDD-5DB35105E7EB}", "ptr", buf.ptr + guidOffset) ; EncoderQuality GUID
        NumPut("uint", 1, buf, guidOffset + 16) ; NumberOfValues = 1
        NumPut("uint", 4, buf, guidOffset + 20) ; Type = 4 (EncoderParameterValueTypeLong)
        q := (quality < 0) ? 0 : (quality > 100) ? 100 : Integer(quality)
        NumPut("uint", q, buf, valOffset) ; Quality value
        NumPut("ptr", buf.ptr + valOffset, buf, guidOffset + 24) ; Value pointer
        return buf
    }

    /**
     * Pre-compiles this bitmap into a high-speed GDI+ CachedBitmap targeted to a Graphics context or Layer.
     * Pre-rendering converts pixel data to the native format of the display device (~2x-3x faster blitting).
     *
     * @param {Graphics|Layer|Ptr} gfx Target Graphics context, Layer, or native pGraphics pointer
     * @returns {CachedBitmap}
     *
     * @example
     * cached := bmp.GetCached(myLayer)
     * cached.Draw(myLayer, 100, 100)
     */
    GetCached(gfx) => CachedBitmap(this, gfx)

    /**
     * Draws this bitmap onto the target graphics surface.
     *
     * @param {Graphics|Layer|Ptr} gfx Target Graphics context, Layer, or native pGraphics pointer
     * @param {Integer} [x=0] Destination X
     * @param {Integer} [y=0] Destination Y
     * @param {Integer} [w] Destination Width (defaults to native width)
     * @param {Integer} [h] Destination Height (defaults to native height)
     * @returns {Integer} GDI+ status code (0 = success)
     */
    Draw(gfx, x := 0, y := 0, w?, h?) {
        local pGfx, dstW, dstH
        pGfx := (IsObject(gfx)) ? ((gfx is Layer) ? gfx.gfx.ptr : (gfx.ptr || gfx)) : gfx
        dstW := IsSet(w) ? w : this.w
        dstH := IsSet(h) ? h : this.h
        if (!this.ptr || !pGfx)
            return 2
        if (IsSet(w) || IsSet(h)) {
            return DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", pGfx, "ptr", this.ptr
                , "int", Round(x), "int", Round(y), "int", Round(dstW), "int", Round(dstH)
                , "int", 0, "int", 0, "int", this.w, "int", this.h
                , "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)
        }
        return DllCall("gdiplus\GdipDrawImage", "ptr", pGfx, "ptr", this.ptr, "float", Float(x), "float", Float(y))
    }

    /**
     * Releases the native GDI+ bitmap handle and frees its memory.
     *
     * @returns {void}
     */
    Dispose() {
        local pBitmap
        if (!this.ptr)
            return
        pBitmap := this.ptr
        this.ptr := 0
        if (Gdip.pToken) {
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
            GpGFX.DebugLog("[-] Bitmap deleted " pBitmap "`n")
        }
    }

    __Delete() => this.Dispose()
}

; Convenient aliases for GdipBitmap
GdiBitmap := GdipBitmap
GpImage := GdipBitmap

/**
 * GDI+ CachedBitmap class for ultra-high-speed static sprite and layer blitting.
 * Pre-renders and compiles a Bitmap into the native pixel format of the target Device Context (2x - 3x faster than standard DrawImage calls).
 */
class CachedBitmap {
    ptr := 0
    w   := 0
    h   := 0

    /**
     * Pre-compiles a GDI+ Bitmap into the native pixel format of the target Graphics DC.
     *
     * @constructor
     * @param {GdipBitmap|Ptr} bmp Source GdipBitmap instance or native pBitmap pointer
     * @param {Graphics|Layer|Ptr} gfx Target Graphics context, Layer instance, or native pGraphics pointer
     *
     * @example
     * ; Compile a static sprite for fast blitting onto a layer
     * sprite := GdipBitmap("character.png")
     * cachedSprite := CachedBitmap(sprite, mainLayer)
     *
     * ; Inside render loop:
     * cachedSprite.Draw(mainLayer, 100, 100)
     */
    __New(bmp, gfx) {
        local pBmp, pGfx, pCached
        pBmp := (IsObject(bmp)) ? (bmp.ptr || bmp) : bmp
        pGfx := (IsObject(gfx)) ? ((gfx is Layer) ? gfx.gfx.ptr : (gfx.ptr || gfx)) : gfx
        pCached := 0

        if (pBmp && pGfx) {
            DllCall("gdiplus\GdipCreateCachedBitmap", "ptr", pBmp, "ptr", pGfx, "ptr*", &pCached:=0)
            this.ptr := pCached
            this.w := (IsObject(bmp) && (bmp.w || 0)) ? bmp.w : 0
            this.h := (IsObject(bmp) && (bmp.h || 0)) ? bmp.h : 0
        }
    }

    /**
     * Blits the pre-compiled cached bitmap directly to the target graphics DC.
     *
     * @param {Graphics|Layer|Ptr} gfx Target Graphics context or Layer instance
     * @param {Integer} [x=0] X position on destination surface
     * @param {Integer} [y=0] Y position on destination surface
     * @returns {Integer} GDI+ status code (0 = success)
     */
    Draw(gfx, x := 0, y := 0) {
        local pGfx := (IsObject(gfx)) ? ((gfx is Layer) ? gfx.gfx.ptr : (gfx.ptr || gfx)) : gfx
        if (this.ptr && pGfx) {
            return DllCall("gdiplus\GdipDrawCachedBitmap", "ptr", pGfx, "ptr", this.ptr, "int", Round(x), "int", Round(y))
        }
        return 2 ; InvalidParameter
    }

    /**
     * Releases the native GDI+ cached bitmap handle.
     */
    Dispose() {
        if (this.ptr) {
            local p := this.ptr
            this.ptr := 0
            if (Gdip.pToken) {
                try DllCall("gdiplus\GdipDeleteCachedBitmap", "ptr", p)
            }
        }
    }

    __Delete() => this.Dispose()
}

/**
 * Pre-defined 5x5 Color Matrices for high-speed hardware-accelerated color filtering.
 */
class ColorMatrix {

    static matrices := Map()

    ; Preset accessors for common color filters
    static bright => this.get("bright")
    static grayscale => this.get("grayscale")
    static negative => this.get("negative")
    static sepia => this.get("sepia")
    static invert => this.get("invert")
    static redonly => this.get("redonly")
    static greenonly => this.get("greenonly")
    static blueonly => this.get("blueonly")

    /**
     * Retrieves or compiles a 100-byte 5x5 float matrix buffer by preset name.
     * Built on-demand to keep startup memory footprint at zero.
     *
     * @param {String} name Preset filter name ("bright", "grayscale", "negative", "sepia", "invert", "redonly", "greenonly", "blueonly")
     * @returns {Buffer} 100-byte matrix buffer
     */
    static get(name) {
        local buf, normName := StrLower(Trim(name))
        if (this.matrices.Has(normName))
            return this.matrices[normName]

        buf := Buffer(100, 0)
        switch normName {
            case "bright", "b":
                NumPut("float", 1.5,   "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf,  0)
                NumPut("float", 0,     "float", 1.5,   "float", 0,     "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0,     "float", 0,     "float", 1.5,   "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 0.05,  "float", 0.05,  "float", 0.05,  "float", 0,    "float", 1.0, buf, 80)

            case "grayscale", "gray", "g":
                NumPut("float", 0.299, "float", 0.299, "float", 0.299, "float", 0,    "float", 0,   buf,  0)
                NumPut("float", 0.587, "float", 0.587, "float", 0.587, "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0.114, "float", 0.114, "float", 0.114, "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 1.0, buf, 80)

            case "negative", "neg", "n", "invert", "i":
                NumPut("float", -1.0,  "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf,  0)
                NumPut("float", 0,     "float", -1.0,  "float", 0,     "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0,     "float", 0,     "float", -1.0,  "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 1.0,   "float", 1.0,   "float", 1.0,   "float", 0,    "float", 1.0, buf, 80)

            case "sepia", "s":
                NumPut("float", 0.393, "float", 0.349, "float", 0.272, "float", 0,    "float", 0,   buf, 0)
                NumPut("float", 0.769, "float", 0.686, "float", 0.534, "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0.189, "float", 0.168, "float", 0.131, "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 1.0, buf, 80)

            case "redonly", "red", "r":
                NumPut("float", 1.0,   "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf,  0)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 1.0, buf, 80)

            case "greenonly", "green", "gonly":
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf,  0)
                NumPut("float", 0,     "float", 1.0,   "float", 0,     "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 1.0, buf, 80)

            case "blueonly", "blue", "bonly":
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf,  0)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 0,   buf, 20)
                NumPut("float", 0,     "float", 0,     "float", 1.0,   "float", 0,    "float", 0,   buf, 40)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 1.0,  "float", 0,   buf, 60)
                NumPut("float", 0,     "float", 0,     "float", 0,     "float", 0,    "float", 1.0, buf, 80)

            default:
                throw ValueError("[!] Invalid color matrix name: " . name)
        }

        return (this.matrices[normName] := buf)
    }

}