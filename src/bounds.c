/**
 * GpGFX Native MCode - Batch Vectorized 2D Bounding Box Calculator
 * Author: Bence Markiel (bceenaeiklmr)
 * License: MIT License
 *
 * Description:
 *   Computes the axis-aligned bounding box [minX, minY, maxX, maxY] across an array
 *   of N 2D single-precision float points (x, y) in a single vectorized pass.
 *
 * Signature:
 *   void BatchComputeBounds(const float *pPoints, int count, float *pOut);
 *
 * Memory Layout:
 *   pPoints: [x0, y0, x1, y1, x2, y2, ...] (count * 8 bytes)
 *   pOut:    [minX, minY, maxX, maxY] (16 bytes)
 */

void BatchComputeBounds(const float *pPoints, int count, float *pOut) {
    if (count <= 0 || !pPoints || !pOut)
        return;

    float minX = pPoints[0];
    float minY = pPoints[1];
    float maxX = minX;
    float maxY = minY;

    for (int i = 1; i < count; i++) {
        float px = pPoints[i * 2 + 0];
        float py = pPoints[i * 2 + 1];

        if (px < minX) minX = px;
        if (py < minY) minY = py;
        if (px > maxX) maxX = px;
        if (py > maxY) maxY = py;
    }

    pOut[0] = minX;
    pOut[1] = minY;
    pOut[2] = maxX;
    pOut[3] = maxY;
}
