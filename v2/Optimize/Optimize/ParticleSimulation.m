//
//  ParticleSimulation.m
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Metal;
@import simd;

#import "ParticleSimulation.h"
#import "ParticleSimulationShared.h"

@implementation ParticleSimulation {
    TupleScores *tupleScores;

    uint32_t glyphCount;
    uint32_t generationSize;
    float attractionScalar;
    float attractionExponent;
    float repulsionScalar;
    float repulsionExponent;
    float mass;
    float tickDuration;
    float friction;
    float alignmentForceRate;

    id<MTLDevice> device;
    id<MTLCommandQueue> queue;

    id<MTLFunction> updateParticlesFunction;
    id<MTLComputePipelineState> updateParticlesState;
    id<MTLBuffer> particlesABuffer;
    id<MTLBuffer> particlesBBuffer;
    id<MTLBuffer> tupleScoresBuffer;
}

- (instancetype)initWithTupleScores:(TupleScores *)tupleScores;
{
    self = [super init];

    if (self) {
        self->tupleScores = tupleScores;

        glyphCount = (uint32_t)tupleScores.tupleScores.count;
        generationSize = 100;
        attractionScalar = 50;
        attractionExponent = 2;
        repulsionScalar = 0.05;
        repulsionExponent = -0.3;
        mass = 1;
        tickDuration = 0.0010;
        friction = 0.006;
        alignmentForceRate = 0.0005;

        device = MTLCreateSystemDefaultDevice();
        queue = [device newCommandQueue];

        [self loadShaders];
        [self createMetalStates];
        [self createBuffers];
    }

    return self;
}

- (void)loadShaders
{
    NSError *error = nil;
    NSBundle *bundle = [NSBundle bundleForClass:[ParticleSimulation class]];
    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle error:&error];
    assert(error == nil);
    MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
    [constantValues setConstantValue:&glyphCount type:MTLDataTypeUInt withName:@"glyphCount"];
    [constantValues setConstantValue:&attractionScalar type:MTLDataTypeFloat withName:@"attractionScalar"];
    [constantValues setConstantValue:&attractionExponent type:MTLDataTypeFloat withName:@"attractionExponent"];
    [constantValues setConstantValue:&repulsionScalar type:MTLDataTypeFloat withName:@"repulsionScalar"];
    [constantValues setConstantValue:&repulsionExponent type:MTLDataTypeFloat withName:@"repulsionExponent"];
    [constantValues setConstantValue:&mass type:MTLDataTypeFloat withName:@"mass"];
    [constantValues setConstantValue:&tickDuration type:MTLDataTypeFloat withName:@"tickDuration"];
    [constantValues setConstantValue:&friction type:MTLDataTypeFloat withName:@"friction"];
    updateParticlesFunction = [library newFunctionWithName:@"updateParticles" constantValues:constantValues error:&error];
    assert(error == nil);
}

- (void)createMetalStates
{
    NSError *error;
    {
        MTLComputePipelineDescriptor *updateParticlesPiplineDescriptor = [MTLComputePipelineDescriptor new];
        updateParticlesPiplineDescriptor.computeFunction = updateParticlesFunction;
        updateParticlesPiplineDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        updateParticlesPiplineDescriptor.buffers[1].mutability = MTLMutabilityImmutable;
        updateParticlesPiplineDescriptor.buffers[2].mutability = MTLMutabilityImmutable;
        updateParticlesPiplineDescriptor.buffers[3].mutability = MTLMutabilityMutable;
        updateParticlesState = [device newComputePipelineStateWithDescriptor:updateParticlesPiplineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
}

- (void)createBuffers
{
    struct Particle* particles = malloc(generationSize * glyphCount * sizeof(struct Particle));
    for (uint32_t i = 0; i < generationSize; ++i) {
        for (uint32_t j = 0; j < glyphCount; ++j) {
            particles[i * glyphCount + j].position = simd_make_float3((float)arc4random() / (float)UINT32_MAX, (float)arc4random() / (float)UINT32_MAX, (float)arc4random() / (float)UINT32_MAX);
            particles[i * glyphCount + j].velocity = simd_make_float3((float)arc4random() / (float)UINT32_MAX, (float)arc4random() / (float)UINT32_MAX, (float)arc4random() / (float)UINT32_MAX);
        }
    }
    particlesABuffer = [device newBufferWithBytes:particles length:generationSize * glyphCount * sizeof(struct Particle) options:MTLResourceStorageModeManaged];
    particlesBBuffer = [device newBufferWithLength:generationSize * glyphCount * sizeof(struct Particle) options:MTLResourceStorageModeManaged];
    free(particles);

    float* tupleScoresData = malloc(glyphCount * glyphCount * sizeof(float));
    assert(tupleScores.tupleScores.count == glyphCount);
    for (uint32_t i = 0; i < glyphCount; ++i) {
        assert(tupleScores.tupleScores[i].count == glyphCount);
        for (uint32_t j = 0; j < glyphCount; ++j) {
            tupleScoresData[glyphCount * i + j] = tupleScores.tupleScores[i][j].unsignedIntValue;
        }
    }
    tupleScoresBuffer = [device newBufferWithBytes:tupleScoresData length:glyphCount * glyphCount * sizeof(float) options:MTLResourceStorageModeManaged];
    free(tupleScoresData);
}

- (void)runWithAlignmentForceScalar:(float)alignmentForceScalar andCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:updateParticlesState];
        id<MTLBuffer> buffers[] = {particlesABuffer, tupleScoresBuffer, particlesBBuffer};
        NSUInteger offsets[] = {0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 3)];
        [computeEncoder setBytes:&alignmentForceScalar length:sizeof(alignmentForceScalar) atIndex:3];
        [computeEncoder dispatchThreads:MTLSizeMake(glyphCount, generationSize, 1) threadsPerThreadgroup:MTLSizeMake(32, 32, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        assert(particlesABuffer.length == particlesBBuffer.length);
        [blitEncoder copyFromBuffer:particlesBBuffer sourceOffset:0 toBuffer:particlesABuffer destinationOffset:0 size:particlesABuffer.length];
    }
    [blitEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        assert(commandBuffer.error == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback();
        });
    }];
    [commandBuffer commit];
}

- (void)runIterations:(unsigned)iterations withAlignmentForceScalar:(float)alignmentForceScalar andCallback:(void (^)(void))callback
{
    if (iterations == 0) {
        callback();
        return;
    }
    [self runWithAlignmentForceScalar:alignmentForceScalar andCallback:^() {
        [self runIterations:iterations - 1 withAlignmentForceScalar:alignmentForceScalar + self->alignmentForceRate andCallback:callback];
    }];
}

- (void)runIterations:(unsigned)iterations withCallback:(void (^)(void))callback
{
    [self runIterations:iterations withAlignmentForceScalar:0 andCallback:callback];
}

@end
