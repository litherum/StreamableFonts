//
//  main.m
//  CodepointsToGlyphs
//
//  Created by Myles C. Maxfield on 10/31/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <assert.h>

static uint16_t bigEndianToLittleEndian16(uint16_t x) {
    return ((x & 0x00FF) << 8) | ((x & 0xFF00) >> 8);
}

static uint32_t bigEndianToLittleEndian32(uint32_t x) {
    return ((x & 0x0000FF) << 24) | ((x & 0x0000FF00) << 8) | ((x & 0x00FF0000) >> 8) | ((x & 0xFF000000) >> 24);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray <NSFontDescriptor *> *fontDescriptors = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((CFURLRef)[NSURL fileURLWithPath:@"/Users/litherum/src/Google Fonts/ofl/mplus1p/Mplus1p-Regular.ttf"]));
        assert(fontDescriptors.count == 1);
        NSFontDescriptor *fontDescriptor = fontDescriptors[0];
        NSFont *font = CFBridgingRelease(CTFontCreateWithFontDescriptor((CTFontDescriptorRef)fontDescriptor, 0, NULL));

        NSError *error = nil;

        {
            NSData *head = CFBridgingRelease(CTFontCopyTable((CTFontRef)font, kCTFontTableHead, kCTFontTableOptionNoOptions));
            uint16_t format;
            [head getBytes:(UInt8*)&format range:NSMakeRange(50, 2)];
            format = bigEndianToLittleEndian16(format);
            assert(format != 0); // Assume long offets for now
            
            NSData *maxp = CFBridgingRelease(CTFontCopyTable((CTFontRef)font, kCTFontTableMaxp, kCTFontTableOptionNoOptions));
            uint16_t numGlyphs;
            [maxp getBytes:(UInt8*)&numGlyphs range:NSMakeRange(4, 2)];
            numGlyphs = bigEndianToLittleEndian16(numGlyphs);
            assert(numGlyphs == [font numberOfGlyphs]);

            NSLog(@"%" PRIu16 " glyphs in the font", numGlyphs);

            uint32_t offsets[numGlyphs + 1];
            NSData *loca = CFBridgingRelease(CTFontCopyTable((CTFontRef)font, kCTFontTableLoca, kCTFontTableOptionNoOptions));
            for (uint16_t i = 0; i < numGlyphs + 1; ++i) {
                [loca getBytes:(UInt8*)(offsets + i) range:NSMakeRange(i * 4, 4)];
                offsets[i] = bigEndianToLittleEndian32(offsets[i]);
            }

            // FIXME: Flatten compound glyphs
            
            NSMutableArray *result = [NSMutableArray arrayWithCapacity:numGlyphs];
            for (uint16_t i = 0; i < numGlyphs; ++i)
                [result addObject:[NSNumber numberWithUnsignedInt:offsets[i + 1] - offsets[i]]];
            NSData *serializedResult = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
            assert(error == nil);
            [serializedResult writeToFile:@"output_glyph_sizes.json" atomically:NO];
        }

        {
            NSData *jsonContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Downloads/apache-nutch-1.16/output.json"];
            assert(jsonContents != nil);
            NSArray<NSDictionary<NSString *, NSString *> *> *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonContents options:0 error:&error];
            assert(error == nil);
            assert(jsonArray != nil);
            NSMutableArray *result = [NSMutableArray arrayWithCapacity:jsonArray.count];
            for (NSDictionary<NSString *, NSString *> *jsonDictionary in jsonArray) {
                NSString *url = jsonDictionary[@"URL"];
                NSString *text = jsonDictionary[@"Contents"];
                NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName : font}];
                CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attributedString);
                CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                CFIndex runCount = CFArrayGetCount(glyphRuns);
                NSMutableSet *glyphSet = [NSMutableSet set];
                for (CFIndex i = 0; i < runCount; ++i) {
                    CTRunRef glyphRun = CFArrayGetValueAtIndex(glyphRuns, i);
                    NSDictionary *runAttributes = (NSDictionary *)CTRunGetAttributes(glyphRun);
                    NSFont *usedFont = runAttributes[NSFontAttributeName];
                    if (![font isEqual:usedFont])
                        continue;
                    CFIndex glyphCount = CTRunGetGlyphCount(glyphRun);
                    CGGlyph glyphs[glyphCount];
                    CTRunGetGlyphs(glyphRun, CFRangeMake(0, glyphCount), glyphs);
                    for (CFIndex j = 0; j < glyphCount; ++j)
                        [glyphSet addObject:[NSNumber numberWithUnsignedShort:glyphs[j]]];
                }
                [result addObject:@{@"URL" : url, @"Glyphs" : [glyphSet allObjects]}];
                NSLog(@"%@: %lu unique glyphs", url, (unsigned long)[glyphSet count]);
                CFRelease(line);
            }
            NSLog(@"%lu pages", (unsigned long)jsonArray.count);
            NSData *serializedResult = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
            assert(error == nil);
            [serializedResult writeToFile:@"output_glyphs.json" atomically:NO];
        }
    }
    return 0;
}
