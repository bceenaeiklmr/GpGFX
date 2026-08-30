/**
 * File:     throttle.c
 * License:  MIT License
 * Author:   Bence Markiel (bceenaeiklmr)
 * Github:   https://github.com/bceenaeiklmr/GpGFX
 */

﻿/**
 * GpGFX.Core - Native Frame Throttle & Pacing Engine
 * Author: Bence Markiel (bceenaeiklmr)
 * License: MIT License
 *
 * Provides sub-millisecond, jitter-free frame scheduling via a dedicated
 * high-priority background worker thread (THREAD_PRIORITY_TIME_CRITICAL).
 * Communicates with AutoHotkey via a hidden message-only window (HWND_MESSAGE).
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmsystem.h>
#include <stdint.h>
#include <stdbool.h>

#if defined(_MSC_VER)
    #include <intrin.h>
    #define CPU_PAUSE() _mm_pause()
#elif defined(__GNUC__) || defined(__clang__)
    #include <x86intrin.h>
    #define CPU_PAUSE() __builtin_ia32_pause()
#else
    #define CPU_PAUSE() ((void)0)
#endif

#pragma comment(lib, "winmm.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "kernel32.lib")

#define EXPORT __declspec(dllexport)

// Core state structure
typedef struct {
    HWND            targetHwnd;
    UINT            frameMsg;
    double          targetFPS;
    LARGE_INTEGER   qpf;
    LONGLONG        ticksPerFrame;
    
    // Control flags
    volatile LONG   running;
    volatile LONG   pendingAck;
    int             autoMode; // 1 = continuous interval, 0 = wait for FrameCompleted

    // Telemetry
    volatile double   lastDeltaMs;
    volatile double   avgFps;
    volatile uint64_t totalFrames;
    
    // Thread management
    HANDLE          hThread;
    HANDLE          hWakeEvent;
} FrameThrottleState;

static FrameThrottleState g_state = {0};

// Background high-precision worker thread
static DWORD WINAPI FrameThrottleThread(LPVOID lpParam) {
    FrameThrottleState *s = (FrameThrottleState *)lpParam;
    
    // Request 1ms resolution from Windows scheduler for the thread's lifetime
    timeBeginPeriod(1);

    LARGE_INTEGER now, nextDeadline, lastFrameTime;
    QueryPerformanceCounter(&now);
    lastFrameTime = now;
    nextDeadline.QuadPart = now.QuadPart + s->ticksPerFrame;

    double frameCount = 0;
    double accumulatedTimeMs = 0;

    while (InterlockedCompareExchange(&s->running, 1, 1) == 1) {
        
        // If in handshake mode, wait until AHK acknowledges the previous frame
        if (!s->autoMode) {
            while (InterlockedCompareExchange(&s->pendingAck, 0, 0) == 1) {
                if (InterlockedCompareExchange(&s->running, 1, 1) != 1)
                    goto thread_exit;
                CPU_PAUSE();
            }
        }

        // Coarse sleep: Sleep for bulk of the frame if more than 2ms remain
        QueryPerformanceCounter(&now);
        LONGLONG remainingTicks = nextDeadline.QuadPart - now.QuadPart;
        double remainingMs = (double)remainingTicks / (double)s->qpf.QuadPart * 1000.0;

        if (remainingMs > 2.0) {
            DWORD sleepMs = (DWORD)(remainingMs - 1.5);
            Sleep(sleepMs);
        }

        // High-precision spin loop for sub-millisecond tail
        while (1) {
            QueryPerformanceCounter(&now);
            if (now.QuadPart >= nextDeadline.QuadPart)
                break;
            CPU_PAUSE();
        }

        // Calculate delta timing & telemetry
        double deltaMs = (double)(now.QuadPart - lastFrameTime.QuadPart) / (double)s->qpf.QuadPart * 1000.0;
        lastFrameTime = now;
        s->lastDeltaMs = deltaMs;
        s->totalFrames++;

        frameCount++;
        accumulatedTimeMs += deltaMs;
        if (accumulatedTimeMs >= 500.0) {
            s->avgFps = (frameCount / accumulatedTimeMs) * 1000.0;
            frameCount = 0;
            accumulatedTimeMs = 0;
        }

        // Signal frame readiness to AHK window
        if (!s->autoMode) {
            InterlockedExchange(&s->pendingAck, 1);
        }

        // Post message to AHK message-only window
        if (s->targetHwnd && s->frameMsg) {
            PostMessageW(s->targetHwnd, s->frameMsg, (WPARAM)s->totalFrames, (LPARAM)(UINT)(deltaMs * 100.0));
        }

        // Compute next deadline
        // If we drifted behind by more than 2 frames, resynchronize to avoid frame burst
        QueryPerformanceCounter(&now);
        if (now.QuadPart > nextDeadline.QuadPart + (s->ticksPerFrame * 2)) {
            nextDeadline.QuadPart = now.QuadPart + s->ticksPerFrame;
        } else {
            nextDeadline.QuadPart += s->ticksPerFrame;
        }
    }

thread_exit:
    timeEndPeriod(1);
    return 0;
}

/**
 * Starts the high-precision native frame pacing timer thread.
 * @param targetHwnd  HWND of the window to receive WM notifications (e.g. HWND_MESSAGE)
 * @param frameMsg    Window message ID (e.g. RegisterWindowMessage("GpGFX_FrameReady"))
 * @param targetFPS   Target frame rate (e.g. 60.0, 120.0, 144.0, 240.0)
 * @param autoMode    1 = continuous pulse (default), 0 = wait for FrameCompleted() handshake
 * @return 1 on success, 0 on failure
 */
EXPORT int StartFrameTimer(HWND targetHwnd, UINT frameMsg, double targetFPS, int autoMode) {
    if (InterlockedCompareExchange(&g_state.running, 1, 1) == 1) {
        // Already running; update settings dynamically
        g_state.targetHwnd = targetHwnd;
        g_state.frameMsg   = frameMsg;
        g_state.autoMode   = autoMode;
        
        if (targetFPS > 0.0) {
            g_state.targetFPS     = targetFPS;
            g_state.ticksPerFrame = (LONGLONG)((double)g_state.qpf.QuadPart / targetFPS);
        }
        return 1;
    }

    QueryPerformanceFrequency(&g_state.qpf);
    if (targetFPS <= 0.0) targetFPS = 60.0;
    
    g_state.targetHwnd     = targetHwnd;
    g_state.frameMsg       = frameMsg;
    g_state.targetFPS      = targetFPS;
    g_state.ticksPerFrame  = (LONGLONG)((double)g_state.qpf.QuadPart / targetFPS);
    g_state.autoMode       = autoMode;
    g_state.totalFrames    = 0;
    g_state.lastDeltaMs    = 0.0;
    g_state.avgFps         = targetFPS;
    g_state.pendingAck     = 0;

    InterlockedExchange(&g_state.running, 1);

    g_state.hThread = CreateThread(NULL, 0, FrameThrottleThread, &g_state, 0, NULL);
    if (!g_state.hThread) {
        InterlockedExchange(&g_state.running, 0);
        return 0;
    }

    // Elevate thread priority for microsecond-level scheduling accuracy
    SetThreadPriority(g_state.hThread, THREAD_PRIORITY_TIME_CRITICAL);
    return 1;
}

/**
 * Called from AHK when a frame finishes rendering (only needed when autoMode == 0).
 */
EXPORT void FrameCompleted(void) {
    InterlockedExchange(&g_state.pendingAck, 0);
}

/**
 * Updates the target framerate dynamically without restarting the thread.
 */
EXPORT void SetTargetFPS(double targetFPS) {
    if (targetFPS > 0.0) {
        g_state.targetFPS = targetFPS;
        g_state.ticksPerFrame = (LONGLONG)((double)g_state.qpf.QuadPart / targetFPS);
    }
}

/**
 * Retrieves real-time pacing telemetry.
 */
EXPORT void GetFrameStats(double *pLastDeltaMs, double *pAvgFps, uint64_t *pTotalFrames) {
    if (pLastDeltaMs)  *pLastDeltaMs  = g_state.lastDeltaMs;
    if (pAvgFps)       *pAvgFps       = g_state.avgFps;
    if (pTotalFrames)  *pTotalFrames  = g_state.totalFrames;
}

/**
 * Stops the frame pacing thread cleanly.
 */
EXPORT void StopFrameTimer(void) {
    if (InterlockedCompareExchange(&g_state.running, 0, 1) == 1) {
        if (g_state.hThread) {
            WaitForSingleObject(g_state.hThread, 1000);
            CloseHandle(g_state.hThread);
            g_state.hThread = NULL;
        }
    }
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_DETACH) {
        StopFrameTimer();
    }
    return TRUE;
}
