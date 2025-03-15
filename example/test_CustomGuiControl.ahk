; Script     test_CustomGuiControl.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

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
rect := Rectangle(0, 0, lyrWidth, lyrHeight, "0xdc1d8bc2")
rect.visible := false

; Create a red rectangle for the button
btn := Rectangle(5, 5, 100, 100, "Red")

; Assign click event to the button
btn.OnEvent("Click", btn_OnClick)

; Create a status rectangle with initial text
status := Rectangle((lyrWidth - 200) // 2, 50, 200, 50, "0xf19220b4")
status.Text("Click red btn!", "Black", 20)

; Enable debug mode
main.Debug(, 1, 0xAB)

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
    clr := Color.GetTransation("Red", "Lime")
    
    ; Apply the color transition to the status rectangle
    loop clr.length {
        status.color := clr[A_Index]
        Draw(main)
        Sleep(20)
    }
    
    ; Update the status text
    status.Text("Clicked!", "Black", 20)
    Draw(main)
    Sleep(1000)
    
    ; End the script
    End(1)
}
