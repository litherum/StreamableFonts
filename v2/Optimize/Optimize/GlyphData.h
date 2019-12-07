//
//  GlyphData.h
//  Optimize
//
//  Created by Litherum on 12/6/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

@interface GlyphData : NSObject
- (instancetype)init;
- (void)dealloc;
@property (readonly) NSArray<NSDictionary<NSString *, id> *> *urlData;
@property (readonly) NSArray<NSNumber *> *glyphSizes;
@property (readonly) uint32_t* urlBitmaps;
@property (readonly) NSUInteger glyphCount;
@property (readonly) NSUInteger glyphBitfieldSize;
@property (readonly) NSUInteger urlCount;
@end
