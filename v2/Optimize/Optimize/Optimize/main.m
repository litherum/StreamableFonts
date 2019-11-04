//
//  main.m
//  Optimize
//
//  Created by Litherum on 11/3/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "OptimizeFramework.h"
#import <assert.h>

struct Uniforms {
    uint32_t populationCount;
    uint32_t glyphCount;
};

struct Arguments {
    uint32_t majorParentIndex;
    uint32_t minorParentIndex;
    uint32_t minimum;
    uint32_t maximum;
};

static NSUInteger weightedPick(NSArray<NSNumber *> *fitnesses, unsigned long long sum) {
    double pick = drand48();
    double partial = 0;
    for (NSUInteger i = 0; i < fitnesses.count; ++i) {
        partial += (double)fitnesses[i].unsignedLongLongValue / (double)sum;
        if (pick < partial)
            return i;
    }
    return fitnesses.count - 1;
}

@interface Crossoverer: NSObject
- (instancetype)initWithPopulationCount:(NSUInteger)populationCount glyphCount:(NSUInteger)glyphCount;
- (void)createResourcesWithGeneration:(NSArray<NSArray<NSNumber *> *> *)generation;
- (NSArray<NSArray<NSNumber *> *> *)computeWithFitnesses:(NSArray<NSNumber *> *)fitnesses sum:(unsigned long long)sum;
@end

@implementation Crossoverer {
    NSUInteger populationCount;
    NSUInteger glyphCount;
    id<MTLDevice> device;
    id<MTLComputePipelineState> reverseComputePipelineState;
    id<MTLComputePipelineState> computePipelineState;
    id<MTLBuffer> generationBuffer;
    id<MTLBuffer> reverseGenerationBuffer;
    id<MTLBuffer> newGenerationBuffer;
    id<MTLBuffer> uniformBuffer;
    id<MTLCommandQueue> commandQueue;
}

- (instancetype)initWithPopulationCount:(NSUInteger)populationCount glyphCount:(NSUInteger)glyphCount
{
    if (self != nil) {
        NSString *source = [NSString stringWithFormat:@"\n"
        "#include <metal_stdlib>\n"
        "\n"
        "using namespace metal;\n"
        "\n"
        "constant constexpr const uint32_t glyphCount = %lu;\n"
        "\n"
        "kernel void reverse(device uint32_t* generation [[buffer(0)]], device uint32_t* reverseGeneration [[buffer(1)]], uint2 tid [[thread_position_in_grid]]) {\n"
        "    device uint32_t* inputArray = generation + glyphCount * tid.x;\n"
        "    device uint32_t* outputArray = reverseGeneration + glyphCount * tid.x;\n"
        "    uint32_t a = tid.y;\n"
        "    uint32_t b = inputArray[a];\n"
        "    outputArray[b] = a;\n"
        "}\n"
        "\n"
        "struct Arguments {\n"
        "    uint32_t majorParentIndex;\n"
        "    uint32_t minorParentIndex;\n"
        "    uint32_t minimum;\n"
        "    uint32_t maximum;\n"
        "};\n"
        "\n"
        "kernel void computeFunction(device uint32_t* generation [[buffer(0)]], device uint32_t* reverseGeneration [[buffer(1)]], device uint32_t* newGeneration [[buffer(2)]], device Arguments* arguments [[buffer(3)]], uint tid [[thread_position_in_grid]]) {\n"
        "    Arguments args = arguments[tid];\n"
        "    device uint32_t* majorParent = generation + glyphCount * args.majorParentIndex;\n"
        "    device uint32_t* minorParent = generation + glyphCount * args.minorParentIndex;\n"
        "    device uint32_t* reverseMajorParent = reverseGeneration + glyphCount * args.majorParentIndex;\n"
        "    device uint32_t* reverseMinorParent = reverseGeneration + glyphCount * args.minorParentIndex;\n"
        "    device uint32_t* outputArray = newGeneration + glyphCount * tid;\n"
        "    for (uint32_t i = 0; i < args.minimum; ++i)\n"
        "        outputArray[i] = glyphCount;\n"
        "    for (uint32_t i = args.minimum; i < args.maximum; ++i)\n"
        "        outputArray[i] = majorParent[i];\n"
        "    for (uint32_t i = args.maximum; i < glyphCount; ++i)\n"
        "        outputArray[i] = glyphCount;\n"
        "\n"
        "    for (uint32_t i = args.minimum; i < args.maximum; ++i) {\n"
        "        uint32_t index = i;\n"
        "        uint32_t item = minorParent[i];\n"
        "        uint32_t position = reverseMajorParent[item];\n"
        "        if (position < args.minimum || position >= args.maximum) {\n"
        "            while (index >= args.minimum && index < args.maximum) {\n"
        "                item = majorParent[index];\n"
        "                index = reverseMinorParent[item];\n"
        "            }\n"
        "            outputArray[index] = minorParent[i];\n"
        "        }\n"
        "    }\n"
        "\n"
        "    for (uint32_t i = 0; i < glyphCount; ++i) {\n"
        "        if (outputArray[i] == glyphCount)\n"
        "            outputArray[i] = minorParent[i];\n"
        "    }\n"
        "}\n", glyphCount];

        device = MTLCreateSystemDefaultDevice();
        
        NSError *error = nil;

        MTLCompileOptions *compileOptions = [MTLCompileOptions new];
        id<MTLLibrary> library = [device newLibraryWithSource:source options:compileOptions error:&error];
        assert(error == nil);
        id<MTLFunction> reverseFunction = [library newFunctionWithName:@"reverse"];
        id<MTLFunction> computeFunction = [library newFunctionWithName:@"computeFunction"];
        
        MTLComputePipelineDescriptor *reversePipelineDescriptor = [MTLComputePipelineDescriptor new];
        reversePipelineDescriptor.computeFunction = reverseFunction;
        reverseComputePipelineState = [device newComputePipelineStateWithDescriptor:reversePipelineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
        
        MTLComputePipelineDescriptor *computePipelineDescriptor = [MTLComputePipelineDescriptor new];
        computePipelineDescriptor.computeFunction = computeFunction;
        computePipelineState = [device newComputePipelineStateWithDescriptor:computePipelineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);

        self->populationCount = populationCount;
        self->glyphCount = glyphCount;

        reverseGenerationBuffer = [device newBufferWithLength:populationCount * glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
        newGenerationBuffer = [device newBufferWithLength:populationCount * glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];

        commandQueue = [device newCommandQueue];
    }
    return self;
}

- (void)createResourcesWithGeneration:(NSArray<NSArray<NSNumber *> *> *)generation
{
    assert(generation.count == populationCount);
    assert(generation.count > 0);
    assert(generation[0].count == glyphCount);
    uint32_t generationData[populationCount * glyphCount];
    for (NSUInteger i = 0; i < populationCount; ++i) {
        assert(generation[i].count == glyphCount);
        for (NSUInteger j = 0; j < glyphCount; ++j)
            generationData[glyphCount * i + j] = generation[i][j].unsignedIntValue;
    }
    generationBuffer = [device newBufferWithBytes:generationData length:populationCount * glyphCount * sizeof(uint32_t) options:MTLResourceStorageModeManaged];
}

- (NSArray<NSArray<NSNumber *> *> *)computeWithFitnesses:(NSArray<NSNumber *> *)fitnesses sum:(unsigned long long)sum
{
    struct Arguments argumentsData[populationCount];
    for (NSUInteger i = 0; i < populationCount; ++i) {
        argumentsData[i].majorParentIndex = (uint32_t)weightedPick(fitnesses, sum);
        argumentsData[i].minorParentIndex = (uint32_t)weightedPick(fitnesses, sum);
        uint32_t index0 = arc4random_uniform((uint32_t)glyphCount);
        uint32_t index1 = arc4random_uniform((uint32_t)glyphCount);
        argumentsData[i].minimum = MIN(index0, index1);
        argumentsData[i].maximum = MAX(index0, index1);
    }
    id<MTLBuffer> argumentsBuffer = [device newBufferWithBytes:argumentsData length:populationCount * sizeof(struct Arguments) options:MTLResourceStorageModeManaged];
    
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
    [computeCommandEncoder setComputePipelineState:reverseComputePipelineState];
    {
        id<MTLBuffer> buffers[] = {generationBuffer, reverseGenerationBuffer};
        NSUInteger offsets[] = {0, 0};
        [computeCommandEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 2)];
    }
    [computeCommandEncoder dispatchThreads:MTLSizeMake(populationCount, glyphCount, 1) threadsPerThreadgroup:MTLSizeMake(4, 4, 1)];
    [computeCommandEncoder setComputePipelineState:computePipelineState];
    {
        id<MTLBuffer> buffers[] = {generationBuffer, reverseGenerationBuffer, newGenerationBuffer, argumentsBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeCommandEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
    }
    [computeCommandEncoder dispatchThreads:MTLSizeMake(populationCount, 1, 1) threadsPerThreadgroup:MTLSizeMake(16, 1, 1)];
    [computeCommandEncoder endEncoding];
    __block NSMutableArray<NSArray<NSNumber *> *> *result;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        assert(commandBuffer.error == nil);
        dispatch_sync(dispatch_get_main_queue(), ^() {
            uint32_t* newGenerationData = self->newGenerationBuffer.contents;
            result = [NSMutableArray arrayWithCapacity:self->populationCount];
            for (NSUInteger i = 0; i < self->populationCount; ++i) {
                NSMutableArray<NSNumber *> *glyphs = [NSMutableArray arrayWithCapacity:self->glyphCount];
                for (NSUInteger j = 0; j < self->glyphCount; ++j)
                    [glyphs addObject:[NSNumber numberWithUnsignedInt:newGenerationData[i * self->glyphCount + j]]];
                [result addObject:glyphs];
            }
            CFRunLoopStop(CFRunLoopGetMain());
        });
    }];
    [commandBuffer commit];
    CFRunLoopRun();
    return result;
}

@end

static NSArray<NSArray<NSNumber *> *> *seedGeneration(NSUInteger populationCount, NSUInteger glyphCount) {
    NSMutableArray<NSArray<NSNumber *> *> *generation = [NSMutableArray arrayWithCapacity:populationCount];
    for (NSUInteger i = 0; i < populationCount; ++i) {
        NSMutableArray *availableEntries = [NSMutableArray arrayWithCapacity:glyphCount];
        for (NSUInteger j = 0; j < glyphCount; ++j)
            [availableEntries addObject:[NSNumber numberWithUnsignedInteger:j]];
        NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphCount];
        while (availableEntries.count > 0) {
            uint32_t index = arc4random_uniform((uint32_t)availableEntries.count);
            NSNumber *next = availableEntries[index];
            [availableEntries removeObjectAtIndex:index];
            [order addObject:next];
        }
        [generation addObject:order];
    }
    return generation;
}

static NSArray<NSNumber *> *computeFitnesses(CostFunction *costFunction, NSArray<NSArray<NSNumber *> *> *generation) {
    NSMutableArray<NSNumber *> *fitnesses = [NSMutableArray arrayWithCapacity:generation.count];
    __block NSUInteger count = 0;
    NSNumber *dummy = [NSNumber numberWithInt:0];
    for (NSUInteger i = 0; i < generation.count; ++i) {
        [fitnesses addObject:dummy];
        [costFunction calculateAsync:generation[i] callback:^void (uint64_t result) {
            assert(costFunction.totalDataSize >= result);
            result = costFunction.totalDataSize - result;
            fitnesses[i] = [NSNumber numberWithUnsignedLongLong:result];
            if (++count == generation.count)
                CFRunLoopStop(CFRunLoopGetMain());
        }];
    }
    CFRunLoopRun();
    return fitnesses;
}

static NSArray<NSArray<NSNumber *> *> *crossoverMetal(Crossoverer *crossoverer, NSArray<NSArray<NSNumber *> *> *generation, NSArray<NSNumber *> *fitnesses, unsigned long long sum) {
    [crossoverer createResourcesWithGeneration:generation];
    return [crossoverer computeWithFitnesses:fitnesses sum:sum];
}

/*static NSArray<NSNumber *> *mutate(NSArray<NSNumber *> *child) {
    // FIXME: Consider doing this in Metal too
    NSMutableArray<NSNumber *> *copy = [child mutableCopy];
    for (NSUInteger i = 0; i < child.count / 10; ++i) {
        uint32_t index0 = arc4random_uniform((uint32_t)copy.count);
        uint32_t index1 = arc4random_uniform((uint32_t)copy.count);
        NSNumber *temp = copy[index0];
        copy[index0] = copy[index1];
        copy[index1] = temp;
    }
    return copy;
}*/

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CostFunction *costFunction = [[CostFunction alloc] init];
        [costFunction loadData];
        [costFunction createResources];
        
        NSUInteger populationCount = 10;
        Crossoverer *crossoverer = [[Crossoverer alloc] initWithPopulationCount:populationCount glyphCount:costFunction.glyphCount];
        /*
        NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:costFunction.glyphCount];
        for (NSUInteger i = 0; i < costFunction.glyphCount; ++i)
            [order addObject:[NSNumber numberWithUnsignedInteger:i]];
        [costFunction calculate:order];
        */
        
        NSArray<NSArray<NSNumber *> *> *generation = seedGeneration(populationCount, costFunction.glyphCount);

        unsigned long long best = 0;
        for (NSUInteger i = 0; i < 10; ++i) {
            NSArray<NSNumber *> *fitnesses = computeFitnesses(costFunction, generation);
            for (NSNumber *fitness in fitnesses) {
                if (fitness.unsignedLongLongValue > best)
                    best = fitness.unsignedLongLongValue;
            }
            NSLog(@"Best: %llu", best);

            unsigned long long sum = 0;
            for (NSUInteger i = 0; i < fitnesses.count; ++i)
                sum += fitnesses[i].unsignedLongLongValue;
            NSArray<NSArray<NSNumber *> *> *newGeneration = crossoverMetal(crossoverer, generation, fitnesses, sum);
            generation = newGeneration;
        }
    }
    return 0;
}
