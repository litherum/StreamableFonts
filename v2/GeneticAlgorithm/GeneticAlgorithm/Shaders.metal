#include <metal_stdlib>

#include "SharedTypes.h"

using namespace metal;

constant uint32_t glyphCount [[function_constant(0)]];
constant uint32_t glyphBitfieldSize [[function_constant(1)]];
constant uint32_t urlCount [[function_constant(2)]];
constant uint32_t generationSize [[function_constant(3)]];
constant uint32_t maxMutationInstructions [[function_constant(4)]];

constant constexpr uint32_t threshold = 8 * 170;
constant constexpr uint32_t unconditionalDownloadSize = 282828;
constant constexpr uint32_t sentinel = 0xFFFFFFFF;

inline bool glyphIsNecessary(device uint32_t* urlData, uint urlIndex, uint32_t glyph) {
    return urlData[glyphBitfieldSize * urlIndex + glyph / 8] & (1 << (glyph % 8));
}

inline float singleScore(uint both, uint neither, uint just0, uint just1) {
    uint contains0 = both + just0;
    uint doesntContain0 = neither + just1;
    if (contains0 == 0 || doesntContain0 == 0)
        return 0;
    return (static_cast<float>(both) / static_cast<float>(contains0)) * (static_cast<float>(neither) / static_cast<float>(doesntContain0));
}

kernel void bigramScore(device uint32_t* urlData [[buffer(0)]], device float* output [[buffer(1)]], uint2 tid [[thread_position_in_grid]]) {
    uint glyph0 = tid.x;
    uint glyph1 = tid.y;
    uint both = 0;
    uint neither = 0;
    uint just0 = 0;
    uint just1 = 0;
    for (uint32_t i = 0; i < urlCount; ++i) {
        bool contains0 = glyphIsNecessary(urlData, i, glyph0);
        bool contains1 = glyphIsNecessary(urlData, i, glyph1);
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

// if the order is [7, 13, 52] that means that the first glyph in the sequence is glyphID 7, the second glyph in the sequence is glyphID 13, etc.
kernel void fitness(device uint32_t* generation [[buffer(0)]], device uint32_t* glyphSizes [[buffer(1)]], device uint32_t* urlData [[buffer(2)]], device uint32_t* output [[buffer(3)]], uint2 tid [[thread_position_in_grid]]) {
    uint generationIndex = tid.x;
    uint urlIndex = tid.y;
    uint32_t result = unconditionalDownloadSize + threshold;
    uint32_t unnecessarySize = 0;
    bool state = false;
    for (uint32_t i = 0; i < glyphCount; ++i) {
        uint32_t glyph = generation[glyphCount * generationIndex + i];
        uint32_t size = glyphSizes[glyph];
        bool glyphIsNecessary = ::glyphIsNecessary(urlData, urlIndex, glyph);
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

kernel void reverseGeneration(device uint32_t* generation [[buffer(0)]], device uint32_t* reverseGeneration [[buffer(1)]], uint2 tid [[thread_position_in_grid]]) {
    uint generationIndex = tid.x;
    uint glyphIndex = tid.y;
    device uint32_t* order = generation + glyphCount * generationIndex;
    device uint32_t* reverseOrder = reverseGeneration + glyphCount * generationIndex;
    reverseOrder[order[glyphIndex]] = glyphIndex;
}

kernel void mate(device uint32_t* generation [[buffer(0)]], device uint32_t* reverseGeneration [[buffer(1)]], device uint32_t* newGeneration [[buffer(2)]], device MatingInstructions* matingInstructions [[buffer(3)]], uint tid [[thread_position_in_grid]]) {
    MatingInstructions instructions = matingInstructions[tid];
    device uint32_t* parent0 = generation + glyphCount * instructions.parent0;
    device uint32_t* parent1 = generation + glyphCount * instructions.parent1;
    device uint32_t* reverseParent0 = reverseGeneration + glyphCount * instructions.parent0;
    device uint32_t* reverseParent1 = reverseGeneration + glyphCount * instructions.parent1;
    device uint32_t* child = newGeneration + glyphCount * tid;

    for (uint32_t i = 0; i < instructions.lowerIndex; ++i) {
        child[i] = sentinel;
    }
    for (uint32_t i = instructions.lowerIndex; i < instructions.upperIndex; ++i) {
        child[i] = parent0[i];
    }
    for (uint32_t i = instructions.upperIndex; i < glyphCount; ++i) {
        child[i] = sentinel;
    }

    for (uint32_t i = instructions.lowerIndex; i < instructions.upperIndex; ++i) {
        uint32_t index = i;
        uint32_t item = parent1[i];
        uint32_t position = reverseParent0[item];
        if (position < instructions.lowerIndex || position >= instructions.upperIndex) {
            while (index >= instructions.lowerIndex && index < instructions.upperIndex) {
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
}

// FIXME: It should be possible to integrate this into mate()
kernel void mutate(device uint32_t* generation [[buffer(0)]], device uint32_t* instructions [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
    device uint32_t* order = generation + glyphCount * tid;
    instructions = instructions + (maxMutationInstructions * 2 + 1) * tid;
    uint32_t instructionCount = instructions[0];
    for (uint32_t i = 0; i < instructionCount; ++i) {
        uint32_t index0 = instructions[i * 2 + 1];
        uint32_t index1 = instructions[i * 2 + 2];
        uint32_t temp = order[index0];
        order[index0] = order[index1];
        order[index1] = temp;
    }
}
