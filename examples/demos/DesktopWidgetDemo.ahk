; Script     DesktopWidgetDemo.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; GpGFX Desktop Widget Demo (Interactive Desktop Dashboard)
; Pinned to Windows Desktop behind open applications & immune to Win+D.
; Supports live OnEvent handlers (Click, MouseEnter, MouseLeave)!

widgetW := 380, widgetH := 290
widgetX := A_ScreenWidth - widgetW - 40
widgetY := 50

lyr := Layer(widgetX, widgetY, widgetW, widgetH, "DesktopWidget")

; 1. Glass Background Card (Auto fills layer)
RoundedRectangle(16, "0xDD181824", true)
cardBorder := RoundedRectangle(16, "0x4478DCE8", false)

; 2. Title Header (Auto aligned with Shift)
Text("{#78DCE8}GpGFX{} Desktop Dashboard", "0xFFFCFCFA", 12, "Segoe UI", "Bold")
    .TopLeft().Shift(20, 16)

; 3. Live Clock & Date (Auto aligned with Shift)
clockTxt := Text(FormatTime(, "HH:mm:ss"), "0xFF00FF66", 26, "Segoe UI", "Bold")
    .TopLeft().Shift(20, 44)
dateTxt  := Text(FormatTime(, "dddd, MMMM dd, yyyy"), "0xFFA0A0B0", 10, "Segoe UI", "Regular")
    .TopLeft().Shift(20, 94)

; 4. System Status Box
RoundedRectangle(20, 122, widgetW - 40, 75, 8, "0x66000000", true)
statusTxt := Text("", "0xFFAB9DF2", 9, "Consolas", "Regular")
    .TopLeft().Shift(30, 128)

; 5. Interactive Buttons via CreateGraphicsObject (Zero math for multi-column buttons!)
btns := CreateGraphicsObject(1, 2, 20, 210, 160, 36, 20)
btnTrim := btns[1].Button("Trim Memory").OnHover("0xFF504B70", "0xFF2D2A3E", OnTrimMemory)
btnTheme := btns[2].Button("Change Color").OnHover("0xFF504B70", "0xFF2D2A3E", OnChangeTheme)

themes := ["0xFF00FF66", "0xFFFF6188", "0xFF78DCE8", "0xFFFFD866", "0xFFAB9DF2"]
themeIdx := 1

; 6. Hint Footer (Auto BottomCenter with Shift)
Text("Click buttons on desktop • Press Esc to exit", "0xFF707080", 8, "Segoe UI", "Regular")
    .BottomCenter().Shift(0, -15)

OnTrimMemory(*) {
    DllCall("psapi\EmptyWorkingSet", "ptr", -1)
    btnTrim.colour := 0xFF00FF66
    Draw(lyr)
    SetTimer(() => (btnTrim.colour := 0xFF2D2A3E, Draw(lyr)), -200)
    updateStats()
}

OnChangeTheme(*) {
    global themeIdx
    themeIdx := Mod(themeIdx, themes.Length) + 1
    clockTxt.colour := themes[themeIdx]
    cardBorder.colour := themes[themeIdx]
    Draw(lyr)
}

updateStats() {
    statusStr := Format(
          "• Mode    : Pinned to Desktop (Progman Owner)`n"
        . "• Win+D   : Immune to Minimize`n"
        . "• Memory  : {:0.1f} MB (Current AHK Process)",
        (ProcessGetWorkingSetSize() / 1048576)
    )
    statusTxt.str := statusStr
}

ProcessGetWorkingSetSize() {
    local hProcess := DllCall("GetCurrentProcess", "ptr")
    local pmc := Buffer(72, 0)
    NumPut("uint", pmc.Size, pmc, 0)
    DllCall("psapi\GetProcessMemoryInfo", "ptr", hProcess, "ptr", pmc.ptr, "uint", pmc.Size)
    return NumGet(pmc, 16, "uptr")
}

; Initial render & recurring 1-second auto-clock loop
updateStats()
lyr.Draw(1000, UpdateWidget)

; Pin directly to Windows Desktop
lyr.AttachToDesktop()

UpdateWidget(l) {
    clockTxt.str := FormatTime(, "HH:mm:ss")
    updateStats()
}

HotKey("~*Esc", (*) => ExitApp())
