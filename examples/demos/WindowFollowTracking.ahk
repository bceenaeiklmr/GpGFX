; Script:    WindowFollowTracking.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Warn All, StdOut
#include ../../GpGFX.ahk

; Create a test target window
targetGui := Gui("+Resize +AlwaysOnTop", "GpGFX Snap Target Window")
targetGui.Show("x300 y300 w400 h300")
targetHwnd := targetGui.Hwnd
Sleep(100)

; Create a test layer and attach with continuous window following
lyr := Layer(10, 10, 200, 100, "SnapFollowLayer")
RoundedRectangle(12, "0xF0181824", true)
Text("Tracking Target Window", "0xFF00FF66", 11, "Segoe UI", "Bold").MiddleCenter()
lyr.Draw()

; Test 1: Snap & Follow
lyr.SnapToWindow(targetHwnd, 20, 20, false, 15)

Sleep(5000)
vPos := WinGetVisiblePos(targetHwnd)
if (lyr.x != vPos.x + 20 || lyr.y != vPos.y + 20)
    throw Error(Format("SnapToWindow failed initial position match: lyr=({}, {}), target=({}, {})", lyr.x, lyr.y, vPos.x + 20, vPos.y + 20))

; Test 2: Move target window and verify layer follows!
targetGui.Show("x500 y400")
Sleep(80) ; Allow tracking loop to update

vPos2 := WinGetVisiblePos(targetHwnd)
if (lyr.x != vPos2.x + 20 || lyr.y != vPos2.y + 20)
    throw Error(Format("FollowWindow failed to follow moved window: lyr=({}, {}), target=({}, {})", lyr.x, lyr.y, vPos2.x + 20, vPos2.y + 20))

; Test 3: StopFollowing
lyr.StopFollowing()
if (lyr.__followTimer != 0)
    throw Error("StopFollowing failed to clear timer")

lyr.Dispose()
targetGui.Destroy()

FileAppend("SNAP & FOLLOW WINDOW TESTS PASSED SUCCESSFULLY!`n", "*")
ExitApp(0)
