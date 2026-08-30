/**
 * File:     qpc_spin.c
 * License:  MIT License
 * Author:   Bence Markiel (bceenaeiklmr)
 * Github:   https://github.com/bceenaeiklmr/GpGFX
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
