; Script     test_GameMenu.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       16.03.2025

#include ../GpGFX.ahk

/**
 * This script creates a simple game menu with a player object.
 * The player can move using the arrow keys and change color with the space bar.
 * Press F1 to display the main menu.
 * The main menu includes three buttons: Game, Options, and Exit.
 * The Options button displays a temporary options menu as text.
 * Buttons change color when hovered over.
 * The duration of the last key press is displayed on the player object when moving.
 */

main := Layer(1920, 1080)
mainBg := Rectangle(0, 0, 1920, 1080, "0x3f000000")
Draw(main)

; Game menu
gm := gMenu(["Game", "Options", "Exit"])

; second layer, player
lyr2 := Layer(100, 100)
player := Square(,, 100, "Lime")
player.Text(, "black", 20)
Draw(lyr2)

; End
^esc::End()

; Show main menu
f1:: {
    gMenu.show()
    settimer colorOnHover, 50
}

MovePlayer() {
    
    t := A_TickCount

    while GetKeyState(A_ThisHotkey, "P") {
        switch A_ThisHotkey {
            case "left":
                lyr2.x -= 0.0075
                if (GetKeyState("up", "P")) {
                    lyr2.y -= 0.0075
                } else if (GetKeyState("down", "P")) {
                    lyr2.y += 0.0075
                }
            case "right":
                lyr2.x += 0.0075
                if (GetKeyState("up", "P")) {
                    lyr2.y -= 0.0075
                } else if (GetKeyState("down", "P")) {
                    lyr2.y += 0.0075
                }
            case "up":
                lyr2.y -= 0.0075
                if (GetKeyState("left", "P")) {
                    lyr2.x -= 0.0075
                } else if (GetKeyState("right", "P")) {
                    lyr2.x += 0.0075
                }
            case "down":
                if (GetKeyState("left", "P")) {
                    lyr2.x -= 0.0075
                } else if (GetKeyState("right", "P")) {
                    lyr2.x += 0.0075
                }
                lyr2.y += 0.0075
        }
        lyr2.Move(lyr2.x, lyr2.y)
    }

    player.str := "last hkey`n" (A_TickCount - t) " ms"
    lyr2.x := Ceil(lyr2.x)
    lyr2.y := Ceil(lyr2.y)
    lyr2.Draw()
}

; Hotkeys for player movement
left::
right::
up::
down:: {
    MovePlayer()
}

; Player color change
space:: {
    player.color := Color.Random()
    ;lyr2.x := Ceil(lyr2.x)
    ;lyr2.y := Ceil(lyr2.y)
    Draw(lyr2)
}

class gMenu {

    static started := 0

    __New(options) {

        btnWidth := 300
        btnHeight := 150
        pad := 50

        gMenu.obj := CreateGraphicsObject(3, 1, ,, btnWidth, btnHeight, pad)
        loop options.Length {
            gMenu.obj[A_Index].color := Color.Honeydew
            gMenu.obj[A_Index].Text(options[A_Index], "black", 32)
        }
        Draw(main)
        
        ; bind functions to buttons
        gMenu.obj[1].OnEvent("Click", btnNew)
        gMenu.obj[2].OnEvent("Click", btnOpt)
        gMenu.obj[3].OnEvent("Click", btnEnd)

        ; construct the options menu
        gMenu.opt := Layer(1920, 1080)
        gMenu.optBg := Rectangle(, , main.w // 2, 1080, "", 1)
        gMenu.optBg.color := ["Lime", "Green"]
        gMenu.optBg.x += 150
        gMenu.optBg.y += 150
        gMenu.optBg.w -= 400
        gMenu.optBg.h -= 400
        gMenu.optBg.Text("This will be the options menu...", , 32)
        gMenu.opt.Draw()
        gMenu.opt.Hide()

        Settimer(ColorOnHover, 50)

        ; set back id layer active id here, like spawning enemies
        while (!gMenu.started) {
            Sleep(200)
        }
    }

    static show() {
        loop 3 {
           gMenu.obj[A_Index].Visible := 1
        }
        Draw(main)
        ; Hide player layer
        lyr2.Hide()
    }
}

; Start a new game
btnNew() {
    loop 3 {
        gMenu.obj[A_Index].Visible := 0
    }
    Draw(main)
    gMenu.started := 1

    ; show player
    if (IsSet(lyr2)) {
        lyr2.Show()
    }
    settimer(colorOnHover, 0)
}

; Go to options
btnOpt() {
    gMenu.opt.Show()
    SetTimer((*) => gMenu.opt.Hide(), 2000)
}

; Exit the game
btnEnd() {
    End()
}

ColorOnHover() {

    if !WinActive(main.hwnd) {
        WinActivate(main.hwnd)
    }

    CoordMode("Mouse", "Window")

    MouseGetPos(&x, &y)

    for index, item in gMenu.obj {
        if (item.x < x  && item.x + item.w > x && item.y < y && item.y + item.h > y) {

            for _, item2 in gMenu.obj {
                item2.color := "White"
            }
            item.color := "Yellow"
            Draw(main)
            break
        }
    }
}

; Info

; This is very slow due to how hotkeys work in AHK
; It's better to use the approach below
;left::lyr2.x -= 10, lyr2.Move(lyr2.x)
;right::lyr2.x += 10, lyr2.Move(lyr2.x)
;up::lyr2.y -= 10, lyr2.Move(, lyr2.y)
;down::lyr2.y += 10, lyr2.Move(, lyr2.y)

;+left::lyr2.x -= 50, lyr2.Move(lyr2.x)
;+right::lyr2.x += 50, lyr2.Move(lyr2.x)
;+up::lyr2.y -= 50, lyr2.Move(, lyr2.y)
;+down::lyr2.y += 50, lyr2.Move(, lyr2.y)
