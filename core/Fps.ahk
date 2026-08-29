; Script     Fps.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

/**
 * GpGFX Frame Rate and Pacing Telemetry
 *
 * Provides frame timing, FPS capping, and an optional real-time on-screen telemetry overlay:
 * - Pacing & Target: Sets frame time caps (SetTarget, Target, Toggle) integrated with Render.
 * - Overlay Display: Persistent or temporary on-screen overlay showing FPS, average FPS, render latency, and frame count (Fps(), Display, Position).
 * - Statistics: Tracks instantaneous and rolling frame metrics (frames, lastfps, lastrender, totalrender).
 */
class Fps {

    static Layer := 0
    static Shape := 0
    static frames := 0
    static frametime := 0
    static totaltime := 0.0001
    static lastfps := 0.0001
    static lastrender := 0.0001
    static totalrender := 0.0001
    static rendertime := 0.0001
    static w := 200
    static h := 100
    static margin := 25
    static pos := "topcenter"

    ; Persistence flag, managed by calling Fps(...)
    static persistent := false

    ; Standard FPS presets for cycling
    static Presets := [30, 60, 120, 144, 240, 360, 500, 1000, 0] ; 0 = Unlimited / Max
    static presetIndex := 2                                      ; Default to 60 FPS
    static __target := 0

    /**
     * Target FPS property (setting this automatically recalculates Fps.frametime).
     *
     * @example
     * Fps.Target := 60   ; Cap rendering at 60 FPS
     * Fps.Target := 0    ; Unlimited FPS
     */
    static Target {
        get => this.__target
        set => this.SetTarget(value)
    }

    /**
     * Creates and configures the persistent on-screen FPS telemetry overlay panel.
     * Method chaining is supported (e.g. Fps(60).UpdateFreq(30)).
     *
     * @param {Integer|String} [targetfps=0] Target frame rate cap (0 or "max" for unlimited)
     * @param {String} [position="topcenter"] Screen position ("topleft", "topcenter", "topright")
     * @param {Integer} [w=200] Overlay panel width in pixels
     * @param {Integer} [h=100] Overlay panel height in pixels
     * @param {Integer} [margin=25] Margin distance from screen edges in pixels
     * @returns {Fps} Fps class instance for chaining
     *
     * @example
     * ; 1. Enable 60 FPS overlay at top center
     * Fps(60)
     *
     * ; 2. Enable 144 FPS overlay at top right with custom dimensions
     * Fps(144, "topright", 220, 90)
     */
    static Call(targetfps := 0, position := "topcenter", w := 200, h := 100, margin := 25) {
        local activePtr

        this.w := w
        this.h := h
        this.margin := margin
        this.pos := position

        ; Create a new layer and shape
        if (!this.Layer) {
            
            ; Store the active layer pointer temporarily
            activePtr := LayerStack.activePtr
            
            ; Create the layer and the shape
            this.Layer := Layer(, , this.w, this.h, "Fps")
            this.Shape := Rectangle(, , this.w, this.h, "Black")
            this.Shape.str := "?"
            this.Layer.updatefreq := 20
            this.Position(this.pos)

            ; Restore active layer pointer
            LayerStack.activePtr := activePtr
            this.persistent := 1
        }
        ; Allow repositioning and resizing
        else {
            if (w != this.Layer.w)
                this.Layer.w := w
            if (h != this.Layer.h)
                this.Layer.h := h
            if (margin != this.margin)
                this.margin := margin
            if (position != this.pos)
                this.Position(position)
        }

        this.SetTarget(targetfps)
        return this
    }

    /**
     * Displays a temporary FPS overlay panel on screen for a specified duration.
     *
     * @param {Integer} [delay=1000] Duration in milliseconds to show the panel
     * @returns {void}
     *
     * @example
     * ; Flash FPS panel for 2 seconds
     * Fps.Display(2000)
     */
    static Display(delay := 1000) {
        local activePtr

        ; The Layer may not exist yet
        if (!this.Layer) {

            ; Store the active layer pointer temporarily
            activePtr := LayerStack.activePtr

            ; Create layer and shape with crisp monospace typography
            this.Layer := Layer(this.w, this.h)
            this.Shape := Rectangle(, , this.w, this.h, "black")
            this.Shape.Font := Font("Tahoma", 10, "Regular", "White", 5)
            this.Shape.strQ := 5

            ; Position on screen
            this.Position(this.pos)

            ; Restore active layer pointer
            LayerStack.activePtr := activePtr
        }

        ; Update fps panel text and draw
        this.Update()
        Draw(this.Layer)

        ; Add delay
        if (delay)
            Sleep(delay)
        
        ; Clean up
        if (!this.persistent)
            this.Remove()
    }
    
    /**
     * Sets the position of the FPS overlay panel on screen.
     *
     * @param {String|Integer} [pos="topright"] Named position ("topleft", "topcenter", "topright") or numeric numpad position (7, 8, 9)
     * @param {Integer} [x] Optional explicit X screen coordinate override
     * @param {Integer} [y] Optional explicit Y screen coordinate override
     * @returns {void}
     *
     * @example
     * Fps.Position("topleft")
     * Fps.Position("topright", A_ScreenWidth - 250, 40)
     */
    static Position(pos := "topRight", x?, y?) {
        if (pos is Integer)
            pos := PositionByNumber(pos)
        if (pos is String)
            pos := StrLower(pos)

        switch pos, 0 {
            case "topleft":
                this.Layer.x := this.margin
                this.Layer.y := this.margin
            case "topcenter":
                this.Layer.x := (A_ScreenWidth - this.Shape.w) // 2
                this.Layer.y := this.margin
            case "topright":
                this.Layer.x := A_ScreenWidth - this.Shape.w - this.margin
                this.Layer.y := this.margin
            case "middleleft":
                this.Layer.x := this.margin
                this.Layer.y := (A_ScreenHeight - this.Shape.h) // 2
            case "middlecenter", "center":
                this.Layer.x := (A_ScreenWidth - this.Shape.w) // 2
                this.Layer.y := (A_ScreenHeight - this.Shape.h) // 2
            case "middleright":
                this.Layer.x := A_ScreenWidth - this.Shape.w - this.margin
                this.Layer.y := (A_ScreenHeight - this.Shape.h) // 2
            case "bottomleft":
                this.Layer.x := this.margin
                this.Layer.y := A_ScreenHeight - this.Shape.h - this.margin
            case "bottomcenter":
                this.Layer.x := (A_ScreenWidth - this.Shape.w) // 2
                this.Layer.y := A_ScreenHeight - this.Shape.h - this.margin
            case "bottomright":
                this.Layer.x := A_ScreenWidth - this.Shape.w - this.margin
                this.Layer.y := A_ScreenHeight - this.Shape.h - this.margin
            default:
                this.Layer.x := (A_ScreenWidth - this.Shape.w) // 2
                this.Layer.y := this.margin
        }
        if (IsSet(x))
            this.Layer.x := x
        if (IsSet(y))
            this.Layer.y := y
    }

    /**
     * Updates the FPS panel text content with the latest performance telemetry.
     *
     * @returns {void}
     */
    static Update() {
        local avgFps, avgRender
        avgFps := (Fps.frames > 0 && Fps.totaltime > 0) ? Round(Fps.frames * 1000 / Fps.totaltime, 2) : 0
        avgRender := (Fps.frames > 0 && Fps.totalrender > 0) ? Round(Fps.frames * 1000 / Fps.totalrender, 2) : 0
        try this.Shape.str :=
          "fps   " Round(Fps.lastfps, 2)           "    " Round(Fps.lastrender, 2) "`n"
        . "avg   " avgFps                          "    " avgRender "`n"
        . "sec   " Round(Fps.rendertime / 1000, 2) "    " "i " Fps.frames
    }

    /**
     * Sets the update frequency (in frame intervals) for redrawing the FPS overlay.
     *
     * @param {Integer} value Number of render frames between panel redraws (default is 20)
     * @returns {void}
     *
     * @example
     * Fps.UpdateFreq(30) ; Update overlay text every 30 rendered frames
     */
    static UpdateFreq(value) {
        this.Layer.updatefreq := value
    }

    /**
     * Removes and disposes the FPS overlay panel layer.
     *
     * @param {Any} [*] Unused parameters - callback for onExit
     * @returns {void}
     *
     * @example
     * Fps.Remove()
     */
    static Remove(*) {
        if (this.Layer is Layer) {
            this.Shape := ""
            this.Layer := ""
            GpGFX.DebugLog("[i] Fps panel disposed`n")
        }
    }

    /**
     * Cycles through standard FPS target presets (30 -> 60 -> 120 -> 144 -> 240 -> Max).
     *
     * @returns {String} Formatted description of the new active target (e.g. "144 FPS", "Max (Unlimited)")
     *
     * @example
     * currentSetting := Fps.Toggle()
     */
    static Toggle() {
        local target
        this.presetIndex := Mod(this.presetIndex, this.Presets.Length) + 1
        target := this.Presets[this.presetIndex]
        this.SetTarget(target)
        return (target == 0) ? "Max (Unlimited)" : target " FPS"
    }

    /**
     * Sets a specific FPS target cap and computes the required frame interval.
     *
     * @param {Integer|String} [targetfps=0] Target frame rate (e.g. 60, 144, "max", 0)
     * @returns {Integer} Resolved integer target FPS (0 for unlimited)
     *
     * @example
     * Fps.SetTarget(60)       ; 60 FPS (frametime ~16.67ms)
     * Fps.SetTarget("max")    ; Unlimited (frametime 0ms)
     */
    static SetTarget(targetfps := 0) {
        if (!targetfps || targetfps == "max" || targetfps == "unlimited" || targetfps == 2**32) {
            this.__target := 0
            this.frametime := 0
        }
        else if (IsInteger(targetfps) || IsFloat(targetfps)) {
            this.__target := Integer(targetfps)
            this.frametime := Round(1000 / this.__target, 2)
        }
        else if (targetfps is String) {
            try {
                this.__target := Integer(targetfps)
                this.frametime := Round(1000 / this.__target, 2)
            }
            catch {
                this.__target := 0
                this.frametime := 0
            }
        }
        return this.__target
    }

    /**
     * Resets all cumulative frame counters and timing telemetry.
     *
     * @returns {void}
     *
     * @example
     * Fps.Reset()
     */
    static Reset() {
        this.frames := 0
        this.totaltime := 0.0001
        this.totalrender := 0.0001
        this.rendertime := 0.0001
    }

    /**
     * Destructor to ensure the overlay layer is disposed on script exit.
     */
    static __Delete() {
        if (Fps.Layer is Layer) {
            if (Fps.HasOwnProp("Remove"))
                this.Remove()
        }
    }
}