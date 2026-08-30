/**
 * File:     colorlut.c
 * License:  MIT License
 * Author:   Bence Markiel (bceenaeiklmr)
 * Github:   https://github.com/bceenaeiklmr/GpGFX
 */

__attribute__((ms_abi))
void ApplyLUT(
    unsigned char* scan0,
    int width,
    int height,
    int stride,
    const unsigned char* lutB,
    const unsigned char* lutG,
    const unsigned char* lutR,
    const unsigned char* lutA
) {
    if (!scan0 || width <= 0 || height <= 0 || !lutB || !lutG || !lutR)
        return;

    if (lutA) {
        // Transform all 4 channels (BGRA)
        for (int y = 0; y < height; ++y) {
            unsigned char* row = scan0 + (y * stride);
            for (int x = 0; x < width; ++x) {
                unsigned char* px = row + (x * 4);
                px[0] = lutB[px[0]];
                px[1] = lutG[px[1]];
                px[2] = lutR[px[2]];
                px[3] = lutA[px[3]];
            }
        }
    } else {
        // Transform RGB channels only, preserving Alpha
        for (int y = 0; y < height; ++y) {
            unsigned char* row = scan0 + (y * stride);
            for (int x = 0; x < width; ++x) {
                unsigned char* px = row + (x * 4);
                px[0] = lutB[px[0]];
                px[1] = lutG[px[1]];
                px[2] = lutR[px[2]];
            }
        }
    }
}
