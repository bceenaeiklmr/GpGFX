; Script:    Layer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2

/**
 * GpGFX Layer & LayerStack engine
 *
 * Core layered window composition and render coordinator for GpGFX.
 *
 * Capabilities:
 * - Direct Win32 Layered Window creation (WS_EX_LAYERED, WS_POPUP, CS_DBLCLKS).
 * - High-speed DIBSection graphics backing with zero-copy GDI+ memory mapping.
 * - Reactive Signal binding and frame pacing (Interval, One-shot, Toast, QPC Render).
 * - Multi-monitor positioning (WorkArea, Primary, Next, Prev, Virtual Screen spanning).
 * - Window attachment, tracking, desktop pinning (Rainmeter-style Progman ownership), and dragging.
 * - Shape lifecycle registration, dirty bounding box culling, and interactive event dispatch.
 *
 * Acknowledgments and redits:
 * - iseahound (TextRender / ImagePut): Native C-callback WindowProc dispatcher,
 *   RegisterClassExW architecture, and per-pixel UpdateLayeredWindow pipeline.
 *   https://github.com/iseahound/TextRender
 */

/**
 * Global coordinator and Z-order manager for all active GpGFX layers.
 */
class LayerStack {

    static pointers := Map()
    static history := []
    static activeId := 1
    static activePtr := 0
    static rootHwnd := 0

    /**
     * Gets or sets the currently active foreground GpGFX layer instance.
     * @type {Layer|Integer}
     */
    static ActiveLayer {
        get => (this.activePtr) ? ObjFromPtrAddRef(this.activePtr) : 0
        set {
            local ptr
            if (value) {
                ptr := ObjPtr(value)
                this.activePtr := ptr
                this.PushHistory(ptr)
                Layer.w := value.w
                Layer.h := value.h
                Layer.x := value.x
                Layer.y := value.y
            } else {
                this.activePtr := 0
            }
        }
    }

    /**
     * Pushes a layer pointer to the top of the activation history stack.
     *
     * @param {Integer} ptr Object pointer
     * @returns {void}
     */
    static PushHistory(ptr) {
        loop this.history.Length {
            if (this.history[A_Index] == ptr) {
                this.history.RemoveAt(A_Index)
                break
            }
        }
        this.history.Push(ptr)
    }

    /**
     * Removes a layer pointer from the activation history stack and updates activePtr.
     *
     * @param {Integer} ptr Object pointer
     * @returns {void}
     */
    static PopHistory(ptr) {
        loop this.history.Length {
            if (this.history[A_Index] == ptr) {
                this.history.RemoveAt(A_Index)
                break
            }
        }
        if (this.activePtr == ptr) {
            this.activePtr := (this.history.Length) ? this.history[this.history.Length] : 0
        }
    }

    /**
     * Registers a new layer instance with the global LayerStack.
     *
     * @param {Layer} layerObj The layer instance
     * @returns {void}
     */
    static Register(layerObj) {
        local ptr := ObjPtr(layerObj)
        this.pointers[layerObj.id] := ptr
        if (this.rootHwnd == 0)
            this.rootHwnd := layerObj.hwnd
        this.ActiveLayer := layerObj
        GpGFX.DebugLog("[i] Layer registered [ID: " layerObj.id ", Ptr: " ptr "]`n")
    }

    /**
     * Unregisters a layer by ID and detaches its pointer tracking.
     *
     * @param {Integer} id Layer ID
     * @returns {void}
     */
    static Unregister(id) {
        local ptr
        if this.pointers.Has(id) {
            ptr := this.pointers[id]
            this.pointers.Delete(id)
            this.PopHistory(ptr)
            if (this.pointers.Count == 0)
                this.rootHwnd := 0
            if (Gdip.pToken)
                GpGFX.DebugLog("[i] Layer unregistered [ID: " id "]`n")
        }
    }

    /**
     * Swaps the visual Z-order and stack position of two layers.
     *
     * @param {Layer} layer1 First layer
     * @param {Layer} layer2 Second layer
     * @returns {void}
     *
     * @example
     * LayerStack.Swap(lyrBackground, lyrForeground)
     */
    static Swap(layer1, layer2) {
        if (!IsObject(layer1) || !IsObject(layer2) || !layer1.hwnd || !layer2.hwnd)
            return

        local ptr1 := ObjPtr(layer1), ptr2 := ObjPtr(layer2)
        local idx1 := 0, idx2 := 0
        loop LayerStack.history.Length {
            if (LayerStack.history[A_Index] == ptr1)
                idx1 := A_Index
            else if (LayerStack.history[A_Index] == ptr2)
                idx2 := A_Index
        }

        ; Swap OS window Z-order (SWP_NOSIZE 1 | SWP_NOMOVE 2 | SWP_NOACTIVATE 0x10 = 0x0013)
        if (idx1 > idx2) {
            DllCall("user32\SetWindowPos", "ptr", layer1.hwnd, "ptr", layer2.hwnd, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
        } else {
            DllCall("user32\SetWindowPos", "ptr", layer2.hwnd, "ptr", layer1.hwnd, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
        }

        ; Swap tracking positions in LayerStack history
        if (idx1 && idx2) {
            LayerStack.history[idx1] := ptr2
            LayerStack.history[idx2] := ptr1
        }
    }

    /**
     * Instantly hides all active layer windows and enables click-through transparency.
     * Used during unhandled exceptions / errors so the user is never locked out of clicking.
     *
     * @returns {void}
     */
    static HideAll() {
        local id, ptr, layerObj
        for id, ptr in this.pointers.Clone() {
            try {
                layerObj := ObjFromPtrAddRef(ptr)
                if (IsObject(layerObj) && layerObj.hwnd && DllCall("user32\IsWindow", "ptr", layerObj.hwnd)) {
                    layerObj.ClickThrough := true
                    DllCall("user32\ShowWindow", "ptr", layerObj.hwnd, "int", 0) ; SW_HIDE
                }
                layerObj := ""
            }
        }
    }

    /**
     * Safely disposes all active layers, shapes, and font caches before Gdiplus shutdown.
     *
     * @returns {void}
     */
    static DisposeAll() {
        local id, ptr, layerObj
        GpGFX.DebugLog("[i] LayerStack: Disposing all active layers and resources...`n")

        ; Clone the map keys to allow safe unregistering during iteration
        for id, ptr in this.pointers.Clone() {
            try {
                layerObj := ObjFromPtrAddRef(ptr)
                layerObj.Dispose()
                layerObj := ""
            }
        }
        this.pointers.Clear()
        this.history := []
        this.activePtr := 0
        this.rootHwnd := 0

        ; Flush all cached fonts and font brushes
        Font.DisposeAll()
        GpGFX.DebugLog("[+] LayerStack: Cleanup complete.`n")
    }
}

/**
 * Represents a layered transparent canvas window with a dedicated GDI+ Graphics context.
 *
 * @credit iseahound (TextRender / ImagePut WindowProc & RegisterClass architecture)
 */
class Layer {

    ; Native Win32 Window Class & Window Procedure
    static className := "GpGFX_Layer"
    static pWndProc := 0

    ; Active layer dimensions for shape auto-centering during shape construction
    static w := A_ScreenWidth
    static h := A_ScreenHeight
    static x := 0
    static y := 0

    ; Default graphics quality for rendering GDI+ objects on new layers ("low", "mid", "high")
    static DefaultQuality := "mid"

    ; Internal fields
    drawSequence   := []
    signalSequence := []
    shapes         := []
    shapeMap       := Map()
    events         := Map()
    attachedLayers := []
    
    isDirtyBounds  := true
    isDisposed     := false
    
    Static         := false
    draggable      := false
    alpha          := 0xFF
    gfx            := 0
    hwnd           := 0
    textQuality    := 0
    setting        := 0

    __alpha        := 255
    __quality      := "mid"
    __updateFreq   := 0
    __redraw       := false
    __visible      := true
    __clickThrough := false
    __async        := false
    workerId       := 0

    __drawTimer    := 0
    __followTimer  := 0
    __followHwnd   := 0
    __desktopMouseTimer := 0

    __isDragging   := false
    __dragStartX   := 0
    __dragStartY   := 0
    __dragWinX     := 0
    __dragWinY     := 0
    __hoveredShapeId := 0
    __pressedShapeId := 0

    nextId         := 1
    id             := 0
    name           := ""

    x              := 0
    y              := 0
    w              := 0
    h              := 0
    width          := 0
    height         := 0
    x1             := 0
    y1             := 0
    x2             := 0
    y2             := 0

    /**
     * Registers the Win32 custom WindowClass with high-DPI support.
     *
     * @returns {String} Class name "GpGFX_Layer"
     */
    static RegisterClass() {
        if (this.pWndProc)
            return this.className

        ; Set Per-Monitor V2 DPI Awareness Context
        try DllCall("user32\SetProcessDpiAwarenessContext", "ptr", -4, "int")

        this.pWndProc := CallbackCreate(Layer_WindowProc, "F", 4)
        local wc := Buffer(80, 0)
        local hInst := DllCall("GetModuleHandle", "ptr", 0, "ptr")
        local hCursor := DllCall("LoadCursor", "ptr", 0, "ptr", 32512, "ptr") ; IDC_ARROW

        ; WNDCLASSEXW struct (80 bytes)
        NumPut(
            "uint", 80,                         ; cbSize
            "uint", 0x0008,                     ; style: CS_DBLCLKS
            "ptr",  this.pWndProc,              ; lpfnWndProc
            "int",  0,                          ; cbClsExtra
            "int",  8,                          ; cbWndExtra (holds ObjPtr(this))
            "ptr",  hInst,                      ; hInstance
            "ptr",  0,                          ; hIcon
            "ptr",  hCursor,                    ; hCursor
            "ptr",  0,                          ; hbrBackground
            "ptr",  0,                          ; lpszMenuName
            "ptr",  StrPtr(this.className),     ; lpszClassName
            "ptr",  0,                          ; hIconSm
            wc
        )

        DllCall("RegisterClassExW", "ptr", wc, "ushort")
        return this.className
    }

    /**
     * Creates a new GpGFX layered transparent window canvas.
     *
     * @param {Integer|String} [x] Screen X position, or single string for layer name, or width
     * @param {Integer} [y] Screen Y position, or height when width is provided in first param
     * @param {Integer|String} [w] Width in pixels, or layer name
     * @param {Integer} [h] Height in pixels
     * @param {String} [name=""] Optional friendly identifier for debugging
     * @param {Integer} [hOwner=0] Optional Win32 parent/owner window handle
     *
     * @example
     * ; 1. Fullscreen layer:
     * lyr := Layer()
     *
     * ; 2. Centered canvas (800x600):
     * lyr := Layer(800, 600)
     *
     * ; 3. Explicit positioning:
     * lyr := Layer(100, 100, 400, 300, "HUD")
     */
    __New(x?, y?, w?, h?, name := "", hOwner := 0) {
        local ownerHwnd

        ; Case 1: Layer("LayerName") or Layer()
        if (IsSet(x) && !IsSet(y) && !IsSet(w) && !IsSet(h)) {
            if (x is String)
                name := x
            else if (x is Integer && WinExist(x))
                hOwner := x
            else
                throw Error("Invalid argument for Layer constructor.")
            w := A_ScreenWidth
            h := A_ScreenHeight
            x := 0
            y := 0
        }
        ; Case 2: Layer(w, h, "LayerName") or Layer(w, h)
        else if (IsSet(x) && IsSet(y) && (!IsSet(w) || w is String) && !IsSet(h)) {
            w := x
            h := y
            x := (A_ScreenWidth  - w) // 2
            y := (A_ScreenHeight - h) // 2
            name := (IsSet(w) && w is String) ? w : name
        }
        ; Case 3: Layer(x, y, w, h, name, hOwner) or partial coordinates
        else {
            w := IsSet(w) ? w : A_ScreenWidth
            h := IsSet(h) ? h : A_ScreenHeight
            x := IsSet(x) ? x : (A_ScreenWidth  - w) // 2
            y := IsSet(y) ? y : (A_ScreenHeight - h) // 2
            name := name
        }

        this.x := Round(x)
        this.y := Round(y)
        this.w := Round(w)
        this.h := Round(h)
        this.width  := this.w
        this.height := this.h

        this.x1 := 0
        this.y1 := 0
        this.x2 := 0
        this.y2 := 0

        this.id := LayerStack.activeId++
        this.name := (name == "") ? "Layer" this.id : name
        this.gfx := Graphics(this.w, this.h)

        this.Redraw := false
        this.Visible := true
        this.UpdateFreq := 0
        this.Quality := Layer.DefaultQuality
        this.setting := 0

        ; Register custom WindowClass (iseahound architecture)
        Layer.RegisterClass()

        ; Create raw Win32 layered popup window
        ; WS_EX_LAYERED (0x80000) | WS_EX_TOOLWINDOW (0x80) | WS_EX_TOPMOST (0x8)
        static dwExStyle := 0x00080088
        static dwStyle   := 0x80000000 ; WS_POPUP

        ownerHwnd := (hOwner) ? hOwner : ((LayerStack.rootHwnd && DllCall("user32\IsWindow", "ptr", LayerStack.rootHwnd)) ? LayerStack.rootHwnd : 0)

        this.hwnd := DllCall("CreateWindowExW"
            , "uint", dwExStyle
            , "str",  Layer.className
            , "str",  this.name
            , "uint", dwStyle
            , "int",  this.x
            , "int",  this.y
            , "int",  this.w
            , "int",  this.h
            , "ptr",  ownerHwnd
            , "ptr",  0
            , "ptr",  DllCall("GetModuleHandle", "ptr", 0, "ptr")
            , "ptr",  0
            , "ptr")

        ; Store ObjPtr(this) in the window's extra bytes for 0 ns WindowProc object lookup
        DllCall("SetWindowLongPtr", "ptr", this.hwnd, "int", 0, "ptr", ObjPtr(this), "ptr")

        ; Show window in inactive state
        DllCall("user32\ShowWindow", "ptr", this.hwnd, "int", 4) ; SW_SHOWNOACTIVATE

        LayerStack.Register(this)
        LayerStack.ActiveLayer := this
        GpGFX.DebugLog("[+] Layer created: " this.name " [ID: " this.id "]`n")
    }

    /**
     * Explicit disposal method that frees graphics contexts, shapes, and destroys the native OS window.
     *
     * @returns {void}
     */
    Dispose() {
        local oldShapes, shp

        if (this.isDisposed)
            return
        this.isDisposed := true

        this.Stop()
        this.StopFollowing()
        this.__disableDesktopMouseTracking()

        ; Detach from LayerStack
        LayerStack.Unregister(this.id)
        if (LayerStack.rootHwnd == this.hwnd)
            LayerStack.rootHwnd := 0

        ; Detach and notify all registered shapes
        oldShapes := this.shapes
        this.shapes := []
        this.shapeMap.Clear()
        this.drawSequence := []
        this.__hoveredShapeId := 0
        this.__pressedShapeId := 0

        for shp in oldShapes {
            try {
                shp.layerPtr := 0
                shp.Dispose()
            }
        }

        ; Explicitly delete the graphics context (HDC, HBITMAP, GDI+ Graphics)
        if (this.gfx) {
            this.gfx.Dispose()
            this.gfx := 0
        }

        ; Destroy the native Win32 window immediately
        if (this.hwnd) {
            DllCall("SetWindowLongPtrW", "ptr", this.hwnd, "int", 0, "ptr", 0, "ptr")
            DllCall("user32\DestroyWindow", "ptr", this.hwnd)
            this.hwnd := 0
        }

        if (Gdip.pToken)
            GpGFX.DebugLog("[-] Layer disposed: " this.name " [ID: " this.id "]`n")
    }

    __Delete() => this.Dispose()

    ; Properties & Attributes

    /**
     * Overall opacity/alpha of the layered window (0 - 255, 0.0 - 1.0, or "50%").
     * @type {Integer|Float|String}
     */
    Alpha {
        get => this.__alpha
        set {
            switch Type(value) {
                case "Integer": value := (value <= 255 && value >= 0) ? value : 0
                case "Float": value := (value > 1.0 ? 255 : value < 0.0 ? 0 : Ceil(value * 255))
                case "String":
                    if (value ~= "^\d+\s?%$")
                        this.__alpha := Ceil((SubStr(value, 1, -1) / 100) * 255)
                    else if (value ~= "^\d+\.\d*$")
                        this.__alpha := (value > 1.0 ? 255 : value < 0.0 ? 0 : Ceil(value * 255))
                    else if (value ~= "^\d+$")
                        this.__alpha := (value <= 255 && value >= 0) ? value : 0
                default:
                    return
            }
            this.__alpha := value
        } 
    }

    /**
     * Multi-core background worker execution mode.
     * When true, assigns a dedicated CPU worker process via WorkerPool.
     * @type {Boolean}
     */
    Async {
        get => this.__async
        set {
            if (value) {
                if (!WorkerPool.isInitialized)
                    WorkerPool.Init()
                this.workerId := WorkerPool.AssignWorker(this)
                this.__async := true
            } else {
                this.__async := false
                this.workerId := 0
            }
        }
    }

    /**
     * Steps dynamic simulation on the assigned background CPU worker core.
     *
     * @param {Float} [dt=0.03] Delta time
     * @returns {void}
     */
    Step(dt := 0.03) {
        if (this.Async && this.workerId) {
            WorkerPool.StepWorker(this.workerId, dt)
        }
    }

    /**
     * Graphics Quality Preset ("low", "mid", "high").
     * - "low"  / 0 : High-speed rendering (Smoothing: None, PixelOffset: None, Interp: Default)
     * - "mid"  / 1 : Balanced default (Smoothing: AntiAlias, PixelOffset: None/Integer, Interp: Bicubic)
     * - "high" / 2 : Ultra-smooth presentation (Smoothing: AntiAlias, PixelOffset: Half, Interp: HighQualityBicubic)
     * @type {String}
     */
    Quality {
        get => this.__quality
        set {
            local v := value
            if (v is Integer) {
                v := (v <= 0) ? "low" : (v == 1) ? "mid" : "high"
            }
            else if (v is String) {
                v := StrLower(Trim(v))
                switch v, 0 {
                    case "fast", "low", "speed":
                        v := "low"
                    case "high", "quality", "best", "hq":
                        v := "high"
                    default:
                        v := "mid"
                }
            }
            else {
                v := "mid"
            }
            this.__quality := v
            this.setting := 0  ; Invalidate cached GDI+ rasterization state to force re-application on next draw
        }
    }

    /**
     * Fluent setter for graphics quality preset.
     *
     * @param {String|Integer} [quality="mid"] Preset: "low" (0), "mid" (1), or "high" (2)
     * @returns {Layer} this (for method chaining)
     */
    SetQuality(quality := "mid") {
        this.Quality := quality
        return this
    }

    UpdateFreq {
        get => this.__updateFreq
        set => (value >= 0) ? this.__updateFreq := value : 0
    }

    Redraw {
        get => this.__redraw
        set => (value == true || value == false) ? this.__redraw := value : 0
    }

    Visible {
        get => this.__visible
        set => (value == true || value == false) ? this.__visible := value : 0
    }

    /**
     * Gets the active screen DPI for this layer window.
     * @type {Integer}
     */
    Dpi {
        get {
            static DEF_DPI := 96
            if (this.hwnd) {
                try return DllCall("user32\GetDpiForWindow", "ptr", this.hwnd, "uint")
            }
            try return DllCall("user32\GetDpiForSystem", "uint")
            return DEF_DPI
        }
    }

    /**
     * Gets the scaling factor relative to 96 DPI (e.g. 1.25 for 120 DPI).
     * @type {Float}
     */
    DpiScale => this.Dpi / 96.0

    /**
     * Enables or disables mouse click-through transparency (WS_EX_TRANSPARENT).
     * When true, all mouse clicks and gestures pass directly to windows underneath.
     * @type {Boolean}
     */
    ClickThrough {
        get => this.__clickThrough
        set {
            static GWL_EXSTYLE := -20
            static WS_EX_TRANSPARENT := 0x20
            if (!this.hwnd || value == this.__clickThrough || (value !== 0 && value !== 1))
                return
            this.__clickThrough := !!value
            local exStyle := DllCall("GetWindowLongPtrW", "ptr", this.hwnd, "int", GWL_EXSTYLE, "ptr")
            if (this.__clickThrough)
                exStyle |= WS_EX_TRANSPARENT
            else
                exStyle &= ~WS_EX_TRANSPARENT
            DllCall("SetWindowLongPtrW", "ptr", this.hwnd, "int", GWL_EXSTYLE, "ptr", exStyle, "ptr")
        }
    }

    ; Drawing & Frame Pacing

    /**
     * Clears all registered shapes and resets layer sequence for immediate redraw.
     *
     * @returns {Layer} this
     */
    Clear() {
        local oldShapes, shp

        oldShapes := this.shapes
        this.shapes := []
        this.shapeMap.Clear()
        this.drawSequence := []
        this.__hoveredShapeId := 0
        this.__pressedShapeId := 0
        this.isDirtyBounds := true

        for shp in oldShapes {
            shp.layerPtr := 0
            try shp.Dispose()
        }
        return this
    }

    /**
     * Renders the layer to the screen. Supports single-shot renders, auto-dismiss toasts,
     * recurring frame/clock loops, or reactive Signal binding.
     * 
     * @param {Integer|Boolean|Signal} [trigger] 
     *   - Omitted: Single immediate render.
     *   - Negative Integer: Immediate render + auto-destroy after `Abs(trigger)` ms (e.g. `lyr.Draw(-1500)` -> 1.5s Toast).
     *   - Positive Integer: Recurring interval loop in ms (e.g. `lyr.Draw(1000, updateFn)` -> Clock).
     *   - Signal: Reactive data binding — auto-redraws whenever the signal changes value.
     *   - 0 or False: Stops any active recurring loop on this layer.
     * @param {Function} [updateFn] Optional callback executed before each frame render:
     *   - For interval loops: `fn(layer)`
     *   - For reactive signals: `fn(signalValue, layer)`
     * @returns {Layer} this (for chaining)
     * 
     * @example
     * ; 1. Single immediate render:
     * lyr.Draw()
     * 
     * @example
     * ; 2. Ephemeral notification toast (auto-destroys after 1500 ms):
     * lyr.Draw(-1500)
     * 
     * @example
     * ; 3. Recurring clock/HUD loop (updates every second):
     * lyr.Draw(1000, (l) => txt.Text(FormatTime(, "HH:mm:ss")))
     * 
     * @example
     * ; 4. Reactive Signal binding (auto-redraws when sigHealth.Value changes):
     * sigHealth := Signal(100)
     * lyr.Draw(sigHealth, (hp, l) => healthBar.w := hp * 3)
     * 
     * @example
     * ; 5. Synchronous modal (blocks script until timeout or layer is closed):
     * lyr.Draw().Wait(2000)
     */
    Draw(trigger?, updateFn?) {
        ; 1. Reactive Signal binding
        if (IsSet(trigger) && IsObject(trigger) && trigger.HasMethod("Subscribe")) {
            this.Bind(trigger, updateFn?)
            Draw(this)
            return this
        }

        ; 2. Single-shot render
        Draw(this)

        if (!IsSet(trigger))
            return this

        ; 3. Stop recurring loop
        if (trigger == 0 || trigger == false) {
            this.Stop()
            return this
        }

        ; 4. Negative interval: render immediately and auto-destroy after Abs(trigger) ms (e.g. lyr.Draw(-1000) -> 1s Toast)
        if (trigger is Integer && trigger < 0) {
            this.Timeout(Abs(trigger))
            return this
        }

        ; 5. Recurring timed interval loop
        if (trigger is Integer && trigger > 0) {
            this.Stop()
            local loopCallback := () => (
                (!this || this.isDisposed || !WinExist(this.hwnd)) ? this.Stop() :
                (IsSet(updateFn) && (updateFn)(this), Draw(this))
            )
            this.__drawTimer := loopCallback
            SetTimer(loopCallback, trigger)
        }

        return this
    }

    /**
     * Renders all active layers in the LayerStack in their current Z-order.
     *
     * @returns {void}
     */
    static Draw() {
        local id, ptr, layerObj
        for id, ptr in LayerStack.pointers {
            layerObj := ObjFromPtrAddRef(ptr)
            Draw(layerObj)
            layerObj := ""
        }
    }

    /**
     * Halts script execution synchronously (keeps GUI responsive) until the layer is closed or timeout expires.
     * 
     * @param {Integer} [timeoutMs=0] Timeout in milliseconds (0 = wait indefinitely until closed/destroyed)
     * @param {Boolean} [destroyAfter=false] If true, automatically destroys the layer after the wait completes
     * @returns {Layer} this (for chaining)
     * 
     * @example
     * ; Display a splash screen, pause script execution for 2 seconds, then auto-destroy:
     * lyr.Draw().Wait(2000, true)
     * 
     * @example
     * ; Display a modal popup dialog and block until the user clicks a button / closes it:
     * lyr.Draw().Wait()
     */
    Wait(timeoutMs := 0, destroyAfter := false) {
        local start := A_TickCount
        while (this.hwnd && WinExist(this.hwnd) && !this.isDisposed) {
            if (timeoutMs > 0 && (A_TickCount - start) >= timeoutMs)
                break
            Sleep(15)
        }
        if (destroyAfter && !this.isDisposed)
            this.Dispose()
        return this
    }

    /**
     * Renders the layer using high-precision QueryPerformanceCounter (QPC) timing,
     * native MCode spin-waits, and FPS overlay synchronization.
     *
     * @returns {Layer} this (for chaining)
     */
    Render() {
        Render.Layer(this)
        return this
    }

    /**
     * Schedules a deferred 1-shot render after `afterMs`.
     *
     * @param {Integer} afterMs Delay before rendering in milliseconds
     * @param {Function} [updateFn] Optional callback executed before rendering
     * @returns {Layer} this (for chaining)
     */
    DrawOnce(afterMs, updateFn?) {
        if (afterMs > 0) {
            SetTimer(() => (
                (!this || this.isDisposed || !WinExist(this.hwnd)) ? 0 :
                (IsSet(updateFn) && (updateFn)(this), Draw(this))
            ), -afterMs)
        }
        return this
    }

    /**
     * Binds a reactive Signal to auto-redraw the layer whenever the signal value changes.
     *
     * @param {Signal} sig The Signal instance to watch
     * @param {Function} [updateFn] Optional callback fn(val, layer) executed before rendering
     * @returns {Layer} this (for chaining)
     */
    Bind(sig, updateFn?) {
        if (IsObject(sig) && sig.HasMethod("Subscribe")) {
            sig.Subscribe((val) => (
                (!this || this.isDisposed || !WinExist(this.hwnd)) ? 0 :
                (IsSet(updateFn) && (updateFn)(val, this), Draw(this))
            ))
        }
        return this
    }

    /**
     * Stops any active recurring draw loop on this layer.
     *
     * @returns {Layer} this
     */
    Stop() {
        if (this.__drawTimer) {
            SetTimer(this.__drawTimer, 0)
            this.__drawTimer := 0
        }
        return this
    }

    /**
     * Automatically disposes the layer after a specified timeout duration.
     * Perfect for temporary toast notifications, popups, and HUD alerts.
     *
     * @param {Integer} ms Milliseconds before the layer is destroyed
     * @returns {Layer} this
     */
    Timeout(ms) {
        if (ms > 0)
            SetTimer(() => (!this || this.isDisposed ? 0 : this.Dispose()), -ms)
        return this
    }

    /**
     * Marks layer bounding box as dirty to force bounds re-calculation on next frame.
     *
     * @returns {Boolean}
     */
    Invalidate() => (this.isDirtyBounds := true)

    /**
     * Clears the layered window by setting alpha to zero via UpdateLayeredWindow.
     *
     * @credit iseahound (TextRender UpdateLayeredWindow pipeline)
     * @returns {void}
     */
    Clean() {
        DllCall("UpdateLayeredWindow"
            ,    "ptr", this.hwnd                ; hWnd
            ,    "ptr", 0                        ; hdcDst
            ,    "ptr", 0                        ; *pptDst
            ,    "ptr", 0                        ; *psize
            ,    "ptr", 0                        ; hdcSrc
            ,    "ptr", 0                        ; *pptSrc
            ,   "uint", 0                        ; crKey
            ,  "uint*", 0 << 16 | 0x01 << 24     ; *pblend
            ,   "uint", 2                        ; dwFlags
            ,    "int")                          ; Success = 1
    }

    /**
     * Prepares the layer for drawing by calculating the bounding box of all visible shapes.
     * This is used to optimize rendering and clipping.
     *
     * @returns {Integer} The length of the draw sequence array (number of drawable shapes)
     */
    Prepare() {
        local w, h, x1, y1, x2, y2, shp, tool, extra, sx, sy, sw, sh, sig

        ; If layer is frozen or static and already prepared once, reuse bounds
        if (this.Static && this.drawSequence.Length)
            return this.drawSequence.Length

        ; Execute active signals before calculating bounds
        if (this.signalSequence.Length) {
            for sig in this.signalSequence {
                (sig.fn)(sig.shp, sig.params*)
            }
        }

        ; Initialize variables for layer bounds
        static DIBsize := 32767
        x1 :=  DIBsize
        y1 :=  DIBsize
        x2 := -DIBsize
        y2 := -DIBsize

        ; Clear draw sequence array without reallocating its capacity
        this.drawSequence.Length := 0

        ; Calculate the bounds of the layer
        for shp in this.shapes {
            if (!shp.Visible)
                continue

            ; Get bounds of dynamic shapes that don't have static x, y, w, h
            if (shp.HasProp("getBounds") && IsObject(shp.getBounds))
                shp.getBounds()

            ; Account for pen stroke thickness/alignment so outer borders never clip
            tool := shp.Tool
            extra := (tool && tool.type == 5)
                ? (tool.Mode == 2 ? Integer(tool.width)
                :  tool.Mode == 0 ? (Integer(tool.width) + 1) // 2
                :  0)
                : 0

            sx := shp.x - extra
            sy := shp.y - extra
            sw := shp.w + (extra * 2)
            sh := shp.h + (extra * 2)

            (sx < x1) && x1 := sx
            (sy < y1) && y1 := sy
            (sx + sw > x2) && x2 := sx + sw
            (sy + sh > y2) && y2 := sy + sh

            this.drawSequence.Push(shp)
        }

        if (!this.drawSequence.Length)
            return 0
        
        ; Calculate and clamp bounds to layer DIB boundaries [0, gfx.w] and [0, gfx.h]
        x1 := Max(0, x1)
        y1 := Max(0, y1)
        x2 := Min(this.gfx.w, x2)
        y2 := Min(this.gfx.h, y2)

        this.x1 := Integer(x1)
        this.y1 := Integer(y1)
        this.x2 := Integer(x2)
        this.y2 := Integer(y2)
        this.width  := Integer(Max(1, x2 - x1))
        this.height := Integer(Max(1, y2 - y1))

        this.isDirtyBounds := false
        return this.drawSequence.Length
    }

    /**
     * Configures GDI+ rasterization and anti-aliasing parameters based on shape category and layer quality preset.
     * 
     * @param {String} shapeCategory "Rectangle" (axis-aligned boxes) or "Curved" (lines, arcs, polygons, circles)
     * @returns {void}
     */
    GraphicsQuality(shapeCategory) {
        local gfx := this.gfx.ptr
        if (!gfx)
            return

        switch shapeCategory, 0 {
            case "Rectangle":
                switch this.__quality, 0 {
                    case "low":
                        if (this.setting == 100)
                            return
                        this.setting := 100
                        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 3)      ; SmoothingModeNone (3)
                        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 0)    ; PixelOffsetModeDefault (0)
                        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 0)  ; InterpolationModeDefault (0)

                    case "high":
                        if (this.setting == 102)
                            return
                        this.setting := 102
                        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)      ; SmoothingModeAntiAlias (4)
                        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 4)    ; PixelOffsetModeHalf (4)
                        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7)  ; HighQualityBicubic (7)

                    default: ; "mid"
                        if (this.setting == 101)
                            return
                        this.setting := 101
                        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 3)      ; SmoothingModeNone (3)
                        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 0)    ; PixelOffsetModeDefault (0)
                        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 5)  ; Bicubic (5)
                }

            default: ; "Curved" (Line, Lines, Polygon, Triangle, Circle, Ellipse, Arc, Bezier, Curve, etc.)
                switch this.__quality, 0 {
                    case "low":
                        if (this.setting == 200)
                            return
                        this.setting := 200
                        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 3)      ; SmoothingModeNone (3)
                        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 0)    ; PixelOffsetModeDefault (0)
                        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 0)  ; InterpolationModeDefault (0)

                    case "high":
                        if (this.setting == 202)
                            return
                        this.setting := 202
                        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)      ; SmoothingModeAntiAlias (4)
                        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 4)    ; PixelOffsetModeHalf (4)
                        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7)  ; HighQualityBicubic (7)

                    default: ; "mid"
                        if (this.setting == 201)
                            return
                        this.setting := 201
                        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)      ; SmoothingModeAntiAlias (4)
                        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 0)    ; PixelOffsetModeDefault (0)
                        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 5)  ; Bicubic (5)
                }
        }
    }

    /**
     * Debugs a layer by drawing visual bounding box overlays around the full DIB and used content area.
     *
     * @param {Integer} [seconds=1] Duration in seconds before the debug layer auto-destroys
     * @param {Integer} [filled=0] Whether to fill the rectangles (0 = outline, 1 = filled)
     * @param {Integer} [alpha=0x60] Transparency of the debug overlays
     * @returns {void}
     */
    Debug(seconds := 1, filled := 0, alpha := 0x60) {
        local rect1, rect2, lyr
        
        this.Prepare()
        lyr := Layer(this.x, this.y, this.w, this.h)
       
        rect1 := Rectangle(0, 0, this.w, this.h, "blue")
        rect2 := Rectangle(this.x1, this.y1, this.width, this.height, "red", filled)
        rect1.Text("Layer DIB size", "black", 42)
        rect2.Text("Layer used size", "black", 21)
        rect1.alpha := alpha
        rect2.alpha := alpha

        lyr.Draw(-seconds * 1000)
    }

    ; Positioning, Motion & Window Transforms

    /**
     * Moves and resizes the layered window on screen.
     * Strings with leading '+' or '-' (e.g. "+8", "-5") increment or decrement values.
     *
     * @param {Integer|String} [x] New X coordinate or offset
     * @param {Integer|String} [y] New Y coordinate or offset
     * @param {Integer|String} [w] New width or offset
     * @param {Integer|String} [h] New height or offset
     * @returns {Layer} this (for method chaining)
     */
    Move(x?, y?, w?, h?) {
        static calc(current, val) {
            if (val is String) {
                local firstChr := SubStr(Trim(val), 1, 1)
                if (firstChr == "+" || firstChr == "-")
                    return current + val
            }
            return val + 0
        }

        local changedPos := false, changedSize := false
        if (IsSet(x)) {
            this.x := calc(this.x, x)
            changedPos := true
        }
        if (IsSet(y)) {
            this.y := calc(this.y, y)
            changedPos := true
        }
        if (IsSet(w)) {
            this.w := calc(this.w, w)
            changedSize := true
        }
        if (IsSet(h)) {
            this.h := calc(this.h, h)
            changedSize := true
        }

        if (this.hwnd && DllCall("user32\IsWindow", "ptr", this.hwnd)) {
            local flags := 0x0014 ; SWP_NOZORDER (4) | SWP_NOACTIVATE (0x10)
            if (!changedSize)
                flags |= 0x0001   ; SWP_NOSIZE (1) -> 0x0015
            if (!changedPos)
                flags |= 0x0002   ; SWP_NOMOVE (2)
            DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", Integer(this.x), "int", Integer(this.y), "int", Integer(this.w), "int", Integer(this.h), "uint", flags)
            this.SyncAttachedLayers()
        }
        return this
    }

    /**
     * Resizes the layer and re-allocates its underlying Graphics surface.
     *
     * @param {Integer} w New width
     * @param {Integer} h New height
     * @returns {Layer} this (for method chaining)
     */
    Resize(w, h) {
        if (w == this.w && h == this.h && this.gfx)
            return this
        if (IsObject(this.gfx) && this.gfx.HasMethod("Dispose"))
            this.gfx.Dispose()
        this.gfx := ""
        this.gfx := Graphics(w, h)
        this.w := w
        this.h := h
        this.Prepare()
        return this
    }

    /**
     * Centers the layer on the primary display.
     *
     * @returns {Layer} this (for method chaining)
     */
    Center() {
        local sw, sh
        sw := DllCall("user32\GetSystemMetrics", "int", 0, "int")  ; SM_CXSCREEN
        sh := DllCall("user32\GetSystemMetrics", "int", 1, "int")  ; SM_CYSCREEN
        this.x := (sw - this.w) // 2
        this.y := (sh - this.h) // 2
        if (this.hwnd && DllCall("user32\IsWindow", "ptr", this.hwnd)) {
            ; SWP_NOSIZE (0x0001) | SWP_NOZORDER (0x0004) | SWP_NOACTIVATE (0x0010)
            DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", this.x, "int", this.y, "int", 0, "int", 0, "uint", 0x0015)
            this.SyncAttachedLayers()
        }
        return this
    }

    /**
     * Shows the layer window without stealing keyboard/mouse focus.
     *
     * @returns {Layer} this
     */
    Show() {
        DllCall("ShowWindow", "ptr", this.hwnd, "int", 4) ; SW_SHOWNOACTIVATE = 4
        this.visible := 1
        return this
    }

    /**
     * Hides the layer window without destroying it.
     *
     * @returns {Layer} this
     */
    Hide() {
        DllCall("ShowWindow", "ptr", this.hwnd, "int", 0) ; SW_HIDE = 0
        this.visible := 0
        return this
    }

    /**
     * Toggles the visibility of the layer window.
     *
     * @returns {Layer} this
     */
    ShowHide() {
        (this.visible) ? this.Hide() : this.Show()
        return this
    }

    /**
     * Activates and focuses the layer window for interactive inputs.
     *
     * @returns {Layer} this
     */
    Activate() {
        local exStyle := DllCall("GetWindowLongW", "ptr", this.hwnd, "int", -20, "uint")
        if (exStyle & 0x08000000) {
            DllCall("SetWindowLongW", "ptr", this.hwnd, "int", -20, "uint", exStyle & ~0x08000000)
        }
        DllCall("user32\ShowWindow", "ptr", this.hwnd, "int", 5) ; SW_SHOW
        DllCall("user32\SetForegroundWindow", "ptr", this.hwnd)
        DllCall("user32\SetActiveWindow", "ptr", this.hwnd)
        try WinActivate("ahk_id " . this.hwnd)
        return this
    }

    /**
     * Sets the layer window to be always on top or removes topmost flag.
     *
     * @param {Boolean} [v=true] True for topmost, false for normal
     * @returns {Layer} this
     */
    TopMost(v := true) {
        local insertAfter := (v) ? -1 : -2 ; HWND_TOPMOST (-1), HWND_NOTOPMOST (-2)
        DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", insertAfter, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
        return this
    }

    /**
     * Backward-compatible alias for TopMost.
     */
    AlwaysOnTop() => this.TopMost(true)

    /**
     * Enables or disables click-through transparency for the layer window.
     *
     * @param {Boolean} v True to enable click-through, False to disable
     * @returns {Layer} this
     */
    Clickthrough(v) {
        this.ClickThrough := v
        return this
    }

    /**
     * Prevents the layer window from stealing focus (WS_EX_NOACTIVATE).
     *
     * @returns {Layer} this
     */
    NoActivate() {
        local exStyle := DllCall("user32\GetWindowLongPtrW", "ptr", this.hwnd, "int", -20, "ptr")
        DllCall("user32\SetWindowLongPtrW", "ptr", this.hwnd, "int", -20, "ptr", exStyle | 0x08000000)
        return this
    }

    /**
     * Swaps the visual desktop Z-order and stack position of this layer with another layer.
     *
     * @param {Layer} otherLayer The layer to swap Z-order with
     * @returns {Layer} this
     */
    Swap(otherLayer) {
        LayerStack.Swap(this, otherLayer)
        return this
    }

    /**
     * Attaches a child layer to this parent layer so it moves and stays locked to it.
     * Sets Win32 window ownership so child layer always floats above parent without Z-fighting.
     *
     * @param {Layer} childLayer The child layer to lock to this parent
     * @param {Integer} [xOffset=0] Horizontal offset relative to parent
     * @param {Integer} [yOffset=0] Vertical offset relative to parent
     * @returns {Layer} this
     */
    Attach(childLayer, xOffset := 0, yOffset := 0) {
        if (!IsObject(childLayer) || !childLayer.HasProp("hwnd"))
            return this

        ; Set Win32 window owner (GWLP_HWNDPARENT = -8)
        DllCall("user32\SetWindowLongPtrW", "ptr", childLayer.hwnd, "int", -8, "ptr", this.hwnd)

        this.attachedLayers.Push({ layer: childLayer, xOff: xOffset, yOff: yOffset })
        childLayer.Move(this.x + xOffset, this.y + yOffset)
        return this
    }

    /**
     * Synchronizes positions of all attached child layers.
     *
     * @returns {void}
     */
    SyncAttachedLayers() {
        local item
        for item in this.attachedLayers {
            if (IsObject(item.layer) && WinExist(item.layer.hwnd)) {
                item.layer.Move(this.x + item.xOff, this.y + item.yOff)
            }
        }
    }

    /**
     * Initiates native Win32 window dragging, or enables draggable mode when chained during setup.
     *
     * @param {Boolean|Integer|Array|Func} [v] Optional drag setting; enables drag if omitted or at setup
     * @returns {Layer} this
     */
    Drag(v?) {
        local wx, wy
        if (IsSet(v)) {
            this.draggable := v
            return this
        }
        if (!GetKeyState("LButton", "P")) {
            this.draggable := true
            return this
        }
        DllCall("user32\ReleaseCapture")
        DllCall("user32\SendMessage", "ptr", this.hwnd, "uint", 0x00A1, "uptr", 2, "ptr", 0)
        if (WinExist(this.hwnd)) {
            WinGetPos(&wx, &wy, , , this.hwnd)
            this.x := wx
            this.y := wy
            this.SyncAttachedLayers()
        }
        return this
    }

    /**
     * Synchronizes layer (x, y) coordinates with the current OS window position.
     *
     * @returns {Layer} this
     */
    SyncPos() {
        local wx, wy
        if (WinExist(this.hwnd)) {
            WinGetPos(&wx, &wy, , , this.hwnd)
            this.x := wx
            this.y := wy
            this.SyncAttachedLayers()
        }
        return this
    }

    /**
     * Snaps this layer pixel-perfect to the visible frame of a target window.
     * Automatically compensates for Windows 10/11 invisible drop shadows.
     * Optionally tracks the target window continuously as it moves and resizes.
     *
     * @param {Integer|String} hwnd Target window handle (HWND) or title
     * @param {Integer} [xOffset=0] Horizontal offset in pixels
     * @param {Integer} [yOffset=0] Vertical offset in pixels
     * @param {Boolean} [resize=true] Whether to match the target window's visible width and height
     * @param {Boolean|Integer} [follow=false] If true or integer ms, continuously tracks the window
     * @returns {Layer} this
     */
    SnapToWindow(hwnd, xOffset := 0, yOffset := 0, resize := true, follow := false) {
        local targetHwnd := WinExist(hwnd)
        if (!targetHwnd)
            return this

        local rect := WinGetVisiblePos(targetHwnd)
        if (rect.w <= 0 || rect.h <= 0)
            return this

        local targetX := rect.x + xOffset
        local targetY := rect.y + yOffset

        if (resize) {
            if (rect.w != this.w || rect.h != this.h)
                this.Resize(rect.w, rect.h)
            this.Move(targetX, targetY)
        } else {
            this.Move(targetX, targetY)
        }

        if (follow) {
            local interval := (follow is Integer && follow > 0) ? follow : 16
            this.FollowWindow(targetHwnd, xOffset, yOffset, resize, interval)
        }

        return this
    }

    /**
     * Continuously tracks and follows a target window as it moves and resizes.
     * Automatically hides the layer when the target window is minimized, and restores when restored.
     *
     * @param {Integer|String} target Target window handle (HWND) or title
     * @param {Integer} [xOffset=0] Horizontal offset in pixels
     * @param {Integer} [yOffset=0] Vertical offset in pixels
     * @param {Boolean} [resize=true] Whether to match the target window's visible width and height
     * @param {Integer} [interval=16] Polling update frequency in milliseconds (default 16ms ~60fps)
     * @returns {Layer} this
     */
    FollowWindow(target, xOffset := 0, yOffset := 0, resize := true, interval := 16) {
        local targetHwnd := WinExist(target)
        if (!targetHwnd)
            return this

        this.StopFollowing()
        this.SnapToWindow(targetHwnd, xOffset, yOffset, resize, false)

        local lastX := this.x, lastY := this.y, lastW := this.w, lastH := this.h
        local lastMinMax := 0

        local followCallback := () => (
            (!this || this.isDisposed || !WinExist(this.hwnd)) ? this.StopFollowing() :
            (!WinExist(targetHwnd)) ? this.StopFollowing() :
            _syncFollow(targetHwnd, xOffset, yOffset, resize, &lastX, &lastY, &lastW, &lastH, &lastMinMax)
        )

        _syncFollow(tHwnd, xOff, yOff, shouldResize, &pX, &pY, &pW, &pH, &pMinMax) {
            local minMax := WinGetMinMax(tHwnd)
            if (minMax == -1) { ; Minimized
                if (pMinMax != -1) {
                    DllCall("user32\ShowWindow", "ptr", this.hwnd, "int", 0) ; SW_HIDE
                    pMinMax := -1
                }
                return
            } else if (pMinMax == -1) { ; Restored
                DllCall("user32\ShowWindow", "ptr", this.hwnd, "int", 8) ; SW_SHOWNA (NoActivate)
                pMinMax := minMax
            }

            local rect := WinGetVisiblePos(tHwnd)
            if (rect.w <= 0 || rect.h <= 0)
                return

            local targetX := rect.x + xOff
            local targetY := rect.y + yOff

            if (shouldResize) {
                if (rect.w != this.w || rect.h != this.h) {
                    this.Resize(rect.w, rect.h)
                    pW := rect.w, pH := rect.h
                }
            }

            if (targetX != this.x || targetY != this.y) {
                this.Move(targetX, targetY)
                pX := targetX, pY := targetY
            }
        }

        this.__followTimer := followCallback
        this.__followHwnd := targetHwnd
        SetTimer(followCallback, interval)
        return this
    }

    /**
     * Stops following any tracked window.
     *
     * @returns {Layer} this
     */
    StopFollowing() {
        if (this.__followTimer) {
            SetTimer(this.__followTimer, 0)
            this.__followTimer := 0
            this.__followHwnd := 0
        }
        return this
    }

    /**
     * Attaches this layer directly to the Windows Desktop (live wallpaper / background desktop widget).
     * Sits behind application windows and does not minimize on Win+D (Show Desktop).
     *
     * @param {String} [mode="Owner"] "Owner" (Rainmeter technique: sets Progman as Win32 owner, alpha & Win+D immune),
     *                                "WorkerW" (reparents into Explorer WorkerW canvas),
     *                                or "Bottom" (HWND_BOTTOM)
     * @returns {Layer} this
     */
    AttachToDesktop(mode := "Owner") {
        if (!WinExist(this.hwnd))
            return this

        local prevDHW := DetectHiddenWindows(true)
        local hProgman := DllCall("user32\FindWindowW", "wstr", "Progman", "ptr", 0, "ptr")
        if (!hProgman)
            hProgman := WinExist("ahk_class Progman")

        if (mode == "Owner" || mode == "BehindIcons" || mode == "Desktop" || mode == "Rainmeter") {
            DllCall("user32\SetParent", "ptr", this.hwnd, "ptr", 0)
            if (hProgman)
                DllCall("user32\SetWindowLongPtrW", "ptr", this.hwnd, "int", -8, "ptr", hProgman)
            DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 1, "int", this.x, "int", this.y, "int", this.w, "int", this.h, "uint", 0x0050)
            DetectHiddenWindows(prevDHW)
            return this
        }

        if (mode == "Bottom") {
            DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 1, "int", this.x, "int", this.y, "int", this.w, "int", this.h, "uint", 0x0050)
            DetectHiddenWindows(prevDHW)
            return this
        }

        ; Mode: WorkerW reparenting
        if (hProgman) {
            local result := 0
            DllCall("user32\SendMessageTimeoutW", "ptr", hProgman, "uint", 0x052C, "uptr", 0x0000000D, "ptr", 0, "uint", 0, "uint", 1000, "ptr*", &result)
        }

        local hDesktop := 0
        local wList := WinGetList("ahk_class WorkerW ahk_exe explorer.exe")
        if (wList.Length) {
            local wHwnd, hShell
            for wHwnd in wList {
                hShell := DllCall("user32\FindWindowExW", "ptr", wHwnd, "ptr", 0, "wstr", "SHELLDLL_DefView", "ptr", 0, "ptr")
                if (hShell) {
                    hDesktop := DllCall("user32\FindWindowExW", "ptr", 0, "ptr", wHwnd, "wstr", "WorkerW", "ptr", 0, "ptr")
                    break
                }
            }
            if (!hDesktop && wList.Length)
                hDesktop := wList[wList.Length]
        }

        if (!hDesktop)
            hDesktop := (hProgman) ? hProgman : DllCall("user32\GetDesktopWindow", "ptr")

        local style := DllCall("user32\GetWindowLongW", "ptr", this.hwnd, "int", -16, "uint")
        style := (style & ~0x00C00000)                ; Remove WS_CAPTION
        style := (style & ~0x00800000)                ; Remove WS_BORDER
        style := (style & ~0x80000000)                ; Remove WS_POPUP
        style := (style | 0x40000000 | 0x10000000)    ; Add WS_CHILD | WS_VISIBLE
        DllCall("user32\SetWindowLongW", "ptr", this.hwnd, "int", -16, "uint", style)

        DllCall("user32\SetParent", "ptr", this.hwnd, "ptr", hDesktop)
        DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", this.x, "int", this.y, "int", this.w, "int", this.h, "uint", 0x0054)

        try {
            local wallpaper := RegRead("HKEY_CURRENT_USER\Control Panel\Desktop", "Wallpaper")
            DllCall("user32\SystemParametersInfoW", "uint", 0x0014, "uint", 0, "str", wallpaper, "uint", 0)
        }

        this.__enableDesktopMouseTracking()
        DetectHiddenWindows(prevDHW)
        return this
    }

    /**
     * Alias for AttachToDesktop.
     */
    PinToDesktop(mode := "Owner") => this.AttachToDesktop(mode)

    /**
     * Detaches the layer from the Windows Desktop and restores it to a normal top-level window.
     *
     * @returns {Layer} this
     */
    DetachFromDesktop() {
        if (!WinExist(this.hwnd))
            return this
        this.__disableDesktopMouseTracking()
        DllCall("user32\SetWindowLongPtrW", "ptr", this.hwnd, "int", -8, "ptr", 0)
        local style := DllCall("user32\GetWindowLongW", "ptr", this.hwnd, "int", -16, "uint")
        style := (style & ~0x40000000) ; Remove WS_CHILD
        style := (style | 0x80000000 | 0x10000000) ; Add WS_POPUP | WS_VISIBLE
        DllCall("user32\SetWindowLongW", "ptr", this.hwnd, "int", -16, "uint", style)
        DllCall("user32\SetParent", "ptr", this.hwnd, "ptr", 0)
        DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", this.x, "int", this.y, "int", this.w, "int", this.h, "uint", 0x0054)
        return this
    }


    ; Monitor & Multi-Display


    /**
     * Retrieves the bounding box of the entire virtual multi-monitor desktop.
     *
     * @returns {Object} { x, y, w, h }
     */
    static GetVirtualScreen() {
        return {
            x: DllCall("GetSystemMetrics", "int", 76, "int"), ; SM_XVIRTUALSCREEN
            y: DllCall("GetSystemMetrics", "int", 77, "int"), ; SM_YVIRTUALSCREEN
            w: DllCall("GetSystemMetrics", "int", 78, "int"), ; SM_CXVIRTUALSCREEN
            h: DllCall("GetSystemMetrics", "int", 79, "int")  ; SM_CYVIRTUALSCREEN
        }
    }

    /**
     * Retrieves array of all monitor information objects.
     *
     * @returns {Array} Array of monitor info objects
     */
    static GetMonitors() => GetMonitorInfo()

    /**
     * Retrieves information for a specific monitor.
     *
     * @param {Integer|String} [disp=1] Monitor index (1, 2, ...) or "Primary"
     * @returns {Object} Monitor info object
     */
    static GetMonitor(disp := 1) {
        local monitor := GetMonitorInfo()
        if (!monitor.Length) {
            return { index : 1, name : "Default", isPrimary : true,
                x  : 0, y  : 0, w  : A_ScreenWidth, h  : A_ScreenHeight,
                wx : 0, wy : 0, ww : A_ScreenWidth, wh : A_ScreenHeight }
        }
        
        if (disp == "Primary" || disp == "primary" || disp == 0) {
            local m
            for m in monitor {
                if (m.isPrimary)
                    return m
            }
            return monitor[1]
        }

        local idx := Integer(disp)
        if (idx < 1)
            idx := 1
        else if (idx > monitor.Length)
            idx := monitor.Length
        return monitor[idx]
    }

    /**
     * Returns the monitor index that the center of this layer currently resides on.
     *
     * @returns {Integer} Monitor index (1-based)
     */
    GetCurrentMonitor() {
        local cx := this.x + this.w // 2
        local cy := this.y + this.h // 2
        local m
        for m in GetMonitorInfo() {
            if (cx >= m.x 
            && cx < m.x + m.w
            && cy >= m.y
            && cy < m.y + m.h)
                return m.index
        }
        return MonitorGetPrimary()
    }

    /**
     * Moves and positions the layer onto a specific monitor with flexible alignment.
     *
     * @param {Integer|String} [disp=1] Monitor index (1, 2, ...), "Primary", "Next", "Prev", or "Virtual"
     * @param {String} [align="center"] "center", "top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right", "fill"
     * @param {Boolean} [useWorkArea=true] Respect taskbars/work area
     * @returns {Layer} this (for chaining)
     */
    SetMonitor(disp := 1, align := "center", useWorkArea := true) {
        local mon, targetX, targetY, refX, refY, refW, refH

        if (disp = "virtual") {
            mon := Layer.GetVirtualScreen()
            refX := mon.x, refY := mon.y, refW := mon.w, refH := mon.h
        }
        else if (disp = "next") {
            local curMon := this.GetCurrentMonitor()
            local totalMon := MonitorGetCount()
            local nextMon := (curMon >= totalMon) ? 1 : (curMon + 1)
            mon := Layer.GetMonitor(nextMon)
            refX := (useWorkArea) ? mon.wx : mon.x
            refY := (useWorkArea) ? mon.wy : mon.y
            refW := (useWorkArea) ? mon.ww : mon.w
            refH := (useWorkArea) ? mon.wh : mon.h
        }
        else if (disp = "prev") {
            local curMon := this.GetCurrentMonitor()
            local totalMon := MonitorGetCount()
            local prevMon := (curMon <= 1) ? totalMon : (curMon - 1)
            mon := Layer.GetMonitor(prevMon)
            refX := (useWorkArea) ? mon.wx : mon.x
            refY := (useWorkArea) ? mon.wy : mon.y
            refW := (useWorkArea) ? mon.ww : mon.w
            refH := (useWorkArea) ? mon.wh : mon.h
        }
        else {
            mon := Layer.GetMonitor(disp)
            refX := (useWorkArea) ? mon.wx : mon.x
            refY := (useWorkArea) ? mon.wy : mon.y
            refW := (useWorkArea) ? mon.ww : mon.w
            refH := (useWorkArea) ? mon.wh : mon.h
        }

        switch StrLower(align) {
            case "topleft", "top-left", "tl":
                targetX := refX
                targetY := refY
            case "top", "topcenter", "top-center", "tc":
                targetX := refX + (refW - this.w) // 2
                targetY := refY
            case "topright", "top-right", "tr":
                targetX := refX + refW - this.w
                targetY := refY
            case "bottomleft", "bottom-left", "bl":
                targetX := refX
                targetY := refY + refH - this.h
            case "bottom", "bottomcenter", "bottom-center", "bc":
                targetX := refX + (refW - this.w) // 2
                targetY := refY + refH - this.h
            case "bottomright", "bottom-right", "br":
                targetX := refX + refW - this.w
                targetY := refY + refH - this.h
            case "left", "middleleft", "middle-left":
                targetX := refX
                targetY := refY + (refH - this.h) // 2
            case "right", "middleright", "middle-right":
                targetX := refX + refW - this.w
                targetY := refY + (refH - this.h) // 2
            case "fill", "fullscreen":
                this.x := refX
                this.y := refY
                this.Resize(refW, refH)
                if (this.hwnd && DllCall("user32\IsWindow", "ptr", this.hwnd)) {
                    DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", refX, "int", refY, "int", refW, "int", refH, "uint", 0x0014)
                }
                return this
            default: ; "center", "middle"
                targetX := refX + (refW - this.w) // 2
                targetY := refY + (refH - this.h) // 2
        }

        this.x := targetX
        this.y := targetY

        if (this.hwnd && DllCall("user32\IsWindow", "ptr", this.hwnd)) {
            ; SWP_NOSIZE (0x0001) | SWP_NOZORDER (0x0004) | SWP_NOACTIVATE (0x0010)
            DllCall("user32\SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", targetX, "int", targetY, "int", 0, "int", 0, "uint", 0x0015)
        }

        return this
    }

    ; Backward compatibility alias
    MoveToMonitor(disp := 1, align := "center", useWorkArea := true) => this.SetMonitor(disp, align, useWorkArea)

    /**
     * Saves the position and dimensions of the layer to an array or object.
     *
     * @param {Boolean} [arr=false] If true returns [x, y, w, h], otherwise {x, y, w, h}
     * @returns {Array|Object}
     */
    SavePos(arr := false) {
        return (arr) ? [this.x, this.y, this.w, this.h]
            : {x : this.x, y : this.y, w : this.w, h : this.h}
    }

    /**
     * Restores the position and dimensions of the layer from an array or object.
     *
     * @param {Array|Object} obj [x, y, w, h] or {x, y, w, h}
     * @returns {void}
     */
    RestorePos(obj) {
        if (obj is Array && obj.Length == 4) {
            this.x := obj[1], this.y := obj[2]
            this.w := obj[3], this.h := obj[4]
            return
        }
        (obj.HasOwnProp("x")) ? this.x := obj.x : 0
        (obj.HasOwnProp("y")) ? this.y := obj.y : 0
        (obj.HasOwnProp("w")) ? this.w := obj.w : 0
        (obj.HasOwnProp("h")) ? this.h := obj.h : 0
    }


    ; Shape Collection Management


    /**
     * Registers a shape instance into this layer's draw sequence.
     *
     * @param {Shape} shapeObj Shape instance
     * @returns {void}
     */
    Register(shapeObj) {
        shapeObj.id := this.nextId++
        shapeObj.layerPtr := ObjPtr(this)
        for sig in shapeObj.signals {
            this.signalSequence.Push(sig)
        }
        this.shapes.Push(shapeObj)
        this.shapeMap[shapeObj.id] := shapeObj
        this.drawSequence.Capacity := this.shapes.Length
        this.signalSequence.Capacity := this.shapes.Length
        this.isDirtyBounds := true
        GpGFX.DebugLog("[i] Shape registered in Layer '" this.name "' [ID: " shapeObj.id "]`n")
    }

    /**
     * Unregisters and removes a shape from this layer by its unique ID.
     *
     * @param {Integer} id Shape ID
     * @returns {void}
     */
    Unregister(id) {
        local shp, i
        if this.shapeMap.Has(id) {
            shp := this.shapeMap[id]
            this.shapeMap.Delete(id)
            if (shp.signals.Length && this.signalSequence.Length) {
                i := this.signalSequence.Length
                while (i > 0) {
                    if (this.signalSequence[i].shp == shp)
                        this.signalSequence.RemoveAt(i)
                    i -= 1
                }
            }
            loop this.shapes.Length {
                if (this.shapes[A_Index] == shp) {
                    this.shapes.RemoveAt(A_Index)
                    break
                }
            }
            this.isDirtyBounds := true
            if (Gdip.pToken)
                GpGFX.DebugLog("[i] Shape unregistered from Layer '" this.name "' [ID: " id "]`n")
        }
    }

    /**
     * Disposes and deletes all registered shapes on this layer.
     *
     * @returns {void}
     */
    DeleteShapes() {
        local shp
        for shp in this.shapes {
            try {
                shp.layerPtr := 0
                shp.Dispose()
            }
        }
        this.shapes := []
        this.shapeMap.Clear()
        this.drawSequence := []
    }


    ; Data, Pixel Sampling & Image Export


    /**
     * Gets the 32-bit ARGB color value of a pixel at (x, y) on this Layer.
     * Reads directly from DIB section memory.
     *
     * @param {Integer} x X coordinate (0-indexed)
     * @param {Integer} y Y coordinate (0-indexed)
     * @param {String} [outFormat="hex"] Output format: "hex" (0xAARRGGBB), "int", "rgb", "rgba"
     * @returns {Integer|String|Object} Pixel color
     */
    GetPixel(x, y, outFormat := "hex") {
        local argb, a, r, g, b
        if (!this.gfx || !this.gfx.pBits || x < 0 || y < 0 || x >= this.w || y >= this.h)
            return 0

        argb := NumGet(this.gfx.pBits, (Integer(y) * this.w + Integer(x)) * 4, "uint")

        switch StrLower(outFormat) {
            case "hex", "1":
                return itoARGB(argb)
            case "int", "uint", "0":
                return argb
            case "rgb", "4":
                return itoARGB(argb) 
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
                return itoARGB(argb)
        }
    }

    /**
     * Copies the current rendered Layer directly to the Windows Clipboard as CF_DIB.
     * Preserves full 32-bit ARGB transparency directly from the memory buffer.
     *
     * @param {Boolean} [cropToContent=false] If true, crops clipboard image to drawn shape bounding box
     * @returns {Boolean} True on success, False on failure
     */
    ToClipboard(cropToContent := false) {
        local pBitmap := 0, pCropped := 0, stride, finalBitmap, bmp, res := false
        if (!this.gfx || !this.gfx.ptr || !this.gfx.pBits)
            return false

        DllCall("gdiplus\GdipFlush", "ptr", this.gfx.ptr, "int", 1)
        stride := this.gfx.w * 4
        DllCall("gdiplus\GdipCreateBitmapFromScan0"
            , "int", this.gfx.w
            , "int", this.gfx.h
            , "int", stride
            , "int", 0x26200A ; PixelFormat32bppARGB
            , "ptr", this.gfx.pBits
            , "ptr*", &pBitmap:=0)

        if (!pBitmap)
            return false

        finalBitmap := pBitmap
        if (cropToContent && this.width > 0 && this.height > 0 && (this.width < this.gfx.w || this.height < this.gfx.h)) {
            if (DllCall("gdiplus\GdipCloneBitmapAreaI", "int", this.x1, "int", this.y1, "int", this.width, "int", this.height, "int", 0x26200A, "ptr", pBitmap, "ptr*", &pCropped:=0) == 0 && pCropped) {
                finalBitmap := pCropped
            }
        }

        bmp := { base: GdipBitmap.Prototype }
        bmp.ptr := finalBitmap
        bmp.w := (pCropped ? this.width : this.gfx.w)
        bmp.h := (pCropped ? this.height : this.gfx.h)

        res := bmp.ToClipboard()
        bmp.Dispose()
        if (pCropped && pCropped != pBitmap)
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)

        return res
    }

    /**
     * Exports the layer to an image file (PNG, JPG, BMP, GIF, TIFF).
     * Preserves full 32-bit ARGB transparency from the DIBSection memory buffer.
     *
     * @param {String} filepath Destination file path
     * @param {Boolean} [cropToContent=true] Crop to drawn shape bounding box
     * @returns {Boolean} True on success
     */
    toFile(filepath, cropToContent := true) {
        local pBitmap := 0, pCropped := 0, pCodec, ext, clsid, finalBitmap, result, stride, m

        if (!this.gfx || !this.gfx.ptr || !this.gfx.pBits)
            return false

        DllCall("gdiplus\GdipFlush", "ptr", this.gfx.ptr, "int", 1)
        stride := this.gfx.w * 4
        DllCall("gdiplus\GdipCreateBitmapFromScan0"
            , "int", this.gfx.w
            , "int", this.gfx.h
            , "int", stride
            , "int", 0x26200A ; PixelFormat32bppARGB
            , "ptr", this.gfx.pBits
            , "ptr*", &pBitmap:=0)

        if (!pBitmap)
            return false

        finalBitmap := pBitmap
        if (cropToContent && this.width > 0 && this.height > 0 && (this.width < this.gfx.w || this.height < this.gfx.h)) {
            if (DllCall("gdiplus\GdipCloneBitmapAreaI", "int", this.x1, "int", this.y1, "int", this.width, "int", this.height, "int", 0x26200A, "ptr", pBitmap, "ptr*", &pCropped:=0) == 0 && pCropped) {
                finalBitmap := pCropped
            }
        }

        clsid := "{557CF406-1A04-11D3-9A73-0000F81EF32E}" ; default PNG
        if (RegExMatch(filepath, "i)\.([a-z0-9]+)$", &m)) {
            switch StrLower(m[1]) {
                case "bmp", "dib": clsid := "{557CF400-1A04-11D3-9A73-0000F81EF32E}"
                case "jpg", "jpeg", "jpe", "jfif": clsid := "{557CF401-1A04-11D3-9A73-0000F81EF32E}"
                case "gif": clsid := "{557CF402-1A04-11D3-9A73-0000F81EF32E}"
                case "tif", "tiff": clsid := "{557CF405-1A04-11D3-9A73-0000F81EF32E}"
                case "png": clsid := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
            }
        }

        pCodec := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", clsid, "ptr", pCodec, "hresult")
        result := DllCall("gdiplus\GdipSaveImageToFile", "ptr", finalBitmap, "wstr", filepath, "ptr", pCodec, "ptr", 0)

        if (pCropped)
            DllCall("gdiplus\GdipDisposeImage", "ptr", pCropped)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)

        return (result == 0)
    }

    /**
     * Converts the entire current layer canvas into an ASCII art string.
     *
     * @param {Integer} [targetW=80] Output character columns / width
     * @param {Integer} [targetH] Output character rows / height (auto aspect-corrected if omitted)
     * @param {String}  [ramp=" .:-=+*#@"] Luminance character brightness ramp
     * @param {Boolean} [colored=false] Embed rich color tags
     * @param {Boolean} [doubleChar=false] Double characters horizontally
     * @returns {String} Formatted ASCII art string
     */
    ToASCII(targetW := 80, targetH?, ramp := " .:-=+*#@", colored := false, doubleChar := false) {
        local pBmp := 0, bmp, strOut
        if (!this.gfx || !this.gfx.hdc)
            return ""

        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", this.gfx.hbm, "ptr", 0, "ptr*", &pBmp:=0)
        if (!pBmp)
            return ""

        bmp := { base: GdipBitmap.Prototype, ptr: pBmp, w: this.w, h: this.h }
        strOut := bmp.ToASCII(targetW, targetH?, ramp, colored, doubleChar)
        bmp.Dispose()
        return strOut
    }


    ; Event Handling & Dragging Helpers


    /**
     * Registers a callback function for layer-level mouse/window events.
     *
     * @param {String} [eventName="Click"] "Click", "LeftMouseDown", "LeftMouseUp", "RightMouseDown", "RightMouseUp", "MouseMove", "MouseScroll", "MouseScrollUp", "MouseScrollDown"
     * @param {Function} [fn] Callback function fn(lyr, mx, my) or fn(params*)
     * @param {Array} params Additional parameters to pass to fn
     * @returns {Layer} this (for chaining)
     */
    OnEvent(eventName := "Click", fn?, params*) {
        local wrappedFn, maxP
        if (IsSet(fn)) {
            if (params.Length) {
                wrappedFn := ((lyr, mx, my) => (fn)(params*))
            } else if (HasProp(fn, "MaxParams")) {
                maxP := fn.MaxParams
                wrappedFn := (maxP == 0) ? ((lyr, mx, my) => (fn)())
                           : (maxP == 1) ? ((lyr, mx, my) => (fn)(lyr))
                           : (maxP == 2) ? ((lyr, mx, my) => (fn)(lyr, mx))
                           : fn
            } else {
                wrappedFn := fn
            }
            this.events[eventName] := wrappedFn
        } else {
            this.events.Delete(eventName)
        }
        return this
    }

    /**
     * Determines whether a click at client coordinates (mx, my) falls within the allowed draggable region.
     *
     * @param {Integer} mx Mouse X relative to layer client area
     * @param {Integer} my Mouse Y relative to layer client area
     * @returns {Boolean} True if click should initiate dragging
     */
    __IsDraggableHit(mx, my) {
        local drag := this.draggable
        if (!drag)
            return false

        if (drag == true || drag == 1 || drag == "all")
            return true

        if (IsNumber(drag))
            return (my >= 0 && my <= drag)

        if (HasMethod(drag))
            return !!(drag(this, mx, my))

        if (IsObject(drag) && drag.HasProp("x") && drag.HasProp("y") && drag.HasProp("w") && drag.HasProp("h"))
            return (mx >= drag.x && mx <= drag.x + drag.w && my >= drag.y && my <= drag.y + drag.h)

        if (drag is Array) {
            if (drag.Length == 4 && IsNumber(drag[1]) && IsNumber(drag[2]) && IsNumber(drag[3]) && IsNumber(drag[4]))
                return (mx >= drag[1] && mx <= drag[1] + drag[3] && my >= drag[2] && my <= drag[2] + drag[4])

            local item
            for item in drag {
                if (IsObject(item) && item.HasProp("x") && item.HasProp("y") && item.HasProp("w") && item.HasProp("h")) {
                    if (mx >= item.x && mx <= item.x + item.w && my >= item.y && my <= item.y + item.h)
                        return true
                } else if (item is Array && item.Length == 4) {
                    if (mx >= item[1] && mx <= item[1] + item[3] && my >= item[2] && my <= item[2] + item[4])
                        return true
                }
            }
        }

        return false
    }

    __enableDesktopMouseTracking() {
        if (this.__desktopMouseTimer)
            return
        local tracker := () => (
            (!this || this.isDisposed || !WinExist(this.hwnd)) ? this.__disableDesktopMouseTracking() :
            this.__pollDesktopMouse()
        )
        this.__desktopMouseTimer := tracker
        SetTimer(tracker, 30)
    }

    __disableDesktopMouseTracking() {
        if (this.__desktopMouseTimer) {
            SetTimer(this.__desktopMouseTimer, 0)
            this.__desktopMouseTimer := 0
        }
    }

    __pollDesktopMouse() {
        local pt := Buffer(8, 0)
        DllCall("user32\GetCursorPos", "ptr", pt)
        local sx := NumGet(pt, 0, "int")
        local sy := NumGet(pt, 4, "int")

        local mx := sx - this.x
        local my := sy - this.y

        local isInside := (mx >= 0 && mx <= this.w && my >= 0 && my <= this.h)
        if (isInside) {
            PostMessage(0x0200, 0, (my << 16) | (mx & 0xFFFF), , "ahk_id " this.hwnd)
        } else if (this.HasProp("__hoveredShapeId") && this.__hoveredShapeId) {
            PostMessage(0x02A3, 0, 0, , "ahk_id " this.hwnd)
        }
    }
}

/**
 * Native Win32 Window Procedure for all GpGFX Layers.
 * Direct C-callback dispatcher without AHK Gui wrapper overhead.
 *
 * @credit iseahound (TextRender / ImagePut)
 */
Layer_WindowProc(hwnd, uMsg, wParam, lParam) {
    static cursorPt := Buffer(8, 0)
    local ptr, self, mx, my, handled, shp, eventName, flags, curX, curY, newX, newY, evMap, hitShape, prevHovered, prevHoveredId, pressedId, hoverId, curHitId

    ; Retrieve the Layer instance bound to this specific HWND
    ptr := DllCall("GetWindowLongPtrW", "ptr", hwnd, "int", 0, "ptr")
    if (!ptr)
        return DllCall("DefWindowProcW", "ptr", hwnd, "uint", uMsg, "uptr", wParam, "ptr", lParam, "ptr")

    self := ObjFromPtrAddRef(ptr)

    ; WM_DISPLAYCHANGE (0x007E) - Monitor resolution or display DPI change
    if (uMsg == 0x007E) {
        Draw(self)
    }

    ; WM_MOUSEACTIVATE (0x0021) - Ensure mouse clicks are delivered immediately without OS delay
    if (uMsg == 0x0021) {
        return 1 ; MA_ACTIVATE = 1
    }

    ; WM_SETFOCUS (0x0007) - Layer window received focus
    if (uMsg == 0x0007) {
        if (self.events.Has("Focus"))
            try (self.events["Focus"])(self)
    }

    ; WM_SETCURSOR (0x0020) - Display hand cursor over interactive shapes and buttons
    if (uMsg == 0x0020) {
        hoverId := (self.HasProp("__hoveredShapeId") ? self.__hoveredShapeId : 0)
        if (hoverId && self.shapeMap.Has(hoverId)) {
            static hHandCursor := DllCall("user32\LoadCursorW", "ptr", 0, "ptr", 32649, "ptr") ; IDC_HAND = 32649
            DllCall("user32\SetCursor", "ptr", hHandCursor)
            return 1
        }
    }

    ; WM_WINDOWPOSCHANGED (0x0047) - Real-time coordinate synchronization during dragging (0 ns overhead)
    if (uMsg == 0x0047 && lParam) {
        flags := NumGet(lParam, 32, "uint")
        if !(flags & 0x0002) { ; SWP_NOMOVE = 0x0002
            curX := NumGet(lParam, 16, "int")
            curY := NumGet(lParam, 20, "int")
            if (Abs(self.x - curX) >= 2)
                self.x := curX
            if (Abs(self.y - curY) >= 2)
                self.y := curY
        }
    }

    ; WM_MOUSELEAVE (0x02A3) - Cursor left the layer window
    if (uMsg == 0x02A3) {
        prevHoveredId := (self.HasProp("__hoveredShapeId") ? self.__hoveredShapeId : 0)
        if (prevHoveredId && self.shapeMap.Has(prevHoveredId)) {
            prevHovered := self.shapeMap[prevHoveredId]
            if (prevHovered.eventMap && prevHovered.eventMap.Has("MouseLeave"))
                try (prevHovered.eventMap["MouseLeave"])(prevHovered, -1, -1)
        }
        self.__hoveredShapeId := 0
        self._trackingMouse := false
    }

    ; Map mouse events to clean callback names
    static msgEvents := Map(
        0x0201, "LeftMouseDown",
        0x0202, "LeftMouseUp",
        0x0203, "LeftMouseDoubleClick",
        0x0204, "RightMouseDown",
        0x0205, "RightMouseUp",
        0x0206, "RightMouseDoubleClick",
        0x0207, "MiddleMouseDown",
        0x0208, "MiddleMouseUp",
        0x0209, "MiddleMouseDoubleClick",
        0x020A, "MouseScroll",
        0x0200, "MouseMove"
    )

    if (msgEvents.Has(uMsg)) {
        eventName := msgEvents[uMsg]
        if (uMsg == 0x020A)
            eventName := (wParam & 0x80000000) ? "MouseScrollDown" : "MouseScrollUp"

        ; Signed 16-bit client coordinates
        mx := (lParam << 48 >> 48)
        my := (lParam << 32 >> 48)

        ; Ensure mouse tracking for WM_MOUSELEAVE
        if (!self.HasProp("_trackingMouse") || !self._trackingMouse) {
            static tmeSize := A_PtrSize == 8 ? 24 : 16
            static tme := Buffer(tmeSize, 0)
            NumPut("uint", tmeSize, tme, 0)     ; cbSize
            NumPut("uint", 0x00000002, tme, 4)  ; TME_LEAVE = 0x00000002
            NumPut("ptr", hwnd, tme, 8)         ; hwndTrack
            DllCall("user32\TrackMouseEvent", "ptr", tme)
            self._trackingMouse := true
        }

        ; Hit-test interactive shapes from top to bottom (reverse draw order)
        hitShape := ""
        if (self.shapes.Length) {
            loop self.shapes.Length {
                shp := self.shapes[self.shapes.Length - A_Index + 1]
                if (shp.Visible && mx >= shp.x && mx <= shp.x + shp.w && my >= shp.y && my <= shp.y + shp.h) {
                    if (shp.eventMap && shp.eventMap.Count) {
                        hitShape := shp
                        break
                    }
                }
            }
        }

        ; Handle Hover / MouseEnter / MouseLeave state transitions safely via IDs
        if (uMsg == 0x0200) { ; MouseMove
            prevHoveredId := (self.HasProp("__hoveredShapeId") ? self.__hoveredShapeId : 0)
            curHitId := hitShape ? hitShape.id : 0
            if (curHitId != prevHoveredId) {
                if (prevHoveredId && self.shapeMap.Has(prevHoveredId)) {
                    prevHovered := self.shapeMap[prevHoveredId]
                    if (prevHovered.eventMap && prevHovered.eventMap.Has("MouseLeave"))
                        try (prevHovered.eventMap["MouseLeave"])(prevHovered, mx, my)
                }
                if (hitShape && hitShape.eventMap && hitShape.eventMap.Has("MouseEnter")) {
                    try (hitShape.eventMap["MouseEnter"])(hitShape, mx, my)
                }
                self.__hoveredShapeId := curHitId
            }
        }

        handled := false

        ; Dispatch shape-level events
        if (hitShape && hitShape.eventMap) {
            evMap := hitShape.eventMap
            if (eventName == "LeftMouseDown") {
                self.__pressedShapeId := hitShape.id
                if (evMap.Has("LeftMouseDown")) {
                    handled := true
                    try (evMap["LeftMouseDown"])(hitShape, mx, my)
                } else if (evMap.Has("Click")) {
                    handled := true
                }
            } else if (eventName == "LeftMouseUp") {
                pressedId := (self.HasProp("__pressedShapeId") ? self.__pressedShapeId : 0)
                self.__pressedShapeId := 0
                if (pressedId && pressedId == hitShape.id && evMap.Has("Click")) {
                    handled := true
                    try (evMap["Click"])(hitShape, mx, my)
                }
                if (evMap.Has("LeftMouseUp")) {
                    handled := true
                    try (evMap["LeftMouseUp"])(hitShape, mx, my)
                }
            } else if (evMap.Has(eventName)) {
                handled := true
                try (evMap[eventName])(hitShape, mx, my)
            }
        }

        ; Layer-level event handlers
        if (self.events.Has(eventName)) {
            try (self.events[eventName])(self, mx, my)
        }

        ; Non-blocking continuous vector dragging
        if (self.draggable && !handled) {
            if (!handled && eventName == "LeftMouseDown") {
                if (self.__IsDraggableHit(mx, my)) {
                    self.__isDragging := true
                    DllCall("user32\GetCursorPos", "ptr", cursorPt)
                    self.__dragStartX := NumGet(cursorPt, 0, "int")
                    self.__dragStartY := NumGet(cursorPt, 4, "int")
                    self.__dragWinX := self.x
                    self.__dragWinY := self.y
                    DllCall("user32\SetCapture", "ptr", hwnd)
                    handled := true
                }
            } else if (eventName == "MouseMove" && self.__isDragging) {
                DllCall("user32\GetCursorPos", "ptr", cursorPt)
                curX := NumGet(cursorPt, 0, "int")
                curY := NumGet(cursorPt, 4, "int")
                newX := self.__dragWinX + (curX - self.__dragStartX)
                newY := self.__dragWinY + (curY - self.__dragStartY)
                if (newX != self.x || newY != self.y) {
                    self.x := newX
                    self.y := newY
                    DllCall("user32\SetWindowPos", "ptr", hwnd, "ptr", 0, "int", newX, "int", newY, "int", 0, "int", 0, "uint", 0x0015)
                    self.SyncAttachedLayers()
                }
            } else if (eventName == "LeftMouseUp" && self.__isDragging) {
                self.__isDragging := false
                DllCall("user32\ReleaseCapture")
            }
        }
    }

    return DllCall("DefWindowProcW", "ptr", hwnd, "uint", uMsg, "uptr", wParam, "ptr", lParam, "ptr")
}