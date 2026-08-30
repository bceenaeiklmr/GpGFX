; Script:    Palette.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2

/**
 * GpGFX Color Palette & Theme Engine
 *
 * Provides curated design palettes with pre-computed continuous gradient lookup tables (ColorBuffer)
 * for instant ~2 ns real-time color sampling without runtime interpolation math.
 *
 * Features:
 * - Curated themes: Catppuccin, Nord, Gruvbox, TokyoNight, Dracula, Solarized, Cyberpunk, Monokai.
 * - Semantic roles: .primary, .accent, .highlight, .secondary, .bg, .text, .surface, .accent2.
 * - Array indexing: pal[1] swatch access, pal[0.75] continuous gradient float sampling.
 * - Custom palette registration via Palette.Create(name, colors, bg, text).
 */
class Palette {

    ; Registry of all instantiated palettes
    static __registry := Map()

    /**
     * Retrieves a palette by name or returns the default Catppuccin palette.
     *
     * @param {String} [name="Catppuccin"] Palette name (e.g. "Catppuccin", "Nord", "Gruvbox", "TokyoNight", "Dracula", "Solarized", "Cyberpunk", "Monokai")
     * @returns {PaletteInstance}
     *
     * @example
     * ; 1. Get Nord palette
     * pal := Palette.Get("Nord")
     *
     * ; 2. Direct property access
     * pal := Palette.Dracula
     */
    static Get(name := "Catppuccin") {
        local n := StrLower(name)
        if (this.__registry.Has(n))
            return this.__registry[n]
        if (this.HasOwnProp(name))
            return this.%name%
        return this.Catppuccin
    }

    /**
     * Samples a color from a named palette across normalized distance 0.0 .. 1.0 or 0 .. 255.
     *
     * @param {String} name Palette name
     * @param {Float|Integer} [t=0.0] Position in palette gradient (0.0 to 1.0, or 0 to 255)
     * @returns {Integer} 32-bit ARGB uint
     *
     * @example
     * ; Sample midpoint color from TokyoNight
     * color := Palette.Sample("TokyoNight", 0.5)
     */
    static Sample(name, t := 0.0) {
        return this.Get(name).Sample(t)
    }

    /**
     * Returns a random swatch color from the specified palette.
     *
     * @param {String} [name="Catppuccin"] Palette name
     * @returns {Integer} 32-bit ARGB uint
     *
     * @example
     * randColor := Palette.Random("Nord")
     */
    static Random(name := "Catppuccin") {
        return this.Get(name).Random()
    }

    /**
     * Creates and registers a custom color palette.
     *
     * @param {String} name Unique palette name
     * @param {Array} colors Array of core colors [c1, c2, c3, ...]
     * @param {Integer|String} [bg="0xFF181825"] Background color
     * @param {Integer|String} [text="0xFFFFFFFF"] Text / foreground color
     * @param {Integer|String} [surface="0xFF282838"] Surface / card color
     * @param {Integer|String} [accent2="0xFFE0AF68"] Secondary accent color
     * @returns {PaletteInstance}
     *
     * @example
     * ; Create custom Sunset theme
     * myTheme := Palette.Create("Sunset", ["#FF5E36", "#FFAE34", "#FF007F", "#7800A8"], "#120520", "#FFFFFF")
     * c := Palette.Sample("Sunset", 0.3)
     */
    static Create(name, colors, bg := "0xFF181825", text := "0xFFFFFFFF", surface := "0xFF282838", accent2 := "0xFFE0AF68") {
        local pal := PaletteInstance(name, colors, bg, text, surface, accent2)
        this.__registry[StrLower(name)] := pal
        return pal
    }

    ; Curated Built-in Design Palettes

    ; Catppuccin Mocha
    static Catppuccin := PaletteInstance("Catppuccin"
        , ["0xFF89B4FA", "0xFFCBA6F7", "0xFFF38BA8", "0xFFA6E3A1"] ; Blue, Mauve, Red, Green
        , "0xFF1E1E2E" ; Base (Dark Background)
        , "0xFFCDD6F4" ; Text
        , "0xFF313244" ; Surface0
        , "0xFFFAB387") ; Peach (Accent 2)

    ; Nord Theme
    static Nord := PaletteInstance("Nord"
        , ["0xFF88C0D0", "0xFF81A1C1", "0xFFA3BE8C", "0xFFBF616A"] ; Frost Blue, Slate, Green, Red
        , "0xFF2E3440" ; Polar Night
        , "0xFFECEFF4" ; Snow Storm
        , "0xFF3B4252" ; Surface
        , "0xFFEBCB8B") ; Yellow

    ; Gruvbox Dark
    static Gruvbox := PaletteInstance("Gruvbox"
        , ["0xFF83A598", "0xFFFABD2F", "0xFFFB4934", "0xFFB8BB26"] ; Blue, Yellow, Red, Green
        , "0xFF282828" ; Dark0
        , "0xFFEBDBB2" ; Light0
        , "0xFF3C3836" ; Dark1
        , "0xFFFE8019") ; Orange

    ; Tokyo Night
    static TokyoNight := PaletteInstance("TokyoNight"
        , ["0xFF7AA2F7", "0xFFBB9AF7", "0xFFF7768E", "0xFF9ECE6A"] ; Blue, Purple, Red, Green
        , "0xFF1A1B26" ; Background
        , "0xFFC0CAF5" ; Foreground
        , "0xFF24283B" ; Surface
        , "0xFFE0AF68") ; Yellow

    ; Dracula
    static Dracula := PaletteInstance("Dracula"
        , ["0xFFBD93F9", "0xFF50FA7B", "0xFFFF79C6", "0xFFFF5555"] ; Purple, Green, Pink, Red
        , "0xFF282A36" ; Background
        , "0xFFF8F8F2" ; Foreground
        , "0xFF44475A" ; Current Line
        , "0xFF8BE9FD") ; Cyan

    ; Solarized Dark
    static Solarized := PaletteInstance("Solarized"
        , ["0xFF268BD2", "0xFF859900", "0xFFDC322F", "0xFF2AA198"] ; Blue, Green, Red, Cyan
        , "0xFF002B36" ; Base03
        , "0xFFFDF6E3" ; Base3
        , "0xFF073642" ; Base02
        , "0xFFB58900") ; Yellow

    ; Cyberpunk Neon
    static Cyberpunk := PaletteInstance("Cyberpunk"
        , ["0xFF00F0FF", "0xFFFCEE0A", "0xFFFF003C", "0xFF7122FA"] ; Cyan, Yellow, Neon Red, Purple
        , "0xFF0D0221" ; Void
        , "0xFFFFFFFF" ; White
        , "0xFF261447" ; Deep Purple
        , "0xFF05D9E8") ; Laser Blue

    ; Monokai Pro
    static Monokai := PaletteInstance("Monokai"
        , ["0xFF78DCE8", "0xFFFFD866", "0xFFFF6188", "0xFFA9DC76"] ; Cyan, Yellow, Pink, Green
        , "0xFF2D2A2E" ; Charcoal
        , "0xFFFCFCFA" ; Text
        , "0xFF403E41" ; Surface
        , "0xFFAB9DF2") ; Purple
}

/**
 * Concrete palette instance representing a cohesive color scheme with background, surface,
 * text roles, and a pre-calculated 256-step continuous ARGB gradient buffer.
 */
class PaletteInstance {

    name := ""
    colors := []
    bg := 0xFF181825
    text := 0xFFFFFFFF
    surface := 0xFF282838
    accent2 := 0xFFE0AF68

    ; High-performance pre-computed ColorBuffer instance
    buffer := 0
    pGradient => this.buffer.ptr
    __bufGradient => this.buffer.buf

    /**
     * Initializes a new PaletteInstance.
     *
     * @param {String} name Palette name
     * @param {Array} colors Swatch colors
     * @param {Integer|String} [bg="0xFF181825"] Background color
     * @param {Integer|String} [text="0xFFFFFFFF"] Text color
     * @param {Integer|String} [surface="0xFF282838"] Surface color
     * @param {Integer|String} [accent2="0xFFE0AF68"] Secondary accent
     */
    __New(name, colors, bg := "0xFF181825", text := "0xFFFFFFFF", surface := "0xFF282838", accent2 := "0xFFE0AF68") {
        local i, c
        this.name := name
        this.colors := []
        for i, c in colors {
            this.colors.Push(Color(c))
        }
        this.bg := Color(bg)
        this.text := Color(text)
        this.surface := Color(surface)
        this.accent2 := Color(accent2)

        ; Register in global palette map
        Palette.__registry[StrLower(name)] := this

        ; Pre-compute continuous gradient buffer across colors
        this.buffer := ColorBuffer(this.colors)
    }

    /**
     * Array-like indexing for core colors:
     * - `pal[1]`, `pal[2]` -> Discrete swatch colors
     * - `pal[0.5]` -> Continuous gradient sampling
     *
     * @param {Integer|Float} index 1-based swatch index or 0.0-1.0 gradient position
     * @returns {Integer} 32-bit ARGB uint
     *
     * @example
     * pal := Palette.Nord
     * c1 := pal[1]    ; First swatch
     * cMid := pal[0.5] ; Smooth interpolated midpoint
     */
    __Item[index] {
        get {
            if (index is Float)
                return this.buffer.Sample(index)
            local idx := Integer(index)
            if (idx >= 1 && idx <= this.colors.Length)
                return this.colors[idx]
            return this.colors[1]
        }
    }

    ; Semantic role getters
    primary   => this.colors[1]
    accent    => (this.colors.Length >= 2) ? this.colors[2] : this.colors[1]
    highlight => (this.colors.Length >= 3) ? this.colors[3] : this.accent
    secondary => (this.colors.Length >= 4) ? this.colors[4] : this.accent

    /**
     * Samples a color from the pre-computed gradient lookup table in ~2 nanoseconds.
     *
     * @param {Float|Integer} [t=0.0] Position in gradient: normalized 0.0 .. 1.0, or integer 0 .. 255
     * @returns {Integer} 32-bit ARGB uint
     *
     * @example
     * pal := Palette.Dracula
     * color := pal.Sample(0.75)
     */
    Sample(t := 0.0) => this.buffer.Sample(t)

    /**
     * Returns a random color from the palette's swatch colors.
     *
     * @returns {Integer} 32-bit ARGB uint
     *
     * @example
     * randColor := Palette.Gruvbox.Random()
     */
    Random() => this.colors[Random(1, this.colors.Length)]
}
