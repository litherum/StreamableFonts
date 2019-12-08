//
//  PickAndPlace.h
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "GlyphData.h"

@interface PickAndPlace : NSObject
- (instancetype)initWithGlyphData:(GlyphData *)glyphData andSeeds:(NSArray<NSArray<NSNumber *> *> *)seeds;
- (void)runWithGlyphIndices:(NSArray<NSNumber *> *)indices andCallback:(void (^)(void))callback;
@end
