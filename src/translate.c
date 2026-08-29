/**
 * GpGFX Native MCode - Batch Vectorized 2D Point Translation Kernel
 * Author: Bence Markiel (bceenaeiklmr)
 * License: MIT License
 *
 * Description:
 *   Applies an in-place [x += dx, y += dy] translation across an array of N 2D
 *   single-precision float points (x, y) directly in memory.
 *
 * Signature:
 *   void BatchTranslate(float *pPoints, int count, float dx, float dy);
 *
 * Memory Layout:
 *   pPoints: [x0, y0, x1, y1, x2, y2, ...] (count * 8 bytes)
 */

void BatchTranslate(float *pPoints, int count, float dx, float dy) {
    if (count <= 0 || !pPoints)
        return;

    for (int i = 0; i < count; i++) {
        pPoints[i * 2 + 0] += dx;
        pPoints[i * 2 + 1] += dy;
    }
}
