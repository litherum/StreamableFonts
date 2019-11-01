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
    id<MTLDevice> device;
    id<MTLComputePipelineState> computePipelineState;
    id<MTLBuffer> glyphSizesBuffer;
    id<MTLBuffer> glyphsBuffer;
    id<MTLBuffer> outputBuffer;
    id<MTLCommandQueue> commandQueue;
}

-(instancetype)init
{
    if (self) {
        NSData *jsonContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/output_glyphs.json"];
        assert(jsonContents != nil);
        NSError *error = nil;
        NSArray<NSDictionary<NSString *, id> *> *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonContents options:0 error:&error];
        assert(error == nil);
        assert(jsonArray != nil);

        NSData *jsonSizeContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/output_glyph_sizes.json"];
        assert(jsonSizeContents != nil);
        NSArray<NSNumber *> *jsonSizeArray = [NSJSONSerialization JSONObjectWithData:jsonSizeContents options:0 error:&error];
        assert(error == nil);
        assert(jsonSizeArray != nil);

        self.urlCount = jsonArray.count;
        self.glyphCount = jsonSizeArray.count;
        NSUInteger glyphBitfieldSize = (self.glyphCount + 7) / 8;

        NSString *source = [NSString stringWithFormat:@"\n"
        "#include <metal_stdlib>\n"
        "\n"
        "using namespace metal;\n"
        "\n"
        "kernel void computeFunction(device uint32_t* order [[buffer(0)]], device uint32_t* glyphSizes [[buffer(1)]], device uint8_t* glyphs [[buffer(2)]], device uint32_t* output [[buffer(3)]], uint tid [[thread_position_in_grid]]) {\n"
        "    constexpr uint32_t unconditionalDownloadSize = 282828;\n"
        "    constexpr uint32_t threshold = 8 * 170;\n"
        "    uint32_t glyphCount = %lu;\n"
        "    uint32_t glyphBitfieldSize = %lu;\n"
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
        "}", (unsigned long)self.glyphCount, (unsigned long)glyphBitfieldSize];

        device = MTLCreateSystemDefaultDevice();
        self.deviceName = device.name;
        
        MTLCompileOptions *compileOptions = [MTLCompileOptions new];
        id<MTLLibrary> library = [device newLibraryWithSource:source options:compileOptions error:&error];
        assert(error == nil);
        id<MTLFunction> computeFunction = [library newFunctionWithName:@"computeFunction"];
        
        MTLComputePipelineDescriptor *computePipelineDescriptor = [MTLComputePipelineDescriptor new];
        computePipelineDescriptor.computeFunction = computeFunction;
        computePipelineState = [device newComputePipelineStateWithDescriptor:computePipelineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);

        uint32_t glyphSizes[self.glyphCount];
        for (int i = 0; i < self.glyphCount; ++i)
            glyphSizes[i] = [jsonSizeArray[i] unsignedIntValue];
        glyphSizesBuffer = [device newBufferWithBytes:glyphSizes length:sizeof(uint32_t) * self.glyphCount options:MTLResourceStorageModeManaged];
        
        uint8_t* glyphBitfield = malloc(glyphBitfieldSize * self.urlCount);
        for (size_t i = 0; i < glyphBitfieldSize * self.urlCount; ++i)
            glyphBitfield[i] = 0;
        for (NSUInteger i = 0; i < self.urlCount; ++i) {
            NSDictionary<NSString *, id> *jsonDictionary = jsonArray[i];
            NSArray<NSNumber *> *glyphs = jsonDictionary[@"Glyphs"];
            for (NSNumber *glyph in glyphs) {
                CGGlyph glyphValue = glyph.unsignedShortValue;
                if (glyphValue >= self.glyphCount)
                    continue;
                glyphBitfield[glyphBitfieldSize * i + glyphValue / 8] |= (1 << (glyphValue % 8));
            }
        }
        glyphsBuffer = [device newBufferWithBytes:glyphBitfield length:glyphBitfieldSize * self.urlCount options:MTLResourceStorageModeManaged];
        free(glyphBitfield);
        
        outputBuffer = [device newBufferWithLength:sizeof(uint32_t) * self.urlCount options:MTLResourceStorageModeShared];

        commandQueue = [device newCommandQueue];
    }
    return self;
}

-(uint64_t)calculate:(NSArray<NSNumber *> *)order
{
    assert(order.count == self.glyphCount);
    
    uint32_t orderData[self.glyphCount];
    for (int i = 0; i < self.glyphCount; ++i)
        orderData[i] = [order[i] unsignedIntValue];
    id<MTLBuffer> orderBuffer = [device newBufferWithBytes:orderData length:sizeof(uint32_t) * self.glyphCount options:MTLResourceStorageModeManaged];

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
    [computeCommandEncoder setComputePipelineState:computePipelineState];
    id<MTLBuffer> buffers[] = {orderBuffer, glyphSizesBuffer, glyphsBuffer, outputBuffer};
    NSUInteger offsets[] = {0, 0, 0, 0};
    [computeCommandEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
    [computeCommandEncoder dispatchThreads:MTLSizeMake(self.urlCount, 1, 1) threadsPerThreadgroup:MTLSizeMake(512, 1, 1)];
    [computeCommandEncoder endEncoding];
    __block uint64_t result = 0;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        uint32_t* results = self->outputBuffer.contents;
        for (size_t i = 0; i < self.urlCount; ++i)
            result += (uint64_t)results[i];
        NSLog(@"%f ms", (commandBuffer.GPUEndTime - commandBuffer.GPUStartTime) * 1000);
        CFRunLoopStop(CFRunLoopGetMain());
    }];
    [commandBuffer commit];
    CFRunLoopRun();
    return result;
}
@end
