; Script     Fps.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       23.03.2025
; Version    0.7.2

/**
 * The Fps class provides a simple way to display the frames per second on the screen.
 * The class is designed to be used with the Render class, which will create a temporary
 * layer for the fps panel. The fps panel can be positioned on the screen and updated
 * with the latest values. The panel can be removed immediately or at the end of the script.
 * Important: if the panel is persistent, the user needs to call End() when the script ends.
 */
class Fps {

    ; Static variables
    static __New() {
        
        ; Hold the graphics object
        this.id := 2**63 - 1 ; largest int in AHK
        this.Layer := 0
        this.Shape := 0
        
        ; Required for the fps calculation
        this.frames := 0
        this.frametime := 0
        this.lasttick := 0
        this.totaltime := 0.0001
        this.lastfps := 0.0001
        this.lastrender := 0.0001
        this.totalrender := 0.0001
        this.rendertime := 0.0001

        ; Target fps bounds
        this.max := 99999
        this.min := 0.001
        
        ; Positioning
        this.w := 200
        this.h := 100
        this.margin := 25
        this.pos := "topcenter"
    }

    /**
     * Using the Render class instead of the Draw function enables the fps
     * panel to be displayed on the screen. Creates a temporary layer.
     * @param {int|float} delay 
     */
    static Display(delay := 1000) {
        
        ; The Layer may not exist yet
        if (!this.Layer) {

            ; Store the active layer id, important where new shapes spawn
            activeid := Layer.activeid
            Layer.activeid := this.id

            ; Create layer and shape
            this.Layer := Layer(, , this.w, this.h)
            this.Shape := Rectangle(, , this.w, this.h, "black")

            ; Can be overridden via Fps.pos := value
            this.Position(this.pos)

            ; Set back id
            Layer.activeid := activeid
        }

        ; Update fps panel text, draw fps layer
        this.Update()
        Draw(this.Layer) ; we cannot use this here

        ; Add delay
        if (delay)
            Sleep(delay)
        
        ; Clean up
        if (!this.persistent)
            this.Remove()
    }
    
    /**
     * Set the position of the fps panel on the screen.
     * @param {int|str} pos string like "topright" or a number from 7 to 9
     * @param {int} x offset from calculated position
     * @param {int} y offset
     * the string is case insensitive
     */
    static Position(pos := "topRight", x?, y?) {
        if (pos ~= "\w+")
            pos := Format("{:L}", pos)
        switch pos, 0 {
            case 7, "topleft":
                this.Layer.x := this.margin
                this.layer.y := this.margin
            case 8, "topcenter":
                this.layer.x := (A_ScreenWidth - this.shape.w) // 2
                this.layer.y := this.margin
            case 9, "topright":
                this.layer.x := A_ScreenWidth - this.shape.w - this.margin
                this.layer.y := this.margin
        }
        if (IsSet(x))
            this.layer.x := x
        if (IsSet(y))
            this.layer.y := y
        return
    }

    /**
     * Update the fps panel string property with the latest values.
     * * The update triggered automatically by Display method or calling  
     * Render.Layer() instead of Draw().
     */
    static Update() {
        try	this.Shape.str :=
        "fps   " Round(Fps.lastfps, 2)                         "    " Round(Fps.lastrender, 2) "`n"
      . "avg   " Round(1000 / (Fps.totaltime / Fps.frames), 2) "    " Round(1000 / (Fps.totalrender / Fps.frames), 2) "`n"
      . "sec   " Round(Fps.rendertime / 1000, 2)               "    " "i " Fps.frames
    }

    /**
     * Set the update frequency of the fps panel.
     * @param {int} value The fps layer update frequency, default is 20.
     * * The value indicates the number of draw calls before the panel updates.
     */
    static UpdateFreq(value) {
        this.Layer.updatefreq := value
    }

    /**
     * Deletes the fps panel. If the panel is persistent, it will be removed
     * from the screen in the end, otherwise it will be removed immediately.
     * Display will take care of the removal.
     */
    static Remove(*) {
        if (Type(this.Layer) == "Layer") {
            this.Shape := ""
            this.Layer := ""
            OutputDebug("[i] Fps panel disposed`n")
        }
    }
    
    ; The fps target for rendering managed by calling Fps()
    static target  := 0

    ; The fps panel's persistence, managed by calling Fps()
    static persistent := false

    /**
     * Sets the Fps panel peristent during using the Render class
     * Chaining is allowed: Fps(144).UpdateFreq(100)
     * @param {int} target 
     * @param {str} position 
     * @param {int} w 
     * @param {int} h 
     * @param {int} margin
     */
    static Call(targetfps := 0, position := "topcenter", w := 200, h := 100, margin := 25) {

        this.w := w
        this.h := h
        this.margin := margin
        this.pos := position

        ; Create a new layer and shape
        if (!this.Layer) {
            
            ; Store the active layer id temporarily
            activeid := Layer.activeid
            Layer.activeid := this.id
            
            ; Create the layer and the shape
            this.Layer := Layer(, , this.w, this.h, "Fps")
            this.Shape := Rectangle(, , this.w, this.h, "Black")
            this.Shape.str := "?"
            this.Layer.updatefreq := 20
            this.id := this.Layer.id
            this.position(this.pos)

            ; This ensures the shapes constructed on the active layer again
            Layer.activeid := activeid
            this.persistent := 1
        }
        ; Allow repositioning
        else {
            if (w != this.Layer.w)
                this.Layer.w := w
            if (h != this.Layer.h)
                this.Layer.h := h
            if (margin != this.margin)
                this.margin := margin
            if (position != this.pos)
                this.position(position)
        }

        ; Hurting my eyes, needs a rework
        if (!targetfps || targetfps ~= "i)Max(imum)?") {
            this.target := Fps.max
        }
        else if (Type(targetfps) == "Integer") {
            switch {
                case targetfps <= this.max && targetfps >= this.min:
                    this.target := targetfps
                case targetfps > this.max:
                    this.target := this.max
                case targetfps < this.min:
                    this.target := this.min
            }
        }
        else if (Type(targetfps) == "Float") {
            this.target := Integer(targetfps)
        }
        else if (Type(targetfps) == "String") {
            try	this.target := Integer(targetfps)
            catch
                throw ValueError "Invalid Fps target"
        }
                
        this.frametime := Round(1000 / this.target, 2)

        return this
    }

    /**
     * Removes the fps panel. If persistent End() will remove it,
     * otherwise it will hang the process.
     */
    static __Delete() {
        if (Type(Fps.Layer) == "Layer") {
            if (Fps.HasOwnProp("Remove")) {
                this.Remove()
            }
        }
    }
}
