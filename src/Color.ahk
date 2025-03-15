; Script     Color.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025
; Version    0.7.0

/**
 * A class for color manipulation and generation.
 * @property ColorNames a list of color names
 * credits for sharing: iseahound
 * 
 * @Example
 * c := Color() ; random color
 * c := Color("Lime") ; color name by calling the color class
 * c := Color.Lime ; direct access to value by name
 * c := Color("Red|Blue|Green") ; random color from the list
 * c := Color("0xFF0000FF") ; 0xARGB
 * c := Color("#FF0000FF") ; #ARGB
 * c := Color("0x0000FF") ; 0xRRGGBB
 * c := Color("#0000FF") ; #RRGGBB
 * c := Color(0xFF000000) ; hex
 */
class Color {

    /**
     * Returns a random color, accepts multiple type of color inputs
     * @param {str} c a color name, ARGB, or a list of color names separated by "|"
     * @returns {int} ARGB
     * credits for the idea: iseahound https://github.com/iseahound/Graphics
     * 
     * TODO: color name should be around the top segment
     */
    static Call(c := "") {
        if (Type(c) == "String") {
            return (c == "") ? Random(0xFF000000, 0xFFFFFFFF)       ; random ARGB with max alpha
                : c ~= "^0x[a-fA-F0-9]{8}$" ? c                   ; correct 0xAARRGGBB 
                : c ~= "^0x[a-fA-F0-9]{6}$" ? "0xFF" SubStr(c, 3) ; missing alpha channel (0xRRGGBB)
                : c ~= "^#[a-fA-F0-9]{8}$"  ? "0x" SubStr(c, 2)   ; #AARRGGBB
                : c ~= "^#[a-fA-F0-9]{6}$"  ? "0xFF" SubStr(c, 2) ; #RRGGBB
                : c ~= "^[a-fA-F0-9]{8}$"   ? "0x" c              ; missing prefix (AARRGGBB)
                : c ~= "^[a-fA-F0-9]{6}$"   ? "0xFF" c            ; missing 0xFF (RRGGBB)
                : c ~= "\|"                 ? this.Random(c)      ; random ARGB
                : c ~= "^[a-zA-Z]{3,}"      ? this.%c% : ""       ; colorName
        }
        else if (Type(c) == "Integer" && c <= 0xFFFFFFFF && c >= 0x00000000) {
            return c
        }
        throw ValueError("Invalid color input")
    }

    /**
     * Sets the alpha channel of a color
     * @param ARGB a valid ARGB
     * @param {int} A alpha channel value
     * @returns {int} ARGB
     */
    static Alpha(ARGB, A := 255) {
        A := (A > 255 ? 255 : A < 0 ? 0 : A)
        return (A << 24) | (ARGB & 0x00FFFFFF)
    }

    /**
     * Sets the alpha channel of a color in float format
     * @param ARGB a valid ARGB
     * @param {float} A alpha channel value
     * @returns {int} ARGB
     */
    static AlphaF(ARGB, A := 1.0) {
        A := (A > 1.0 ? 255 : A < 0.0 ? 0 : Ceil(A * 255))
        return (A << 24) | (ARGB & 0x00FFFFFF)
    }

    /**
     * Swaps the color channels of an ARGB color
     * @param colour 
     * @param {str} mode 
     * @returns {int} 
     */
    static ChannelSwap(colour, mode := "Rand") {
        
        static modes := ["RGB", "RBG", "BGR", "BRG", "GRB", "GBR"]
        
        local A, R, G, B
        local c := 0x0

        if (mode ~= "i)^R(and(om)?)?$") {
            mode := modes[Random(1, modes.Length)]
        }
        else if !(mode ~= "i)^(?!.*(.).*\1)[RGB]{3}$") {
            throw ValueError("Invalid mode")
        }

        A := (0xff000000 & colour) >> 24
        R := (0x00ff0000 & colour) >> 16
        G := (0x0000ff00 & colour) >>  8
        B :=  0x000000ff & colour

        for i, channel in StrSplit(mode) {
            switch channel {
                case "R","r": c := c | R << 8 * (3 - i)
                case "G","g": c := c | G << 8 * (3 - i)
                case "B","b": c := c | B << 8 * (3 - i)
            }
        }
        return (A << 24) | c
    }

    /**
     * Returns an array of colors that transition from color1 to color2
     * @param color1 starting color
     * @param color2 end color
     * @param backforth number of transitions * 100, 2 means back and forth (doubles the array size)
     * @returns {array}
     */
    static GetTransation(color1, color2, backforth := false) {
        
        local clr, arr

        if (backforth !== 0 && backforth !== 1)
            throw ValueError("backforth must be bool")

        ; Validate the colors
        color1 := this.Call(color1)
        color2 := this.Call(color2)

        ; Prepare the return array
        arr := []
        arr.Length := (backforth + 1) * 100

        ; Push the colors to the array based on the color distance
        loop 100 {
            clr := this.LinearInterpolation(color1, color2, A_Index)
            if (backforth) {
                arr[200 - A_Index + 1] := clr
            } 
            arr[A_Index] := clr
        }
        return arr
    }

    /**
     * Returns a color that transition from color1 to color2 on a given distance
     * @param color1 starting color
     * @param color2 end color
     * @param dist distance between the colors
     * @param alpha alpha channel
     * @returns {array}
     */
    static LinearInterpolation(color1, color2, dist, alpha := 255) {
        
        local p, c1, c2, R, G, B, R1, G1, B1, R2, G2, B2
        
        ; Convert integer and float to percentage
        if (Type(dist) == "Integer" && dist >= 0 && dist <= 100) {
            p := dist * .01
        }
        else if (Type(dist) == "Float" && dist >= 0 && dist <= 1) {
            p := dist * 100
        }
        else {
            throw ValueError("Must be an integer or float")
        }

        ; Get the R, G, B components of colors
        c1 := color1
        c2 := color2
    
        R1 := (0x00ff0000 & c1) >> 16
        G1 := (0x0000ff00 & c1) >>  8
        B1 :=  0x000000ff & c1
        
        R2 := (0x00ff0000 & c2) >> 16
        G2 := (0x0000ff00 & c2) >>  8
        B2 :=  0x000000ff & c2
        
        ; Calculate the new values
        R := R1 + Ceil(p * (R2 - R1))
        G := G1 + Ceil(p * (G2 - G1))
        B := B1 + Ceil(p * (B2 - B1))

        return (alpha << 24) | (R << 16) | (G << 8) | B
    }

    /**
     * Returns a random color, accepts multiple color names, and randomness
     * @param {str} colorName single or multiple color names separated by "|"
     * @param {int} randomness adds a random factor to each channel
     * @returns {int} ARGB
     */
    static Random(colorName := "", randomness := false) {
        
        local colors, rand

        if (colorName == "")
            return Random(0xFF000000, 0xFFFFFFFF)

        ; Check if the string contains multiple color names
        if (colorName ~= "i)^[a-zA-Z|]+$") {           ; <----- TODO simpler regex
            colors := StrSplit(colorName, "|")
        } else
            colors := [colorName]

        ; Select a random color from the list
        rand := Random(1, colors.Length)
        if (!this.HasProp(colors[rand])) {
            OutputDebug("[i] Color " colors[rand] " not found`n")
            ; or try regex search from here ...
            return Random(0xFF000000, 0xFFFFFFFF)
        }

        ; Apply randomness
        colors := this.%colors[rand]%
        if (randomness) {
            return this.Randomize(colors, randomness)
        }
        return colors
    }

    /**
     * Randomize a color with a given randomness
     * @param {int} ARGB a valid ARGB
     * @param {int} rand the randomness value
     * @returns {int} 
     */
    static Randomize(ARGB, rand := 15) {

        local R := (0x00ff0000 & ARGB) >> 16
        local G := (0x0000ff00 & ARGB) >>  8
        local B :=  0x000000ff & ARGB

        R := Min(255, Max(0, R + Random(-rand, rand)))
        G := Min(255, Max(0, G + Random(-rand, rand)))
        B := Min(255, Max(0, B + Random(-rand, rand)))

        return 0xFF000000 | (R << 16) | (G << 8) | B
    }

    /**
     * Returns a random ARGB, also accessible as a function (RandomARGB)
     * @returns {int} 
     */
    static RandomARGB() {
        return Random(0xFF000000, 0xFFFFFFFF)
    }

    /**
     * Returns a random color with a given alpha channel from a range
     * @param {int} alpha the alpha channel value or the range minimum
     * @param {int} max the maximum range value
     * @returns {int} 
     */
    static RandomARGBAlphaMax(alpha := 0xFF, max := false) {
        if (alpha > 255 || alpha < 0 || max > 255 || max < 0)
            throw ValueError("Alpha must be between 0 and 255")
        
        alpha := (max) ? Random(alpha, max) : alpha
        return (alpha << 24) | Random(0x0, 0xFFFFFF)
    }

    /**
     * Returns a color that transition from color1 to color2 on a given distance.
     * Alias for LinearInterpolation.
     * @param color1 starting color
     * @param color2 end color
     * @param dist distance between the colors
     * @param alpha alpha channel
     * @returns {int} ARGB
     */
    static Transation(color1, color2, dist := 1, alpha := 255) {
        return this.LinearInterpolation(color1, color2, dist, alpha)
    }

    ;{ Color names
    ;
    ; Credits for sharing: iseahound https://github.com/iseahound
    ;
    ; José Roca Software, GDI+ Flat API Reference
    ; Enumerations: http://www.jose.it-berater.org/gdiplus/iframe/index.htm
    ;
    ; Get a colorname: ARGB := Color.BlueViolet
    static Aliceblue            := "0xFFF0f8FF",
           AntiqueWhite         := "0xFFFAEBD7",
           Aqua                 := "0xFF00FFFF",
           Aquamarine           := "0xFF7FFFD4",
           Azure                := "0xFFF0FFFF",
           Beige                := "0xFFF5F5DC",
           Bisque               := "0xFFFFE4C4",
           Black                := "0xFF000000",
           BlanchedAlmond       := "0xFFFFEBCD",
           Blue                 := "0xFF0000FF",
           BlueViolet           := "0xFF8A2BE2",
           Brown                := "0xFFA52A2A",
           BurlyWood            := "0xFFDEB887",
           CadetBlue            := "0xFF5F9EA0",
           Chartreuse           := "0xFF7FFF00",
           Chocolate            := "0xFFD2691E",
           Coral                := "0xFFFF7F50",
           CornflowerBlue       := "0xFF6495ED",
           Cornsilk             := "0xFFFFF8DC",
           Crimson              := "0xFFDC143C",
           Cyan                 := "0xFF00FFFF",
           DarkBlue             := "0xFF00008B",
           DarkCyan             := "0xFF008B8B",
           DarkGoldenrod        := "0xFFB8860B",
           DarkGray             := "0xFFA9A9A9",
           DarkGreen            := "0xFF006400",
           DarkKhaki            := "0xFFBDB76B",
           DarkMagenta          := "0xFF8B008B",
           DarkOliveGreen       := "0xFF556B2F",
           DarkOrange           := "0xFFFF8C00",
           DarkOrchid           := "0xFF9932CC",
           DarkRed              := "0xFF8B0000",
           DarkSalmon           := "0xFFE9967A",
           DarkSeaGreen         := "0xFF8FBC8B",
           DarkSlateBlue        := "0xFF483D8B",
           DarkSlateGray        := "0xFF2F4F4F",
           DarkTurquoise        := "0xFF00CED1",
           DarkViolet           := "0xFF9400D3",
           DeepPink             := "0xFFFF1493",
           DeepSkyBlue          := "0xFF00BFFF",
           DimGray              := "0xFF696969",
           DodgerBlue           := "0xFF1E90FF",
           Firebrick            := "0xFFB22222",
           FloralWhite          := "0xFFFFFAF0",
           ForestGreen          := "0xFF228B22",
           Fuchsia              := "0xFFFF00FF",
           Gainsboro            := "0xFFDCDCDC",
           GhostWhite           := "0xFFF8F8FF",
           Gold                 := "0xFFFFD700",
           Goldenrod            := "0xFFDAA520",
           Gray                 := "0xFF808080",
           Green                := "0xFF008000",
           GreenYellow          := "0xFFADFF2F",
           Honeydew             := "0xFFF0FFF0",
           HotPink              := "0xFFFF69B4",
           IndianRed            := "0xFFCD5C5C",
           Indigo               := "0xFF4B0082",
           Ivory                := "0xFFFFFFF0",
           Khaki                := "0xFFF0E68C",
           Lavender             := "0xFFE6E6FA",
           LavenderBlush        := "0xFFFFF0F5",
           LawnGreen            := "0xFF7CFC00",
           LemonChiffon         := "0xFFFFFACD",
           LightBlue            := "0xFFADD8E6",
           LightCoral           := "0xFFF08080",
           LightCyan            := "0xFFE0FFFF",
           LightGoldenrodYellow := "0xFFFAFAD2",
           LightGray            := "0xFFD3D3D3",
           LightGreen           := "0xFF90EE90",
           LightPink            := "0xFFFFB6C1",
           LightSalmon          := "0xFFFFA07A",
           LightSeaGreen        := "0xFF20B2AA",
           LightSkyBlue         := "0xFF87CEFA",
           LightSlateGray       := "0xFF778899",
           LightSteelBlue       := "0xFFB0C4DE",
           LightYellow          := "0xFFFFFFE0",
           Lime                 := "0xFF00FF00",
           LimeGreen            := "0xFF32CD32",
           Linen                := "0xFFFAF0E6",
           Magenta              := "0xFFFF00FF",
           Maroon               := "0xFF800000",
           MediumAquamarine     := "0xFF66CDAA",
           MediumBlue           := "0xFF0000CD",
           MediumOrchid         := "0xFFBA55D3",
           MediumPurple         := "0xFF9370DB",
           MediumSeaGreen       := "0xFF3CB371",
           MediumSlateBlue      := "0xFF7B68EE",
           MediumSpringGreen    := "0xFF00FA9A",
           MediumTurquoise      := "0xFF48D1CC",
           MediumVioletRed      := "0xFFC71585",
           MidnightBlue         := "0xFF191970",
           MintCream            := "0xFFF5FFFA",
           MistyRose            := "0xFFFFE4E1",
           Moccasin             := "0xFFFFE4B5",
           NavajoWhite          := "0xFFFFDEAD",
           Navy                 := "0xFF000080",
           OldLace              := "0xFFFDF5E6",
           Olive                := "0xFF808000",
           OliveDrab            := "0xFF6B8E23",
           Orange               := "0xFFFFA500",
           OrangeRed            := "0xFFFF4500",
           Orchid               := "0xFFDA70D6",
           PaleGoldenrod        := "0xFFEEE8AA",
           PaleGreen            := "0xFF98FB98",
           PaleTurquoise        := "0xFFAFEEEE",
           PaleVioletRed        := "0xFFDB7093",
           PapayaWhip           := "0xFFFFEFD5",
           PeachPuff            := "0xFFFFDAB9",
           Peru                 := "0xFFCD853F",
           Pink                 := "0xFFFFC0CB",
           Plum                 := "0xFFDDA0DD",
           PowderBlue           := "0xFFB0E0E6",
           Purple               := "0xFF800080",
           Red                  := "0xFFFF0000",
           RosyBrown            := "0xFFBC8F8F",
           RoyalBlue            := "0xFF4169E1",
           SaddleBrown          := "0xFF8B4513",
           Salmon               := "0xFFFA8072",
           SandyBrown           := "0xFFF4A460",
           SeaGreen             := "0xFF2E8B57",
           SeaShell             := "0xFFFFF5EE",
           Sienna               := "0xFFA0522D",
           Silver               := "0xFFC0C0C0",
           SkyBlue              := "0xFF87CEEB",
           SlateBlue            := "0xFF6A5ACD",
           SlateGray            := "0xFF708090",
           Snow                 := "0xFFFFFAFA",
           SpringGreen          := "0xFF00FF7F",
           SteelBlue            := "0xFF4682B4",
           Tan                  := "0xFFD2B48C",
           Teal                 := "0xFF008080",
           Thistle              := "0xFFD8BFD8",
           Tomato               := "0xFFFF6347",
           Transparent          := "0x00FFFFFF",
           Turquoise            := "0xFF40E0D0",
           Violet               := "0xFFEE82EE",
           Wheat                := "0xFFF5DEB3",
           White                := "0xFFFFFFFF",
           WhiteSmoke           := "0xFFF5F5F5",
           Yellow               := "0xFFFFFF00",
           YellowGreen          := "0xFF9ACD32",
           
           ; User defined colors

           ; Github
           GitHubBlue           := "0xFF0969DA", ; Links and branding elements
           GitHubGray900        := "0xFF0D1117", ; Dark mode background
           GitHubGray800        := "0xFF161B22"  ; Secondary background
    ;}
    ; Region specific colors
    static LoadRAL() {
        local key, ARGB, RAL
        RAL := {
           RAL1000 : "0xFFBEBD7F",
           RAL1001 : "0xFFC2B078",
           RAL1002 : "0xFFC6A664",
           RAL1003 : "0xFFE5BE01",
           RAL1004 : "0xFFFFD700",
           RAL1005 : "0xFFFFAA1D",
           RAL1006 : "0xFFFFA420",
           RAL1007 : "0xFFFF8C00",
           RAL1011 : "0xFF8A6642",
           RAL1012 : "0xFFD7D7D7",
           RAL1013 : "0xFFEAE6CA",
           RAL1014 : "0xFFE1CC4F",
           RAL1015 : "0xFFE6D690",
           RAL1016 : "0xFFFFF700",
           RAL1017 : "0xFFFFE600",
           RAL1018 : "0xFFFFF200",
           RAL1019 : "0xFF9E9764",
           RAL1020 : "0xFF999950",
           RAL1021 : "0xFFFFD700",
           RAL1023 : "0xFFFFC000",
           RAL1024 : "0xFFAEA04B",
           RAL1026 : "0xFFFFE600",
           RAL1027 : "0xFF9D9101",
           RAL1028 : "0xFFFFA420",
           RAL1032 : "0xFFFFD300",
           RAL1033 : "0xFFFFA420",
           RAL1034 : "0xFFFFE600",
           RAL1035 : "0xFF6A5D4D",
           RAL1036 : "0xFF705335",
           RAL1037 : "0xFFFFA420",
           RAL2000 : "0xFFED760E",
           RAL2001 : "0xFFBE4D25",
           RAL2002 : "0xFFB7410E",
           RAL2003 : "0xFFFF7514",
           RAL2004 : "0xFFFF5E00",
           RAL2005 : "0xFFFF4F00",
           RAL2007 : "0xFFFFB000",
           RAL2008 : "0xFFF44611",
           RAL2009 : "0xFFD84B20",
           RAL2010 : "0xFFE55137",
           RAL2011 : "0xFFF35C20",
           RAL2012 : "0xFFD35831",
           RAL3000 : "0xFFAF2B1E",
           RAL3001 : "0xFFA52019",
           RAL3002 : "0xFF9B111E",
           RAL3003 : "0xFF75151E",
           RAL3004 : "0xFF5E2129",
           RAL3005 : "0xFF5E1A1B",
           RAL3007 : "0xFF412227",
           RAL3009 : "0xFF642424",
           RAL3011 : "0xFF781F19",
           RAL3012 : "0xFFC1876B",
           RAL3013 : "0xFF9E2A2B",
           RAL3014 : "0xFFD36E70",
           RAL3015 : "0xFFEA899A",
           RAL3016 : "0xFFB32821",
           RAL3017 : "0xFFB44C43",
           RAL3018 : "0xFFCC474B",
           RAL3020 : "0xFFCC3333",
           RAL3022 : "0xFFD36E70",
           RAL3024 : "0xFFFF3F00",
           RAL3026 : "0xFFFF2B2B",
           RAL3027 : "0xFFB53389",
           RAL3028 : "0xFFCB3234",
           RAL3031 : "0xFFB32428",
           RAL4001 : "0xFF6D3F5B",
           RAL4002 : "0xFF922B3E",
           RAL4003 : "0xFFDE4C8A",
           RAL4004 : "0xFF641C34",
           RAL4005 : "0xFF6C4675",
           RAL4006 : "0xFF993366",
           RAL4007 : "0xFF4A192C",
           RAL4008 : "0xFF924E7D",
           RAL4009 : "0xFFCF3476",
           RAL5000 : "0xFF354D73",
           RAL5001 : "0xFF1F4764",
           RAL5002 : "0xFF00387B",
           RAL5003 : "0xFF1D334A",
           RAL5004 : "0xFF18171C",
           RAL5005 : "0xFF1E2460",
           RAL5007 : "0xFF3E5F8A",
           RAL5008 : "0xFF26252D",
           RAL5009 : "0xFF025669",
           RAL5010 : "0xFF0E294B",
           RAL5011 : "0xFF231A24",
           RAL5012 : "0xFF3B83BD",
           RAL5013 : "0xFF232C3F",
           RAL5014 : "0xFF637D96",
           RAL5015 : "0xFF2874A6",
           RAL5017 : "0xFF063971",
           RAL5018 : "0xFF3F888F",
           RAL5019 : "0xFF1B5583",
           RAL5020 : "0xFF1D334A",
           RAL5021 : "0xFF256D7B",
           RAL5022 : "0xFF282D3C",
           RAL5023 : "0xFF3F3F4E",
           RAL5024 : "0xFF5D9B9B",
           RAL6000 : "0xFF327662",
           RAL6001 : "0xFF287233",
           RAL6002 : "0xFF2D572C",
           RAL6003 : "0xFF424632",
           RAL6004 : "0xFF1F3A3D",
           RAL6005 : "0xFF2F4538",
           RAL6006 : "0xFF3E3B32",
           RAL6007 : "0xFF343B29",
           RAL6008 : "0xFF39352A",
           RAL6009 : "0xFF31372B",
           RAL6010 : "0xFF35682D",
           RAL6011 : "0xFF587246",
           RAL6012 : "0xFF343E40",
           RAL6013 : "0xFF6C7156",
           RAL6014 : "0xFF47402E",
           RAL6015 : "0xFF3B3C36",
           RAL6016 : "0xFF1E5945",
           RAL6017 : "0xFF4C9141",
           RAL6018 : "0xFF57A639",
           RAL6019 : "0xFFBDECB6",
           RAL6020 : "0xFF2E3A23",
           RAL6021 : "0xFF89AC76",
           RAL6022 : "0xFF25221B",
           RAL6024 : "0xFF308446",
           RAL6025 : "0xFF3D642D",
           RAL6026 : "0xFF015D52",
           RAL6027 : "0xFF84C3BE",
           RAL6028 : "0xFF2C5545",
           RAL6029 : "0xFF20603D",
           RAL6032 : "0xFF317F43",
           RAL6033 : "0xFF497E76",
           RAL6034 : "0xFF7FB5B5",
           RAL7000 : "0xFF78858B",
           RAL7001 : "0xFF8A9597",
           RAL7002 : "0xFF817F68",
           RAL7003 : "0xFF7D7F7D",
           RAL7004 : "0xFF9C9C9C",
           RAL7005 : "0xFF6C7059",
           RAL7006 : "0xFF766A5A",
           RAL7008 : "0xFF6A5F31",
           RAL7009 : "0xFF4D5645",
           RAL7010 : "0xFF4C514A",
           RAL7011 : "0xFF434B4D",
           RAL7012 : "0xFF4E5754",
           RAL7013 : "0xFF464531",
           RAL7015 : "0xFF51565C",
           RAL7016 : "0xFF373F43",
           RAL7021 : "0xFF2F353B",
           RAL7022 : "0xFF4B4D46",
           RAL7023 : "0xFF818479",
           RAL7024 : "0xFF474A51",
           RAL7026 : "0xFF374447",
           RAL7030 : "0xFF939388",
           RAL7031 : "0xFF5D6970",
           RAL7032 : "0xFFB9B9A8",
           RAL7033 : "0xFF7D8471",
           RAL7034 : "0xFF8F8B66",
           RAL7035 : "0xFFD7D7D7",
           RAL7036 : "0xFF7F7679",
           RAL7037 : "0xFF7D7F7D",
           RAL7038 : "0xFFB8B8B1",
           RAL7039 : "0xFF6C6E58",
           RAL7040 : "0xFF9DA1AA",
           RAL7042 : "0xFF8D948D",
           RAL7043 : "0xFF4E5451",
           RAL7044 : "0xFFCAC4B0",
           RAL7045 : "0xFF909090",
           RAL7046 : "0xFF82898F",
           RAL7047 : "0xFFD0D0D0",
           RAL8000 : "0xFF826C34",
           RAL8001 : "0xFF955F20",
           RAL8002 : "0xFF6C3B2A",
           RAL8003 : "0xFF734222",
           RAL8004 : "0xFF8E402A",
           RAL8007 : "0xFF59351F",
           RAL8008 : "0xFF6F4F28",
           RAL8011 : "0xFF5B3A29",
           RAL8012 : "0xFF592321",
           RAL8014 : "0xFF382C1E",
           RAL8015 : "0xFF633A34",
           RAL8016 : "0xFF4C2F27",
           RAL8017 : "0xFF45322E",
           RAL8019 : "0xFF403A3A",
           RAL8022 : "0xFF212121",
           RAL8023 : "0xFFA65E2E",
           RAL8024 : "0xFF79553D",
           RAL8025 : "0xFF755C48",
           RAL8028 : "0xFF4E3B31",
           RAL9001 : "0xFFFDF4E3",
           RAL9002 : "0xFFE7EBDA",
           RAL9003 : "0xFFF4F4F4",
           RAL9004 : "0xFF282828",
           RAL9005 : "0xFF0A0A0A",
           RAL9006 : "0xFFA5A5A5",
           RAL9007 : "0xFF8F8F8F",
           RAL9010 : "0xFFFFFFF4",
           RAL9011 : "0xFF1C1C1C",
           RAL9016 : "0xFFF6F6F6",
           RAL9017 : "0xFF1E1E1E",
           RAL9018 : "0xFFD7D7D7" }
        for key, ARGB in RAL.OwnProps() {
            this.%key% := ARGB
        }
    }
}
