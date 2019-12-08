//
//  GeneticAlgorithm.metal
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#include <metal_stdlib>
#include "SharedShaders.h"
#include "GeneticAlgorithmShared.h"

using namespace metal;

constant uint32_t glyphCount [[function_constant(1)]];
constant uint32_t urlCount [[function_constant(2)]];
constant uint32_t generationSize [[function_constant(3)]];
constant uint32_t maxMutationInstructions [[function_constant(4)]];

constant constexpr uint32_t threshold = 8 * 170;
constant constexpr uint32_t unconditionalDownloadSize = 282828;
constant constexpr uint32_t sentinel = 0xFFFFFFFF;

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
    output[urlCount * generationIndex + urlIndex] = result;
}

kernel void sumFitnesses(device uint32_t* fitnesses [[buffer(0)]], device float* output [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
    uint generationIndex = tid;

    float result = 0;
    for (uint32_t i = 0; i < urlCount; ++i)
        result += static_cast<float>(fitnesses[urlCount * generationIndex + i]) / static_cast<float>(fontSize);

    output[generationIndex] = result;
}

kernel void reverseGeneration(device uint32_t* generation [[buffer(0)]], device uint32_t* reverseGeneration [[buffer(1)]], uint2 tid [[thread_position_in_grid]]) {
    uint generationIndex = tid.x;
    uint glyphIndex = tid.y;
    device uint32_t* order = generation + glyphCount * generationIndex;
    device uint32_t* reverseOrder = reverseGeneration + glyphCount * generationIndex;
    reverseOrder[order[glyphIndex]] = glyphIndex;
}

kernel void mate(device uint32_t* generation [[buffer(0)]], device uint32_t* reverseGeneration [[buffer(1)]], device uint32_t* newGeneration [[buffer(2)]], device MatingInstructions* matingInstructions [[buffer(3)]], device uint32_t* mutationInstructions [[buffer(4)]], uint tid [[thread_position_in_grid]]) {
    MatingInstructions myMatingInstructions = matingInstructions[tid];
    device uint32_t* parent0 = generation + glyphCount * myMatingInstructions.parent0;
    device uint32_t* parent1 = generation + glyphCount * myMatingInstructions.parent1;
    device uint32_t* reverseParent0 = reverseGeneration + glyphCount * myMatingInstructions.parent0;
    device uint32_t* reverseParent1 = reverseGeneration + glyphCount * myMatingInstructions.parent1;
    device uint32_t* child = newGeneration + glyphCount * tid;

    for (uint32_t i = 0; i < myMatingInstructions.lowerIndex; ++i) {
        child[i] = sentinel;
    }
    for (uint32_t i = myMatingInstructions.lowerIndex; i < myMatingInstructions.upperIndex; ++i) {
        child[i] = parent0[i];
    }
    for (uint32_t i = myMatingInstructions.upperIndex; i < glyphCount; ++i) {
        child[i] = sentinel;
    }

    for (uint32_t i = myMatingInstructions.lowerIndex; i < myMatingInstructions.upperIndex; ++i) {
        uint32_t index = i;
        uint32_t item = parent1[i];
        uint32_t position = reverseParent0[item];
        if (position < myMatingInstructions.lowerIndex || position >= myMatingInstructions.upperIndex) {
            while (index >= myMatingInstructions.lowerIndex && index < myMatingInstructions.upperIndex) {
                item = parent0[index];
                index = reverseParent1[item];
            }
            child[index] = parent1[i];
        }
    }

    for (uint32_t i = 0; i < glyphCount; ++i) {
        if (child[i] == sentinel)
            child[i] = parent1[i];
    }
    
    mutationInstructions = mutationInstructions + (maxMutationInstructions * 2 + 1) * tid;
    uint32_t instructionCount = mutationInstructions[0];
    for (uint32_t i = 0; i < instructionCount; ++i) {
        uint32_t index0 = mutationInstructions[i * 2 + 1];
        uint32_t index1 = mutationInstructions[i * 2 + 2];
        uint32_t temp = child[index0];
        child[index0] = child[index1];
        child[index1] = temp;
    }
}
