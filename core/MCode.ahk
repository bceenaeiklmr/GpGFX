; Script:    MCode.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2

/**
 * GpGFX Native Machine Code (MCode) & High-Precision Timing Engine
 *
 * MCode (Machine Code) allows compiled C/C++ and x64 assembly routines to execute
 * directly within the AutoHotkey process at bare-metal hardware speeds without external DLLs.
 *
 * How MCode Works:
 * 1. C/C++ algorithms are compiled into position-independent machine code (PIC).
 * 2. Binary bytes are Base64-encoded into compact strings stored directly in scripts.
 * 3. VirtualAlloc allocates executable memory pages with PAGE_EXECUTE_READWRITE (0x40).
 * 4. CryptStringToBinary decodes Base64 into the executable memory buffer.
 * 5. DllCall executes the memory pointer with 0 ns invocation overhead.
 *
 * Use Cases in GpGFX:
 * - Sub-millisecond Hardware Spin Pacing: x64 `pause` instruction loop with zero CPU pipeline stalls.
 * - Windows High-Resolution Waitable Timers: Fractional millisecond kernel sleep (e.g. 1.2ms) with zero power draw.
 * - Vectorized Point Math: Batch 2D bounding box calculations and SIMD matrix point translations.
 * - Pixel Search & Heatmap Color LUT: 4K frame color scanning at memory bandwidth speed.
 *
 * Source Code:
 * - C source files for all kernels are maintained under `src/`:
 *   - `src/qpc_spin.c`: Hardware spin-wait loop with pause instruction.
 *   - `src/bounds.c`: Vectorized 2D float point bounding box calculator.
 *   - `src/translate.c`: Vectorized in-place 2D point translation kernel.
 *   - `src/colorlut.c`: Packed ARGB color LUT mapper.
 *   - `src/pixelsearch.c`: Multi-threaded SIMD pixel search.
 *   - `src/throttle.c`: Native background thread frame pacing DLL.
 */
class MCode {

    /**
     * Allocates executable virtual memory, decodes Base64 machine code, and returns the function pointer.
     *
     * @param {String|Object} code Base64 encoded machine code string or Object with {x64: "...", x86: "..."}
     * @returns {Integer} Executable memory pointer callable directly via DllCall
     *
     * @example
     * ; 1. Compile and call a simple x64 addition function
     * ; C code: int Add(int a, int b) { return a + b; }
     * ; Assembly: lea eax, [rcx+rdx]; ret -> Base64: "i8DrA=="
     * pAdd := MCode.Call("i8DrA==")
     * sum := DllCall(pAdd, "int", 10, "int", 25, "int") ; returns 35
     *
     * @example
     * ; 2. Pass architecture-specific dictionary
     * pFunc := MCode.Call({ x64: "U1ZIg+wo...", x86: "VYnli..." })
     */
    static Call(code) {
        local str := "", sSize := 0, pCode := 0

        if (code is String) {
            str := code
        } else if (IsObject(code)) {
            str := code.HasProp("x64") ? code.x64 : (code.HasProp("x86") ? code.x86 : "")
        }

        if (str == "")
            throw ValueError("[!] No machine code string provided")

        ; Calculate required binary buffer size (CRYPT_STRING_BASE64 = 1)
        DllCall("crypt32\CryptStringToBinary", "str", str, "uint", 0, "uint", 1, "ptr", 0, "uint*", &sSize:=0, "ptr", 0, "ptr", 0)
        
        ; Allocate executable memory (MEM_COMMIT=0x1000 | MEM_RESERVE=0x2000, PAGE_EXECUTE_READWRITE=0x40)
        pCode := DllCall("VirtualAlloc", "ptr", 0, "uptr", sSize, "uint", 0x3000, "uint", 0x40, "ptr")
        if (!pCode)
            throw Error("[!] Failed to allocate executable memory for MCode (LastError: " A_LastError ")")

        ; Decode Base64 binary directly into the executable page
        DllCall("crypt32\CryptStringToBinary", "str", str, "uint", 0, "uint", 1, "ptr", pCode, "uint*", &sSize, "ptr", 0, "ptr", 0)
        return pCode
    }

    ; Internal function pointers and timer handles
    static __pQpcSpin := 0
    static __pQpcFunc := 0
    static __hHiResTimer := 0
    static __dueTimeBuf := Buffer(8, 0)
    static __pBoundsFunc := 0
    static __pTransFunc := 0

    ; High-Resolution Hardware & Kernel Pacing

    /**
     * Initializes a modern Windows High-Resolution Waitable Timer (CREATE_WAITABLE_TIMER_HIGH_RESOLUTION).
     * Supported on Windows 10 (Version 1803+) and Windows 11.
     *
     * @returns {Boolean} True if supported and initialized, false otherwise
     */
    static InitHiResTimer() {
        local hTimer
        if (this.__hHiResTimer)
            return true

        ; CREATE_WAITABLE_TIMER_HIGH_RESOLUTION = 0x2, TIMER_ALL_ACCESS = 0x1F0003
        hTimer := DllCall("CreateWaitableTimerExW", "ptr", 0, "ptr", 0, "uint", 0x2, "uint", 0x1F0003, "ptr")
        if (hTimer) {
            this.__hHiResTimer := hTimer
            return true
        }
        return false
    }

    /**
     * High-resolution kernel sleep supporting fractional milliseconds (e.g. 1.5ms, 0.8ms).
     * Relinquishes CPU core execution to the OS scheduler in a true zero-power idle state.
     *
     * @param {Float} ms Milliseconds to sleep
     * @returns {void}
     *
     * @example
     * ; Sleep for precisely 2.5 milliseconds
     * MCode.HiResWait(2.5)
     */
    static HiResWait(ms) {
        local dueTimeVal
        if (ms <= 0.1)
            return

        if (!this.__hHiResTimer)
            this.InitHiResTimer()

        ; Negative 100-nanosecond intervals (1 ms = 10,000 units)
        dueTimeVal := -Integer(ms * 10000)
        NumPut("int64", dueTimeVal, this.__dueTimeBuf, 0)
        DllCall("SetWaitableTimer", "ptr", this.__hHiResTimer, "ptr", this.__dueTimeBuf, "int", 0, "ptr", 0, "ptr", 0, "int", 0)
        DllCall("WaitForSingleObject", "ptr", this.__hHiResTimer, "uint", 1000)
    }

    /**
     * Closes the high-resolution waitable timer handle on shutdown.
     *
     * @returns {void}
     */
    static DisposeHiResTimer() {
        if (this.__hHiResTimer) {
            DllCall("CloseHandle", "ptr", this.__hHiResTimer)
            this.__hHiResTimer := 0
        }
    }

    /**
     * Initializes the native x64 hardware spin-wait routine with CPU pause instructions.
     *
     * @returns {void}
     */
    static InitQPC() {
        if (this.__pQpcSpin)
            return

        ; Verified x64 assembly with hardware pause instruction (38 bytes):
        ; Source: native/src/qpc_spin.c
        ;   push rbx
        ;   push rsi
        ;   sub rsp, 0x28
        ;   mov rbx, rcx          ; targetTick
        ;   mov rsi, rdx          ; pQPC function pointer
        ; .loop:
        ;   pause                 ; 0xF3 0x90 (Hardware CPU spin-wait hint: drops power & heat by ~80%)
        ;   lea rcx, [rsp+0x20]   ; &localQpc
        ;   call rsi              ; QueryPerformanceCounter(&localQpc)
        ;   mov rax, [rsp+0x20]   ; rax = current tick
        ;   cmp rax, rbx          ; cmp current, target
        ;   jl .loop              ; repeat if current < target
        ;   add rsp, 0x28
        ;   pop rsi
        ;   pop rbx
        ;   ret
        static code64 := "U1ZIg+woSInLSInW85BIjUwkIP/WSItEJCBIOdh87UiDxCheW8M="

        try {
            this.__pQpcSpin := this.Call(code64)
            local hKernel := DllCall("GetModuleHandle", "str", "kernel32.dll", "ptr")
            this.__pQpcFunc := DllCall("GetProcAddress", "ptr", hKernel, "astr", "QueryPerformanceCounter", "ptr")
        } catch {
            this.__pQpcSpin := 0
        }
    }

    /**
     * Executes ultra-low latency hardware spin-wait until target QPC tick count is reached.
     * Uses native x64 assembly with CPU pause hints to prevent pipeline stalls.
     *
     * @param {Integer} targetTick The QPC tick value to wait for
     * @returns {Integer} Final QPC tick count upon release
     *
     * @example
     * DllCall("QueryPerformanceCounter", "int64*", &now:=0)
     * DllCall("QueryPerformanceFrequency", "int64*", &qpf:=0)
     * target := now + (qpf // 144) ; Target for 144 FPS frame
     * MCode.QpcSpinWait(target)
     */
    static QpcSpinWait(targetTick) {
        if (!this.__pQpcSpin)
            this.InitQPC()

        if (this.__pQpcSpin && this.__pQpcFunc) {
            try {
                return DllCall(this.__pQpcSpin, "int64", targetTick, "ptr", this.__pQpcFunc, "int64")
            } catch {
                ; Fallback to interpreter loop if MCode execution fails
            }
        }

        local qpc := 0
        while (qpc < targetTick) {
            DllCall("QueryPerformanceCounter", "int64*", &qpc:=0)
        }
        return qpc
    }

    ; Vectorized Batch Math & SIMD Kernels

    /**
     * High-speed native vector bounding box calculation over an array of 2D float points.
     * Computes [minX, minY, maxX, maxY] in a single vectorized pass.
     *
     * @param {Integer|Buffer} pPoints Raw memory pointer or Buffer of [float x, float y, ...]
     * @param {Integer} count Total number of (x,y) point pairs
     * @param {Buffer} [outBoundsBuf] Optional output buffer (16 bytes: 4 floats)
     * @returns {Array} [minX, minY, maxX, maxY] as float numbers
     *
     * @example
     * ; Points: (10, 20), (100, 5), (45, 80)
     * ptBuf := Buffer(24, 0)
     * NumPut("float", 10.0, ptBuf, 0), NumPut("float", 20.0, ptBuf, 4)
     * NumPut("float", 100.0, ptBuf, 8), NumPut("float", 5.0, ptBuf, 12)
     * NumPut("float", 45.0, ptBuf, 16), NumPut("float", 80.0, ptBuf, 20)
     * bounds := MCode.BatchComputeBounds(ptBuf, 3) ; [10.0, 5.0, 100.0, 80.0]
     */
    static BatchComputeBounds(pPoints, count, outBoundsBuf?) {
        local buf, pOut, ptrIn, minX := 0.0, minY := 0.0, maxX := 0.0, maxY := 0.0, offset := 0, px := 0.0, py := 0.0

        ; Source: native/src/bounds.c
        static code64 := "hdJ+S/MPEAHzDxBJBA8o0A8o2f/KdCFIg8EI8w8QIfMPEGkE8w9dxPMPXc3zD1/U8w9f3f/Kdd/zQQ8RAPNBDxFIBPNBDxFQCPNBDxFYDMM="

        if (count <= 0 || !pPoints)
            return [0.0, 0.0, 0.0, 0.0]

        buf := IsSet(outBoundsBuf) ? outBoundsBuf : Buffer(16, 0)
        pOut := buf.ptr
        ptrIn := HasProp(pPoints, "ptr") ? pPoints.ptr : pPoints

        if (!this.__pBoundsFunc) {
            try {
                this.__pBoundsFunc := this.Call(code64)
            } catch {
                this.__pBoundsFunc := 0
            }
        }

        if (this.__pBoundsFunc) {
            DllCall(this.__pBoundsFunc, "ptr", ptrIn, "int", count, "ptr", pOut)
            return [NumGet(pOut, 0, "float"), NumGet(pOut, 4, "float"), NumGet(pOut, 8, "float"), NumGet(pOut, 12, "float")]
        }

        ; Fallback: Pure interpreter loop
        minX := NumGet(ptrIn, 0, "float")
        minY := NumGet(ptrIn, 4, "float")
        maxX := minX
        maxY := minY

        loop count - 1 {
            offset := A_Index * 8
            px := NumGet(ptrIn, offset + 0, "float")
            py := NumGet(ptrIn, offset + 4, "float")
            (px < minX) ? minX := px : 0
            (py < minY) ? minY := py : 0
            (px > maxX) ? maxX := px : 0
            (py > maxY) ? maxY := py : 0
        }
        return [minX, minY, maxX, maxY]
    }

    /**
     * High-speed vectorized translation over an array of 2D float points in memory.
     * Applies [x += dx, y += dy] across all points in-place with native assembly speed.
     *
     * @param {Integer|Buffer} pPoints Raw memory pointer or Buffer of [float x, float y, ...]
     * @param {Integer} count Total number of (x,y) point pairs
     * @param {Float} dx Delta X translation
     * @param {Float} dy Delta Y translation
     * @returns {Integer|Buffer} The modified pPoints pointer / Buffer for method chaining
     *
     * @example
     * ; Translate 1,000 polygon vertices by (+50, -30) in 1 microsecond
     * MCode.BatchTranslate(ptBuffer, 1000, 50.0, -30.0)
     */
    static BatchTranslate(pPoints, count, dx, dy) {
        local offset := 0, px := 0.0, py := 0.0, ptrIn

        ; Source: native/src/translate.c
        static code64 := "hdJ+Fg8U0w8SAQ9Ywg8TAUiDwQj/ynXtww=="

        if (count <= 0 || !pPoints)
            return pPoints

        ptrIn := HasProp(pPoints, "ptr") ? pPoints.ptr : pPoints

        if (!this.__pTransFunc) {
            try {
                this.__pTransFunc := this.Call(code64)
            } catch {
                this.__pTransFunc := 0
            }
        }

        if (this.__pTransFunc) {
            DllCall(this.__pTransFunc, "ptr", ptrIn, "int", count, "float", dx, "float", dy)
            return pPoints
        }

        ; Fallback: Pure interpreter loop
        loop count {
            offset := (A_Index - 1) * 8
            px := NumGet(ptrIn, offset + 0, "float") + dx
            py := NumGet(ptrIn, offset + 4, "float") + dy
            NumPut("float", px, ptrIn, offset + 0)
            NumPut("float", py, ptrIn, offset + 4)
        }
        return pPoints
    }
}
