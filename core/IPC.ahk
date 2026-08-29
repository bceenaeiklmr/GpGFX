; Script     IPC.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       29.08.2026
; Version    1.0.0

#Requires AutoHotkey v2

/**
 * GpGFX Inter-Process Communication (IPC)
 *
 * Provides low-level Win32 shared memory and synchronization for multi-process concurrency:
 * - FileMapping: Named shared memory in RAM (CreateFileMapping / MapViewOfFile) for zero-copy binary communication between processes.
 * - Mutex: Named Win32 mutual exclusion lock to prevent concurrent write collisions in shared buffers.
 * - Semaphore: Named Win32 counting semaphore for instant task queue signaling between master and worker processes.
 * - Worker: Background AHK worker process controller for offloading intensive tasks.
 *
 * When to use:
 * - Heavy particle simulation (thousands of objects) without dropping frame rates on the main UI thread.
 * - Multi-process rendering and coordinate processing across multiple CPU cores via WorkerPool.
 * - Sharing large binary buffers (such as raw pixel arrays or physics matrices) between separate scripts.
 *
 * Where it is used:
 * - Used directly by WorkerPool.ahk (multi-core worker orchestration), Layer.ahk (worker assignment), and Worker.ahk (background execution loop).
 *
 * Acknowledgments and credits:
 * - Descolada & iseahound: AHK v2 IPC reference and architecture foundations
 *   https://www.autohotkey.com/boards/viewtopic.php?t=124720
 */
class FileMapping {

    /**
     * Creates or opens a named shared memory mapping.
     *
     * @param {String} [szName="Local\GpGFX_SharedMem"] Unique system-wide mapping name
     * @param {Integer} [dwDesiredAccess=0xF001F] File map access flags (0xF001F = FILE_MAP_ALL_ACCESS)
     * @param {Integer} [flProtect=0x4] Memory protection (0x4 = PAGE_READWRITE)
     * @param {Integer} [dwSize=65536] Buffer size in bytes (default 64 KB)
     *
     * @example
     * ; 1. Create a 1 MB shared memory block
     * fm := FileMapping("Local\MySharedBuffer", , , 1048576)
     *
     * ; 2. Open an existing shared buffer created by another process
     * fmClient := FileMapping("Local\MySharedBuffer")
     */
    __New(szName := "Local\GpGFX_SharedMem", dwDesiredAccess := 0xF001F, flProtect := 0x4, dwSize := 65536) {
        static INVALID_HANDLE_VALUE := -1
        this.BUF_SIZE := dwSize
        this.szName := szName

        ; Open existing or create new file mapping object
        if !(this.hMapFile := DllCall("OpenFileMapping", "uint", dwDesiredAccess, "int", 0, "str", szName, "ptr")) {
            if !(this.hMapFile := DllCall("CreateFileMapping", "ptr", INVALID_HANDLE_VALUE, "ptr", 0, "uint", flProtect, "uint", 0, "uint", dwSize, "str", szName, "ptr"))
                throw Error("[!] Unable to create or open FileMapping: " szName " (LastError: " A_LastError ")")
        }

        ; Map view of file - use 0 for dwNumberOfBytesToMap to map entire object
        if !(this.pBuf := DllCall("MapViewOfFile", "ptr", this.hMapFile, "uint", dwDesiredAccess, "uint", 0, "uint", 0, "uptr", 0, "ptr"))
            throw Error("[!] Unable to map view of FileMapping (LastError: " A_LastError ")")
    }

    /**
     * Writes string or binary Buffer data into shared memory at a specific offset.
     *
     * @param {String|Buffer} data Data payload to write
     * @param {Integer} [offset=0] Byte offset within the shared buffer
     * @returns {void}
     *
     * @example
     * ; Write a string
     * fm.Write("Hello from Process 1", 0)
     *
     * ; Write a binary Buffer
     * rawBuf := Buffer(16, 0)
     * NumPut("float", 123.45, rawBuf, 0)
     * fm.Write(rawBuf, 64)
     */
    Write(data, offset := 0) {
        if (!this.pBuf)
            throw Error("[!] FileMapping is closed")

        if (data is String)
            StrPut(data, this.pBuf + offset, this.BUF_SIZE - offset)
        else if (data is Buffer)
            DllCall("RtlCopyMemory", "ptr", this.pBuf + offset, "ptr", data, "int", Min(data.Size, this.BUF_SIZE - offset))
        else
            throw TypeError("[!] Data must be a String or Buffer")
    }

    /**
     * Reads string or binary data from shared memory.
     *
     * @param {Buffer} [buffer] Optional destination Buffer to receive raw binary data. If omitted, reads a null-terminated UTF-16 string
     * @param {Integer} [offset=0] Byte offset within shared memory
     * @param {Integer} [size] Maximum bytes to read into destination buffer
     * @returns {String|Integer} String content when buffer is omitted, or bytes copied when buffer is provided
     *
     * @example
     * ; Read string
     * str := fm.Read(, 0)
     *
     * ; Read binary struct into local Buffer
     * destBuf := Buffer(16, 0)
     * fm.Read(destBuf, 64, 16)
     * val := NumGet(destBuf, 0, "float")
     */
    Read(buffer?, offset := 0, size?) {
        local readSize := 0

        if (!this.pBuf)
            throw Error("[!] FileMapping is closed")

        if (IsSet(buffer)) {
            readSize := Min(buffer.size, this.BUF_SIZE - offset, IsSet(size) ? size : (this.BUF_SIZE - offset))
            return DllCall("RtlCopyMemory", "ptr", buffer, "ptr", this.pBuf + offset, "int", readSize)
        }
        return StrGet(this.pBuf + offset)
    }

    /**
     * Closes memory view and releases Win32 file mapping handle.
     *
     * @returns {void}
     */
    Close() {
        if (this.pBuf) {
            DllCall("UnmapViewOfFile", "ptr", this.pBuf)
            this.pBuf := 0
        }
        if (this.hMapFile) {
            DllCall("CloseHandle", "ptr", this.hMapFile)
            this.hMapFile := 0
        }
    }

    __Delete() => this.Close()
}

/**
 * Win32 Named Mutex for inter-process mutual exclusion synchronization.
 */
class Mutex {

    /**
     * Creates or opens a named Mutex object.
     *
     * @param {String} [name="Local\GpGFX_TaskMutex"] Unique system-wide mutex name
     * @param {Boolean} [initialOwner=false] If true, caller acquires initial ownership
     * @param {Integer} [securityAttributes=0] Optional pointer to SECURITY_ATTRIBUTES
     *
     * @example
     * mtx := Mutex("Local\MyProcessLock")
     */
    __New(name := "Local\GpGFX_TaskMutex", initialOwner := 0, securityAttributes := 0) {
        if !(this.ptr := DllCall("CreateMutex", "ptr", securityAttributes, "int", !!initialOwner, "str", name, "ptr"))
            throw Error("[!] Unable to create or open Mutex: " name)
    }

    /**
     * Acquires exclusive lock on the mutex.
     *
     * @param {Integer} [timeout=0xFFFFFFFF] Milliseconds to wait (0xFFFFFFFF = INFINITE)
     * @returns {Integer} 0 = WAIT_OBJECT_0 (acquired), 0x80 = WAIT_ABANDONED, 0x120 = WAIT_TIMEOUT
     *
     * @example
     * if (mtx.Lock(1000) == 0) {
     *     ; Critical section: safe to read/write shared memory
     *     mtx.Release()
     * }
     */
    Lock(timeout := 0xFFFFFFFF) => DllCall("WaitForSingleObject", "ptr", this.ptr, "int", timeout, "int")

    /**
     * Releases ownership of the mutex so other waiting processes can acquire it.
     *
     * @returns {Boolean} Non-zero on success
     */
    Release() => DllCall("ReleaseMutex", "ptr", this.ptr)

    /**
     * Closes the Win32 mutex handle.
     */
    Close() {
        if (this.ptr) {
            DllCall("CloseHandle", "ptr", this.ptr)
            this.ptr := 0
        }
    }

    __Delete() => this.Close()
}

/**
 * Win32 Counting Semaphore for inter-process task signaling and producer-consumer queues.
 */
class Semaphore {

    /**
     * Creates or opens a named or anonymous counting Semaphore.
     *
     * @param {Integer} [initialCount=0] Initial count available to callers
     * @param {Integer} [maximumCount=1000] Maximum count limit
     * @param {String} [name] Optional unique system-wide name. If omitted, creates an anonymous semaphore
     * @param {Integer} [securityAttributes=0] Optional pointer to SECURITY_ATTRIBUTES
     *
     * @example
     * ; Producer-consumer task semaphore
     * semTask := Semaphore(0, 100, "Local\GpGFX_WorkerTask")
     */
    __New(initialCount := 0, maximumCount := 1000, name?, securityAttributes := 0) {
        if (IsSet(name) && name != "") {
            ; Try open first
            if (this.ptr := DllCall("OpenSemaphore", "uint", 0x1F0003, "int", 0, "str", name, "ptr"))
                return
            ; Otherwise create
            if (!this.ptr := DllCall("CreateSemaphore", "ptr", securityAttributes, "int", initialCount, "int", maximumCount, "str", name, "ptr"))
                throw Error("[!] Unable to create Semaphore: " name)
        } else {
            if (!this.ptr := DllCall("CreateSemaphore", "ptr", securityAttributes, "int", initialCount, "int", maximumCount, "ptr", 0, "ptr"))
                throw Error("[!] Unable to create anonymous Semaphore")
        }
    }

    /**
     * Waits for the semaphore count to be greater than 0, then decrements it.
     *
     * @param {Integer} [timeout=0xFFFFFFFF] Milliseconds to wait (0xFFFFFFFF = INFINITE)
     * @returns {Integer} 0 = WAIT_OBJECT_0 (signaled), 0x120 = WAIT_TIMEOUT
     *
     * @example
     * ; Wait for master process to post a task
     * if (semTask.Wait(500) == 0) {
     *     ; Process task...
     * }
     */
    Wait(timeout := 0xFFFFFFFF) => DllCall("WaitForSingleObject", "ptr", this.ptr, "int", timeout, "int")

    /**
     * Increments the semaphore count by a specified amount, waking waiting processes.
     *
     * @param {Integer} [count=1] Amount to increment
     * @returns {Boolean} Non-zero on success
     *
     * @example
     * ; Signal worker that 1 task is ready
     * semTask.Release(1)
     */
    Release(count := 1) => DllCall("ReleaseSemaphore", "ptr", this.ptr, "int", count, "ptr", 0)

    /**
     * Closes the Win32 semaphore handle.
     */
    Close() {
        if (this.ptr) {
            DllCall("CloseHandle", "ptr", this.ptr)
            this.ptr := 0
        }
    }

    __Delete() => this.Close()
}

/**
 * Manages a background AutoHotkey worker process for task offloading.
 */
class Worker {

    static fm := 0
    static mtx := 0
    static process := 0
    static msgTask := 0
    static isReady := false

    /**
     * Spawns a background worker process communicating over shared memory.
     *
     * @returns {void}
     */
    static Spawn() {
        local scriptPath, pid, e

        if (this.process)
            return

        ; Initialize shared memory and synchronization mutex
        this.fm := FileMapping("Local\GpGFX_WorkerMem", , , 4096)
        this.mtx := Mutex("Local\GpGFX_WorkerMutex")

        ; Register custom window notification message
        this.msgTask := DllCall("RegisterWindowMessage", "str", "GpGFX_TaskMessage")

        ; Worker script path
        scriptPath := A_LineFile "\..\worker.ahk"

        try {
            pid := Run(A_AhkPath ' "' scriptPath '" Local\GpGFX_WorkerMem Local\GpGFX_WorkerMutex', , "Hide")
            this.process := {pid: pid}
            this.isReady := true
        } catch as e {
            GpGFX.DebugLog("[!] Failed to spawn worker: " e.Message "`n")
        }
    }

    /**
     * Offloads high-precision QPC sleep to the background worker.
     *
     * @param {Integer} targetTick Target QPC tick count to reach
     * @returns {void}
     */
    static OffloadQpcSleep(targetTick) {
        if (!this.isReady)
            this.Spawn()

        this.mtx.Lock()
        ; Slot 0: TaskType (1 = QPC Sleep), Param1 = targetTick (int64), State (1 = QUEUED)
        NumPut("int", 1, this.fm.pBuf, 0)            ; TaskType = 1 (Sleep)
        NumPut("int", 1, this.fm.pBuf, 4)            ; State = 1 (QUEUED)
        NumPut("int64", targetTick, this.fm.pBuf, 8) ; Param1 = targetTick
        this.mtx.Release()

        ; Notify worker via PostMessage broadcast
        PostMessage(this.msgTask, 0, 0, , 0xFFFF)
    }

    /**
     * Cleanly shuts down the background worker process.
     *
     * @returns {void}
     */
    static Shutdown() {
        if (!this.process)
            return

        try {
            this.mtx.Lock()
            NumPut("int", 99, this.fm.pBuf, 0) ; TaskType = 99 (EXIT)
            this.mtx.Release()
            PostMessage(this.msgTask, 0, 0, , 0xFFFF)
        }
        this.process := 0
        this.isReady := false
    }
}
