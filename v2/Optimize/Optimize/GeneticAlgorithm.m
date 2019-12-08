//
//  GeneticAlgorithm.m
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Metal;

#import "GeneticAlgorithm.h"
#import "GeneticAlgorithmShared.h"

@implementation GeneticAlgorithm {
    GlyphData *glyphData;
    NSArray<NSArray<NSNumber *> *> *seeds;

    uint32_t glyphCount;
    uint32_t glyphBitfieldSize;
    uint32_t urlCount;
    uint32_t generationSize;
    uint32_t maxMutationInstructions;

    id<MTLDevice> device;
    id<MTLCommandQueue> queue;

    id<MTLFunction> fitnessFunction;
    id<MTLFunction> sumFitnessesFunction;
    id<MTLFunction> reverseGenerationFunction;
    id<MTLFunction> mateFunction;
    id<MTLComputePipelineState> fitnessState;
    id<MTLComputePipelineState> sumFitnessesState;
    id<MTLComputePipelineState> reverseGenerationState;
    id<MTLComputePipelineState> mateState;
    id<MTLBuffer> generationABuffer;
    id<MTLBuffer> generationBBuffer;
    id<MTLBuffer> reverseGenerationBuffer;
    id<MTLBuffer> glyphSizesBuffer;
    id<MTLBuffer> urlBitmapsBuffer;
    id<MTLBuffer> fitnessesPerURLBuffer;
    id<MTLBuffer> fitnessBuffer;
    id<MTLBuffer> matingInstructionsBuffer;
    id<MTLBuffer> mutationInstructionsBuffer;

    BOOL validateGeneration;
}

- (instancetype)initWithGlyphData:(GlyphData *)glyphData andSeeds:(NSArray<NSArray<NSNumber *> *> *)seeds
{
    self = [super init];

    if (self) {
        self->glyphData = glyphData;
        self->seeds = seeds;
        
        glyphCount = (uint32_t)glyphData.glyphCount;
        glyphBitfieldSize = (uint32_t)glyphData.glyphBitfieldSize;
        urlCount = (uint32_t)glyphData.urlCount;
        generationSize = (uint32_t)seeds.count;

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
    id<MTLLibrary> library = [device newLibraryWithFile:@"default.metallib" error:&error];
    assert(error == nil);
    MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
    [constantValues setConstantValue:&glyphCount type:MTLDataTypeUInt withName:@"glyphCount"];
    [constantValues setConstantValue:&glyphBitfieldSize type:MTLDataTypeUInt withName:@"glyphBitfieldSize"];
    [constantValues setConstantValue:&urlCount type:MTLDataTypeUInt withName:@"urlCount"];
    [constantValues setConstantValue:&generationSize type:MTLDataTypeUInt withName:@"generationSize"];
    [constantValues setConstantValue:&maxMutationInstructions type:MTLDataTypeUInt withName:@"maxMutationInstructions"];
    fitnessFunction = [library newFunctionWithName:@"fitness" constantValues:constantValues error:&error];
    assert(error == nil);
    sumFitnessesFunction = [library newFunctionWithName:@"sumFitnesses" constantValues:constantValues error:&error];
    assert(error == nil);
    reverseGenerationFunction = [library newFunctionWithName:@"reverseGeneration" constantValues:constantValues error:&error];
    assert(error == nil);
    mateFunction = [library newFunctionWithName:@"mate" constantValues:constantValues error:&error];
    assert(error == nil);
}

- (void)createMetalStates
{
    NSError *error;
    {
        MTLComputePipelineDescriptor *fitnessPiplineDescriptor = [MTLComputePipelineDescriptor new];
        fitnessPiplineDescriptor.computeFunction = fitnessFunction;
        fitnessPiplineDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        fitnessPiplineDescriptor.buffers[1].mutability = MTLMutabilityImmutable;
        fitnessPiplineDescriptor.buffers[2].mutability = MTLMutabilityImmutable;
        fitnessPiplineDescriptor.buffers[3].mutability = MTLMutabilityMutable;
        fitnessState = [device newComputePipelineStateWithDescriptor:fitnessPiplineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }

    {
        MTLComputePipelineDescriptor *sumFitnessesPiplineDescriptor = [MTLComputePipelineDescriptor new];
        sumFitnessesPiplineDescriptor.computeFunction = sumFitnessesFunction;
        sumFitnessesPiplineDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        sumFitnessesPiplineDescriptor.buffers[1].mutability = MTLMutabilityMutable;
        sumFitnessesState = [device newComputePipelineStateWithDescriptor:sumFitnessesPiplineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
    
    {
        MTLComputePipelineDescriptor *reverseGenerationPiplineDescriptor = [MTLComputePipelineDescriptor new];
        reverseGenerationPiplineDescriptor.computeFunction = reverseGenerationFunction;
        reverseGenerationPiplineDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        reverseGenerationPiplineDescriptor.buffers[1].mutability = MTLMutabilityMutable;
        reverseGenerationState = [device newComputePipelineStateWithDescriptor:reverseGenerationPiplineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
    
    {
        MTLComputePipelineDescriptor *matePiplineDescriptor = [MTLComputePipelineDescriptor new];
        matePiplineDescriptor.computeFunction = mateFunction;
        matePiplineDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        matePiplineDescriptor.buffers[1].mutability = MTLMutabilityImmutable;
        matePiplineDescriptor.buffers[2].mutability = MTLMutabilityMutable;
        matePiplineDescriptor.buffers[3].mutability = MTLMutabilityImmutable;
        mateState = [device newComputePipelineStateWithDescriptor:matePiplineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
}

- (void)createBuffers
{
    uint32_t seedsData[generationSize * glyphCount];
    assert(seeds.count == generationSize);
    for (uint32_t i = 0; i < generationSize; ++i) {
        NSArray<NSNumber *> *seed = seeds[i];
        assert(seed.count == glyphCount);
        for (uint32_t j = 0; j < glyphCount; ++j)
            seedsData[glyphCount * i + j] = seed[j].unsignedIntValue;
    }
    generationABuffer = [device newBufferWithBytes:seedsData length:glyphCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    generationBBuffer = [device newBufferWithLength:glyphCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    reverseGenerationBuffer = [device newBufferWithLength:glyphCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    uint32_t glyphSizesData[glyphCount];
    for (uint32_t i = 0; i < glyphCount; ++i)
        glyphSizesData[i] = glyphData.glyphSizes[i].unsignedIntValue;
    glyphSizesBuffer = [device newBufferWithBytes:glyphSizesData length:glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    urlBitmapsBuffer = [device newBufferWithBytes:glyphData.urlBitmaps length:urlCount * glyphBitfieldSize * sizeof(uint8_t) options:MTLResourceStorageModeManaged];

    fitnessesPerURLBuffer = [device newBufferWithLength:generationSize * urlCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    fitnessBuffer = [device newBufferWithLength:generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    matingInstructionsBuffer = [device newBufferWithLength:generationSize * sizeof(struct MatingInstructions) options:MTLResourceStorageModeManaged];

    mutationInstructionsBuffer = [device newBufferWithLength:generationSize * (maxMutationInstructions * 2 + 1) * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
}

@end
