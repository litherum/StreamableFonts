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
- (float)computeFitnessWithTransformationMatrix:(NSArray<NSNumber *> *)transformationMatrix;
- (void)computeFitness:(NSArray<NSNumber *> *)order withCallback:(void (^)(float))callback;
@property NSUInteger dimension;

@end
