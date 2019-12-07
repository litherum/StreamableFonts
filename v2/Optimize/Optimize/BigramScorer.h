//
//  BigramScorer.h
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "GlyphData.h"

@interface BigramScorer : NSObject
- (instancetype)initWithGlyphData:(GlyphData *)glyphData;
- (void)computeWithCallback:(void (^)(NSArray<NSArray<NSNumber *> *> *))callback;
@end
