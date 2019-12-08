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

- (void)computeFitnessesWithCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:fitnessState];
        id<MTLBuffer> buffers[] = {generationABuffer, glyphSizesBuffer, urlBitmapsBuffer, fitnessesPerURLBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, urlCount, 1) threadsPerThreadgroup:MTLSizeMake(32, 32, 1)];
    }
    {
        [computeEncoder setComputePipelineState:sumFitnessesState];
        id<MTLBuffer> buffers[] = {fitnessesPerURLBuffer, fitnessBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, 1, 1) threadsPerThreadgroup:MTLSizeMake(512, 1, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        [blitEncoder synchronizeResource:fitnessBuffer];
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

- (void)reverseGenerationWithCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:reverseGenerationState];
        id<MTLBuffer> buffers[] = {generationABuffer, reverseGenerationBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, glyphCount, 1) threadsPerThreadgroup:MTLSizeMake(32, 32, 1)];
    }
    [computeEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        assert(commandBuffer.error == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback();
        });
    }];
    [commandBuffer commit];
}

- (void)mateWithCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:mateState];
        id<MTLBuffer> buffers[] = {generationABuffer, reverseGenerationBuffer, generationBBuffer, matingInstructionsBuffer, mutationInstructionsBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 5)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, 1, 1) threadsPerThreadgroup:MTLSizeMake(512, 1, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        assert(generationABuffer.length == generationBBuffer.length);
        [blitEncoder copyFromBuffer:generationBBuffer sourceOffset:0 toBuffer:generationABuffer destinationOffset:0 size:generationABuffer.length];
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

- (void)populateMatingInstructionsBuffer
{
    float* fitnessData = fitnessBuffer.contents;
    float sum = 0;
    float best = 0;
    __block float* cumulativeFitnesses = malloc(generationSize * sizeof(float));
    for (uint32_t i = 0; i < generationSize; ++i) {
        best = MAX(best, fitnessData[i]);
        float previousSum = sum;
        cumulativeFitnesses[i] = sum = sum + fitnessData[i];
        assert(sum >= previousSum);
    }
    NSLog(@"Best: %f", best);
    struct MatingInstructions matingInstructions[generationSize];
    for (uint32_t i = 0; i < generationSize; ++i) {
        uint32_t (^pickWeightedIndex)(void) = ^uint32_t(void) {
            float r = (float)arc4random() / (float)UINT32_MAX * sum;
            // FIXME: Do a binary search here instead
            uint32_t j;
            for (j = 0; j < self->generationSize && cumulativeFitnesses[j] <= r; ++j);
            assert(j < self->generationSize);
            return j;
        };
        matingInstructions[i].parent0 = pickWeightedIndex();
        matingInstructions[i].parent1 = pickWeightedIndex();
        uint32_t index0 = arc4random_uniform(glyphCount);
        uint32_t index1 = arc4random_uniform(glyphCount);
        matingInstructions[i].lowerIndex = MIN(index0, index1);
        matingInstructions[i].upperIndex = MAX(index0, index1);
    }
    free(cumulativeFitnesses);
    memcpy(matingInstructionsBuffer.contents, matingInstructions, generationSize * sizeof(struct MatingInstructions));
    [matingInstructionsBuffer didModifyRange:NSMakeRange(0, generationSize * sizeof(struct MatingInstructions))];
}

- (void)populateMutationInstructionsBuffer
{
    for (uint32_t i = 0; i < generationSize; ++i) {
        uint32_t numMutationInstructions = arc4random_uniform(maxMutationInstructions + 1);
        uint32_t mutationInstructions[2 * numMutationInstructions + 1];
        mutationInstructions[0] = numMutationInstructions;
        for (uint32_t j = 0; j < numMutationInstructions; ++j) {
            mutationInstructions[j * 2 + 1] = arc4random_uniform(glyphCount);
            mutationInstructions[j * 2 + 2] = arc4random_uniform(glyphCount);
        }
        size_t byteOffset = (maxMutationInstructions * 2 + 1) * i * sizeof(uint32_t);
        memcpy((char*)mutationInstructionsBuffer.contents + byteOffset, mutationInstructions, sizeof(mutationInstructions));
        [mutationInstructionsBuffer didModifyRange:NSMakeRange(byteOffset, sizeof(mutationInstructions))];
    }
}

- (void)runWithCallback:(void (^)(void))callback
{
    [self computeFitnessesWithCallback:^() {
        [self reverseGenerationWithCallback:^() {
            [self mateWithCallback:^() {
                callback();
            }];
        }];

        // GPU runs the reversing code at the same time the CPU gets ready for mating
        [self populateMatingInstructionsBuffer];
        [self populateMutationInstructionsBuffer];
    }];
}

- (void)runIterations:(unsigned)iteration withCallback:(void (^)(void))callback
{
    if (iteration == 0) {
        callback();
        return;
    }
    [self runWithCallback:^() {
        [self runIterations:iteration - 1 withCallback:callback];
    }];
}

@end
