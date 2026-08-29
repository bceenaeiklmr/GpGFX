; Script     ToastNotificationDemo.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; GpGFX Toast Notification Demo (Negative Timeout lyr.Draw(-ms))
; Shows self-destructing toast cards that auto-dispose with 0 manual cleanup!

ShowToast("Task Completed Successfully!", "0xFF00FF66", 2000)

SetTimer(() => ShowToast("System Memory Trimmed (42 MB freed)", "0xFF78DCE8", 2500), -2200)

SetTimer(() => ShowToast("New Theme Applied: Cyber Neon", "0xFFFF6188", 3000), -4800)

ShowToast(msg, accentClr := "0xFF78DCE8", durationMs := 2000) {
    static toastY := 60
    toastW := 360, toastH := 60
    toastX := A_ScreenWidth - toastW - 30

    toast := Layer(toastX, toastY, toastW, toastH, "ToastPopup")
    
    ; Glass background card
    RoundedRectangle(12, "0xF0181824", true)
    RoundedRectangle(12, accentClr, false)
    
    ; Message
    Text(msg, "0xFFFCFCFA", 10, "Segoe UI", "Bold").MiddleCenter()
    
    ; Auto-render and self-destruct after durationMs!
    toast.Draw(-durationMs)
}

HotKey("~*Esc", (*) => ExitApp())
