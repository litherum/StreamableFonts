//
//  Shaders.metal
//  ParticleSimulation
//
//  Created by Myles C. Maxfield on 4/4/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

constexpr constant float pointSize = 20;
constexpr constant float scalar = .25;
constexpr constant float repulsion = 0.006;
constexpr constant float tickDuration = 0.01;
constexpr constant float mass = 1;
constexpr constant float friction = 0.2;

struct Particle {
    float4 position;
    float4 velocity;
};

kernel void computeShader(device Particle* particles [[ buffer(0) ]], constant uint& count [[ buffer(1) ]], device float* scores [[ buffer(2) ]], uint index [[ thread_position_in_grid ]]) {
    float4 force = float4(0);
    auto particlePosition = particles[index].position;
    auto velocity = particles[index].velocity;
    for (uint i = 0; i < count; ++i) {
        if (i == index)
            continue;
        auto otherParticlePosition = particles[i].position;
        auto dist = distance(otherParticlePosition, particlePosition);
        auto direction = normalize(otherParticlePosition - particlePosition);
        float score = scores[count * index + i];
        force += direction * score * scalar;
        force -= direction * repulsion / (dist * dist);
    }
    auto acceleration = force / mass;
    velocity += acceleration * tickDuration;
    velocity *= 1 - friction;
    particlePosition += velocity * tickDuration;
    auto newParticlePosition = clamp(particlePosition, -0.99, 0.99);
    if (newParticlePosition.x != particlePosition.x)
        velocity.x *= -1;
    if (newParticlePosition.y != particlePosition.y)
        velocity.y *= -1;
    if (newParticlePosition.z != particlePosition.z)
        velocity.z *= -1;
    particles[index].velocity = velocity;
    particles[index].position = newParticlePosition;
}

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float pointSize [[ point_size ]];
    float2 center [[ id(0) ]];
};

vertex VertexOut vertexShader(VertexIn vertexIn [[ stage_in ]]) {
    VertexOut result;
    result.position = float4(vertexIn.position.xyz, 1);
    result.pointSize = pointSize;
    result.center = vertexIn.position.xy;
    return result;
}

struct FragmentIn {
    float2 center [[ id(0) ]];
    float4 position [[ position ]];
};

fragment float4 fragmentShader(constant uint2& screenSize [[ buffer(0) ]], FragmentIn fragmentIn [[ stage_in ]]) {
    float centerScreenSpaceX = fragmentIn.center.x * screenSize.x / 2 + screenSize.x / 2;
    float centerScreenSpaceY = -fragmentIn.center.y * screenSize.y / 2 + screenSize.y / 2;
    float2 centerScreenSpace = float2(centerScreenSpaceX, centerScreenSpaceY);

    return float4(1, 0, 0, smoothstep(pointSize / 2, pointSize / 2 - 1, distance(fragmentIn.position.xy, centerScreenSpace.xy)));
}
