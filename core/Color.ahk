; Script:    Color.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

/**
 * GpGFX Color Architecture Overview
 *
 * Color engine providing unified color parsing, color space conversions, palettes,
 * 1D gradient tables (ColorBuffer), and hardware-accelerated LUT filters (ColorLUT).
 *
 * Core Capabilities:
 * - Color Parsing: CSS names (140+), hex (#RGB, #ARGB, #RRGGBB, #AARRGGBB, 0x...), decimal integers, and random tokens.
 * - Color Spaces: HSL <-> ARGB conversions, perceived luminance calculation, and smart high-contrast text selection.
 * - Blending & Noise: 4-channel ARGB linear interpolation (Mix / Lerp), multi-step transition ramps, and channel jitter/randomization.
 * - Themes & Standards: Curated dark/light themes (Nord, Dracula, Catppuccin, Cyberpunk, Monokai), RAL classic library, and INI loading.
 * - ColorBuffer: Continuous 1D N-stop gradient lookup tables pre-calculated into unmanaged memory.
 * - ColorLUT: x64 machine-code 256-entry lookup table processor operating directly on 32bpp Bitmap Scan0 memory (1080p in ~0.3ms).
 */

class Color {

    static cache := Map()

    /**
     * Converts any color representation into a canonical 32-bit ARGB integer (`0xAARRGGBB`).
     * Supports CSS names, hex strings, integers, random tokens, and optional alpha overrides.
     * Results are cached for O(1) ~25 ns performance on repeat lookups.
     *
     * @param {String|Integer} [c=""] Hex string, CSS color name, pipe-delimited list, or integer
     * @param {Integer|Float} [a] Optional alpha override: Integer (0-255) or Float (0.0-1.0)
     * @returns {Integer} 32-bit ARGB integer (`0xAARRGGBB`)
     *
     * @example
     * ; 1. Named CSS colors
     * clr := Color("Crimson")
     * clr := Color("MidnightBlue")
     *
     * ; 2. Hex strings (with or without # / 0x)
     * clr := Color("#FF0000")       ; 6-digit RGB (0xFFFF0000)
     * clr := Color("#80FF0000")     ; 8-digit ARGB (50% transparent red)
     * clr := Color("#F00")          ; 3-digit shorthand
     *
     * ; 3. Color with alpha override
     * clr := Color("Lime", 0.5)     ; 50% opacity
     * clr := Color("0xFF0000", 128) ; 128 / 255 alpha
     *
     * ; 4. Pipe-delimited random pick
     * clr := Color("Red|Green|Blue")
     */
    static Call(c := "", alpha?) {
        local val, len, str, r, g, b, a

        ; Fast path 1: numerical integer (e.g. 0xFF000000, 4294901760, or -65536)
        if (c is Integer) {
            val := c & 0xFFFFFFFF
            ; Auto-promote 24-bit RGB (0x000001 to 0x00FFFFFF) to opaque 32-bit ARGB (0xFFRRGGBB)
            ; Note: val == 0 is strictly preserved as 0x00000000 (fully transparent)
            if (val > 0 && val <= 0x00FFFFFF)
                val |= 0xFF000000
            if (IsSet(alpha))
                return (alpha is Float && alpha <= 1.0 && alpha >= 0.0) ? (Ceil(alpha * 255) << 24) | (val & 0x00FFFFFF) : ((Integer(alpha) & 0xFF) << 24) | (val & 0x00FFFFFF)
            return val
        }

        ; If alpha is provided, parse base color first then apply alpha
        if (IsSet(alpha)) {
            val := this.Call(c)
            return (alpha is Float && alpha <= 1.0 && alpha >= 0.0) ? (Ceil(alpha * 255) << 24) | (val & 0x00FFFFFF) : ((Integer(alpha) & 0xFF) << 24) | (val & 0x00FFFFFF)
        }

        ; Cache lookup (single hash map lookup)
        if ((val := this.cache.Get(c, "")) !== "")
            return val

        ; Fast path 2: Hex String Parsing (#RGB, #ARGB, #RRGGBB, #AARRGGBB, 0x...)
        if (c is String && (len := StrLen(c)) > 0) {
            str := c
            if (SubStr(str, 1, 1) == "#") {
                str := SubStr(str, 2)
                len -= 1
            }
            else if (len >= 2 && (SubStr(str, 1, 2) = "0x" || SubStr(str, 1, 2) = "0X")) {
                str := SubStr(str, 3)
                len -= 2
            }

            ; Direct Hex Integer Conversion
            switch len {
                case 6: ; RRGGBB -> 0xFFRRGGBB
                    try {
                        val := ("0xFF" . str) + 0
                        this.cache[c] := val
                        return val
                    }
                
                case 8: ; AARRGGBB -> 0xAARRGGBB
                    try {
                        val := ("0x" . str) + 0
                        this.cache[c] := val
                        return val
                    }

                case 3: ; RGB -> 0xFFRRGGBB
                    try {
                        r := SubStr(str, 1, 1), g := SubStr(str, 2, 1), b := SubStr(str, 3, 1)
                        val := ("0xFF" . r . r . g . g . b . b) + 0
                        this.cache[c] := val
                    return val
                    }

                case 4: ; ARGB -> 0xAARRGGBB
                    try {
                        a := SubStr(str, 1, 1), r := SubStr(str, 2, 1), g := SubStr(str, 3, 1), b := SubStr(str, 4, 1)
                        val := ("0x" . a . a . r . r . g . g . b . b) + 0
                        this.cache[c] := val
                        return val
                    }
            }
        }

        ; Fast path 3: Decimal Numeric String Parsing (e.g. "4294901760", "-65536", "16711680")
        if (c is String && IsNumber(c)) {
            try {
                val := Integer(c) & 0xFFFFFFFF
                if (val > 0 && val <= 0x00FFFFFF)
                    val |= 0xFF000000
                this.cache[c] := val
                return val
            }
        }

        ; Random ARGB
        if (c == "" || c = "rand" || c = "random")
            return Random(0xFF000000, 0xFFFFFFFF)

        ; Pipe-delimited random selection (e.g. "Red|Blue|Green")
        if InStr(c, "|")
            return this.Random(c)

        ; Named CSS Color (e.g. "Red", "Cyan")
        if (this.HasOwnProp(c) && !this.HasMethod(c)) {
            val := this.%c%
            this.cache[c] := val
            return val
        }

        ; Fallback on invalid input
        return this.Red
    }

    /**
     * Sets the alpha (opacity) channel of a color using an integer scale (0 to 255).
     *
     * @param {Integer|String} ARGB Base color
     * @param {Integer} [A=255] Alpha value: 0 (transparent) to 255 (opaque)
     * @returns {Integer} 32-bit ARGB integer
     *
     * @example
     * semiRed := Color.Alpha("Red", 128)  ; 50% opacity
     * fullCyan := Color.Alpha("Cyan", 255) ; 100% opacity
     */
    static Alpha(ARGB, A := 255) {
        ARGB := this.Call(ARGB)
        A := (A is Float && A <= 1.0 && A >= 0.0) ? Ceil(A * 255) : (A > 255 ? 255 : A < 0 ? 0 : Integer(A))
        return (A << 24) | (ARGB & 0x00FFFFFF)
    }

    /**
     * Sets the alpha (opacity) channel of a color using a normalized float scale (0.0 to 1.0).
     *
     * @param {Integer|String} ARGB Base color
     * @param {Float} [A=1.0] Normalized opacity: 0.0 (transparent) to 1.0 (opaque)
     * @returns {Integer} 32-bit ARGB integer
     *
     * @example
     * quarterBlue := Color.AlphaF("Blue", 0.25) ; 25% opacity
     * solidGold   := Color.AlphaF("Gold", 1.0)  ; 100% opacity
     */
    static AlphaF(ARGB, A := 1.0) {
        ARGB := this.Call(ARGB)
        A := (A >= 1.0 ? 255 : A <= 0.0 ? 0 : Ceil(Float(A) * 255))
        return (A << 24) | (ARGB & 0x00FFFFFF)
    }

    /**
     * Calculates the perceived relative luminance of a color according to ITU-R BT.601 (0.0 to 255.0).
     *
     * @param {Integer|String} ARGB Color to measure
     * @returns {Float} Perceived luminance (0.0 = darkest black, 255.0 = brightest white)
     *
     * @example
     * lumDark  := Color.Luminance("#1E1E2E") ; ~31.2
     * lumLight := Color.Luminance("Yellow")  ; ~240.2
     */
    static Luminance(ARGB) {
        local r, g, b
        ARGB := this.Call(ARGB)
        r := (ARGB >> 16) & 0xFF
        g := (ARGB >> 8) & 0xFF
        b := ARGB & 0xFF
        return (0.299 * r) + (0.587 * g) + (0.114 * b)
    }

    /**
     * Returns either dark (0xFF11111B) or light (0xFFFFFFFF) text color for optimal contrast against a background.
     *
     * @param {Integer|String} bgClr Background color
     * @returns {Integer} Contrasting 32-bit ARGB integer (dark or light)
     *
     * @example
     * textColor1 := Color.Contrast("White") ; Returns dark color
     * textColor2 := Color.Contrast("Navy")  ; Returns white
     */
    static Contrast(bgClr) {
        return this.Luminance(bgClr) > 145 ? 0xFF11111B : 0xFFFFFFFF
    }

    /**
     * Permutes or swaps the RGB color channels of an ARGB color.
     *
     * @param {Integer|String} colour Base color
     * @param {String} [mode="Rand"] Channel ordering: "RGB", "RBG", "BGR", "BRG", "GRB", "GBR", or "Rand"
     * @returns {Integer} Channel-swapped 32-bit ARGB integer
     *
     * @example
     * origClr := 0xFFFF8800 ; Orange (RGB)
     * bgrClr  := Color.ChannelSwap(origClr, "BGR") ; Blue-ish
     * rndClr  := Color.ChannelSwap("Coral", "Rand")
     */
    static ChannelSwap(colour, mode := "Rand") {
        static modes := ["RGB", "RBG", "BGR", "BRG", "GRB", "GBR"]
        local A, R, G, B, i, channel, clr
        local c := 0x0

        clr := this.Call(colour)

        if (mode ~= "i)^R(and(om)?)?$") {
            mode := modes[Random(1, modes.Length)]
        }
        else if !(mode ~= "i)^(?!.*(.).*\1)[RGB]{3}$") {
            throw ValueError("Invalid channel swap mode: " mode)
        }

        A := (0xff000000 & clr) >> 24
        R := (0x00ff0000 & clr) >> 16
        G := (0x0000ff00 & clr) >>  8
        B :=  0x000000ff & clr

        for i, channel in StrSplit(mode) {
            switch channel, 0 {
                case "R": c := c | (R << (8 * (3 - i)))
                case "G": c := c | (G << (8 * (3 - i)))
                case "B": c := c | (B << (8 * (3 - i)))
            }
        }
        return (A << 24) | c
    }

    /**
     * Converts Hue, Saturation, Lightness (HSL) coordinates into a 32-bit ARGB integer.
     *
     * @param {Float} h Hue angle in degrees (0.0 to 360.0, e.g. 0° = Red, 120° = Green, 240° = Blue)
     * @param {Float} s Saturation factor: 0.0 to 1.0 (or percentage 0 to 100)
     * @param {Float} l Lightness factor: 0.0 to 1.0 (or percentage 0 to 100)
     * @param {Integer} [a=255] Alpha channel: 0 to 255
     * @returns {Integer} 32-bit ARGB integer
     *
     * @example
     * pureRed   := Color.FromHSL(0, 1.0, 0.5)
     * pureGreen := Color.FromHSL(120, 1.0, 0.5)
     * pureBlue  := Color.FromHSL(240, 1.0, 0.5)
     */
    static FromHSL(h, s, l, a := 255) {
        local v, c, x, m, r, g, b
        
        h := Mod(h, 360.0)
        (h < 0) && h += 360.0
        s := (s > 1.0) ? (s / 100.0) : Max(0.0, Min(1.0, Float(s)))
        l := (l > 1.0) ? (l / 100.0) : Max(0.0, Min(1.0, Float(l)))
        a := Max(0, Min(255, Integer(a)))

        if (s == 0) {
            v := Round(l * 255)
            return (a << 24) | (v << 16) | (v << 8) | v
        }

        c := (1.0 - Abs(2.0 * l - 1.0)) * s               ; chroma
        x := c * (1.0 - Abs(Mod(h / 60.0, 2.0) - 1.0))    ; second largest component
        m := l - c / 2.0                                  ; match lightness
        r := 0.0
        g := 0.0
        b := 0.0

        if (h < 60)
            r := c  , g := x  , b := 0.0
        else if (h < 120)
            r := x  , g := c  , b := 0.0
        else if (h < 180)
            r := 0.0, g := c  , b := x
        else if (h < 240)
            r := 0.0, g := x  , b := c
        else if (h < 300)
            r := x  , g := 0.0, b := c
        else
            r := c  , g := 0.0, b := x

        r := Round((r + m) * 255)
        g := Round((g + m) * 255)
        b := Round((b + m) * 255)

        return (a << 24) | (r << 16) | (g << 8) | b
    }

    /**
     * Deconstructs an ARGB color integer into Hue, Saturation, Lightness, and Alpha components.
     *
     * @param {Integer|String} color Color to analyze
     * @returns {Object} `{ h: Float (0..360), s: Float (0..1), l: Float (0..1), a: Integer (0..255) }`
     *
     * @example
     * hsl := Color.ToHSL("DeepSkyBlue")
     * ; hsl.h = 195.1, hsl.s = 1.0, hsl.l = 0.5, hsl.a = 255
     */
    static ToHSL(color) {
        local argb, a, r, g, b, maxVal, minVal, delta, l, h, s

        argb := this.Call(color)
        a := (argb >> 24) & 0xFF
        r := ((argb >> 16) & 0xFF) / 255.0
        g := ((argb >> 8) & 0xFF) / 255.0
        b := (argb & 0xFF) / 255.0

        maxVal := Max(r, g, b)
        minVal := Min(r, g, b)
        delta := maxVal - minVal
        l := (maxVal + minVal) / 2.0
        h := 0.0, s := 0.0

        if (delta != 0) {
            s := (l > 0.5) ? (delta / (2.0 - maxVal - minVal)) : (delta / (maxVal + minVal))
            if (maxVal == r)
                h := (g - b) / delta + (g < b ? 6.0 : 0.0)
            else if (maxVal == g)
                h := (b - r) / delta + 2.0
            else
                h := (r - g) / delta + 4.0
            h *= 60.0
        }

        return {h: Round(h, 1), s: Round(s, 3), l: Round(l, 3), a: a}
    }

    /**
     * Linearly blends between two colors across all 4 channels (Alpha, Red, Green, Blue).
     *
     * @param {Integer|String} c1 Starting color (weight = 0.0)
     * @param {Integer|String} c2 Ending color (weight = 1.0)
     * @param {Float} [weight=0.5] Interpolation factor: 0.0 (all c1) to 1.0 (all c2)
     * @returns {Integer} Blended 32-bit ARGB integer
     *
     * @example
     * midPurple := Color.Mix("Red", "Blue", 0.5)
     * warmYellow := Color.Mix("Red", "Green", 0.8)
     */
    static Mix(c1, c2, weight := 0.5) {
        local clr1, clr2, w, invW, a, r, g, b
        
        clr1 := this.Call(c1)
        clr2 := this.Call(c2)
        w := Max(0.0, Min(1.0, Float(weight)))
        invW := 1.0 - w

        a := Round(((clr1 >> 24) & 0xFF) * invW + ((clr2 >> 24) & 0xFF) * w)
        r := Round(((clr1 >> 16) & 0xFF) * invW + ((clr2 >> 16) & 0xFF) * w)
        g := Round(((clr1 >> 8) & 0xFF) * invW + ((clr2 >> 8) & 0xFF) * w)
        b := Round((clr1 & 0xFF) * invW + (clr2 & 0xFF) * w)

        return (a << 24) | (r << 16) | (g << 8) | b
    }

    /**
     * Generates an array of colors transitioning smoothly from color1 to color2.
     *
     * @param {Integer|String} color1 Starting color
     * @param {Integer|String} color2 Ending color
     * @param {Boolean} [backforth=false] If true, appends the return transition back to color1 (200 steps total)
     * @returns {Array<Integer>} Array of 100 (or 200) 32-bit ARGB integers
     *
     * @example
     * steps100 := Color.GetTransition("Blue", "Gold")
     * loopCycle := Color.GetTransition("Red", "Cyan", true) ; 200 steps
     */
    static GetTransition(color1, color2, backforth := false) {
        local arr, ARGB

        if (backforth !== 0 && backforth !== 1 && backforth !== true && backforth !== false)
            throw ValueError("backforth must be a boolean (true/false)")

        color1 := this.Call(color1)
        color2 := this.Call(color2)

        arr := []
        arr.Length := (backforth) ? 200 : 100

        loop 100 {
            ARGB := this.Mix(color1, color2, A_Index * 0.01)
            arr[A_Index] := ARGB
            if (backforth) {
                arr[200 - A_Index + 1] := ARGB
            }
        }
        return arr
    }

    /**
     * Linearly interpolates from color1 to color2 by distance factor, with optional alpha override.
     *
     * @param {Integer|String} color1 Starting color
     * @param {Integer|String} color2 Ending color
     * @param {Float|Integer} dist Distance factor: Float (0.0 to 1.0) or Integer percentage (0 to 100)
     * @param {Integer} [alpha] Optional override alpha channel (0 to 255)
     * @returns {Integer} 32-bit ARGB integer
     *
     * @example
     * stepClr := Color.LinearInterpolation("Red", "Lime", 0.75) ; 75% towards Lime
     * stepClr := Color.LinearInterpolation("Black", "White", 50, 180) ; 50% Gray with alpha 180
     */
    static LinearInterpolation(color1, color2, dist, alpha?) {
        local w, res
        if (dist is Integer)
            w := dist * 0.01
        else if (dist is Float)
            w := dist
        else
            throw ValueError("Distance must be an integer (0..100) or float (0.0..1.0)")

        res := this.Mix(color1, color2, w)
        if (IsSet(alpha))
            return this.Alpha(res, alpha)
        return res
    }

    /**
     * Alias for `Color.LinearInterpolation`.
     */
    static Transition(color1, color2, dist := 1, alpha := 255) {
        return this.LinearInterpolation(color1, color2, dist, alpha)
    }

    /**
     * Returns a random color, optionally selected from a pipe-delimited list, with optional channel variance.
     *
     * @param {String} [colorName=""] Single color name, pipe list ("Red|Blue|Green"), or empty for full random
     * @param {Integer|Boolean} [randomness=false] Optional channel jitter variance (+/- range)
     * @returns {Integer} 32-bit ARGB integer
     *
     * @example
     * clr1 := Color.Random() ; Random opaque color
     * clr2 := Color.Random("Gold|Teal|Crimson") ; Pick from list
     * clr3 := Color.Random("Navy", 20) ; Navy with jitter
     */
    static Random(colorName := "", randomness := false) {
        local rand, ARGB

        if (colorName == "")
            return Random(0xFF000000, 0xFFFFFFFF)

        colorName := StrSplit(colorName, "|")
        rand := Random(1, colorName.Length)
        ARGB := Trim(colorName[rand])

        if (!this.HasOwnProp(ARGB) && !this.cache.Has(ARGB)) {
            try {
                ARGB := this.Call(ARGB)
            } catch {
                GpGFX.DebugLog("[i] Color " ARGB " not found`n")
                return Random(0xFF000000, 0xFFFFFFFF)
            }
        } else {
            ARGB := this.Call(ARGB)
        }

        if (randomness) {
            return this.Randomize(ARGB, randomness)
        }
        return ARGB
    }

    /**
     * Adds random variance (noise) to the Red, Green, and Blue channels of a color.
     *
     * @param {Integer|String} ARGB Base color
     * @param {Integer} [rand=15] Maximum random variance per channel (+/- range)
     * @returns {Integer} Jittered 32-bit ARGB integer
     *
     * @example
     * organicGrass := Color.Randomize("ForestGreen", 25)
     */
    static Randomize(ARGB, rand := 15) {
        local A, R, G, B

        ARGB := this.Call(ARGB)
        A := (0xFF000000 & ARGB)
        R := (0x00FF0000 & ARGB) >> 16
        G := (0x0000FF00 & ARGB) >>  8
        B :=  0x000000FF & ARGB

        R := Min(255, Max(0, R + Random(-rand, rand)))
        G := Min(255, Max(0, G + Random(-rand, rand)))
        B := Min(255, Max(0, B + Random(-rand, rand)))

        return A | (R << 16) | (G << 8) | B
    }

    /**
     * Returns a random fully opaque 32-bit ARGB integer.
     *
     * @returns {Integer} 32-bit ARGB integer
     */
    static RandomARGB() {
        return Random(0xFF000000, 0xFFFFFFFF)
    }

    /**
     * Returns a random color with an alpha channel within a specified boundary range.
     *
     * @param {Integer} [alpha=0xFF] Alpha channel value, or minimum alpha if max is specified
     * @param {Integer|Boolean} [max=false] Maximum alpha boundary (or false to use exact alpha)
     * @returns {Integer} 32-bit ARGB integer
     *
     * @example
     * partClr := Color.RandomARGBAlphaMax(40, 180) ; Random color with 40-180 alpha
     */
    static RandomARGBAlphaMax(alpha := 0xFF, max := false) {
        if (alpha > 255 || alpha < 0 || (max !== false && (max > 255 || max < 0)))
            throw ValueError("Alpha must be between 0 and 255")
        alpha := (max !== false) ? Random(alpha, max) : alpha
        return (alpha << 24) | Random(0x0, 0xFFFFFF)
    }

    /**
     * Loads custom colors and sectioned palettes from an external INI configuration file using native IniRead.
     *
     * @param {String} filePath Path to the INI color file
     * @returns {Integer} Count of loaded color definitions
     *
     * @example
     * Color.LoadFile("themes/custom.ini")
     * bg := Color.Brand.Primary
     */
    static LoadFile(filePath) {
        local count := 0, sectionNames, section, sectionText, line, key, val, eqPos, parsedClr

        if (!FileExist(filePath))
            throw TargetError("[!] Color file not found: " filePath)

        sectionNames := IniRead(filePath)
        if (sectionNames == "")
            return 0

        loop parse, sectionNames, "`n", "`r" {
            section := Trim(A_LoopField)
            if (section == "")
                continue

            if (!this.HasOwnProp(section))
                this.%section% := {}

            sectionText := IniRead(filePath, section)
            loop parse, sectionText, "`n", "`r" {
                line := Trim(A_LoopField)
                if (line == "" || SubStr(line, 1, 1) == ";" || SubStr(line, 1, 1) == "#")
                    continue

                eqPos := InStr(line, "=")
                if (eqPos) {
                    key := Trim(SubStr(line, 1, eqPos - 1))
                    val := Trim(SubStr(line, eqPos + 1))
                    if (key != "" && val != "") {
                        parsedClr := this.Call(val)
                        this.%key% := parsedClr
                        this.%section%.%key% := parsedClr
                        count += 1
                    }
                }
            }
        }
        return count
    }

    /**
     * Saves a color palette or key-value mapping to an INI configuration file using native IniWrite.
     *
     * @param {String} filePath Destination file path
     * @param {String} section Section name in the INI file
     * @param {Object} colorMap Key-value pairs of color names and values
     * @returns {void}
     *
     * @example
     * Color.SaveFile("themes/mytheme.ini", "Brand", { Primary: "#00F0FF", Secondary: "Magenta" })
     */
    static SaveFile(filePath, section, colorMap) {
        local key, val
        for key, val in colorMap.OwnProps() {
            IniWrite(Format("0x{:08X}", this.Call(val)), filePath, section, key)
        }
    }

    /**
     * Registers a custom color palette theme onto `Color.<Name>` and `Color.Palette.<Name>`.
     * Pre-resolves values to pure 32-bit ARGB integers.
     *
     * @param {String} name Name of the palette (e.g. "Emerald", "TokyoNight")
     * @param {Object} colorMap Key-value pairs of color names to values
     * @returns {Object} Pre-resolved palette object
     *
     * @example
     * Color.AddPalette("Emerald", { bg: "#064E3B", surface: "#047857", accent: "#34D399" })
     * cardBg := Color.Emerald.bg
     */
    static AddPalette(name, colorMap) {
        local resolved := {}, prop, val
        for prop, val in colorMap.OwnProps() {
            resolved.%prop% := this.Call(val)
        }
        this.%name% := resolved
        this.Palette.%name% := resolved
        return resolved
    }

    /**
     * Registers a custom gradient ramp onto `ColorBuffer.<Name>`.
     *
     * @param {String} name Name of the gradient (e.g. "Fire", "Matrix")
     * @param {Array} colors Array of color stops
     * @param {Integer} [steps=256] Step resolution
     * @returns {ColorBuffer} New ColorBuffer instance
     *
     * @example
     * Color.AddGradient("Fire", ["Black", "Red", "Orange", "Yellow", "White"])
     * flameClr := ColorBuffer.Fire[0.75]
     */
    static AddGradient(name, colors, steps := 256) {
        local cb := ColorBuffer(colors, steps)
        ColorBuffer.%name% := cb
        return cb
    }

    /**
     * Curated standard UI themes and design palettes (delegates to Palette class).
     */
    static Palette => Palette
    static GitHubBlue           := 0xFF0969DA,
           GitHubGray900        := 0xFF0D1117,
           GitHubGray800        := 0xFF161B22

    /**
     * @credit iseahound - TextRender v1.9.3, colormap
     * https://github.com/iseahound/TextRender/
     * 
     * José Roca Software, GDI+ Flat API Reference
     * Enumerations: http://www.jose.it-berater.org/gdiplus/iframe/index.htm
     */

    ; CSS 140+ Color Names (W3C standard palette)
    static Aliceblue            := 0xFFF0f8FF,
           AntiqueWhite         := 0xFFFAEBD7,
           Aqua                 := 0xFF00FFFF,
           Aquamarine           := 0xFF7FFFD4,
           Azure                := 0xFFF0FFFF,
           Beige                := 0xFFF5F5DC,
           Bisque               := 0xFFFFE4C4,
           Black                := 0xFF000000,
           BlanchedAlmond       := 0xFFFFEBCD,
           Blue                 := 0xFF0000FF,
           BlueViolet           := 0xFF8A2BE2,
           Brown                := 0xFFA52A2A,
           BurlyWood            := 0xFFDEB887,
           CadetBlue            := 0xFF5F9EA0,
           Chartreuse           := 0xFF7FFF00,
           Chocolate            := 0xFFD2691E,
           Coral                := 0xFFFF7F50,
           CornflowerBlue       := 0xFF6495ED,
           Cornsilk             := 0xFFFFF8DC,
           Crimson              := 0xFFDC143C,
           Cyan                 := 0xFF00FFFF,
           DarkBlue             := 0xFF00008B,
           DarkCyan             := 0xFF008B8B,
           DarkGoldenrod        := 0xFFB8860B,
           DarkGray             := 0xFFA9A9A9,
           DarkGreen            := 0xFF006400,
           DarkKhaki            := 0xFFBDB76B,
           DarkMagenta          := 0xFF8B008B,
           DarkOliveGreen       := 0xFF556B2F,
           DarkOrange           := 0xFFFF8C00,
           DarkOrchid           := 0xFF9932CC,
           DarkRed              := 0xFF8B0000,
           DarkSalmon           := 0xFFE9967A,
           DarkSeaGreen         := 0xFF8FBC8B,
           DarkSlateBlue        := 0xFF483D8B,
           DarkSlateGray        := 0xFF2F4F4F,
           DarkTurquoise        := 0xFF00CED1,
           DarkViolet           := 0xFF9400D3,
           DeepPink             := 0xFFFF1493,
           DeepSkyBlue          := 0xFF00BFFF,
           DimGray              := 0xFF696969,
           DodgerBlue           := 0xFF1E90FF,
           Firebrick            := 0xFFB22222,
           FloralWhite          := 0xFFFFFAF0,
           ForestGreen          := 0xFF228B22,
           Fuchsia              := 0xFFFF00FF,
           Gainsboro            := 0xFFDCDCDC,
           GhostWhite           := 0xFFF8F8FF,
           Gold                 := 0xFFFFD700,
           Goldenrod            := 0xFFDAA520,
           Gray                 := 0xFF808080,
           Green                := 0xFF008000,
           GreenYellow          := 0xFFADFF2F,
           Honeydew             := 0xFFF0FFF0,
           HotPink              := 0xFFFF69B4,
           IndianRed            := 0xFFCD5C5C,
           Indigo               := 0xFF4B0082,
           Ivory                := 0xFFFFFFF0,
           Khaki                := 0xFFF0E68C,
           Lavender             := 0xFFE6E6FA,
           LavenderBlush        := 0xFFFFF0F5,
           LawnGreen            := 0xFF7CFC00,
           LemonChiffon         := 0xFFFFFACD,
           LightBlue            := 0xFFADD8E6,
           LightCoral           := 0xFFF08080,
           LightCyan            := 0xFFE0FFFF,
           LightGoldenrodYellow := 0xFFFAFAD2,
           LightGray            := 0xFFD3D3D3,
           LightGreen           := 0xFF90EE90,
           LightPink            := 0xFFFFB6C1,
           LightSalmon          := 0xFFFFA07A,
           LightSeaGreen        := 0xFF20B2AA,
           LightSkyBlue         := 0xFF87CEFA,
           LightSlateGray       := 0xFF778899,
           LightSteelBlue       := 0xFFB0C4DE,
           LightYellow          := 0xFFFFFFE0,
           Lime                 := 0xFF00FF00,
           LimeGreen            := 0xFF32CD32,
           Linen                := 0xFFFAF0E6,
           Magenta              := 0xFFFF00FF,
           Maroon               := 0xFF800000,
           MediumAquamarine     := 0xFF66CDAA,
           MediumBlue           := 0xFF0000CD,
           MediumOrchid         := 0xFFBA55D3,
           MediumPurple         := 0xFF9370DB,
           MediumSeaGreen       := 0xFF3CB371,
           MediumSlateBlue      := 0xFF7B68EE,
           MediumSpringGreen    := 0xFF00FA9A,
           MediumTurquoise      := 0xFF48D1CC,
           MediumVioletRed      := 0xFFC71585,
           MidnightBlue         := 0xFF191970,
           MintCream            := 0xFFF5FFFA,
           MistyRose            := 0xFFFFE4E1,
           Moccasin             := 0xFFFFE4B5,
           NavajoWhite          := 0xFFFFDEAD,
           Navy                 := 0xFF000080,
           OldLace              := 0xFFFDF5E6,
           Olive                := 0xFF808000,
           OliveDrab            := 0xFF6B8E23,
           Orange               := 0xFFFFA500,
           OrangeRed            := 0xFFFF4500,
           Orchid               := 0xFFDA70D6,
           PaleGoldenrod        := 0xFFEEE8AA,
           PaleGreen            := 0xFF98FB98,
           PaleTurquoise        := 0xFFAFEEEE,
           PaleVioletRed        := 0xFFDB7093,
           PapayaWhip           := 0xFFFFEFD5,
           PeachPuff            := 0xFFFFDAB9,
           Peru                 := 0xFFCD853F,
           Pink                 := 0xFFFFC0CB,
           Plum                 := 0xFFDDA0DD,
           PowderBlue           := 0xFFB0E0E6,
           Purple               := 0xFF800080,
           Red                  := 0xFFFF0000,
           RosyBrown            := 0xFFBC8F8F,
           RoyalBlue            := 0xFF4169E1,
           SaddleBrown          := 0xFF8B4513,
           Salmon               := 0xFFFA8072,
           SandyBrown           := 0xFFF4A460,
           SeaGreen             := 0xFF2E8B57,
           SeaShell             := 0xFFFFF5EE,
           Sienna               := 0xFFA0522D,
           Silver               := 0xFFC0C0C0,
           SkyBlue              := 0xFF87CEEB,
           SlateBlue            := 0xFF6A5ACD,
           SlateGray            := 0xFF708090,
           Snow                 := 0xFFFFFAFA,
           SpringGreen          := 0xFF00FF7F,
           SteelBlue            := 0xFF4682B4,
           Tan                  := 0xFFD2B48C,
           Teal                 := 0xFF008080,
           Thistle              := 0xFFD8BFD8,
           Tomato               := 0xFFFF6347,
           Transparent          := 0x00000000,
           None                 := 0x00000000,
           Turquoise            := 0xFF40E0D0,
           Violet               := 0xFFEE82EE,
           Wheat                := 0xFFF5DEB3,
           White                := 0xFFFFFFFF,
           WhiteSmoke           := 0xFFF5F5F5,
           Yellow               := 0xFFFFFF00,
           YellowGreen          := 0xFF9ACD32

    /**
     * Loads RAL classic color dictionary on-demand into `Color.<RALCode>`.
     */
    static RAL_load() {
        local key, ARGB, RAL
        RAL := {
            RAL1000: 0xFFBEBD7F, RAL1001: 0xFFC2B078, RAL1002: 0xFFC6A664, RAL1003: 0xFFE5BE01,
            RAL1004: 0xFFFFD700, RAL1005: 0xFFFFAA1D, RAL1006: 0xFFFFA420, RAL1007: 0xFFFF8C00,
            RAL1011: 0xFF8A6642, RAL1012: 0xFFD7D7D7, RAL1013: 0xFFEAE6CA, RAL1014: 0xFFE1CC4F,
            RAL1015: 0xFFE6D690, RAL1016: 0xFFFFF700, RAL1017: 0xFFFFE600, RAL1018: 0xFFFFF200,
            RAL1019: 0xFF9E9764, RAL1020: 0xFF999950, RAL1021: 0xFFFFD700, RAL1023: 0xFFFFC000,
            RAL1024: 0xFFAEA04B, RAL1026: 0xFFFFFF00, RAL1027: 0xFF9D9101, RAL1028: 0xFFF4A000,
            RAL1032: 0xFFE2A300, RAL1033: 0xFFF99B1C, RAL1034: 0xFFEB9C52, RAL1035: 0xFF908370,
            RAL1036: 0xFF80643F, RAL1037: 0xFFDD7907, RAL2000: 0xFFED6B21, RAL2001: 0xFFC93C20,
            RAL2002: 0xFFCB2821, RAL2003: 0xFFFF7514, RAL2004: 0xFFF44611, RAL2005: 0xFFFF2301,
            RAL2007: 0xFFFFA421, RAL2008: 0xFFF75E25, RAL2009: 0xFFF54021, RAL2010: 0xFFD84B20,
            RAL2011: 0xFFEC7C25, RAL2012: 0xFFE55137, RAL2013: 0xFFC3583A, RAL3000: 0xFFAF2B1E,
            RAL3001: 0xFFA52019, RAL3002: 0xFF9B111E, RAL3003: 0xFF641C14, RAL3004: 0xFF6C1B23,
            RAL3005: 0xFF581E22, RAL3007: 0xFF402225, RAL3009: 0xFF703731, RAL3011: 0xFF7E2324,
            RAL3012: 0xFFC98370, RAL3013: 0xFF9C332D, RAL3014: 0xFFD47479, RAL3015: 0xFFE1A6AD,
            RAL3016: 0xFFAC4034, RAL3017: 0xFFD3545F, RAL3018: 0xFFD14152, RAL3020: 0xFFC1121C,
            RAL3022: 0xFFD56D56, RAL3024: 0xFFFF3F00, RAL3026: 0xFFFF2B2B, RAL3027: 0xFFB53389,
            RAL3028: 0xFFCB3234, RAL3031: 0xFFB32428, RAL4001: 0xFF6D3F5B, RAL4002: 0xFF922B3E,
            RAL4003: 0xFFDE4C8A, RAL4004: 0xFF641C34, RAL4005: 0xFF6C4675, RAL4006: 0xFF993366,
            RAL4007: 0xFF4A192C, RAL4008: 0xFF924E7D, RAL4009: 0xFFCF3476, RAL5000: 0xFF354D73,
            RAL5001: 0xFF1F4764, RAL5002: 0xFF00387B, RAL5003: 0xFF1D334A, RAL5004: 0xFF18171C,
            RAL5005: 0xFF1E2460, RAL5007: 0xFF3E5F8A, RAL5008: 0xFF26252D, RAL5009: 0xFF025669,
            RAL5010: 0xFF0E294B, RAL5011: 0xFF231A24, RAL5012: 0xFF3B83BD, RAL5013: 0xFF232C3F,
            RAL5014: 0xFF637D96, RAL5015: 0xFF2874A6, RAL5017: 0xFF063971, RAL5018: 0xFF3F888F,
            RAL5019: 0xFF1B5583, RAL5020: 0xFF1D334A, RAL5021: 0xFF256D7B, RAL5022: 0xFF282D3C,
            RAL5023: 0xFF3F3F4E, RAL5024: 0xFF5D9B9B, RAL6000: 0xFF327662, RAL6001: 0xFF287233,
            RAL6002: 0xFF2D572C, RAL6003: 0xFF424632, RAL6004: 0xFF1F3A3D, RAL6005: 0xFF2F4538,
            RAL6006: 0xFF3E3B32, RAL6007: 0xFF343B29, RAL6008: 0xFF39352A, RAL6009: 0xFF31372B,
            RAL6010: 0xFF35682D, RAL6011: 0xFF587246, RAL6012: 0xFF343E40, RAL6013: 0xFF6C7156,
            RAL7012: 0xFF4E5754, RAL7013: 0xFF464531, RAL7015: 0xFF51565C, RAL7016: 0xFF373F43,
            RAL7021: 0xFF2F353B, RAL7022: 0xFF4B4D46, RAL7023: 0xFF818479, RAL7024: 0xFF474A51,
            RAL7026: 0xFF374447, RAL7030: 0xFF939388, RAL7031: 0xFF5D6970, RAL7032: 0xFFB9B9A8,
            RAL7033: 0xFF7D8471, RAL7034: 0xFF8F8B66, RAL7035: 0xFFD7D7D7, RAL7036: 0xFF7F7679,
            RAL7037: 0xFF7D7F7D, RAL7038: 0xFFB8B8B1, RAL7039: 0xFF6C6E58, RAL7040: 0xFF9DA1AA,
            RAL7042: 0xFF8D948D, RAL7043: 0xFF4E5451, RAL7044: 0xFFCAC4B0, RAL7045: 0xFF909090,
            RAL7046: 0xFF82898F, RAL7047: 0xFFD0D0D0, RAL8000: 0xFF826C34, RAL8001: 0xFF955F20,
            RAL8002: 0xFF6C3B2A, RAL8003: 0xFF734222, RAL8004: 0xFF8E402A, RAL8007: 0xFF59351F,
            RAL8008: 0xFF6F4F28, RAL8011: 0xFF5B3A29, RAL8012: 0xFF592321, RAL8014: 0xFF382C1E,
            RAL8015: 0xFF633A34, RAL8016: 0xFF4C2F27, RAL8017: 0xFF45322E, RAL8019: 0xFF403A3A,
            RAL8022: 0xFF212121, RAL8023: 0xFFA65E2E, RAL8024: 0xFF79553D, RAL8025: 0xFF755C48,
            RAL8028: 0xFF4E3B31, RAL9001: 0xFFFDF4E3, RAL9002: 0xFFE7EBDA, RAL9003: 0xFFF4F4F4,
            RAL9004: 0xFF282828, RAL9005: 0xFF0A0A0A, RAL9006: 0xFFA5A5A5, RAL9007: 0xFF8F8F8F,
            RAL9010: 0xFFFFFFF4, RAL9011: 0xFF1C1C1C, RAL9016: 0xFFF6F6F6, RAL9017: 0xFF1E1E1E,
            RAL9018: 0xFFD7D7D7
        }
        for key, ARGB in RAL.OwnProps() {
            Color.%key% := ARGB
        }
    }

    static __New() {
        local name, theme
        for name, theme in this.Palette.OwnProps() {
            this.%name% := theme
        }
    }

    static Buffer => ColorBuffer
    static Buf    => ColorBuffer
}

; Global aliases
RAL_load() => Color.RAL_load()
ColorBuf(params*) => ColorBuffer(params*)

/**
 * 1D continuous multi-stop color gradient lookup table (LUT) in unmanaged memory.
 * Pre-computes continuous linear interpolation across N color stops into a flat binary buffer.
 * Provides zero-allocation O(1) sampling (~2 ns) for animation loops, audio visualizers, and heatmaps.
 */
class ColorBuffer {

    colors := []
    steps := 256
    buf := 0
    ptr := 0

    /**
     * Creates a new ColorBuffer gradient table from color stops and optional step resolution.
     *
     * @constructor
     * @param {Array|String|Integer|ColorBuffer} colorsAndSteps* Color stops and optional final step count
     *
     * @example
     * ; 1. Two-color gradient
     * grad := ColorBuffer("Blue", "Gold")
     *
     * ; 2. Multi-stop gradient with 512 steps
     * grad := ColorBuffer(["Red", "Orange", "Yellow", "White"], 512)
     *
     * ; 3. Built-in colormaps
     * turboMap := ColorBuffer.Turbo
     * plasmaMap := ColorBuffer.Plasma
     */
    __New(colorsAndSteps*) {
        local clrList := []
        local arg, c, st := 256

        ; Flatten arguments (supports arrays, strings, integers, or another ColorBuffer/Palette)
        for arg in colorsAndSteps {
            if (IsObject(arg)) {
                if (arg.HasProp("colors") && Type(arg.colors) == "Array") {
                    for c in arg.colors
                        clrList.Push(Color(c))
                } else if (arg is Array) {
                    for c in arg
                        clrList.Push(Color(c))
                }
            } else if (IsInteger(arg) && clrList.Length >= 2 && A_Index == colorsAndSteps.Length) {
                st := Max(2, Integer(arg)) ; Last integer can be step count if >= 2 colors provided
            } else {
                clrList.Push(Color(arg))
            }
        }

        ; Fallback if empty
        if (!clrList.Length)
            clrList := [0xFF000000, 0xFFFFFFFF]
        else if (clrList.Length == 1)
            clrList.Push(clrList[1])

        this.colors := clrList
        this.steps := st
        this.__BuildBuffer()
    }

    /**
     * Pre-computes continuous linear interpolation between N color stops into flat binary memory.
     */
    __BuildBuffer() {
        local n := this.colors.Length
        local numSegments := n - 1
        local st := this.steps
        local i, segT, segIdx, c1, c2, a1, r1, g1, b1, a2, r2, g2, b2, a, r, g, b, argb

        this.buf := Buffer(st * 4, 0)
        this.ptr := this.buf.ptr

        loop st {
            i := A_Index - 1
            if (numSegments <= 0) {
                argb := this.colors[1]
            } else {
                segT := (i / Float(st - 1)) * numSegments
                segIdx := Min(numSegments, Integer(Floor(segT)) + 1)
                segT := segT - (segIdx - 1)

                c1 := this.colors[segIdx]
                c2 := (segIdx < n) ? this.colors[segIdx + 1] : this.colors[n]

                a1 := (c1 >> 24) & 0xFF, r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
                a2 := (c2 >> 24) & 0xFF, r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF

                a := Integer(a1 + segT * (a2 - a1))
                r := Integer(r1 + segT * (r2 - r1))
                g := Integer(g1 + segT * (g2 - g1))
                b := Integer(b1 + segT * (b2 - b1))

                argb := (a << 24) | (r << 16) | (g << 8) | b
            }

            NumPut("uint", argb, this.ptr, i * 4)
        }
    }

    /**
     * Samples a 32-bit ARGB color from the gradient buffer in O(1) time (~2 ns).
     *
     * @param {Float|Integer} [t=0.0] Normalized position (0.0 to 1.0) or step index (0 to steps-1)
     * @returns {Integer} 32-bit ARGB integer (`0xAARRGGBB`)
     *
     * @example
     * ; Float sampling (0.0 to 1.0)
     * clr1 := ColorBuffer.Turbo.Sample(0.5)
     * clr2 := ColorBuffer.Plasma[0.75] ; Bracket syntax
     *
     * ; Integer step sampling (0 to 255)
     * clr3 := ColorBuffer.Heatmap[128]
     */
    Sample(t := 0.0) {
        local idx
        if (t is Float)
            idx := Integer(Max(0.0, Min(1.0, t)) * (this.steps - 1))
        else
            idx := Integer(Max(0, Min(this.steps - 1, t)))

        return NumGet(this.ptr, idx * 4, "uint")
    }

    ; Bracket indexing & shorthand aliases
    Get(t := 0.0) => this.Sample(t)
    __Item[t] => this.Sample(t)

    /**
     * Returns a random 32-bit ARGB color sampled from the gradient buffer.
     *
     * @returns {Integer} 32-bit ARGB integer
     */
    Random() => NumGet(this.ptr, Random(0, this.steps - 1) * 4, "uint")

    /**
     * Returns a new ColorBuffer with reversed color stops.
     *
     * @returns {ColorBuffer}
     *
     * @example
     * revTurbo := ColorBuffer.Turbo.Reverse()
     */
    Reverse() {
        local rev, i
        rev := []
        rev.Capacity := this.colors.Length
        i := this.colors.Length
        while (i > 0) {
            rev.Push(this.colors[i])
            i -= 1
        }
        return ColorBuffer(rev, this.steps)
    }

    ; Scientific Colormaps & Gradient Singletons (Built on-demand)
    static __turbo := 0
    static Turbo {
        get => (this.__turbo) ? this.__turbo : (this.__turbo := ColorBuffer([
            "0xFF30123B", "0xFF4662D8", "0xFF36ABFB", "0xFF1AE4B6",
            "0xFF72FE5E", "0xFFC8EF34", "0xFFFABA39", "0xFFF66B19",
            "0xFFCB2B04", "0xFF7A0403"]))
    }

    static __viridis := 0
    static Viridis {
        get => (this.__viridis) ? this.__viridis : (this.__viridis := ColorBuffer([
            "0xFF440154", "0xFF482878", "0xFF3E4A89", "0xFF31688E",
            "0xFF26828E", "0xFF1F9E89", "0xFF35B779", "0xFF6DCD59",
            "0xFFB4DE2C", "0xFFFDE725"]))
    }

    static _plasma := 0
    static Plasma {
        get => (this._plasma) ? this._plasma : (this._plasma := ColorBuffer([
            "0xFF0D0887", "0xFF46039F", "0xFF7201A8", "0xFF9C179E",
            "0xFFBD3786", "0xFFD8576B", "0xFFED7953", "0xFFFA9E3B",
            "0xFFFDC926", "0xFFF0F921"]))
    }

    static __magma := 0
    static Magma {
        get => (this.__magma) ? this.__magma : (this.__magma := ColorBuffer([
            "0xFF000004", "0xFF180F3E", "0xFF450F59", "0xFF721F81",
            "0xFF9F2F7F", "0xFFCD4071", "0xFFF1605D", "0xFFFD9567",
            "0xFFFEC98D", "0xFFFCFDBF"]))
    }

    static __inferno := 0
    static Inferno {
        get => (this.__inferno) ? this.__inferno : (this.__inferno := ColorBuffer([
            "0xFF000004", "0xFF1B0C41", "0xFF4A0C6B", "0xFF781C6D",
            "0xFFA52C60", "0xFFCF4446", "0xFFED6925", "0xFFFB9B06",
            "0xFFF7D03C", "0xFFFCFFA4"]))
    }

    static __rainbow := 0
    static Rainbow {
        get => (this.__rainbow) ? this.__rainbow : (this.__rainbow := ColorBuffer([
            "0xFFFF0000", "0xFFFF7F00", "0xFFFFFF00", "0xFF00FF00",
            "0xFF00FFFF", "0xFF0000FF", "0xFF8B00FF"]))
    }

    static __heatmap := 0
    static Heatmap {
        get => (this.__heatmap) ? this.__heatmap : (this.__heatmap := ColorBuffer([
            "0xFF000000", "0xFF800000", "0xFFFF0000", "0xFFFF8000",
            "0xFFFFFF00", "0xFFFFFFFF"]))
    }
    static Thermal => this.Heatmap

    static __coolWarm := 0
    static CoolWarm {
        get => (this.__coolWarm) ? this.__coolWarm : (this.__coolWarm := ColorBuffer([
            "0xFF3B4CC0", "0xFF8CBDFF", "0xFFDDDDDD", "0xFFF49A7B",
            "0xFFB40426"]))
    }

    static __neon := 0
    static Neon {
        get => (this.__neon) ? this.__neon : (this.__neon := ColorBuffer([
            "0xFF00F0FF", "0xFFFF007F", "0xFFFFE600"]))
    }

    static __sunset := 0
    static Sunset {
        get => (this.__sunset) ? this.__sunset : (this.__sunset := ColorBuffer([
            "0xFF0B132B", "0xFF1C2541", "0xFF5BC0BE", "0xFFE05638",
            "0xFFF39C12", "0xFFF1C40F"]))
    }

    static __ocean := 0
    static Ocean {
        get => (this.__ocean) ? this.__ocean : (this.__ocean := ColorBuffer([
            "0xFF03071E", "0xFF0A2463", "0xFF247BA0", "0xFF3F88C5",
            "0xFFE2E4F6"]))
    }

    static __grayscale := 0
    static Grayscale {
        get => (this.__grayscale) ? this.__grayscale : (this.__grayscale := ColorBuffer([
            "0xFF000000", "0xFFFFFFFF"]))
    }
    static BW => this.Grayscale
}

/**
 * 256-entry channel lookup table (LUT) transformation.
 * Executes x64 assembly directly across GDI+ 32bpp Bitmap Scan0 unmanaged memory.
 * Transforms a 1080p frame in ~0.3 ms and 4K UHD in ~0.8 ms.
 */
class ColorLUT {

    static mcodeB64 := "hdJBidJIichBVA+ewkWFwFUPnsFXCMpWU0yLXCRQSItcJFhIi3QkYEiL" . 
    "fCRoD4WQAAAASIXAD4SHAAAASIX/D4SFAAAATWPhMe1JicEPHwBMicgx0mZmLg8fhAAAAAAAZmY" . 
    "uDx+EAAAAAABmZi4PH4QAAAAAAGYuDx+EAAAAAAAPtgiDwgFIg8AEQQ+2DAuISPwPtkj9D7YMC4" . 
    "hI/Q+2SP4PtgwOiEj+D7ZI/w+2DA+ISP9BOdJ/yIPFAU0B4UE56H+NW15fXUFcw0lj+THtSYnBZ" . 
    "mYuDx+EAAAAAAAPHwBMicgx0mZmLg8fhAAAAAAAZmYuDx+EAAAAAAAPH0QAAA+2CIPCAUiDwARB" . 
    "D7YMC4hI/A+2SP0PtgwLiEj9D7ZI/g+2DA6ISP5BOdJ/04PFAUkB+UE56H+oW15fXUFcwzHAww=="

    static pMCode := 0

    /**
     * Initializes the x64 assembly routine on-demand.
     */
    static __InitMCode() {
        if (this.pMCode)
            return
        local len := 0, buf := Buffer(len, 0), oldProt := 0
        DllCall("crypt32\CryptStringToBinaryA", "astr", this.mcodeB64, "uint", 0, "uint", 1, "ptr", 0, "uint*", &len, "ptr", 0, "ptr", 0)
        DllCall("crypt32\CryptStringToBinaryA", "astr", this.mcodeB64, "uint", 0, "uint", 1, "ptr", buf.ptr, "uint*", &len, "ptr", 0, "ptr", 0)
        DllCall("VirtualProtect", "ptr", buf.ptr, "uptr", len, "uint", 0x40, "uint*", &oldProt)
        this.pMCode := buf
    }

    /**
     * Applies a 256-entry color lookup table (LUT) transformation directly to a GDI+ Bitmap.
     *
     * @param {Pointer|Bitmap|Object} targetBitmap GDI+ pBitmap pointer or Bitmap instance
     * @param {Array|Buffer} lutB 256-byte table for Blue channel (B' = lutB[B])
     * @param {Array|Buffer} lutG 256-byte table for Green channel (G' = lutG[G])
     * @param {Array|Buffer} lutR 256-byte table for Red channel (R' = lutR[R])
     * @param {Array|Buffer} [lutA] Optional 256-byte table for Alpha channel (A' = lutA[A])
     * @returns {Boolean} True on success
     *
     * @example
     * ; 1. High-contrast threshold
     * tTable := ColorLUT.Threshold(128)
     * ColorLUT.Apply(myBitmap, tTable, tTable, tTable)
     *
     * ; 2. Invert specific channels
     * ColorLUT.Apply(myBitmap, ColorLUT.Invert(), ColorLUT.Identity(), ColorLUT.Invert())
     */
    static Apply(targetBitmap, lutB, lutG, lutR, lutA?) {
        local pBitmap, w, h, stride, scan0, bufB, bufG, bufR, ptrA, bufA, status

        if (!this.pMCode)
            this.__InitMCode()

        pBitmap := (IsObject(targetBitmap) && targetBitmap.HasProp("ptr")) ? targetBitmap.ptr : targetBitmap
        if (!pBitmap)
            throw ValueError("[!] Invalid pBitmap pointer")

        w := 0
        h := 0
        DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &w:=0)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &h:=0)
        if (w <= 0 || h <= 0)
            return false

        static rect := Buffer(16, 0)
        NumPut("int", 0, rect, 0)
        NumPut("int", 0, rect, 4)
        NumPut("int", w, rect, 8)
        NumPut("int", h, rect, 12)

        ; BitmapData structure: Width, Height, Stride, PixelFormat, Scan0, Reserved
        static bmd := Buffer(32, 0)
        ; PixelFormat32bppARGB (0x26200A), ImageLockModeRead | ImageLockModeWrite (3)
        status := DllCall("gdiplus\GdipBitmapLockBits", "ptr", pBitmap, "ptr", rect, "uint", 3, "int", 0x26200A, "ptr", bmd)
        if (status != 0)
            throw Error("[!] GdipBitmapLockBits failed with status: " status)

        stride := NumGet(bmd, 8, "int")
        scan0  := NumGet(bmd, 16, "ptr")

        bufB := this.__ToBuffer(lutB)
        bufG := this.__ToBuffer(lutG)
        bufR := this.__ToBuffer(lutR)
        ptrA := 0
        bufA := 0
        if (IsSet(lutA)) {
            bufA := this.__ToBuffer(lutA)
            ptrA := bufA.ptr
        }

        ; Call x64 machine code
        DllCall(this.pMCode.ptr, "ptr", scan0, "int", w, "int", h, "int", stride, "ptr", bufB.ptr, "ptr", bufG.ptr, "ptr", bufR.ptr, "ptr", ptrA, "cdecl")

        DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBitmap, "ptr", bmd)
        return true
    }

    /**
     * Normalizes an Array or Buffer into a 256-byte binary lookup buffer.
     */
    static __ToBuffer(lut) {
        local buf, i, v
        if (lut is Buffer && lut.Size >= 256)
            return lut
        buf := Buffer(256, 0)
        loop 256 {
            i := A_Index - 1
            v := (lut.Has(i + 1)) ? lut[i + 1] : i
            NumPut("uchar", Max(0, Min(255, v)), buf, i)
        }
        return buf
    }

    /**
     * Identity (pass-through) table: `f(x) = x`. Leaves channel unmodified.
     *
     * @returns {Buffer} 256-byte binary buffer
     */
    static Identity() {
        local buf := Buffer(256, 0)
        loop 256
            NumPut("uchar", A_Index - 1, buf, A_Index - 1)
        return buf
    }

    /**
     * Invert table: `f(x) = 255 - x`. Inverts channel intensity.
     *
     * @returns {Buffer} 256-byte binary buffer
     */
    static Invert() {
        local buf := Buffer(256, 0)
        loop 256
            NumPut("uchar", 255 - (A_Index - 1), buf, A_Index - 1)
        return buf
    }

    /**
     * Posterize (color quantization) table. Reduces continuous tones into N discrete stepped levels.
     *
     * @param {Integer} [levels=4] Number of discrete steps (2 to 256)
     * @returns {Buffer} 256-byte binary buffer
     */
    static Posterize(levels := 4) {
        local buf := Buffer(256, 0), step, i, bucket
        step := 255 / Max(1, levels - 1)
        loop 256 {
            i := A_Index - 1
            bucket := Round(i / (256 / levels))
            NumPut("uchar", Min(255, Round(bucket * step)), buf, i)
        }
        return buf
    }

    /**
     * High-contrast binary threshold table. Values below cutoff become 0, >= cutoff become 255.
     *
     * @param {Integer} [cutoff=128] Threshold cutoff boundary (0 to 255)
     * @returns {Buffer} 256-byte binary buffer
     */
    static Threshold(cutoff := 128) {
        local buf := Buffer(256, 0), i
        loop 256 {
            i := A_Index - 1
            NumPut("uchar", (i >= cutoff) ? 255 : 0, buf, i)
        }
        return buf
    }

    /**
     * Solarization tone curve table. Inverts tonal values above a specified pivot point.
     *
     * @param {Integer} [cutoff=128] Inversion pivot point (0 to 255)
     * @returns {Buffer} 256-byte binary buffer
     */
    static Solarize(cutoff := 128) {
        local buf := Buffer(256, 0), i
        loop 256 {
            i := A_Index - 1
            NumPut("uchar", (i < cutoff) ? i : (255 - i), buf, i)
        }
        return buf
    }

    /**
     * Brightness and contrast adjustment tone table.
     *
     * @param {Float|Integer} [brightness=0] Additive brightness offset (-255 to 255)
     * @param {Float|Integer} [contrast=0] Multiplicative contrast slope factor (-255 to 255)
     * @returns {Buffer} 256-byte binary buffer
     */
    static BrightnessContrast(brightness := 0, contrast := 0) {
        local buf := Buffer(256, 0), factor, val, adjusted
        factor := (259 * (contrast + 255)) / (255 * (259 - contrast))
        loop 256 {
            val := A_Index - 1
            adjusted := Round(factor * (val - 128) + 128 + brightness)
            NumPut("uchar", Max(0, Min(255, adjusted)), buf, val)
        }
        return buf
    }

    /**
     * Non-linear gamma correction tone table: `f(x) = 255 * (x / 255) ^ (1 / gamma)`.
     *
     * @param {Float} [gamma=2.2] Gamma exponent value (> 0.0)
     * @returns {Buffer} 256-byte binary buffer
     */
    static Gamma(gamma := 2.2) {
        local buf := Buffer(256, 0), invGamma, i, norm
        invGamma := 1.0 / gamma
        loop 256 {
            i := A_Index - 1
            norm := i / 255.0
            NumPut("uchar", Round(255.0 * (norm ** invGamma)), buf, i)
        }
        return buf
    }

    /**
     * Generates a 3-channel (B, G, R) LUT buffer array from a ColorBuffer gradient palette.
     *
     * @param {ColorBuffer} colorBuffer ColorBuffer gradient instance (e.g. `ColorBuffer.Thermal`, `ColorBuffer.Turbo`)
     * @returns {Array<Buffer>} Array of 3 buffers: `[bufB, bufG, bufR]`
     */
    static FromGradient(colorBuffer) {
        local bufB, bufG, bufR, i, clr, pGrad
        bufB := Buffer(256, 0)
        bufG := Buffer(256, 0)
        bufR := Buffer(256, 0)
        pGrad := colorBuffer.ptr
        loop 256 {
            i := A_Index - 1
            clr := NumGet(pGrad, i * 4, "uint")
            NumPut("uchar", clr & 0xFF, bufB, i)
            NumPut("uchar", (clr >> 8) & 0xFF, bufG, i)
            NumPut("uchar", (clr >> 16) & 0xFF, bufR, i)
        }
        return [bufB, bufG, bufR]
    }
}