/**
 * File:     bounds.c
 * License:  MIT License
 * Author:   Bence Markiel (bceenaeiklmr)
 * Github:   https://github.com/bceenaeiklmr/GpGFX
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
