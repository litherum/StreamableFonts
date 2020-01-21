//
//  GlyphData.m
//  Optimize
//
//  Created by Litherum on 12/6/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <assert.h>
#import "GlyphData.h"

@implementation GlyphData

- (instancetype)init
{
    self = [super init];

    if (self != nil) {
        NSData *urlDataContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/urlGlyphsPruned.json"];
        assert(urlDataContents != nil);
        NSError *error = nil;
        _urlData = [NSJSONSerialization JSONObjectWithData:urlDataContents options:0 error:&error];
        assert(error == nil);
        assert(self.urlData != nil);

        NSData *glyphSizesContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/gyphSizesPruned.json"];
        assert(glyphSizesContents != nil);
        _glyphSizes = [NSJSONSerialization JSONObjectWithData:glyphSizesContents options:0 error:&error];
        assert(error == nil);
        assert(self.glyphSizes != nil);

        _urlBitmaps = malloc(self.urlCount * self.glyphBitfieldSize * sizeof(uint8_t));
        for (size_t i = 0; i < self.urlCount * self.glyphBitfieldSize; ++i)
            self.urlBitmaps[i] = 0;
        for (NSUInteger i = 0; i < self.urlCount; ++i) {
            uint8_t* bitfield = self.urlBitmaps + self.glyphBitfieldSize * i;
            NSDictionary<NSString *, id> *jsonDictionary = self.urlData[i];
            NSArray<NSNumber *> *glyphs = jsonDictionary[@"Glyphs"];
            for (NSNumber *glyph in glyphs) {
                if (glyph.unsignedShortValue == 0xFFFF)
                    continue;
                CGGlyph glyphValue = glyph.unsignedShortValue;
                assert(glyphValue < self.glyphCount);
                bitfield[glyphValue / 8] |= (1 << (glyphValue % 8));
            }
        }
    }

    return self;
}

- (void)dealloc
{
    free(_urlBitmaps);
}

- (NSUInteger)glyphCount
{
    return self.glyphSizes.count;
}

- (NSUInteger)glyphBitfieldSize
{
    return (self.glyphCount + 7) / 8;
}

- (NSUInteger)urlCount
{
    return MIN(1000, self.urlData.count);
}

@end
