//
//  ParticleSimulation.metal
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#include <metal_stdlib>
#include "ParticleSimulationShared.h"

using namespace metal;

constant uint32_t glyphCount [[function_constant(0)]];
constant float attractionScalar [[function_constant(1)]];
constant float attractionExponent [[function_constant(2)]];
constant float repulsionScalar [[function_constant(3)]];
constant float repulsionExponent [[function_constant(4)]];
constant float mass [[function_constant(5)]];
constant float tickDuration [[function_constant(6)]];
constant float friction [[function_constant(7)]];

inline float attractionFunction(float score, float distance) {
    return score * attractionScalar * pow(distance, attractionExponent);
}

inline float repulsionFunction(float distance) {
    return repulsionScalar * pow(distance, repulsionExponent);
}

kernel void updateParticles(device Particle* particles [[buffer(0)]], device float* tupleScores [[buffer(1)]], device Particle* output [[buffer(2)]], constant float& alignmentForceScalar [[buffer(3)]], uint2 tid [[thread_position_in_grid]]) {
    uint particleIndex = tid.x;
    uint generationIndex = tid.y;

    float3 force = float3(0);
    float3 position = particles[glyphCount * generationIndex + particleIndex].position;
    float3 velocity = particles[glyphCount * generationIndex + particleIndex].velocity;

    for (uint i = 0; i < glyphCount; ++i) {
        if (i == particleIndex)
            continue;
        float3 otherPosition = particles[i].position;
        float distance = metal::distance(otherPosition, position);
        float3 direction = normalize(otherPosition - position);
        float score = tupleScores[glyphCount * particleIndex + i];
        force += direction * attractionFunction(score, distance);
        force -= direction * repulsionFunction(distance);
    }
    force += float3(0, -position.yz) * alignmentForceScalar;
    
    float3 acceleration = force / mass;
    velocity += acceleration * tickDuration;
    velocity *= 1 - friction;
    position += velocity * tickDuration;
    
    output[glyphCount * generationIndex + particleIndex].velocity = velocity;
    output[glyphCount * generationIndex + particleIndex].position = position;
}
