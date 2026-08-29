/**
 * GpGFX ColorLUT Native x64 Kernel
 * License: MIT License
 *
 * Description:
 *   Ultra-fast 256-entry Channel Lookup Table (LUT) transformation kernel
 *   operating directly across 32bpp BGRA GDI+ Bitmap unmanaged memory (Scan0).
 *
 * Parameters:
 *   scan0  - Pointer to the first scanline byte of the bitmap
 *   width  - Width of the bitmap in pixels
 *   height - Height of the bitmap in scanlines
 *   stride - Byte stride per scanline (pitch)
 *   lutB   - 256-byte lookup table for Blue channel (byte 0)
 *   lutG   - 256-byte lookup table for Green channel (byte 1)
 *   lutR   - 256-byte lookup table for Red channel (byte 2)
 *   lutA   - Optional 256-byte lookup table for Alpha channel (byte 3). Pass NULL to preserve alpha.
 *
 * Pixel Format (32bpp ARGB in GDI+ memory):
 *   [Byte 0: Blue, Byte 1: Green, Byte 2: Red, Byte 3: Alpha]
 *
 * Compilation (GCC / MinGW):
 *   gcc -O3 -c -fno-asynchronous-unwind-tables colorlut.c -o colorlut.o
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
