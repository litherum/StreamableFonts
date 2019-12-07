//
//  BigramScores.h
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "GlyphData.h"

@interface BigramScores : NSObject
- (instancetype)init;
@property (readonly) NSArray<NSArray<NSNumber *> *> *bigramScores;
@end
