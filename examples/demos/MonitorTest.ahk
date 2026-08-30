; Script:    MonitorTest.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include ../../GpGFX.ahk

; Show monitor summary in OutputDebug / Console
mons := Layer.GetMonitors()
virt := Layer.GetVirtualScreen()

width := 480
height := 320

lyr := Layer(0, 0, width, height, "GpGFX Multi-Monitor")
lyr.draggable := true

; Center on primary monitor initially
lyr.SetMonitor("Primary", "center")

RoundedRectangle(10, 10, width - 20, height - 20, 16, "0xFF1E1E24", true)
RoundedRectangle(10, 10, width - 20, height - 20, 16, "0x33FCFCFA", false)

Text(30, 30, width - 60, 30, "MULTI-MONITOR CONTROLS", "0xFFFCFCFA", 13, "Segoe UI", "Bold").Center().Middle()

monInfoStr := "Total Monitors: " . mons.Length . "`nVirtual Screen: " . virt.w . "x" . virt.h . " at (" . virt.x . ", " . virt.y . ")"
Text(30, 65, width - 60, 40, monInfoStr, "0xFF78DCE8", 9.5, "Segoe UI").Center().Middle()

txtCurMon := Text(30, 270, width - 60, 25, "Current Monitor: " . lyr.GetCurrentMonitor(), "0xFF939293", 8.5, "Segoe UI").Center().Middle()

UpdateMon(disp, align := "center") {
    lyr.SetMonitor(disp, align)
    txtCurMon.str := "Current Monitor: " . lyr.GetCurrentMonitor()
    Draw(lyr)
}

; Button 1: Monitor 1
btn1 := RoundedRectangle(30, 120, 130, 36, 8, "0xFF2D2A2E", true)
Text(30, 120, 130, 36, "Monitor 1", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()
btn1.OnEvent("Click", (*) => UpdateMon(1, "center"))

; Button 2: Monitor 2 (if available)
btn2 := RoundedRectangle(175, 120, 130, 36, 8, (mons.Length >= 2) ? "0xFFFF6188" : "0xFF404040", true)
Text(175, 120, 130, 36, "Monitor 2", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()
if (mons.Length >= 2)
    btn2.OnEvent("Click", (*) => UpdateMon(2, "center"))

; Button 3: Cycle Next Monitor
btnNext := RoundedRectangle(320, 120, 130, 36, 8, "0xFFA9DC76", true)
Text(320, 120, 130, 36, "Next Monitor ➜", "0xFF1E1E24", 10, "Segoe UI", "Bold").Center().Middle()
btnNext.OnEvent("Click", (*) => UpdateMon("Next", "center"))

; Row 2 Alignments
btnTL := RoundedRectangle(30, 170, 95, 32, 6, "0x20FCFCFA", true)
Text(30, 170, 95, 32, "Top-Left", "0xFFE0E0E6", 8.5, "Segoe UI").Center().Middle()
btnTL.OnEvent("Click", (*) => UpdateMon(lyr.GetCurrentMonitor(), "top-left"))

btnTR := RoundedRectangle(135, 170, 95, 32, 6, "0x20FCFCFA", true)
Text(135, 170, 95, 32, "Top-Right", "0xFFE0E0E6", 8.5, "Segoe UI").Center().Middle()
btnTR.OnEvent("Click", (*) => UpdateMon(lyr.GetCurrentMonitor(), "top-right"))

btnBL := RoundedRectangle(240, 170, 95, 32, 6, "0x20FCFCFA", true)
Text(240, 170, 95, 32, "Bottom-Left", "0xFFE0E0E6", 8.5, "Segoe UI").Center().Middle()
btnBL.OnEvent("Click", (*) => UpdateMon(lyr.GetCurrentMonitor(), "bottom-left"))

btnBR := RoundedRectangle(345, 170, 95, 32, 6, "0x20FCFCFA", true)
Text(345, 170, 95, 32, "Bottom-Right", "0xFFE0E0E6", 8.5, "Segoe UI").Center().Middle()
btnBR.OnEvent("Click", (*) => UpdateMon(lyr.GetCurrentMonitor(), "bottom-right"))

; Close Button
btnClose := RoundedRectangle(175, 220, 130, 32, 6, "0x30FF6188", true)
Text(175, 220, 130, 32, "Close (Esc)", "0xFFFF6188", 9, "Segoe UI").Center().Middle()
btnClose.OnEvent("Click", (*) => ExitApp())

Draw(lyr)

HotKey("~*Esc", (*) => ExitApp())
