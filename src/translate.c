/**
 * File:     translate.c
 * License:  MIT License
 * Author:   Bence Markiel (bceenaeiklmr)
 * Github:   https://github.com/bceenaeiklmr/GpGFX
 */

void BatchTranslate(float *pPoints, int count, float dx, float dy) {
    if (count <= 0 || !pPoints)
        return;

    for (int i = 0; i < count; i++) {
        pPoints[i * 2 + 0] += dx;
        pPoints[i * 2 + 1] += dy;
    }
}
