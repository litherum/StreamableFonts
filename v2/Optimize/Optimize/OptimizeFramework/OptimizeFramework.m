//
//  OptimizeFramework.m
//  OptimizeFramework
//
//  Created by Litherum on 11/1/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "OptimizeFramework.h"

@implementation CostFunction {
    int urlCount;
    int glyphCount;
    id<MTLDevice> device;
    id<MTLComputePipelineState> computePipelineState;
    id<MTLBuffer> glyphSizesBuffer;
    id<MTLBuffer> glyphsBuffer;
    id<MTLBuffer> outputBuffer;
    id<MTLCommandQueue> commandQueue;
}

-(instancetype)initWithGlyphCount:(int)glyphCount
{
    if (self) {
        NSData *jsonContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Documents/output_glyphs.json"];
        assert(jsonContents != nil);
        NSError *error = nil;
        NSArray<NSDictionary<NSString *, id> *> *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonContents options:0 error:&error];
        assert(error == nil);
        assert(jsonArray != nil);

        NSData *jsonSizeContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Documents/output_glyph_sizes.json"];
        assert(jsonSizeContents != nil);
        NSArray<NSNumber *> *jsonSizeArray = [NSJSONSerialization JSONObjectWithData:jsonSizeContents options:0 error:&error];
        assert(error == nil);
        assert(jsonSizeArray != nil);

        urlCount = (int)jsonArray.count;
        self->glyphCount = glyphCount;
        int glyphBitfieldSize = (glyphCount + 7) / 8;

        NSString *source = [NSString stringWithFormat:@"\n"
        "#include <metal_stdlib>\n"
        "\n"
        "using namespace metal;\n"
        "\n"
        "kernel void computeFunction(device uint32_t* order [[buffer(0)]], device uint32_t* glyphSizes [[buffer(1)]], device uint8_t* glyphs [[buffer(2)]], device uint32_t* output [[buffer(3)]], uint tid [[thread_position_in_grid]]) {\n"
        "    constexpr uint32_t unconditionalDownloadSize = 282828;\n"
        "    constexpr uint32_t threshold = 8 * 170;\n"
        "    uint32_t glyphCount = %d;\n"
        "    uint32_t glyphBitfieldSize = %d;\n"
        "    uint8_t state = 0;\n"
        "    uint32_t unnecessarySize = 0;\n"
        "    uint32_t result = unconditionalDownloadSize + threshold;\n"
        "    for (uint32_t i = 0; i < glyphCount; ++i) {\n"
        "        uint32_t glyph = order[i];\n"
        "        uint32_t size = glyphSizes[glyph];\n"
        "        if (glyphs[glyphBitfieldSize * tid + glyph / 8] & (1 << (glyph %% 8))) {\n"
        "            result += size;\n"
        "            if (state == 0) {\n"
        "                result += min(unnecessarySize, threshold);\n"
        "                unnecessarySize = 0;\n"
        "            }\n"
        "            state = 1;\n"
        "        } else {\n"
        "            unnecessarySize += size;\n"
        "            state = 0;\n"
        "        }\n"
        "    }\n"
        "    output[tid] = result;\n"
        "}", glyphCount, glyphBitfieldSize];

        device = MTLCreateSystemDefaultDevice();
        
        MTLCompileOptions *compileOptions = [MTLCompileOptions new];
        id<MTLLibrary> library = [device newLibraryWithSource:source options:compileOptions error:&error];
        assert(error == nil);
        id<MTLFunction> computeFunction = [library newFunctionWithName:@"computeFunction"];
        
        MTLComputePipelineDescriptor *computePipelineDescriptor = [MTLComputePipelineDescriptor new];
        computePipelineDescriptor.computeFunction = computeFunction;
        computePipelineState = [device newComputePipelineStateWithDescriptor:computePipelineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);

        uint32_t glyphSizes[glyphCount];
        for (int i = 0; i < glyphCount; ++i)
            glyphSizes[i] = [jsonSizeArray[i] unsignedIntValue];
        glyphSizesBuffer = [device newBufferWithBytes:glyphSizes length:sizeof(uint32_t) * glyphCount options:MTLResourceStorageModeManaged];
        
        uint8_t* glyphBitfield = malloc(glyphBitfieldSize * urlCount);
        for (size_t i = 0; i < glyphBitfieldSize * urlCount; ++i)
            glyphBitfield[i] = 0;
        for (NSUInteger i = 0; i < urlCount; ++i) {
            NSDictionary<NSString *, id> *jsonDictionary = jsonArray[i];
            NSArray<NSNumber *> *glyphs = jsonDictionary[@"Glyphs"];
            for (NSNumber *glyph in glyphs) {
                CGGlyph glyphValue = glyph.unsignedShortValue;
                if (glyphValue >= glyphCount)
                    continue;
                glyphBitfield[glyphBitfieldSize * i + glyphValue / 8] |= (1 << (glyphValue % 8));
            }
        }
        glyphsBuffer = [device newBufferWithBytes:glyphBitfield length:glyphBitfieldSize * urlCount options:MTLResourceStorageModeManaged];
        free(glyphBitfield);
        
        outputBuffer = [device newBufferWithLength:sizeof(uint32_t) * urlCount options:MTLResourceStorageModeShared];

        commandQueue = [device newCommandQueue];
    }
    return self;
}

-(uint64_t)calculate:(NSArray<NSNumber *> *)order
{
    assert(order.count == glyphCount);
    
    uint32_t orderData[glyphCount];
    for (int i = 0; i < glyphCount; ++i)
        orderData[i] = [order[i] unsignedIntValue];
    id<MTLBuffer> orderBuffer = [device newBufferWithBytes:orderData length:sizeof(uint32_t) * glyphCount options:MTLResourceStorageModeManaged];

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
    [computeCommandEncoder setComputePipelineState:computePipelineState];
    id<MTLBuffer> buffers[] = {orderBuffer, glyphSizesBuffer, glyphsBuffer, outputBuffer};
    NSUInteger offsets[] = {0, 0, 0, 0};
    [computeCommandEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
    [computeCommandEncoder dispatchThreads:MTLSizeMake(urlCount, 1, 1) threadsPerThreadgroup:MTLSizeMake(512, 1, 1)];
    [computeCommandEncoder endEncoding];
    __block uint64_t result = 0;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        NSLog(@"Complete");
        uint32_t* results = self->outputBuffer.contents;
        for (size_t i = 0; i < self->urlCount; ++i)
            result += (uint64_t)results[i];
        NSLog(@"%" PRIu64, result);
        NSLog(@"%f ms", (commandBuffer.GPUEndTime - commandBuffer.GPUStartTime) * 1000);
        CFRunLoopStop(CFRunLoopGetMain());
    }];
    [commandBuffer commit];
    CFRunLoopRun();
    NSLog(@"Returning %" PRIu64, result);
    return result;
}
@end
