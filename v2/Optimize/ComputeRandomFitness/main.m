//
//  main.m
//  ComputeRandomFitness
//
//  Created by Myles C. Maxfield on 1/21/20.
//  Copyright © 2020 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GlyphData.h"
#import "SingleFitness.h"
#import "Seeds.h"

void compute(SingleFitness *singleFitness, NSUInteger glyphCount, void (^callback)(NSMutableArray<NSNumber *> *), unsigned int count) {
    if (count == 0) {
        callback([NSMutableArray array]);
        return;
    }
    NSMutableArray<NSArray<NSNumber *> *> *array = [NSMutableArray arrayWithCapacity:1];
    [Seeds fillWithRandomSeeds:array withGlyphCount:glyphCount untilCount:1];
    [singleFitness computeFitness:array[0] withCallback:^(float fitness) {
        NSLog(@"Fitness: %f", fitness);
        compute(singleFitness, glyphCount, ^(NSMutableArray<NSNumber *> *results) {
            [results addObject:[NSNumber numberWithFloat:fitness]];
            callback(results);
        }, count - 1);
    }];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        SingleFitness *singleFitness = [[SingleFitness alloc] initWithGlyphData:glyphData];
        compute(singleFitness, glyphData.glyphCount, ^(NSMutableArray<NSNumber *> *results) {
            [results sortUsingComparator:^NSComparisonResult (NSNumber *obj1, NSNumber *obj2) {
                if (obj1.floatValue < obj2.floatValue)
                    return NSOrderedAscending;
                else if (obj1.floatValue == obj2.floatValue)
                    return NSOrderedSame;
                else {
                    assert(obj1.floatValue > obj2.floatValue);
                    return NSOrderedDescending;
                }
            }];
            for (NSNumber *number in results)
                NSLog(@"%f", number.floatValue);
            CFRunLoopStop(CFRunLoopGetMain());
        }, 100);
    }
    CFRunLoopRun();
    return 0;
}
