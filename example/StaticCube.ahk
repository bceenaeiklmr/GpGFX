; Script     StaticCube.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       15.03.2025

#include ../GpGFX.ahk

/**
 * Draw a static cube with lines and polygon
 */

; Create a layer, width and height not specified, so it will be auto-centered
; and width height will be 600x600
lyr := Layer(600, 600)

; Create a rectangle with a black background
rect := Rectangle(,, 600, 600, Color.DarkBlue)

; Add text to the shape
rect.Text("Static cube with" "`n`n" "lines and polygon", "White", 20)
rect.strY := 50

; Set the margin and size of the cube
margin := 200
size := 262

; Coordinates for the cube vertices within the margin
FTL := [margin, margin]
FTR := [size - margin, margin]
FBL := [margin, size - margin]
FBR := [size - margin, size - margin]

BTL := [margin + 50, margin + 50]
BTR := [size - margin + 50, margin + 50]
BBL := [margin + 50, size - margin + 50]
BBR := [size - margin + 50, size - margin + 50]

; Set the color for the lines
red := Color.Red

; Draw the front face
Front := [
    Line(FTL[1], FTL[2], FTR[1], FTR[2], red, 2),
    Line(FTL[1], FTL[2], FBL[1], FBL[2], red, 1),
    Line(FTR[1], FTR[2], FBR[1], FBR[2], red, 1),
    Line(FBL[1], FBL[2], FBR[1], FBR[2], red, 1)
]

; Draw the back face
Back := [
    Line(BTL[1], BTL[2], BTR[1], BTR[2], red, 1),
    Line(BTL[1], BTL[2], BBL[1], BBL[2], red, 1),
    Line(BTR[1], BTR[2], BBR[1], BBR[2], red, 1),
    Line(BBL[1], BBL[2], BBR[1], BBR[2], red, 1)
]

; Paint an area inside the cube with a polygon
poly := Polygon(Color("White"), 1, 1,
    [FTL[1], FTL[2], FTR[1], FTR[2], FBR[1], FBR[2], FBL[1], FBL[2]])

; Connect the front face with the back face
Connect := [
    Line(FTL[1], FTL[2], BTL[1], BTL[2], red, 1),
    Line(FTR[1], FTR[2], BTR[1], BTR[2], red, 1),
    Line(FBL[1], FBL[2], BBL[1], BBL[2], red, 1),
    Line(FBR[1], FBR[2], BBR[1], BBR[2], red, 1)
]

Draw(lyr)
Sleep(2000)
;lyrm.debug()

; Clean up is required or calling End()
lyr := ""

