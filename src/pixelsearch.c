/**
 * File:     pixelsearch.c
 * License:  MIT License
 * Author:   Bence Markiel (bceenaeiklmr)
 * Github:   https://github.com/bceenaeiklmr/GpGFX
 */

typedef struct {
    const unsigned char* pScan0; // +0
    int stride;                  // +8
    unsigned int targetClr;      // +12
    int variation;               // +16
    int subX1;                   // +20
    int subY1;                   // +24
    int subX2;                   // +28
    int subY2;                   // +32
    int pad;                     // +36
    volatile int* pSharedStop;   // +40
    int outFound;                // +48
    int outX;                    // +52
    int outY;                    // +56
    unsigned int outClr;         // +60
} SearchCtx;

typedef struct {
    int dx;
    int dy;
    unsigned int color;
    int pad;
} PatternPoint;

typedef struct {
    const unsigned char* pScan0; // +0
    int stride;                  // +8
    int imgW;                    // +12
    int imgH;                    // +16
    int subX1;                   // +20
    int subY1;                   // +24
    int subX2;                   // +28
    int subY2;                   // +32
    int variation;               // +36
    int numPoints;               // +40
    int pad;                     // +44
    const PatternPoint* pPoints; // +48
    int outFound;                // +56
    int outX;                    // +60
    int outY;                    // +64
} PatternSearchCtx;

__attribute__((ms_abi))
int RunSearch(SearchCtx* c) {
    if (!c || !c->pScan0) return 0;

    const unsigned char* pScan0 = c->pScan0;
    int stride = c->stride;
    unsigned int targetClr = c->targetClr & 0x00FFFFFF;
    int var = c->variation;
    int x1 = c->subX1, y1 = c->subY1;
    int x2 = c->subX2, y2 = c->subY2;
    volatile int* pStop = c->pSharedStop;

    if (var == 0) {
        for (int y = y1; y <= y2; ++y) {
            if (pStop && *pStop) return 0;
            const unsigned int* row = (const unsigned int*)(pScan0 + y * stride);
            for (int x = x1; x <= x2; ++x) {
                if ((row[x] & 0x00FFFFFF) == targetClr) {
                    c->outFound = 1;
                    c->outX = x;
                    c->outY = y;
                    c->outClr = row[x];
                    if (pStop) *pStop = 1;
                    return 1;
                }
            }
        }
    } else {
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
                    if (pStop) *pStop = 1;
                    return 1;
                }
            }
        }
    }
    c->outFound = 0;
    return 0;
}

__attribute__((ms_abi))
int RunPatternSearch(PatternSearchCtx* c) {
    if (!c || !c->pScan0 || c->numPoints <= 0 || !c->pPoints) return 0;

    const unsigned char* pScan0 = c->pScan0;
    int stride = c->stride;
    int imgW = c->imgW;
    int imgH = c->imgH;
    int subX1 = c->subX1, subY1 = c->subY1;
    int subX2 = c->subX2, subY2 = c->subY2;
    int var = c->variation;
    int numPts = c->numPoints;
    const PatternPoint* pts = c->pPoints;

    unsigned int anchorClr = pts[0].color & 0x00FFFFFF;
    int aR = (anchorClr >> 16) & 0xFF;
    int aG = (anchorClr >> 8) & 0xFF;
    int aB = anchorClr & 0xFF;

    for (int y = subY1; y <= subY2; ++y) {
        const unsigned int* row = (const unsigned int*)(pScan0 + y * stride);
        for (int x = subX1; x <= subX2; ++x) {
            unsigned int px = row[x] & 0x00FFFFFF;

            if (var == 0) {
                if (px != anchorClr) continue;
            } else {
                int pR = (px >> 16) & 0xFF, pG = (px >> 8) & 0xFF, pB = px & 0xFF;
                int dR = pR - aR; if (dR < 0) dR = -dR;
                int dG = pG - aG; if (dG < 0) dG = -dG;
                int dB = pB - aB; if (dB < 0) dB = -dB;
                if (dR > var || dG > var || dB > var) continue;
            }

            // Anchor matched, test remaining points
            int allMatched = 1;
            for (int i = 1; i < numPts; ++i) {
                int ptX = x + pts[i].dx;
                int ptY = y + pts[i].dy;
                if (ptX < 0 || ptX >= imgW || ptY < 0 || ptY >= imgH) {
                    allMatched = 0;
                    break;
                }

                unsigned int secPx = *(const unsigned int*)(pScan0 + ptY * stride + ptX * 4) & 0x00FFFFFF;
                unsigned int targetClr = pts[i].color & 0x00FFFFFF;

                if (var == 0) {
                    if (secPx != targetClr) {
                        allMatched = 0;
                        break;
                    }
                } else {
                    int sR = (secPx >> 16) & 0xFF, sG = (secPx >> 8) & 0xFF, sB = secPx & 0xFF;
                    int tR = (targetClr >> 16) & 0xFF, tG = (targetClr >> 8) & 0xFF, tB = targetClr & 0xFF;
                    int dR = sR - tR; if (dR < 0) dR = -dR;
                    int dG = sG - tG; if (dG < 0) dG = -dG;
                    int dB = sB - tB; if (dB < 0) dB = -dB;
                    if (dR > var || dG > var || dB > var) {
                        allMatched = 0;
                        break;
                    }
                }
            }

            if (allMatched) {
                c->outFound = 1;
                c->outX = x;
                c->outY = y;
                return 1;
            }
        }
    }
    c->outFound = 0;
    return 0;
}
