//
//  main.m
//  Optimize
//
//  Created by Litherum on 10/31/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
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

        //int urlCount = 37451;
        int urlCount = 3745;
        //int glyphCount = 8676;
        int glyphCount = 867;
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

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        
        MTLCompileOptions *compileOptions = [MTLCompileOptions new];
        id<MTLLibrary> library = [device newLibraryWithSource:source options:compileOptions error:&error];
        //assert(error == nil);
        id<MTLFunction> computeFunction = [library newFunctionWithName:@"computeFunction"];
        
        MTLComputePipelineDescriptor *computePipelineDescriptor = [MTLComputePipelineDescriptor new];
        computePipelineDescriptor.computeFunction = computeFunction;
        id<MTLComputePipelineState> computePipelineState = [device newComputePipelineStateWithDescriptor:computePipelineDescriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        assert(error == nil);
        
        uint32_t order[glyphCount];
        for (int i = 0; i < glyphCount; ++i)
            order[i] = i;
        id<MTLBuffer> orderBuffer = [device newBufferWithBytes:order length:sizeof(uint32_t) * glyphCount options:MTLResourceStorageModeManaged];

        uint32_t glyphSizes[glyphCount];
        for (int i = 0; i < glyphCount; ++i)
            glyphSizes[i] = [jsonSizeArray[i] unsignedIntValue];
        id<MTLBuffer> glyphSizesBuffer = [device newBufferWithBytes:glyphSizes length:sizeof(uint32_t) * glyphCount options:MTLResourceStorageModeManaged];
        
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
        id<MTLBuffer> glyphsBuffer = [device newBufferWithBytes:glyphBitfield length:glyphBitfieldSize * urlCount options:MTLResourceStorageModeManaged];
        free(glyphBitfield);
        
        id<MTLBuffer> outputBuffer = [device newBufferWithLength:sizeof(uint32_t) * urlCount options:MTLResourceStorageModeShared];

        id<MTLCommandQueue> commandQueue = [device newCommandQueue];

        id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
        [computeCommandEncoder setComputePipelineState:computePipelineState];
        id<MTLBuffer> buffers[] = {orderBuffer, glyphSizesBuffer, glyphsBuffer, outputBuffer};
        NSUInteger offsets[] = {0, 0, 0, 0};
        [computeCommandEncoder setBuffers:buffers offsets:offsets withRange:NSMakeRange(0, 4)];
        [computeCommandEncoder dispatchThreadgroups:MTLSizeMake(urlCount, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
        [computeCommandEncoder endEncoding];
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            NSLog(@"Complete");
            uint32_t* results = outputBuffer.contents;
            uint32_t result = 0;
            for (size_t i = 0; i < urlCount; ++i)
                result += results[i];
            NSLog(@"%" PRIu32, result);
        }];
        [commandBuffer commit];
    }
    return 0;
}
