//
//  main.m
//  Prune
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <assert.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSData *urlDataContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Library/Mobile Documents/com~apple~CloudDocs/Documents/output_glyphs.json"];
        assert(urlDataContents != nil);
        NSError *error = nil;
        NSArray<NSDictionary<NSString *, id> *> *urlData = [NSJSONSerialization JSONObjectWithData:urlDataContents options:0 error:&error];
        assert(error == nil);
        assert(urlData != nil);

        NSData *glyphSizesContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Library/Mobile Documents/com~apple~CloudDocs/Documents/output_glyph_sizes.json"];
        assert(glyphSizesContents != nil);
        NSArray<NSNumber *> *glyphSizes = [NSJSONSerialization JSONObjectWithData:glyphSizesContents options:0 error:&error];
        assert(error == nil);
        assert(glyphSizes != nil);

        NSMutableSet<NSNumber *> *usedGlyphSet = [NSMutableSet setWithCapacity:glyphSizes.count];
        for (NSDictionary<NSString *, id> *urlInfo in urlData) {
            NSArray<NSNumber *> *usedGlyphs = urlInfo[@"Glyphs"];
            for (NSNumber *usedGlyph in usedGlyphs)
                [usedGlyphSet addObject:usedGlyph];
        }

        NSLog(@"%lu used glyphs.", (unsigned long)usedGlyphSet.count);

        int mapping[glyphSizes.count];
        int newID = 0;
        for (NSUInteger i = 0; i < glyphSizes.count; ++i) {
            if ([usedGlyphSet containsObject:[NSNumber numberWithUnsignedInteger:i]])
                mapping[i] = newID++;
            else
                mapping[i] = -1;
        }

        // Its important to discover this glyph -> unicode mapping this way, rather than doing it from the original source document.
        // This way, we incorporate things like the effects of shaping.
        NSURL *fontURL = [NSURL fileURLWithPath:@"/Users/litherum/src/Google Fonts/ofl/mplus1p/Mplus1p-Regular.ttf"];
        NSArray *fontDescriptors = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((CFURLRef)fontURL));
        assert(fontDescriptors.count == 1);
        CTFontDescriptorRef fontDescriptor = (__bridge CTFontDescriptorRef)fontDescriptors[0];
        CTFontRef font = CTFontCreateWithFontDescriptor(fontDescriptor, 0, NULL);
        CFIndex glyphCount = CTFontGetGlyphCount(font);
        int unicodeMapping[newID];
        for (CFIndex i = 0; i < newID; ++i)
            unicodeMapping[i] = -1;
        for (uint32_t i = 0; i < 0x110000; ++i) {
            NSString *characterString = [[NSString alloc] initWithBytes:&i length:sizeof(uint32_t) encoding:NSUTF32LittleEndianStringEncoding];
            if (characterString == nil)
                continue;
            UniChar uniChars[2];
            NSUInteger usedLength;
            NSRange remainingRange;
            BOOL success = [characterString getBytes:uniChars maxLength:sizeof(uniChars) usedLength:&usedLength encoding:NSUTF16LittleEndianStringEncoding options:0 range:NSMakeRange(0, characterString.length) remainingRange:&remainingRange];
            if (success == NO || remainingRange.length != 0)
                continue;
            CGGlyph glyphs[2] = {0, 0};
            CTFontGetGlyphsForCharacters(font, uniChars, glyphs, usedLength / sizeof(UniChar));
            CGGlyph glyph = glyphs[0];
            if (glyph == 0 || glyph == 0xFFFF || glyph >= glyphCount || mapping[glyph] < 0)
                continue;
            glyph = mapping[glyph];
            if (unicodeMapping[glyph] == -1)
                unicodeMapping[glyph] = i;
            else if (unicodeMapping[glyph] > 0 && unicodeMapping[glyph] != i)
                unicodeMapping[glyph] = -2;
        }
        CFRelease(font);

        NSMutableArray<NSDictionary<NSString *, id> *> *prunedURLData = [NSMutableArray arrayWithCapacity:urlData.count];
        for (NSDictionary<NSString *, id> *urlInfo in urlData) {
            NSString *url = urlInfo[@"URL"];
            NSArray<NSNumber *> *usedGlyphs = urlInfo[@"Glyphs"];
            NSMutableArray<NSNumber *> *mappedGlyphs = [NSMutableArray array];
            for (NSNumber *usedGlyph in usedGlyphs) {
                if (usedGlyph.intValue == 0xFFFF)
                    continue;
                assert(usedGlyph.intValue < glyphSizes.count);
                [mappedGlyphs addObject:[NSNumber numberWithInt:mapping[usedGlyph.intValue]]];
            }
            [prunedURLData addObject:@{@"URL" : url, @"Glyphs" : mappedGlyphs}];
        }
        
        NSMutableArray<NSNumber *> *prunedGlyphSizes = [NSMutableArray arrayWithCapacity:usedGlyphSet.count];
        for (NSUInteger i = 0; i < glyphSizes.count; ++i) {
            if ([usedGlyphSet containsObject:[NSNumber numberWithUnsignedInteger:i]]) {
                assert(prunedGlyphSizes.count == mapping[i]);
                [prunedGlyphSizes addObject:glyphSizes[i]];
            } else
                assert(mapping[i] == -1);
        }

        NSMutableArray<id> *glyphUnicodeMapping = [NSMutableArray arrayWithCapacity:glyphSizes.count];
        for (CFIndex i = 0; i < newID; ++i) {
            if (unicodeMapping[i] <= 0)
                [glyphUnicodeMapping addObject:[NSNull null]];
            else {
                uint32_t codePoint = unicodeMapping[i];
                [glyphUnicodeMapping addObject:[[NSString alloc] initWithBytes:&codePoint length:sizeof(uint32_t) encoding:NSUTF32LittleEndianStringEncoding]];
            }
        }

        NSData *data = [NSJSONSerialization dataWithJSONObject:prunedURLData options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/urlGlyphsPruned.json" atomically:NO];

        data = [NSJSONSerialization dataWithJSONObject:prunedGlyphSizes options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/gyphSizesPruned.json" atomically:NO];

        data = [NSJSONSerialization dataWithJSONObject:glyphUnicodeMapping options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/glyphUnicodeMapping.json" atomically:NO];
    }
    return 0;
}
