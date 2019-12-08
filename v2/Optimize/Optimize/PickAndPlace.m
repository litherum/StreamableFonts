//
//  PickAndPlace.m
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Metal;

#import "PickAndPlace.h"
#import "PickAndPlaceShared.h"

@implementation PickAndPlace {
    GlyphData *glyphData;
    NSArray<NSArray<NSNumber *> *> *seeds;

    uint32_t glyphCount;
    uint32_t glyphBitfieldSize;
    uint32_t urlCount;
    uint32_t generationSize;

    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    
    id<MTLFunction> possibleFitnessesFunction;
    id<MTLFunction> sumPossibleFitnessesFunction;
    id<MTLFunction> selectBestPossibilityFunction;
    id<MTLFunction> performRotationFunction;
    id<MTLComputePipelineState> possibleFitnessesState;
    id<MTLComputePipelineState> sumPossibleFitnessesState;
    id<MTLComputePipelineState> selectBestPossibilityState;
    id<MTLComputePipelineState> performRotationState;
    id<MTLBuffer> generationABuffer;
    id<MTLBuffer> generationBBuffer;
    id<MTLBuffer> glyphSizesBuffer;
    id<MTLBuffer> urlBitmapsBuffer;
    id<MTLBuffer> possibleFitnessesPerURLBuffer;
    id<MTLBuffer> possibleFitnessesBuffer;
    id<MTLBuffer> bestBuffer;
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
    NSBundle *bundle = [NSBundle bundleForClass:[PickAndPlace class]];
    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle error:&error];
    assert(error == nil);
    MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
    [constantValues setConstantValue:&glyphCount type:MTLDataTypeUInt withName:@"glyphCount"];
    [constantValues setConstantValue:&glyphBitfieldSize type:MTLDataTypeUInt withName:@"glyphBitfieldSize"];
    [constantValues setConstantValue:&urlCount type:MTLDataTypeUInt withName:@"urlCount"];
    [constantValues setConstantValue:&generationSize type:MTLDataTypeUInt withName:@"generationSize"];
    possibleFitnessesFunction = [library newFunctionWithName:@"possibleFitnesses" constantValues:constantValues error:&error];
    assert(error == nil);
    sumPossibleFitnessesFunction = [library newFunctionWithName:@"sumPossibleFitnesses" constantValues:constantValues error:&error];
    assert(error == nil);
    selectBestPossibilityFunction = [library newFunctionWithName:@"selectBestPossibility" constantValues:constantValues error:&error];
    assert(error == nil);
    performRotationFunction = [library newFunctionWithName:@"performRotation" constantValues:constantValues error:&error];
    assert(error == nil);
}

- (void)createMetalStates
{
    NSError *error;
    {
        MTLComputePipelineDescriptor *possibleFitnessesDescriptor = [MTLComputePipelineDescriptor new];
        possibleFitnessesDescriptor.computeFunction = possibleFitnessesFunction;
        possibleFitnessesDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        possibleFitnessesDescriptor.buffers[1].mutability = MTLMutabilityImmutable;
        possibleFitnessesDescriptor.buffers[2].mutability = MTLMutabilityImmutable;
        possibleFitnessesDescriptor.buffers[3].mutability = MTLMutabilityMutable;
        possibleFitnessesDescriptor.buffers[4].mutability = MTLMutabilityImmutable;
        possibleFitnessesState = [device newComputePipelineStateWithDescriptor:possibleFitnessesDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }

    {
        MTLComputePipelineDescriptor *sumPossibleFitnessesDescriptor = [MTLComputePipelineDescriptor new];
        sumPossibleFitnessesDescriptor.computeFunction = sumPossibleFitnessesFunction;
        sumPossibleFitnessesDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        sumPossibleFitnessesDescriptor.buffers[1].mutability = MTLMutabilityMutable;
        sumPossibleFitnessesState = [device newComputePipelineStateWithDescriptor:sumPossibleFitnessesDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
    
    {
        MTLComputePipelineDescriptor *selectBestPossibilityDescriptor = [MTLComputePipelineDescriptor new];
        selectBestPossibilityDescriptor.computeFunction = selectBestPossibilityFunction;
        selectBestPossibilityDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        selectBestPossibilityDescriptor.buffers[1].mutability = MTLMutabilityMutable;
        selectBestPossibilityState = [device newComputePipelineStateWithDescriptor:selectBestPossibilityDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
    
    {
        MTLComputePipelineDescriptor *performRotationDescriptor = [MTLComputePipelineDescriptor new];
        performRotationDescriptor.computeFunction = performRotationFunction;
        performRotationDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        performRotationDescriptor.buffers[1].mutability = MTLMutabilityImmutable;
        performRotationDescriptor.buffers[2].mutability = MTLMutabilityMutable;
        performRotationDescriptor.buffers[3].mutability = MTLMutabilityImmutable;
        performRotationState = [device newComputePipelineStateWithDescriptor:performRotationDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
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
    generationABuffer = [device newBufferWithBytes:seedsData length:generationSize * glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    generationBBuffer = [device newBufferWithLength:generationSize * glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    
    uint32_t glyphSizesData[glyphCount];
    for (uint32_t i = 0; i < glyphCount; ++i)
        glyphSizesData[i] = glyphData.glyphSizes[i].unsignedIntValue;
    glyphSizesBuffer = [device newBufferWithBytes:glyphSizesData length:glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    urlBitmapsBuffer = [device newBufferWithBytes:glyphData.urlBitmaps length:urlCount * glyphBitfieldSize * sizeof(uint8_t) options:MTLResourceStorageModeManaged];

    possibleFitnessesPerURLBuffer = [device newBufferWithLength:glyphCount * urlCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    possibleFitnessesBuffer = [device newBufferWithLength:glyphCount * generationSize * sizeof(float) options:MTLResourceStorageModeManaged];

    bestBuffer = [device newBufferWithLength:generationSize * sizeof(struct Best) options:MTLResourceStorageModeManaged];
}

- (void)runWithGlyphIndex:(uint32_t)glyphIndex andCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:possibleFitnessesState];
        id<MTLBuffer> buffers[] = {generationABuffer, glyphSizesBuffer, urlBitmapsBuffer, possibleFitnessesPerURLBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
        [computeEncoder setBytes:&glyphIndex length:sizeof(uint32_t) atIndex:4];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, urlCount, glyphCount) threadsPerThreadgroup:MTLSizeMake(2, 2, 2)];
    }
    {
        [computeEncoder setComputePipelineState:sumPossibleFitnessesState];
        id<MTLBuffer> buffers[] = {generationABuffer, possibleFitnessesBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, glyphCount, 1) threadsPerThreadgroup:MTLSizeMake(4, 4, 1)];
    }
    {
        [computeEncoder setComputePipelineState:selectBestPossibilityState];
        id<MTLBuffer> buffers[] = {possibleFitnessesBuffer, bestBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, 1, 1) threadsPerThreadgroup:MTLSizeMake(16, 1, 1)];
    }
    {
        [computeEncoder setComputePipelineState:performRotationState];
        id<MTLBuffer> buffers[] = {generationABuffer, bestBuffer, generationBBuffer};
        NSUInteger offsets[] = {0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 3)];
        [computeEncoder setBytes:&glyphIndex length:sizeof(uint32_t) atIndex:3];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, 1, 1) threadsPerThreadgroup:MTLSizeMake(16, 1, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        assert(generationABuffer.length == generationBBuffer.length);
        [blitEncoder copyFromBuffer:generationBBuffer sourceOffset:0 toBuffer:generationABuffer destinationOffset:0 size:generationABuffer.length];
        [blitEncoder synchronizeResource:bestBuffer];
    }
    [blitEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        assert(commandBuffer.error == nil);
        struct Best* bests = self->bestBuffer.contents;
        for (uint32_t i = 0; i < self->generationSize; ++i)
            NSLog(@"Best score for index %" PRIu32 ": %f", i, bests[i].bestValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback();
        });
    }];
    [commandBuffer commit];
}

- (void)runWithGlyphIndices:(NSArray<NSNumber *> *)indices offset:(NSUInteger)offset callback:(void (^)(void))callback
{
    if (offset >= indices.count) {
        callback();
        return;
    }
    [self runWithGlyphIndex:(uint32_t)indices[offset].unsignedIntValue andCallback:^() {
        [self runWithGlyphIndices:indices offset:offset + 1 callback:callback];
    }];
}

- (void)runWithGlyphIndices:(NSArray<NSNumber *> *)indices andCallback:(void (^)(void))callback
{
    [self runWithGlyphIndices:indices offset:0 callback:callback];
}

@end
