//
//  SimulatedAnnealing.h
//  Optimize
//
//  Created by Myles C. Maxfield on 1/30/20.
//  Copyright © 2020 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "GlyphData.h"

@interface SimulatedAnnealing : NSObject
- (instancetype)initWithGlyphData:(GlyphData *)glyphData seeds:(NSArray<NSArray<NSNumber *> *> *)seeds;
- (float)simulate;
@end
