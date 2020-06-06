//
//  ComputeGlyphSizes.m
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/6/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <Optimizer/Optimizer-Swift.h>

// FIXME: This file shouldn't be necessary.

@interface ExposedGlyphSizes: NSObject
@property NSInteger fontSize;
@property NSArray<NSNumber *> *glyphSizes;
@end

@implementation ExposedGlyphSizes
@end

@interface ExposedGlyphSizeComputer: NSObject
- (instancetype)initWithFont:(CTFontRef)font;
- (ExposedGlyphSizes *)computeGlyphSizes;
@end

@implementation ExposedGlyphSizeComputer {
    CTFontRef font;
}
- (instancetype)initWithFont:(CTFontRef)font
{
    self = [super init];
    if (self != nil) {
        self->font = CFRetain(font);
    }
    return self;
}

- (ExposedGlyphSizes *)computeGlyphSizes
{
    GlyphSizes *data = [GlyphSizesComputer computeGlyphSizesWithFont:font];

    ExposedGlyphSizes *result = [ExposedGlyphSizes new];
    result.fontSize = data.fontSize;
    NSMutableArray<NSNumber *> *glyphSizes = [[NSMutableArray alloc] initWithCapacity:data.glyphSizes.count];
    for (NSNumber *glyphSize in data.glyphSizes) {
        [glyphSizes addObject:[NSNumber numberWithInteger:glyphSize.integerValue]];
    }
    result.glyphSizes = glyphSizes;
    return result;
}

- (void)dealloc {
    CFRelease(font);
}
@end
