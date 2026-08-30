; Script:    Dialog.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2

/**
 * Modern Minimalist Vector Dialog & MsgBox Engine for GpGFX.
 * Features:
 *   - Clean, high-readability typography (13pt titles, 11.5pt body with auto word-wrapping).
 *   - Monokai, Catppuccin, Nord, TokyoNight, and Cyberpunk theme palettes.
 *   - Rich text formatting support: `{color:Red}Word{color}` or `{color:#78DCE8}Accent{color}`.
 *   - Non-blocking vector dragging and fluid button hover animations.
 *   - Pure GpGFX retained vector shapes with 0 Win32 child controls.
 */
class Dialog {

    ; Default active theme (can be set to "Monokai", "Catppuccin", "Nord", "TokyoNight", "Cyberpunk", "Dracula")
    static Theme := "Monokai"
    static DefaultStyle := "Minimal" ; "Minimal", "Glass", "Compact"

    /**
     * Resolves theme colors based on active Palette.
     */
    static GetThemeColors(themeName := "", customAccent := "") {
        local tName := (themeName !== "") ? themeName : Dialog.Theme
        local pal := Palette.Get(tName)

        local bg := pal.bg
        local surface := pal.surface
        local text := pal.text
        local accent := (customAccent != "") ? Color(customAccent) : pal[1] ; Primary accent (e.g. Cyan/Blue)
        local accentWarn := pal[2] ; Yellow/Amber
        local accentError := pal[3] ; Pink/Red
        local accentSuccess := pal[4] ; Green

        return {
            bg: bg,
            surface: surface,
            text: text,
            accent: accent,
            warn: accentWarn,
            error: accentError,
            success: accentSuccess,
            border: "0x33FCFCFA",
            buttonBg: "0xFF2D2A2E",
            buttonHover: "0xFF3E3A40"
        }
    }

    /**
     * Displays a sleek, modern vector InputBox dialog.
     * @param {String} prompt - Prompt description text (supports {color:...} tags)
     * @param {String} title - Dialog title (default "Input Required")
     * @param {String} defaultText - Pre-filled text
     * @param {String} placeholder - Dimmed hint text when empty
     * @param {Object} options - Optional config { width, height, okText, cancelText, accent, theme }
     * @returns {String|False} Entered string on confirmation, false on cancel
     */
    static Input(prompt := "Enter value:", title := "Input Required", defaultText := "", placeholder := "Type here...", options := 0) {
        local w := (IsObject(options) && options.HasOwnProp("width")) ? options.width : 500
        local h := (IsObject(options) && options.HasOwnProp("height")) ? options.height : 250
        local okText := (IsObject(options) && options.HasOwnProp("okText")) ? options.okText : "Confirm"
        local cancelText := (IsObject(options) && options.HasOwnProp("cancelText")) ? options.cancelText : "Cancel"
        local themeName := (IsObject(options) && options.HasOwnProp("theme")) ? options.theme : Dialog.Theme
        local customAccent := (IsObject(options) && options.HasOwnProp("accent")) ? options.accent : ""

        local colors := Dialog.GetThemeColors(themeName, customAccent)
        local accent := colors.accent

        local x := (A_ScreenWidth - w) // 2
        local y := (A_ScreenHeight - h) // 2
        local lyrDlg := Layer(x, y, w, h, "GpGFX Dialog")
        lyrDlg.draggable := true

        local currentText := String(defaultText)
        local isDone := false
        local resultVal := false
        local cursorVisible := true
        local hoveredBtn := ""

        ; Retained Vector UI Elements (Clean Minimalist Card)

        ; Outer Backdrop card with rounded corners & subtle glow border
        RoundedRectangle(10, 10, w - 20, h - 20, 16, "0xF0181822", true)
        RoundedRectangle(10, 10, w - 20, h - 20, 16, colors.border, false)

        ; Accent left tag pill
        RoundedRectangle(26, 22, 5, 20, 3, accent, true)

        ; Title (13pt Bold)
        Rectangle(38, 16, w - 80, 32, "0x00000000", true)
            .Text(title, "0xFFFCFCFA", 13, "Segoe UI", "Bold", 5, "left", "middle")

        ; Prompt description (11.5pt Regular)
        Rectangle(26, 52, w - 52, 28, "0x00000000", true)
            .Text(prompt, "0xFFB0B0B8", 11.5, "Segoe UI", "", 5, "left", "middle")

        ; Input field container (Elevated surface with accent stroke)
        RoundedRectangle(26, 88, w - 52, 48, 10, "0xFF262632", true)
        RoundedRectangle(26, 88, w - 52, 48, 10, accent, false)

        ; Input text display (12pt Segoe UI)
        local inputDisplay := Rectangle(40, 88, w - 80, 48, "0x00000000", true)
        inputDisplay.Text(placeholder, "0xFF72707E", 12, "Segoe UI", "", 5, "left", "middle")

        ; Buttons
        local btnW := 115, btnH := 36
        local btnY := h - 60

        ; Cancel Button
        local btnCancelBg := RoundedRectangle(w - 265, btnY, btnW, btnH, 8, "0xFF262632", true)
        RoundedRectangle(w - 265, btnY, btnW, btnH, 8, "0x33FCFCFA", false)
        local btnCancelText := Rectangle(w - 265, btnY, btnW, btnH, "0x00000000", true)
            .Text(cancelText, "0xFFE0E0E6", 10.5, "Segoe UI", "Bold", 5, "center", "middle")

        ; Confirm Button
        local okBgColor := accent
        local okTxtClr := "0xFF121218"
        local btnOkBg := RoundedRectangle(w - 140, btnY, btnW, btnH, 8, okBgColor, true)
        local btnOkText := Rectangle(w - 140, btnY, btnW, btnH, "0x00000000", true)
            .Text(okText, okTxtClr, 10.5, "Segoe UI", "Bold", 5, "center", "middle")

        ; Interactive Event Handlers
        
        btnCancelBg.OnEvent("Click", (*) => (resultVal := false, isDone := true))
        btnCancelText.OnEvent("Click", (*) => (resultVal := false, isDone := true))

        btnOkBg.OnEvent("Click", (*) => (resultVal := currentText, isDone := true))
        btnOkText.OnEvent("Click", (*) => (resultVal := currentText, isDone := true))

        ; Mouse Hover tracking
        lyrDlg.OnEvent("MouseMove", (lyr, mx, my) => OnDialogHover(mx, my))

        OnDialogHover(mx, my) {
            local newHov := ""
            if (mx >= w - 265 && mx <= w - 150 && my >= btnY && my <= btnY + btnH)
                newHov := "Cancel"
            else if (mx >= w - 140 && mx <= w - 25 && my >= btnY && my <= btnY + btnH)
                newHov := "OK"

            if (newHov != hoveredBtn) {
                hoveredBtn := newHov
                btnCancelBg.Color := (hoveredBtn == "Cancel") ? "0xFF383848" : "0xFF262632"
                btnOkBg.Color := (hoveredBtn == "OK") ? "0xFFFFFFFF" : okBgColor
                Draw(lyrDlg)
            }
        }

        UpdateTextDisplay() {
            if (currentText == "") {
                inputDisplay.Text(placeholder . (cursorVisible ? " |" : ""), "0xFF72707E", 12, "Segoe UI", "", 5, "left", "middle")
            } else {
                inputDisplay.Text(currentText . (cursorVisible ? "|" : ""), "0xFFFCFCFA", 12, "Segoe UI", "", 5, "left", "middle")
            }
            Draw(lyrDlg)
        }

        local dlgHwnd := lyrDlg.hwnd

        ; Keyboard capture (Pass-through, only handles keys when dialog is focused)
        local ih := InputHook("V")
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := (hook, vk, sc) => OnDialogKey(vk, sc)
        ih.OnChar := (hook, char) => OnDialogChar(char)

        OnDialogKey(vk, sc) {
            if (!WinActive("ahk_id " . dlgHwnd) && DllCall("user32\GetForegroundWindow", "ptr") != dlgHwnd)
                return
            if (vk == 13 && !GetKeyState("Shift", "P") && !GetKeyState("Ctrl", "P")) { ; Enter
                resultVal := currentText
                isDone := true
            } else if (vk == 27) { ; Escape
                resultVal := false
                isDone := true
            } else if (vk == 8) { ; Backspace
                if (StrLen(currentText) > 0) {
                    currentText := SubStr(currentText, 1, -1)
                    UpdateTextDisplay()
                }
            } else if (vk == 86 && (GetKeyState("Ctrl", "P") || GetKeyState("Control", "P"))) { ; Ctrl+V Paste
                currentText .= A_Clipboard
                UpdateTextDisplay()
            }
        }

        OnDialogChar(char) {
            if (!WinActive("ahk_id " . dlgHwnd) && DllCall("user32\GetForegroundWindow", "ptr") != dlgHwnd)
                return
            if (Ord(char) >= 32 && !GetKeyState("Ctrl", "P") && !GetKeyState("Alt", "P")) {
                currentText .= char
                UpdateTextDisplay()
            }
        }

        ; Cursor blinking timer
        local blinkTimer := (*) => (cursorVisible := !cursorVisible, UpdateTextDisplay())
        SetTimer(blinkTimer, 500)

        ; Initial Render & Window Activation
        UpdateTextDisplay()
        lyrDlg.Activate()
        ih.Start()

        while (!isDone) {
            Sleep(10)
        }

        ih.Stop()
        SetTimer(blinkTimer, 0)
        KeyWait("LButton")
        KeyWait("Enter")
        lyrDlg.Dispose()
        lyrDlg := ""

        return resultVal
    }

    /**
     * Displays a modern minimalist vector MsgBox with rich text, theme accents, and custom buttons.
     * @param {String} [text=""] - Message description text (supports {color:...} formatting tags)
     * @param {String} [title="GpGFX"] - Dialog title
     * @param {Integer|String|Object} [options=0] - Modal options ("YesNo", "OKCancel", "IconWarn", etc.)
     * @param {Object} [config=0] - Configuration object { theme, accent, width, height, buttons, icon }
     * @returns {String} Clicked button: "OK", "Cancel", "Yes", "No"
     */
    static MsgBox(text := "", title := "GpGFX", options := 0, config := 0) {
        local w := 520
        local h := (StrLen(text) > 140) ? 270 : 230
        local btnType := "OK"
        local themeName := Dialog.Theme
        local customAccent := ""
        local iconType := ""

        ; If 4th parameter config object is provided, merge it
        if (IsObject(config)) {
            themeName := config.HasOwnProp("theme") ? config.theme : themeName
            customAccent := config.HasOwnProp("accent") ? config.accent : customAccent
            iconType := config.HasOwnProp("icon") ? config.icon : iconType
            w := config.HasOwnProp("width") ? config.width : w
            h := config.HasOwnProp("height") ? config.height : h
            if (config.HasOwnProp("buttons"))
                btnType := config.buttons
        }

        ; Parse options (Supports Integer bitmasks, String keywords, and Object configs)
        if (IsObject(options)) {
            btnType := options.HasOwnProp("buttons") ? options.buttons : btnType
            themeName := options.HasOwnProp("theme") ? options.theme : themeName
            customAccent := options.HasOwnProp("accent") ? options.accent : customAccent
            iconType := options.HasOwnProp("icon") ? options.icon : iconType
            w := options.HasOwnProp("width") ? options.width : w
            h := options.HasOwnProp("height") ? options.height : h
        } else if (IsInteger(options)) {
            if (options & 0x01)
                btnType := "OKCancel"
            else if (options & 0x04)
                btnType := "YesNo"
            else if (options & 0x03)
                btnType := "YesNoCancel"

            if (options & 0x10)
                iconType := "Error", customAccent := "0xFFFF6188"
            else if (options & 0x20)
                iconType := "Question", customAccent := "0xFFAB9DF2"
            else if (options & 0x30)
                iconType := "Warning", customAccent := "0xFFFFD866"
            else if (options & 0x40)
                iconType := "Info", customAccent := "0xFFA9DC76"
        } else if (Type(options) == "String") {
            local opts := StrLower(options)
            if InStr(opts, "yesno")
                btnType := "YesNo"
            else if InStr(opts, "okcancel")
                btnType := "OKCancel"

            if (opts ~= "i)Icon(Info|Information|\?)|info")
                iconType := "Info", customAccent := "0xFF78DCE8"
            else if (opts ~= "i)Icon(Warn|Warning|Exclamation|!)|warn")
                iconType := "Warning", customAccent := "0xFFFFD866"
            else if (opts ~= "i)Icon(Err|Error|Stop|Critical|X)|error")
                iconType := "Error", customAccent := "0xFFFF6188"
            else if (opts ~= "i)Icon(Question)|question")
                iconType := "Question", customAccent := "0xFFAB9DF2"
            else if (opts ~= "i)Icon(Check|Success|\*)|success")
                iconType := "Success", customAccent := "0xFFA9DC76"
        }

        ; Map icon presets
        local hasIcon := (iconType != "")
        local iconGlyph := "i", iconClr := 0xFF78DCE8, iconBg := 0x2278DCE8, iconBrd := 0x5578DCE8
        if (hasIcon) {
            switch StrLower(iconType) {
                case "warn", "warning", "exclamation", "3", "0x30", "48":
                    iconGlyph := "!", iconClr := 0xFFFFD866, iconBg := 0x28FFD866, iconBrd := 0x55FFD866
                case "err", "error", "stop", "critical", "1", "0x10", "16":
                    iconGlyph := "X", iconClr := 0xFFFF6188, iconBg := 0x28FF6188, iconBrd := 0x55FF6188
                case "question", "?", "2", "0x20", "32":
                    iconGlyph := "?", iconClr := 0xFFAB9DF2, iconBg := 0x28AB9DF2, iconBrd := 0x55AB9DF2
                case "success", "check", "ok":
                    iconGlyph := "V", iconClr := 0xFFA9DC76, iconBg := 0x28A9DC76, iconBrd := 0x55A9DC76
                default: ; info
                    iconGlyph := "i", iconClr := 0xFF78DCE8, iconBg := 0x2878DCE8, iconBrd := 0x5578DCE8
            }
        }

            local colors := Dialog.GetThemeColors(themeName, customAccent)
            local accent := colors.accent

            ; Clean text string to calculate shape and dialog bounds dynamically
            local cleanText := RegExReplace(text, "\{[^}]*\}", "")
            local rawLines := StrSplit(cleanText, "`n")
            local totalLineCount := 0
            local singleLine
            for singleLine in rawLines {
                local lineLen := StrLen(singleLine)
                totalLineCount += Max(1, Ceil(lineLen / 46))
            }

            local textX := hasIcon ? 76 : 26
            local textW := hasIcon ? (w - 102) : (w - 52)
            local textH := Max(44, totalLineCount * 24 + 10)
            local h := (IsObject(options) && options.HasOwnProp("height")) ? options.height : Max(200, textH + 125)
            local btnY := h - 55

            local x := (A_ScreenWidth - w) // 2
            local y := (A_ScreenHeight - h) // 2
            local lyrDlg := Layer(x, y, w, h, "GpGFX Message Box")
            lyrDlg.draggable := true

            local isDone := false
            local resultVal := (btnType == "YesNo") ? "No" : "Cancel"
            local hoveredBtn := ""

            ; Retained Vector UI Elements (Minimalist Monokai Card)

            ; Backdrop Card (94% opacity deep obsidian) + subtle border
            RoundedRectangle(10, 10, w - 20, h - 20, 16, "0xF0181822", true)
            RoundedRectangle(10, 10, w - 20, h - 20, 16, colors.border, false)

            ; Accent left pill tag
            RoundedRectangle(26, 22, 5, 20, 3, accent, true)

            ; Title (13pt Bold Segoe UI)
            Rectangle(38, 16, w - 80, 32, "0x00000000", true)
                .Text(title, "0xFFFCFCFA", 13, "Segoe UI", "Bold", 5, "left", "middle")

            ; Optional Vector Icon Badge (38x38)
            if (hasIcon) {
                RoundedRectangle(26, 56, 38, 38, 10, iconBg, true)
                RoundedRectangle(26, 56, 38, 38, 10, iconBrd, false)
                Rectangle(26, 56, 38, 38, "0x00000000", true)
                    .Text(iconGlyph, iconClr, 14, "Segoe UI", "Bold", 5, "center", "middle")
            }

            ; Body Message (11.5pt with automatic word wrapping & rich text support)
            Rectangle(textX, 56, textW, textH, "0x00000000", true)
                .Text(text, "0xFFD8D8E0", 11.5, "Segoe UI", "", 5, "left", "top")

            ; Buttons
            local btnW := 115, btnH := 36

            if (btnType == "OK") {
                local okBg := RoundedRectangle(w - 140, btnY, btnW, btnH, 8, accent, true)
                local okTxt := Rectangle(w - 140, btnY, btnW, btnH, "0x00000000", true)
                    .Text("OK", "0xFF121218", 10.5, "Segoe UI", "Bold", 5, "center", "middle")
                okBg.OnEvent("Click", (*) => (resultVal := "OK", isDone := true))
                okTxt.OnEvent("Click", (*) => (resultVal := "OK", isDone := true))
            } else if (btnType == "OKCancel") {
                local cancelBg := RoundedRectangle(w - 265, btnY, btnW, btnH, 8, "0xFF262632", true)
                RoundedRectangle(w - 265, btnY, btnW, btnH, 8, "0x33FCFCFA", false)
                local cancelTxt := Rectangle(w - 265, btnY, btnW, btnH, "0x00000000", true)
                    .Text("Cancel", "0xFFE0E0E6", 10.5, "Segoe UI", "Bold", 5, "center", "middle")
                cancelBg.OnEvent("Click", (*) => (resultVal := "Cancel", isDone := true))
                cancelTxt.OnEvent("Click", (*) => (resultVal := "Cancel", isDone := true))

                local okBg := RoundedRectangle(w - 140, btnY, btnW, btnH, 8, accent, true)
                local okTxt := Rectangle(w - 140, btnY, btnW, btnH, "0x00000000", true)
                    .Text("OK", "0xFF121218", 10.5, "Segoe UI", "Bold", 5, "center", "middle")
                okBg.OnEvent("Click", (*) => (resultVal := "OK", isDone := true))
                okTxt.OnEvent("Click", (*) => (resultVal := "OK", isDone := true))
            } else if (btnType == "YesNo") {
                local noBg := RoundedRectangle(w - 265, btnY, btnW, btnH, 8, "0xFF262632", true)
                RoundedRectangle(w - 265, btnY, btnW, btnH, 8, "0x33FCFCFA", false)
                local noTxt := Rectangle(w - 265, btnY, btnW, btnH, "0x00000000", true)
                    .Text("No", "0xFFE0E0E6", 10.5, "Segoe UI", "Bold", 5, "center", "middle")
                noBg.OnEvent("Click", (*) => (resultVal := "No", isDone := true))
                noTxt.OnEvent("Click", (*) => (resultVal := "No", isDone := true))

                local yesBg := RoundedRectangle(w - 140, btnY, btnW, btnH, 8, accent, true)
                local yesTxt := Rectangle(w - 140, btnY, btnW, btnH, "0x00000000", true)
                    .Text("Yes", "0xFF121218", 10.5, "Segoe UI", "Bold", 5, "center", "middle")
                yesBg.OnEvent("Click", (*) => (resultVal := "Yes", isDone := true))
                yesTxt.OnEvent("Click", (*) => (resultVal := "Yes", isDone := true))
            }

        ; Initial Render & Window Activation
        lyrDlg.Prepare()
        Draw(lyrDlg)
        lyrDlg.Activate()

        ; Active-window keyboard capture (Only handles keys when this dialog is focused)
        local btnSummary := (btnType == "OK" ? "OK   " : btnType == "OKCancel" ? "OK   Cancel   " : "Yes   No   ")
        local clipFormatted := "---------------------------`n" title . 
        "`n---------------------------`n" cleanText . 
        "`n---------------------------`n" btnSummary .
        "`n---------------------------`n"
        local dlgHwnd := lyrDlg.hwnd

        local ih := InputHook("V")
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := (hook, vk, sc) => (
            (!WinActive("ahk_id " . dlgHwnd) && DllCall("user32\GetForegroundWindow", "ptr") != dlgHwnd) ? 0 :
            (vk == 13 && !GetKeyState("Shift", "P") && !GetKeyState("Ctrl", "P") && !GetKeyState("Alt", "P")) ? (resultVal := (btnType == "YesNo" ? "Yes" : "OK"), isDone := true) :
            (vk == 27) ? (resultVal := (btnType == "YesNo" ? "No" : "Cancel"), isDone := true) :
            ((vk == 67 || vk == 99) && (GetKeyState("Ctrl", "P") || GetKeyState("Control", "P"))) ? (A_Clipboard := clipFormatted) : 0
        )
        ih.Start()

        while (!isDone) {
            Sleep(10)
        }

        ih.Stop()
        KeyWait("LButton")
        KeyWait("Enter")
        lyrDlg.Dispose()
        lyrDlg := ""

        return resultVal
    }
}