    /**
     * GpGFX PixelSearch x64
     * License: MIT License
     *
     * Memory Layout (SearchCtx Struct - 64 bytes passed in RCX):
     *   +0   (8 bytes) : const unsigned char* pScan0   - Pointer to first scanline byte
     *   +8   (4 bytes) : int stride                    - Scanline stride in bytes (width * 4)
     *   +12  (4 bytes) : unsigned int targetClr        - 32-bit target ARGB color (0xAARRGGBB)
     *   +16  (4 bytes) : int variation                 - Color channel variation tolerance (0 - 255)
     *   +20  (4 bytes) : int subX1                     - Left boundary (inclusive)
     *   +24  (4 bytes) : int subY1                     - Top boundary (inclusive)
     *   +28  (4 bytes) : int subX2                     - Right boundary (inclusive)
     *   +32  (4 bytes) : int subY2                     - Bottom boundary (inclusive)
     *   +36  (4 bytes) : int pad                       - 8-byte boundary alignment padding
     *   +40  (8 bytes) : volatile int* pSharedStop     - Shared atomic early-exit stop flag
     *   +48  (4 bytes) : int outFound                  - Output: 1 if found, 0 if not found
     *   +52  (4 bytes) : int outX                      - Output: X coordinate of matched pixel
     *   +56  (4 bytes) : int outY                      - Output: Y coordinate of matched pixel
     *   +60  (4 bytes) : unsigned int outClr           - Output: Matched 32-bit ARGB color
     *
     * Compilation (GCC / MinGW):
     *   gcc -O3 -c -fno-asynchronous-unwind-tables PixelSearchKernel.c -o PixelSearchKernel.o
     */

    typedef struct {
        const unsigned char* pScan0;
        int stride;
        unsigned int targetClr;
        int variation;
        int subX1;
        int subY1;
        int subX2;
        int subY2;
        int pad;
        volatile int* pSharedStop;
        int outFound;
        int outX;
        int outY;
        unsigned int outClr;
    } SearchCtx;

    __attribute__((ms_abi))
    int RunSearch(SearchCtx* c) {
        if (!c || !c->pScan0) return 0;

        const unsigned char* pScan0 = c->pScan0;
        int stride = c->stride;
        unsigned int targetClr = c->targetClr;
        int var = c->variation;
        int x1 = c->subX1, y1 = c->subY1;
        int x2 = c->subX2, y2 = c->subY2;
        volatile int* pStop = c->pSharedStop;

        if (var == 0) {
            // High-Speed Exact Match Loop (Sequential L1/L2 Cache Streaming)
            for (int y = y1; y <= y2; ++y) {
                if (pStop && *pStop) return 0;

                const unsigned int* row = (const unsigned int*)(pScan0 + y * stride);
                for (int x = x1; x <= x2; ++x) {
                    if (row[x] == targetClr) {
                        c->outFound = 1;
                        c->outX = x;
                        c->outY = y;
                        c->outClr = targetClr;
                        if (pStop) *pStop = 1; // Signal atomic early-exit
                        return 1;
                    }
                }
            }
        } else {
            // High-Speed RGB Variation Tolerance Loop
            int tR = (targetClr >> 16) & 0xFF;
            int tG = (targetClr >> 8) & 0xFF;
            int tB = targetClr & 0xFF;

            for (int y = y1; y <= y2; ++y) {
                if (pStop && *pStop) return 0;

                const unsigned int* row = (const unsigned int*)(pScan0 + y * stride);
                for (int x = x1; x <= x2; ++x) {
                    unsigned int px = row[x];
                    int pR = (px >> 16) & 0xFF;
                    int pG = (px >> 8) & 0xFF;
                    int pB = px & 0xFF;

                    int dR = pR - tR; if (dR < 0) dR = -dR;
                    int dG = pG - tG; if (dG < 0) dG = -dG;
                    int dB = pB - tB; if (dB < 0) dB = -dB;

                    if (dR <= var && dG <= var && dB <= var) {
                        c->outFound = 1;
                        c->outX = x;
                        c->outY = y;
                        c->outClr = px;
                        if (pStop) *pStop = 1; // Signal atomic early-exit
                        return 1;
                    }
                }
            }
        }

        c->outFound = 0;
        return 0;
    }