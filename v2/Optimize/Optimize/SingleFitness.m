//
//  SingleFitness.m
//  Optimize
//
//  Created by Myles C. Maxfield on 12/17/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Metal;

#import "SingleFitness.h"
#import <assert.h>

// "Weight" as in gravity
@interface GlyphWithWeight : NSObject
- (instancetype)initWithGlyph:(uint32_t)glyph andWeight:(float)weight;
@property uint32_t glyph;
@property float weight;
@end

@implementation GlyphWithWeight
- (instancetype)initWithGlyph:(uint32_t)glyph andWeight:(float)weight
{
    self = [super init];
    if (self) {
        self.glyph = glyph;
        self.weight = weight;
    }
    return self;
}
@end

@implementation SingleFitness {
    GlyphData *glyphData;
    NSData *matrix;

    uint32_t glyphCount;
    uint32_t glyphBitfieldSize;
    uint32_t urlCount;

    id<MTLDevice> device;
    id<MTLCommandQueue> queue;

    id<MTLFunction> fitnessFunction;
    id<MTLFunction> sumFitnessesFunction;
    id<MTLComputePipelineState> fitnessState;
    id<MTLComputePipelineState> sumFitnessesState;
    id<MTLBuffer> generationBuffer;
    id<MTLBuffer> glyphSizesBuffer;
    id<MTLBuffer> urlBitmapsBuffer;
    id<MTLBuffer> fitnessesPerURLBuffer;
}

- (instancetype)initWithGlyphData:(GlyphData *)glyphData
{
    self = [super init];

    if (self) {
        self->glyphData = glyphData;

        NSData *glyphVectorsContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/glyphVectors.json"];
        assert(glyphVectorsContents != nil);
        NSError *error = nil;
        NSArray<id> *glyphVectors = [NSJSONSerialization JSONObjectWithData:glyphVectorsContents options:0 error:&error];
        assert(error == nil);
        assert(glyphVectors != nil);
        
        self.dimension = NSUIntegerMax;
        for (id object in glyphVectors) {
            if ([object isEqual:[NSNull null]])
                continue;
            NSArray<NSNumber *> *vector = object;
            assert(vector.count != NSUIntegerMax);
            if (self.dimension == NSUIntegerMax)
                self.dimension = vector.count;
            else
                assert(self.dimension == vector.count);
        }

        NSMutableData *matrix = [NSMutableData dataWithLength:sizeof(float) * self.dimension * glyphVectors.count];
        float* matrixData = matrix.mutableBytes;
        for (NSUInteger i = 0; i < glyphVectors.count; ++i) {
            float* row = matrixData + i * self.dimension;
            id object = glyphVectors[i];
            if ([object isEqual:[NSNull null]]) {
                for (NSUInteger j = 0; j < self.dimension; ++j)
                    row[j] = 0;
            } else {
                NSArray<NSNumber *> *vector = object;
                assert(vector.count == self.dimension);
                for (NSUInteger j = 0; j < self.dimension; ++j)
                    row[j] = vector[j].floatValue;
            }
        }
        self->matrix = matrix;

        glyphCount = (uint32_t)glyphVectors.count;
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
    NSBundle *bundle = [NSBundle bundleForClass:[SingleFitness class]];
    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle error:&error];
    assert(error == nil);
    MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
    [constantValues setConstantValue:&glyphCount type:MTLDataTypeUInt withName:@"glyphCount"];
    [constantValues setConstantValue:&glyphBitfieldSize type:MTLDataTypeUInt withName:@"glyphBitfieldSize"];
    [constantValues setConstantValue:&urlCount type:MTLDataTypeUInt withName:@"urlCount"];
    fitnessFunction = [library newFunctionWithName:@"fitness" constantValues:constantValues error:&error];
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
}

- (void)createBuffers
{
    generationBuffer = [device newBufferWithLength:sizeof(uint32_t) * glyphCount options:MTLResourceStorageModeManaged];

    uint32_t glyphSizesData[glyphCount];
    for (uint32_t i = 0; i < glyphCount; ++i)
        glyphSizesData[i] = glyphData.glyphSizes[i].unsignedIntValue;
    glyphSizesBuffer = [device newBufferWithBytes:glyphSizesData length:glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

    urlBitmapsBuffer = [device newBufferWithBytes:glyphData.urlBitmaps length:urlCount * glyphBitfieldSize * sizeof(uint8_t) options:MTLResourceStorageModeManaged];

    fitnessesPerURLBuffer = [device newBufferWithLength:urlCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
}

- (void)computeFitnessesWithCallback:(void (^)(void))callback
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    {
        [computeEncoder setComputePipelineState:fitnessState];
        id<MTLBuffer> buffers[] = {generationBuffer, glyphSizesBuffer, urlBitmapsBuffer, fitnessesPerURLBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
        [computeEncoder dispatchThreads:MTLSizeMake(1, urlCount, 1) threadsPerThreadgroup:MTLSizeMake(1, 32, 1)];
    }
    [computeEncoder endEncoding];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    {
        [blitEncoder synchronizeResource:fitnessesPerURLBuffer];
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

- (float)computeFitness:(NSArray<NSNumber *> *)transformationMatrix
{
    assert(transformationMatrix.count == self.dimension);

    NSMutableArray<GlyphWithWeight *> *order = [NSMutableArray arrayWithCapacity:glyphCount];
    const float* matrixData = matrix.bytes;
    for (uint32_t i = 0; i < glyphCount; ++i) {
        const float* row = matrixData + i * self.dimension;
        float weight = 0;
        for (NSUInteger j = 0; j < transformationMatrix.count; ++j)
            weight += transformationMatrix[j].floatValue * row[j];
        [order addObject:[[GlyphWithWeight alloc] initWithGlyph:i andWeight:weight]];
    }
    [order sortUsingComparator:^NSComparisonResult (GlyphWithWeight *obj1, GlyphWithWeight *obj2) {
        if (obj1.weight < obj2.weight)
            return NSOrderedAscending;
        else if (obj1.weight == obj2.weight)
            return NSOrderedSame;
        else {
            assert(obj1.weight > obj2.weight);
            return NSOrderedDescending;
        }
    }];
    uint32_t* bufferContents = generationBuffer.contents;
    for (uint32_t i = 0; i < glyphCount; ++i)
        bufferContents[i] = order[i].glyph;
    [generationBuffer didModifyRange:NSMakeRange(0, sizeof(uint32_t) * glyphCount)];

    __block float fitness = 0;
    [self computeFitnessesWithCallback:^{
        const uint32_t fontSize = 1758483;
        uint32_t* fitnessesPerURL = self->fitnessesPerURLBuffer.contents;
        for (uint32_t i = 0; i < self->urlCount; ++i)
            fitness += (float)fitnessesPerURL[i] / (float)fontSize;

        fitness = fitness / (float)self->urlCount;
        CFRunLoopStop(CFRunLoopGetMain());
    }];
    CFRunLoopRun();

    return fitness;
}

@end
