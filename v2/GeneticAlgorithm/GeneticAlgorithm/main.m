//
//  main.m
//  GeneticAlgorithm
//
//  Created by Myles C. Maxfield on 11/20/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

@import Foundation;
@import Metal;

#import "SharedTypes.h"
#import <assert.h>
#import <math.h>

@interface Runner : NSObject
@end

@implementation Runner {
    NSArray<NSDictionary<NSString *, id> *> *urlData;
    NSArray<NSNumber *> *glyphSizes;

    uint32_t glyphCount;
    uint32_t glyphBitfieldSize;
    uint32_t urlCount;
    uint32_t generationSize;
    uint32_t maxMutationInstructions;
    
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    id<MTLFunction> fitnessFunction;
    id<MTLFunction> reverseGenerationFunction;
    id<MTLFunction> mateFunction;
    id<MTLFunction> mutateFunction;
    id<MTLBuffer> generationABuffer;
    id<MTLBuffer> generationBBuffer;
    id<MTLBuffer> reverseGenerationBuffer;
    id<MTLBuffer> glyphSizesBuffer;
    id<MTLBuffer> urlDataBuffer;
    id<MTLBuffer> fitnessBuffer;
    id<MTLBuffer> matingInstructionsBuffer;
    id<MTLBuffer> mutationInstructionsBuffer;
    id<MTLComputePipelineState> fitnessState;
    id<MTLComputePipelineState> reverseGenerationState;
    id<MTLComputePipelineState> mateState;
    id<MTLComputePipelineState> mutateState;
}

- (instancetype)init
{
    if (self) {
        [self loadData];

        glyphCount = (uint32_t)glyphSizes.count;
        glyphBitfieldSize = (glyphCount + 7) / 8;
        urlCount = MIN(1000, (uint32_t)urlData.count);
        generationSize = 120;
        maxMutationInstructions = 80 /*(uint32_t)sqrt(glyphCount)*/;

        device = MTLCreateSystemDefaultDevice();
        queue = [device newCommandQueue];

        [self loadShaders];
        [self createBuffers];
        [self createMetalStates];
    }
    return self;
}

- (void)loadData
{
    NSData *urlDataContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/output_glyphs.json"];
    assert(urlDataContents != nil);
    NSError *error = nil;
    urlData = [NSJSONSerialization JSONObjectWithData:urlDataContents options:0 error:&error];
    assert(error == nil);
    assert(urlData != nil);

    NSData *glyphSizesContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/output_glyph_sizes.json"];
    assert(glyphSizesContents != nil);
    glyphSizes = [NSJSONSerialization JSONObjectWithData:glyphSizesContents options:0 error:&error];
    assert(error == nil);
    assert(glyphSizes != nil);
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
    reverseGenerationFunction = [library newFunctionWithName:@"reverseGeneration" constantValues:constantValues error:&error];
    assert(error == nil);
    mateFunction = [library newFunctionWithName:@"mate" constantValues:constantValues error:&error];
    assert(error == nil);
    mutateFunction = [library newFunctionWithName:@"mutate" constantValues:constantValues error:&error];
    assert(error == nil);
}

- (void)createBuffers
{
    uint32_t initialGenerationData[glyphCount * generationSize];
    for (uint32_t i = 0; i < generationSize; ++i) {
        uint32_t* orderData = initialGenerationData + i * glyphCount;
        NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphCount];
        for (uint32_t j = 0; j < glyphCount; ++j)
            [order addObject:[NSNumber numberWithUnsignedInt:j]];
        for (uint32_t j = 0; j < glyphCount; ++j) {
            assert(order.count == glyphCount - j);
            uint32_t index = arc4random_uniform(glyphCount - j);
            orderData[j] = order[index].unsignedIntValue;
            [order removeObjectAtIndex:index];
        }
    }
    generationABuffer = [device newBufferWithBytes:initialGenerationData length:glyphCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    generationBBuffer = [device newBufferWithLength:glyphCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    reverseGenerationBuffer = [device newBufferWithLength:glyphCount * generationSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    uint32_t glyphSizesData[glyphCount];
    for (uint32_t i = 0; i < glyphCount; ++i)
        glyphSizesData[i] = glyphSizes[i].unsignedIntValue;
    glyphSizesBuffer = [device newBufferWithBytes:glyphSizesData length:glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    uint32_t* rawUrlData = malloc(urlCount * glyphBitfieldSize * sizeof(uint32_t));
    for (size_t i = 0; i < urlCount * glyphBitfieldSize; ++i)
        rawUrlData[i] = 0;
    for (NSUInteger i = 0; i < urlCount; ++i) {
        uint32_t* bitfield = rawUrlData + glyphBitfieldSize * i;
        NSDictionary<NSString *, id> *jsonDictionary = urlData[i];
        NSArray<NSNumber *> *glyphs = jsonDictionary[@"Glyphs"];
        for (NSNumber *glyph in glyphs) {
            CGGlyph glyphValue = glyph.unsignedShortValue;
            /*if (glyphValue >= glyphCount)
                continue;*/
            bitfield[glyphValue / 8] |= (1 << (glyphValue % 8));
        }
    }
    urlDataBuffer = [device newBufferWithBytes:rawUrlData length:urlCount * glyphBitfieldSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
    free(rawUrlData);

    fitnessBuffer = [device newBufferWithLength:generationSize * urlCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    matingInstructionsBuffer = [device newBufferWithLength:generationSize * sizeof(struct MatingInstructions) options:MTLResourceStorageModeManaged];

    mutationInstructionsBuffer = [device newBufferWithLength:generationSize * (maxMutationInstructions * 2 + 1) * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
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
    
    {
        MTLComputePipelineDescriptor *mutatePiplineDescriptor = [MTLComputePipelineDescriptor new];
        mutatePiplineDescriptor.computeFunction = mutateFunction;
        mutatePiplineDescriptor.buffers[0].mutability = MTLMutabilityMutable;
        mutatePiplineDescriptor.buffers[1].mutability = MTLMutabilityImmutable;
        mutateState = [device newComputePipelineStateWithDescriptor:mutatePiplineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
}

- (void)computeFitnessWithCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:fitnessState];
        id<MTLBuffer> buffers[] = {generationABuffer, glyphSizesBuffer, urlDataBuffer, fitnessBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, urlCount, 1) threadsPerThreadgroup:MTLSizeMake(4, 4, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder synchronizeResource:fitnessBuffer];
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
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, glyphCount, 1) threadsPerThreadgroup:MTLSizeMake(4, 4, 1)];
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
        id<MTLBuffer> buffers[] = {generationABuffer, reverseGenerationBuffer, generationBBuffer, matingInstructionsBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, 1, 1) threadsPerThreadgroup:MTLSizeMake(16, 1, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        assert(generationABuffer.length == generationBBuffer.length);
        [blitEncoder copyFromBuffer:generationBBuffer sourceOffset:0 toBuffer:generationABuffer destinationOffset:0 size:generationABuffer.length];
        [blitEncoder synchronizeResource:generationABuffer];
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

- (void)mutateWithCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:mutateState];
        id<MTLBuffer> buffers[] = {generationABuffer, mutationInstructionsBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
        [computeEncoder dispatchThreads:MTLSizeMake(generationSize, 1, 1) threadsPerThreadgroup:MTLSizeMake(16, 1, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        [blitEncoder synchronizeResource:generationABuffer];
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
    uint32_t* fitnessData = fitnessBuffer.contents;
    uint32_t sum = 0;
    uint32_t best = 0;
    __block uint32_t* fitnesses = malloc(generationSize * sizeof(uint32_t));
    for (uint32_t i = 0; i < generationSize; ++i) {
        uint32_t* results = fitnessData + urlCount * i;
        uint64_t count = 0;
        for (uint32_t j = 0; j < urlCount; ++j) {
            count += (uint64_t)results[j];
        }
        const uint32_t originalFileSize = 1758820;
        fitnesses[i] = (double)count / (double)urlCount;
        assert(fitnesses[i] <= originalFileSize);
        fitnesses[i] = originalFileSize - fitnesses[i];
        if (fitnesses[i] > best)
            best = fitnesses[i];
        uint32_t previousSum = sum;
        fitnesses[i] = sum = sum + fitnesses[i];
        assert(sum >= previousSum);
    }
    NSLog(@"Best: %" PRId32, best);
    struct MatingInstructions matingInstructions[generationSize];
    for (uint32_t i = 0; i < generationSize; ++i) {
        uint32_t (^pickWeightedIndex)(void) = ^uint32_t(void) {
            uint32_t r = arc4random_uniform(sum);
            // FIXME: Do a binary search here instead
            uint32_t j;
            for (j = 0; j < self->generationSize && fitnesses[j] <= r; ++j);
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
    free(fitnesses);
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

- (void)validateGeneration
{
    uint32_t* generation = self->generationABuffer.contents;
    for (uint32_t i = 0; i < self->generationSize; ++i) {
        uint32_t* order = generation + self->glyphCount * i;
        NSMutableSet *set = [NSMutableSet setWithCapacity:self->glyphCount];
        for (uint32_t j = 0; j < self->glyphCount; ++j) {
            [set addObject:[NSNumber numberWithUnsignedInt:order[j]]];
        }
        assert(set.count == self->glyphCount);
    }
}

- (void)runWithCallback:(void (^)(void))callback
{
    [self validateGeneration];
    NSLog(@"Computing fitness.");
    [self computeFitnessWithCallback:^() {
        NSLog(@"Reversing generation.");
        [self reverseGenerationWithCallback:^() {
            [self validateGeneration];
            NSLog(@"Mating.");
            [self mateWithCallback:^() {
                [self validateGeneration];
                NSLog(@"Mutating.");
                [self mutateWithCallback:^() {
                    [self validateGeneration];
                    NSLog(@"Finished.");
                    callback();
                }];
            }];
        }];
        
        NSLog(@"Starting instruction generation.");
        // GPU runs the reversing code at the same time the CPU gets ready for mating
        [self populateMatingInstructionsBuffer];
        [self populateMutationInstructionsBuffer];
        NSLog(@"Finished instruction generation.");
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

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Runner *runner = [[Runner alloc] init];
        [runner runIterations:1000 withCallback:^() {
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        CFRunLoopRun();
    }
    return 0;
}
