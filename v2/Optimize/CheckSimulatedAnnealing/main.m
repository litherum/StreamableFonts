//
//  main.m
//  CheckSimulatedAnnealing
//
//  Created by Myles C. Maxfield on 1/30/20.
//  Copyright © 2020 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GlyphData.h"
#import "Seeds.h"
#import "SimulatedAnnealing.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        NSMutableArray<NSArray<NSNumber *> *> *seeds = [[Seeds new].seeds mutableCopy];
        [Seeds fillWithRandomSeeds:seeds withGlyphCount:glyphData.glyphCount untilCount:6];
        SimulatedAnnealing *simulatedAnnealing = [[SimulatedAnnealing alloc] initWithGlyphData:glyphData seeds:seeds exponent:0.25 maximumSlope:100000.0];
        float result = [simulatedAnnealing simulate];
        NSLog(@"Result: %f", result);
    }
    return 0;
}
