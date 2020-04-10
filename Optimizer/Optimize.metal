//
//  Optimize.metal
//  Optimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

constant uint32_t glyphBitfieldSize [[function_constant(0)]];
constant uint32_t glyphCount [[function_constant(1)]];
constant uint32_t urlCount [[function_constant(2)]];
constant uint32_t threshold [[function_constant(3)]];
constant uint32_t unconditionalDownloadSize [[function_constant(4)]];
constant uint32_t fontSize [[function_constant(5)]];

static inline bool glyphIsNecessary(device uint8_t* urlBitmaps, uint urlIndex, uint32_t glyph) {
    return urlBitmaps[glyphBitfieldSize * urlIndex + glyph / 8] & (1 << (glyph % 8));
}

kernel void fitness(device uint32_t* generation [[buffer(0)]], device uint32_t* glyphSizes [[buffer(1)]], device uint8_t* urlBitmaps [[buffer(2)]], device uint32_t* output [[buffer(3)]], uint2 tid [[thread_position_in_grid]]) {
    uint generationIndex = tid.x;
    uint urlIndex = tid.y;
    uint32_t result = unconditionalDownloadSize + threshold;
    uint32_t unnecessarySize = 0;
    bool state = false;
    for (uint32_t i = 0; i < glyphCount; ++i) {
        uint32_t glyph = generation[glyphCount * generationIndex + i];
        uint32_t size = glyphSizes[glyph];
        bool glyphIsNecessary = ::glyphIsNecessary(urlBitmaps, urlIndex, glyph);
        if (glyphIsNecessary) {
            result += size;
            if (!state) {
                result += min(unnecessarySize, threshold);
                unnecessarySize = 0;
            }
        } else
            unnecessarySize += size;
        state = glyphIsNecessary;
    }
    output[urlCount * generationIndex + urlIndex] = fontSize - result;
}

kernel void sumFitnesses(device uint32_t* fitnesses [[buffer(0)]], device float* output [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
    uint generationIndex = tid;

    float result = 0;
    for (uint32_t i = 0; i < urlCount; ++i)
        result += static_cast<float>(fitnesses[urlCount * generationIndex + i]) / static_cast<float>(fontSize);

    output[generationIndex] = result / static_cast<float>(urlCount);
}

static inline void swap(device uint32_t* order, uint32_t index0, uint32_t index1) {
    uint32_t store = order[index0];
    order[index0] = order[index1];
    order[index1] = store;
}

kernel void swapGlyphs(device uint32_t* generation [[buffer(0)]], const device uint32_t* indices [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
    uint generationIndex = tid;
    device uint32_t* order = generation + glyphCount * generationIndex;
    uint32_t index0 = indices[2 * generationIndex + 0];
    uint32_t index1 = indices[2 * generationIndex + 1];
    swap(order, index0, index1);
}

kernel void anneal(device uint32_t* generation [[buffer(0)]], const device uint32_t* indices [[buffer(1)]], device float* beforeFitnesses [[buffer(2)]], device float* afterFitnesses [[buffer(3)]], uint tid [[thread_position_in_grid]]) {
    uint generationIndex = tid;
    device uint32_t* order = generation + glyphCount * generationIndex;
    uint32_t index0 = indices[2 * generationIndex + 0];
    uint32_t index1 = indices[2 * generationIndex + 1];
    float beforeFitness = beforeFitnesses[generationIndex];
    float afterFitness = afterFitnesses[generationIndex];

    if (afterFitness < beforeFitness) {
        // The neighbor is worse than the current state.
        // Go back to the current state.
        // Luckily, we can just swap the glyphs again to get back to where we were before.
        swap(order, index0, index1);
        afterFitnesses[generationIndex] = beforeFitness;
    }
}
