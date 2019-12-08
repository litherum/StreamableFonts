//
//  ParticleSimulation.h
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "BigramScores.h"

@interface ParticleSimulation : NSObject
- (instancetype)initWithBigramScores:(BigramScores *)bigramScores;
- (void)runIterations:(unsigned)iterations withCallback:(void (^)(void))callback;
@end
