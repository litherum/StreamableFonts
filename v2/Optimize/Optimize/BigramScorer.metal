//
//  BigramScorer.metal
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#include <metal_stdlib>
#include "SharedShaders.h"

using namespace metal;

constant uint32_t glyphCount [[function_constant(1)]];
constant uint32_t urlCount [[function_constant(2)]];

inline float singleScore(uint both, uint neither, uint just0, uint just1) {
    uint contains0 = both + just0;
    uint doesntContain0 = neither + just1;
    if (contains0 == 0 || doesntContain0 == 0)
        return 0;
    return (static_cast<float>(both) / static_cast<float>(contains0)) * (static_cast<float>(neither) / static_cast<float>(doesntContain0));
}

kernel void computeBigramScores(device uint8_t* urlBitmaps [[buffer(0)]], device float* output [[buffer(1)]], uint2 tid [[thread_position_in_grid]]) {
    uint glyph0 = tid.x;
    uint glyph1 = tid.y;
    uint both = 0;
    uint neither = 0;
    uint just0 = 0;
    uint just1 = 0;
    for (uint32_t i = 0; i < urlCount; ++i) {
        bool contains0 = glyphIsNecessary(urlBitmaps, i, glyph0);
        bool contains1 = glyphIsNecessary(urlBitmaps, i, glyph1);
        if (contains0 && contains1)
            ++both;
        else if (contains0 && !contains1)
            ++just0;
        else if (!contains0 && contains1)
            ++just1;
        else
            ++neither;
    }
    output[glyphCount * glyph0 + glyph1] = singleScore(both, neither, just0, just1);
}
