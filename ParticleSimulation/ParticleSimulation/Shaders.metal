//
//  Shaders.metal
//  ParticleSimulation
//
//  Created by Myles C. Maxfield on 4/4/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

constexpr constant float pointSize = 15;
constexpr constant float scalar = .5;
constexpr constant float repulsion = 0.5;
constexpr constant float tickDuration = 0.0010;
constexpr constant float mass = 1;
constexpr constant float friction = 0.0075;

struct Particle {
    float4 position;
    float4 velocity;
};

kernel void computeShader(device Particle* particles [[ buffer(0) ]], constant uint& count [[ buffer(1) ]], device float* scores [[ buffer(2) ]], constant uint& time [[ buffer(3) ]], uint index [[ thread_position_in_grid ]]) {
    float3 force = float3(0);
    auto position = particles[index].position.xyz;
    auto velocity = particles[index].velocity.xyz;

    float3 averagePosition = float3(0);
    for (uint i = 0; i < count; ++i) {
        if (i == index)
            continue;
        auto otherPosition = particles[i].position.xyz;
        averagePosition += otherPosition;
        auto dist = distance(otherPosition, position);
        auto direction = normalize(otherPosition - position);
        float score = scores[count * index + i];
        force += direction * score * scalar * pow(dist - 0.01, 4);
        force -= direction * repulsion * -log(pow(dist, 0.0625));
    }
    averagePosition /= count;
    force += float3(0, -log(position.yz + float2(1))) * time / 2;
    auto acceleration = force / mass;
    velocity += acceleration * tickDuration;
    velocity *= 1 - friction;
    position += velocity * tickDuration - averagePosition;
    auto newPosition = clamp(position, -0.99, 0.99);
    if (length(velocity) > 300)
        velocity = normalize(velocity) * 10;
    if (newPosition.x != position.x)
        velocity.x *= -1;
    if (newPosition.y != position.y)
        velocity.y *= -1;
    if (newPosition.z != position.z)
        velocity.z *= -1;
    particles[index].velocity = float4(velocity, 0);
    particles[index].position = float4(newPosition, 1);
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
    result.position = float4(vertexIn.position.xy, 0.5, 1);
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

    return float4(1, 0, 0, 0.75 * smoothstep(pointSize / 2, pointSize / 2 - 1, distance(fragmentIn.position.xy, centerScreenSpace.xy)));
}
