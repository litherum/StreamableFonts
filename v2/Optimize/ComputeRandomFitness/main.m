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

/*static NSArray<NSNumber *> *reverseArray(NSArray<NSNumber *> *array, NSUInteger index0, NSUInteger index1) {
    assert(index0 < array.count);
    assert(index1 < array.count);
    NSMutableArray<NSNumber *> *result = [array mutableCopy];
    if (index0 == index1)
        return result;
    int delta = index0 < index1 ? 1 : -1;
    for (NSUInteger i = index0; i != index1; i += delta)
        result[i] = array[(int)index1 - ((int)i - (int)index0)];
    result[index1] = array[index0];
    return result;
}*/

static NSArray<NSNumber *> *swapArray(NSArray<NSNumber *> *array, NSUInteger index0, NSUInteger index1) {
    assert(index0 < array.count);
    assert(index1 < array.count);
    NSMutableArray<NSNumber *> *result = [array mutableCopy];
    result[index0] = array[index1];
    result[index1] = array[index0];
    return result;
}

/*static NSArray<NSNumber *> *rotateArray(NSArray<NSNumber *> *array, NSUInteger index0, NSUInteger index1) {
    assert(index0 < array.count);
    assert(index1 < array.count);
    NSMutableArray<NSNumber *> *result = [array mutableCopy];
    if (index0 == index1)
        return result;
    int delta = index0 < index1 ? 1 : -1;
    NSNumber *store = result[index0];
    for (NSUInteger i = index0; i != index1; i += delta)
        result[i] = result[i + delta];
    result[index1] = store;
    return result;
}*/

/*static void computeRotationFitnesses(SingleFitness *singleFitness, NSArray<NSNumber *> *seed, NSUInteger count, void (^callback)(NSMutableArray<NSNumber *> *)) {
    if (count == 10000) {
        callback([NSMutableArray array]);
        return;
    }
    [singleFitness computeFitness:swapArray(seed, arc4random_uniform((uint32_t)seed.count), arc4random_uniform((uint32_t)seed.count)) withCallback:^(float fitness) {
        computeRotationFitnesses(singleFitness, seed, count + 1, ^(NSMutableArray<NSNumber *> *results) {
            [results addObject:[NSNumber numberWithFloat:fitness]];
            callback(results);
        });
    }];
}

static void compute10Best(SingleFitness *singleFitness, NSUInteger glyphCount, NSUInteger count, void (^callback)(NSMutableArray<NSNumber *> *)) {
    if (count == 10) {
        callback([NSMutableArray array]);
        return;
    }
    
    NSMutableArray<NSArray<NSNumber *> *> *array = [NSMutableArray arrayWithCapacity:1];
    [Seeds fillWithRandomSeeds:array withGlyphCount:glyphCount untilCount:1];
    NSArray<NSNumber *> *seed = array[0];
    [singleFitness computeFitness:seed withCallback:^(float originalFitness) {
        computeRotationFitnesses(singleFitness, seed, 0, ^(NSMutableArray<NSNumber *> *results) {
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
            float best = results[results.count - 1].floatValue;
            NSLog(@"%f", best - originalFitness);
            compute10Best(singleFitness, glyphCount, count + 1, ^(NSMutableArray<NSNumber *> *results) {
                [results addObject:[NSNumber numberWithFloat:best - originalFitness]];
                callback(results);
            });
        });
    }];
}

static void computeRandomFitnesses(SingleFitness *singleFitness, NSUInteger glyphCount, void (^callback)(NSMutableArray<NSNumber *> *), unsigned int count) {
    if (count == 0) {
        callback([NSMutableArray array]);
        return;
    }
    NSMutableArray<NSArray<NSNumber *> *> *array = [NSMutableArray arrayWithCapacity:1];
    [Seeds fillWithRandomSeeds:array withGlyphCount:glyphCount untilCount:1];
    [singleFitness computeFitness:array[0] withCallback:^(float fitness) {
        NSLog(@"Fitness: %f", fitness);
        computeRandomFitnesses(singleFitness, glyphCount, ^(NSMutableArray<NSNumber *> *results) {
            [results addObject:[NSNumber numberWithFloat:fitness]];
            callback(results);
        }, count - 1);
    }];
}*/

static void walk(SingleFitness *singleFitness, NSUInteger count, NSArray<NSNumber *> *order, float orderFitness, void (^callback)(void)) {
    if (count == 100000) {
        callback();
        return;
    }
    NSArray<NSNumber *> *perterbedOrder = swapArray(order, arc4random_uniform((uint32_t)order.count), arc4random_uniform((uint32_t)order.count));
    [singleFitness computeFitness:perterbedOrder withCallback:^(float fitness) {
        if (fitness > orderFitness) {
            NSLog(@"%f", fitness);
            walk(singleFitness, count + 1, perterbedOrder, fitness, callback);
        } else {
            walk(singleFitness, count + 1, order, orderFitness, callback);
        }
    }];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        SingleFitness *singleFitness = [[SingleFitness alloc] initWithGlyphData:glyphData];
        Seeds *seeds = [Seeds new];
        //NSMutableArray<NSArray<NSNumber *> *> *array = [NSMutableArray arrayWithCapacity:1];
        //[Seeds fillWithRandomSeeds:array withGlyphCount:glyphData.glyphCount untilCount:1];
        NSArray<NSNumber *> *seed = seeds.seeds[0];
        [singleFitness computeFitness:seed withCallback:^(float fitness) {
            walk(singleFitness, 0, seed, fitness, ^(void) {
                CFRunLoopStop(CFRunLoopGetMain());
            });
        }];
    }
    CFRunLoopRun();
    return 0;
}
