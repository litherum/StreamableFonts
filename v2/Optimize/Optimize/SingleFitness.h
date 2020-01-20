//
//  SingleFitness.h
//  Optimize
//
//  Created by Myles C. Maxfield on 12/17/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "GlyphData.h"

@interface SingleFitness : NSObject

- (instancetype)initWithGlyphData:(GlyphData *)glyphData;
- (float)computeFitness:(NSArray<NSNumber *> *)transformationMatrix;
@property NSUInteger dimension;

@end
