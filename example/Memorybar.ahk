; Script     Memorybar.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       16.03.2025

#include ../src/GpGFX.ahk

/**
 * Creates a simple memory bar using the GlobalMemoryStatusEx function by jNizM.
 * https://github.com/jNizM/MemoryInfo
 * The bar displays the memory load and available memory in GB.
 * ^Esc to end the script.
 */

; Create a small layer, 300x300 pixels are enough
; This way a small DIB will be created.
lyr := Layer(0, 0, 300, 300)

; Add the main rectangles
sq := CreateGraphicsObject(2, 1, 10, 10, 100, 100)

; Create the memory load and available memory bars
sqbar := CreateGraphicsObject(2, 1, 10, 10, 80, 10)
loop 2 {
    sqbar[A_Index].x := sq[A_Index].x + 10
    sqbar[A_Index].y := sq[A_Index].y + sq[A_Index].h - 2*10
    sqbar[A_Index].color := "lime"
}

; Create the used memory bar
used := Rectangle(sqbar[2].x, sqbar[2].y, 0, sqbar[2].h, "1f7713")

Settimer Update, 200

Update() {
    mem := GlobalMemoryStatusEx()
    sq[1].str := "Mem Load`n`n" mem.2 " %`n`n"
    sq[2].str := "Mem Free`n`n" Round(byteTo.GB(mem.4), 2) " GB`n`n"
    sqbar[1].w := 80 * mem.2 / 100
    sqbar[2].w := 80 * mem.4 / mem.3
    used.x := Ceil(80 * mem.4 / mem.3) + sqbar[2].x
    used.w := 80 - Ceil(80 * mem.4 / mem.3)
    lyr.Draw()
}

^Esc::End()

; The following function is jNizM's GlobalMemoryStatusEx function.
; I slighltly modified it to make it work with ahk v2.
; https://github.com/jNizM/MemoryInfo
; ===============================================================================================================================
; Function......: GlobalMemoryStatusEx
; DLL...........: Kernel32.dll
; Library.......: Kernel32.lib
; U/ANSI........:
; Author........: jNizM
; Modified......:
; Links.........: https://msdn.microsoft.com/en-us/library/aa366589.aspx
;                 https://msdn.microsoft.com/en-us/library/windows/desktop/aa366589.aspx
; ===============================================================================================================================

GlobalMemoryStatusEx()
{
    static MEMORYSTATUSEX
    if !IsSet(MEMORYSTATUSEX)
        MEMORYSTATUSEX := Buffer(64, 0), NumPut("UInt", 64, MEMORYSTATUSEX)
    if !(DllCall("kernel32.dll\GlobalMemoryStatusEx", "Ptr", MEMORYSTATUSEX.ptr))
		return DllCall("kernel32.dll\GetLastError")
    return { 1 : NumGet(MEMORYSTATUSEX,  0, "UInt"),   2 : NumGet(MEMORYSTATUSEX,  4, "UInt")
           , 3 : NumGet(MEMORYSTATUSEX,  8, "UInt64"), 4 : NumGet(MEMORYSTATUSEX, 16, "UInt64")
           , 5 : NumGet(MEMORYSTATUSEX, 24, "UInt64"), 6 : NumGet(MEMORYSTATUSEX, 32, "UInt64")
           , 7 : NumGet(MEMORYSTATUSEX, 40, "UInt64"), 8 : NumGet(MEMORYSTATUSEX, 48, "UInt64")
           , 9 : NumGet(MEMORYSTATUSEX, 56, "UInt64") }
}

class byteTo {
    static Gigabyte(b) => this.GB(b)
    static Megabyte(b) => this.MB(b)
    static Kilobyte(b) => this.KB(b)
    static GB(b) => b / 1024 ** 3
    static MB(b) => b / 1024 ** 2
    static KB(b) => b / 1024
}
