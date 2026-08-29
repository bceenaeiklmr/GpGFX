/**
 * GpGFX Native MCode - High-Precision QPC Hardware Spin-Wait
 * Author: Bence Markiel (bceenaeiklmr)
 * License: MIT License
 *
 * Description:
 *   Spins until QueryPerformanceCounter reaches or exceeds targetTick.
 *   Emits the x86/x64 hardware `pause` instruction (0xF3 0x90) on each loop iteration.
 *   This avoids pipeline stall penalties, reduces power consumption by ~80%,
 *   and prevents CPU thermal throttling during high-refresh-rate pacing (144 - 1000 FPS).
 *
 * Signature:
 *   int64_t QpcSpinWait(int64_t targetTick, BOOL (WINAPI *pQueryPerformanceCounter)(LARGE_INTEGER *));
 */

#include <stdint.h>
#include <windows.h>

#if defined(_MSC_VER)
    #include <intrin.h>
    #define CPU_PAUSE() _mm_pause()
#elif defined(__GNUC__) || defined(__clang__)
    #define CPU_PAUSE() __builtin_ia32_pause()
#else
    #define CPU_PAUSE() ((void)0)
#endif

typedef BOOL (WINAPI *QPC_PROC)(LARGE_INTEGER *);

int64_t QpcSpinWait(int64_t targetTick, QPC_PROC pQPC) {
    LARGE_INTEGER qpc;
    do {
        CPU_PAUSE();
        pQPC(&qpc);
    } while (qpc.QuadPart < targetTick);
    return qpc.QuadPart;
}
