//
//  BigramScorer.m
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Metal;

#import "BigramScorer.h"

@implementation BigramScorer {
    GlyphData *glyphData;

    uint32_t glyphCount;
    uint32_t glyphBitfieldSize;
    uint32_t urlCount;

    id<MTLDevice> device;
    id<MTLCommandQueue> queue;

    id<MTLFunction> computeBigramScoresFunction;
    id<MTLComputePipelineState> computeBigramScoresState;
    id<MTLBuffer> urlBitmapsBuffer;
    id<MTLBuffer> bigramScoresBuffer;
}

- (instancetype)initWithGlyphData:(GlyphData *)glyphData;
{
    self = [super init];

    if (self) {
        self->glyphData = glyphData;
        
        glyphCount = (uint32_t)glyphData.glyphCount;
        glyphBitfieldSize = (uint32_t)glyphData.glyphBitfieldSize;
        urlCount = (uint32_t)glyphData.urlCount;

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
    NSBundle *bundle = [NSBundle bundleForClass:[BigramScorer class]];
    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle error:&error];
    assert(error == nil);
    MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
    [constantValues setConstantValue:&glyphCount type:MTLDataTypeUInt withName:@"glyphCount"];
    [constantValues setConstantValue:&glyphBitfieldSize type:MTLDataTypeUInt withName:@"glyphBitfieldSize"];
    [constantValues setConstantValue:&urlCount type:MTLDataTypeUInt withName:@"urlCount"];
    computeBigramScoresFunction = [library newFunctionWithName:@"computeBigramScores" constantValues:constantValues error:&error];
    assert(error == nil);
}

- (void)createMetalStates
{
    NSError *error;
    {
        MTLComputePipelineDescriptor *computeBigramScoresDescriptor = [MTLComputePipelineDescriptor new];
        computeBigramScoresDescriptor.computeFunction = computeBigramScoresFunction;
        computeBigramScoresDescriptor.buffers[0].mutability = MTLMutabilityImmutable;
        computeBigramScoresDescriptor.buffers[1].mutability = MTLMutabilityMutable;
        computeBigramScoresState = [device newComputePipelineStateWithDescriptor:computeBigramScoresDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
    }
}

- (void)createBuffers
{
    urlBitmapsBuffer = [device newBufferWithBytes:glyphData.urlBitmaps length:urlCount * glyphBitfieldSize * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    bigramScoresBuffer = [device newBufferWithLength:glyphCount * glyphCount * sizeof(float) options:MTLResourceStorageModeManaged];
}

- (void)computeWithCallback:(void (^)(NSArray<NSArray<NSNumber *> *> *))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:computeBigramScoresState];
        id<MTLBuffer> buffers[] = {urlBitmapsBuffer, bigramScoresBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
        [computeEncoder dispatchThreads:MTLSizeMake(glyphCount, glyphCount, 1) threadsPerThreadgroup:MTLSizeMake(4, 4, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        [blitEncoder synchronizeResource:bigramScoresBuffer];
    }
    [blitEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        assert(commandBuffer.error == nil);

        float* floatScores = (float*)self->bigramScoresBuffer.contents;
        NSMutableArray<NSArray<NSNumber *> *> *bigramScores = [NSMutableArray arrayWithCapacity:self->glyphCount];
        for (uint32_t i = 0; i < self->glyphCount; ++i) {
            NSMutableArray<NSNumber *> *row = [NSMutableArray arrayWithCapacity:self->glyphCount];
            for (uint32_t j = 0; j < self->glyphCount; ++j)
                [row addObject:[NSNumber numberWithFloat:floatScores[self->glyphCount * i + j]]];
            [bigramScores addObject:row];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            callback(bigramScores);
        });
    }];
    [commandBuffer commit];
}

@end
