//
//  main.m
//  ParticleSystem
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Foundation;

#import "TupleScores.h"
#import "ParticleSimulation.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        TupleScores *tupleScores = [[TupleScores alloc] initWithBigramScores];
        ParticleSimulation *particleSimulation = [[ParticleSimulation alloc] initWithTupleScores:tupleScores];
        NSDate *start = [NSDate date];
        [particleSimulation runIterations:1 withCallback:^void (void) {
            NSDate *end = [NSDate date];
            NSLog(@"Complete. %f ms", [end timeIntervalSinceDate:start] * 1000);
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        CFRunLoopRun();
    }
    return 0;
}
