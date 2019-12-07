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

        NSData *data = [NSJSONSerialization dataWithJSONObject:prunedURLData options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/urlGlyphsPruned.json" atomically:NO];

        data = [NSJSONSerialization dataWithJSONObject:prunedGlyphSizes options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/gyphSizesPruned.json" atomically:NO];
    }
    return 0;
}
