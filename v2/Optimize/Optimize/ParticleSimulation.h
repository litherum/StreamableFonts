//
//  ParticleSimulation.h
//  Optimize
//
//  Created by Litherum on 12/5/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#pragma once

@import Foundation;

#import "TupleScores.h"

@interface ParticleSimulation : NSObject
- (instancetype)initWithTupleScores:(TupleScores *)tupleScores;
- (void)runIterations:(unsigned)iterations withCallback:(void (^)(void))callback;
@end
