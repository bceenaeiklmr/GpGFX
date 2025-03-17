; Script     test_CustomGuiControl.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       17.03.2025

#include ../src/GpGFX.ahk

/**
 * This script creates a layer with a clickable button and a status rectangle,
 * changing colors and text upon interaction.
 */

; Set layer dimensions
lyrWidth := 1280
lyrHeight := 720

; Create the main layer
main := Layer(,, lyrWidth, lyrHeight)

; Create a background rectangle and set it to invisible
rect := Rectangle(0, 0, lyrWidth, lyrHeight, "0xdc104e6d")
rect.visible := false

; Create a red rectangle for the button
btn := Rectangle(, , 100, 100, "Red")
btn.Position("center", "center")

; Assign click event to the button
btn.OnEvent("Click", btn_OnClick)

; Create a status rectangle with initial text
status := Rectangle((lyrWidth - 200) // 2, 50, 200, 50, Color.HotPink)
status.Text("Click the red one!", "Black", 20)

; Make the background rectangle visible
rect.visible := true

; Draw the main layer
Draw(main)

; Define the button click event handler
btn_OnClick() {
    ; Change button color and text
    btn.color := "Lime"
    btn.Text("✓", "Black", 20)
    
    ; Create a color transition from red to lime
    clr := Color.GetTransition(status.color, "Lime")
    status.Text("Clicked!", "Black", 20)
    
    ; Apply the color transition to the status rectangle
    loop clr.length {
        status.color := clr[A_Index]
        Draw(main)
        Sleep(20)
    }
    
    ; Update the status text
    
    Draw(main)
    Sleep(1000)
    
    ; End the script
    End(1)
}
