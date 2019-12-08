//
//  GeneticAlgorithm.h
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "GlyphData.h"

@interface GeneticAlgorithm : NSObject
- (instancetype)initWithGlyphData:(GlyphData *)glyphData andSeeds:(NSArray<NSArray<NSNumber *> *> *)seeds;
- (void)runIterations:(unsigned)iteration withCallback:(void (^)(void))callback;
@end
