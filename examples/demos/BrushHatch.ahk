; Script:    BrushHatch.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#include ../../GpGFX.ahk

; Test the HatchBrush style and the Color.Random() function
;testRandomColor()
testHatchBrushColor()

testRandomColor() {
    ; Create a layer and a grid of rectangles
    main := Layer()
    pad := 5
    rect := CreateGraphicsObject(5, 11,,, 66, 66, pad)

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
    rect := CreateGraphicsObject(6, 8, , , objW, objH, pad)
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
        Draw(main)
    }
    
    ; Will be disposed anyway when the function ends
    for v in rect {
        ;v.Dispose()
    }

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
