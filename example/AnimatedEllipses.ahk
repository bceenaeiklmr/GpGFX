#include ../src/GpGFX.ahk

/**
 * Testing animated ellipses with varying color distances and positions.
 */

; Inside
testEllipsesAnimated(A_ScreenWidth, A_ScreenHeight, 100, 100, 15, 15, 80)

; Outside
;testEllipsesAnimated(A_ScreenWidth, A_ScreenHeight, 100, 100, 10, 10, 100)

; Has to be ended by the user, it's an infinite loop
^Esc::End()

testEllipsesAnimated(Width, Height, mainW, mainH, smallCount, smallRad, animRad) {
    
    ; Define the main ellipse
    mainX := Width // 2
    mainY := Height // 2

    ; Start animation
    AnimateEllipses(mainX, mainY)
    return

    AnimateEllipses(x, y) {

        static Pi := 3.141592653589793

        lyrMain := Layer()
        ellipses := []      
        dist := 1
        
        main := Ellipse(mainX - mainW // 2, mainY - mainH // 2, mainW, mainH, 'White')
        main.color := ["red", "orange"]

        ; Draw moving ellipses
        loop smallCount {
            clr := Color.LinearInterpolation(Color.Red, Color.Orange, A_Index * 100 // smallCount)
            ellipses.Push(Ellipse(0, 0, smallRad * 2, smallRad * 2, clr))
        }            

        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", Graphics.%lyrMain.id%.gfx, "int", 4)

        DllCall("QueryPerformanceFrequency", "Int64*", &freq:=0)
        DllCall("QueryPerformanceCounter", "Int64*", &start:=0)
    
        loop {
            ; Initialize boundaries for the dummy rectangle
            minX := mainX - animRad - smallRad
            maxX := mainX + animRad + smallRad
            minY := mainY - animRad - smallRad
            maxY := mainY + animRad + smallRad

            ; Update positions of the small ellipses
            Loop smallCount {

                DllCall("QueryPerformanceCounter", "Int64*", &now:=0)
                Elapsed := (now - start) / freq * 100
                
                Angle := Elapsed + (360 / smallCount * (A_Index - 1))
                X := mainX + animRad * Cos(Angle * 3.14159 / 180) - smallRad
                Y := mainY + animRad * Sin(Angle * 3.14159 / 180) - smallRad
                ellipses[A_Index].x := Ceil(X)
                ellipses[A_Index].y := Ceil(Y)

                if (X < minX)
                    minX := X
                if (X + smallRad * 2 > maxX)
                    maxX := X + smallRad * 2
                if (Y < minY)
                    minY := Y
                if (Y + smallRad * 2 > maxY)
                    maxY := Y + smallRad * 2

                if !Mod(A_Index, 255)
                    dist := 0
            }
            lyrMain.Draw
        }
    }
}
