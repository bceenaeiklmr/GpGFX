; Script     testBrushHatch.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../GpGFX.ahk

; Test the HatchBrush style and the Color.Random() function
testHatchBrush()
testRandomColor()
testHatchBrushColor()

testHatchBrush() {
    ; Create a layer
    main := Layer()

    ; Set grid parameters
    row := 4
    col := 14
    pad := 10
    objW := 100
    objH := 100

    ; Create a grid of rectangles and change their colors
    rect := CreateGraphicsObjectGrid(row, col, , , objW, objH, pad)
    loop rect.Length {
        if (A_Index < HatchBrush.Style.Length) {
            rect[A_Index].color := ["hatch", Color.Random("Red|Orange|Blue"), 0x0, A_Index]
        } else {
            rect.Pop() ; grid.length > HatchBrush.Style.Length
        }
    }

    ; Add another rectangle to display text
    ; We can prepare the layer to get the used area dimensions, so we can position it above the grid
    main.prepare()
    
    rectTxt := Rectangle(main.x1, main.y1 - 75, main.Width, 50, "black")
    rectTxt.Text("Displaying all HatchBrush styles", "white", 20)
    rectLine := Line(main.x1, main.y1 - 25, main.x2, main.y1 - 25, Color.GitHubBlue, 2)

    Draw(main)
    Sleep(1000)
    ; Display the style names
    loop rect.Length {
        rect[A_Index].str := HatchBrush.Style[A_Index]
        Draw(main)
        Sleep(50)
    }
    Sleep(1000)
}

testRandomColor() {
    ; Create a layer and a grid of rectangles
    main := Layer()
    pad := 5
    rect := CreateGraphicsObjectGrid(5, 11,,, 66, 66, pad)

    ; Set the middle one as a status box
    middle := 2 * 11 + 6
    rect[middle].Text("", , 12)

    caseTest := 25
    
    loop {
        iTest := A_Index
        loop caseTest {
            loop rect.Length {
                switch iTest {
                    case 1:
                        clr := Color.Random()
                        sTest := "Random"
                    case 2:
                        clr := Color.Random("Red|Orange|Yellow")
                        sTest := "Random`nfrom`nlist"
                    case 3:
                        clr := Color.Random("Blue", 25)
                        sTest := "Random`nwith low`nvariance"
                    case 4:
                        clr := Color.Random("Green", 66)
                        sTest := "Random`nwith mid`nvariance"
                    case 5:
                        clr := Color.Random("Yellow", 150)
                        sTest := "Random`nwith high`nvariance"
                    default:
                        break 3
                }
                if (A_Index !== middle) {
                    rect[A_Index].Color := clr
                }
            }
            rect[middle].str := sTest
            Draw(main)
            Sleep(100)
        }
    }
}

testHatchBrushColor() {
    ; Create a FHD layer
    main := Layer(1920, 1080)
    
    ; Set grid parameters
    objW := 125
    objH := 125
    pad := 5
    rect := CreateGraphicsObjectGrid(6, 8, , , objW, objH, pad)
    Pies := []
    
    loop rect.Length {
        if (A_Index >= HatchBrush.Style.Length) {
            continue
        }

        ; Create pies instead of rectangles
        x := rect[A_Index].x
        y := rect[A_Index].y
        w := rect[A_Index].w
        h := rect[A_Index].h

        obj := Ellipse(x, y, w, h)
        obj.Color := ["hatch", Color.SkyBlue, 0x0, A_Index - 1]
        pies.Push(obj)
    }
    
    ; Will be disposed anyway when the function ends
    rect := unset

    ; Draw the layer wait a bit
    Draw(main)
    Sleep(1000)

    ; Change two colors at a time
    loop 53 // 2 {
        pies[A_Index].Color := ["hatch", Color(), Color.black, A_Index-1]
        pies[pies.Length-A_Index+1].Color := ["hatch", Color(), Color.black, A_Index-1]
        Sleep(50)
        Draw(main)
    }
    Sleep(1000)
}
