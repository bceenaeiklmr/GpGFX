; Script     04 Whole Layer Reactive Binding.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Warn All, StdOut
#Include ../../../GpGFX.ahk

    ; 1. Create a modern dark glass HUD card
    lyr := Layer(100, 100, 360, 180, "ReactiveDashboard")
    RoundedRectangle(14, "0xF0181824", true)              ; Dark glass background
    RoundedRectangle(14, "0xFF78DCE8", false)             ; Glowing cyan border stroke

    ; Title header
    Text("{#78DCE8}⚡ Live System Monitor{}", "0xFFFCFCFA", 12, "Segoe UI", "Bold").TopLeft().Shift(20, 16)

    ; Metric Labels & Status indicators
    cpuText := Text("CPU: 0%", "0xFFFCFCFA", 10, "Segoe UI", "Bold").TopLeft().Shift(20, 52)
    cpuBarBg := Rectangle(20, 76, 320, 12, "0xFF2D2A3E", true)
    cpuBar   := Rectangle(20, 76, 0, 12, "0xFF00FF66", true)

    ramText := Text("RAM: 0 GB", "0xFFFCFCFA", 10, "Segoe UI", "Bold").TopLeft().Shift(20, 104)
    ramBarBg := Rectangle(20, 128, 320, 12, "0xFF2D2A3E", true)
    ramBar   := Rectangle(20, 128, 0, 12, "0xFFFFD866", true)

    ; 2. Define the central reactive state signal
    sigData := Signal({ cpu: 15, ram: 3.8, maxRam: 16.0 })

    ; 3. Whole Layer Reactive Binding:
    ; Whenever sigData.Value changes, this callback runs and immediately re-renders the layer!
    lyr.Draw(sigData, (data, l) => (
        ; Update CPU readout and dynamic bar width
        cpuText.str := Format("CPU: {}%", data.cpu),
        cpuBar.w := (320 * data.cpu) // 100,
        cpuBar.colour := (data.cpu > 80 ? "0xFFFF6188" : (data.cpu > 50 ? "0xFFFFD866" : "0xFF00FF66")),

        ; Update RAM readout and dynamic bar width
        ramText.str := Format("RAM: {:.1f} / {:.1f} GB", data.ram, data.maxRam),
        ramBar.w := (320 * data.ram) / data.maxRam
    ))

    ; 4. Modifying sigData.Value from ANYWHERE in your code triggers instant updates!

    ; Press F1, F2, F3 to simulate live server telemetry updates:
    F1::sigData.Value := { cpu: 22, ram: 4.2, maxRam: 16.0 }
    F2::sigData.Value := { cpu: 68, ram: 8.9, maxRam: 16.0 }
    F3::sigData.Value := { cpu: 94, ram: 14.7, maxRam: 16.0 } ; Turns CPU bar RED

    ; Press Esc to exit
    HotKey("~*Esc", (*) => ExitApp())