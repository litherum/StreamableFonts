//
//  main.m
//  Optimize
//
//  Created by Litherum on 11/3/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OptimizeFramework.h"
#import <assert.h>

NSArray<NSNumber *> *computeFitnesses(CostFunction *costFunction, NSArray<NSArray<NSNumber *> *> *generation) {
    NSMutableArray<NSNumber *> *fitnesses = [NSMutableArray arrayWithCapacity:generation.count];
    __block NSUInteger count = 0;
    for (NSUInteger i = 0; i < generation.count; ++i) {
        [fitnesses addObject:[NSNumber numberWithInt:0]];
        [costFunction calculateAsync:generation[i] callback:^void (uint64_t result) {
            assert(costFunction.totalDataSize >= result);
            result = costFunction.totalDataSize - result;
            fitnesses[i] = [NSNumber numberWithUnsignedLongLong:result];
            if (++count == generation.count)
                CFRunLoopStop(CFRunLoopGetMain());
        }];
    }
    CFRunLoopRun();
    return fitnesses;
}

NSUInteger weightedPick(NSArray<NSNumber *> *fitnesses, unsigned long long sum) {
    double pick = drand48();
    double partial = 0;
    for (NSUInteger i = 0; i < fitnesses.count; ++i) {
        partial += (double)fitnesses[i].unsignedLongLongValue / (double)sum;
        if (pick < partial)
            return i;
    }
    return fitnesses.count - 1;
}

NSArray<NSNumber *> *crossover(NSArray<NSNumber *> *parent0, NSArray<NSNumber *> *parent1) {
    return parent0;
}

NSArray<NSNumber *> *mutate(NSArray<NSNumber *> *child) {
    return child;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CostFunction *costFunction = [[CostFunction alloc] init];
        [costFunction loadData];
        [costFunction createResources];
        /*
        NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:costFunction.glyphCount];
        for (NSUInteger i = 0; i < costFunction.glyphCount; ++i)
            [order addObject:[NSNumber numberWithUnsignedInteger:i]];
        [costFunction calculate:order];
        */
        
        NSUInteger populationCount = 10;
        NSMutableArray<NSArray<NSNumber *> *> *generation = [NSMutableArray arrayWithCapacity:populationCount];
        for (NSUInteger i = 0; i < populationCount; ++i) {
            NSMutableArray *availableEntries = [NSMutableArray arrayWithCapacity:costFunction.glyphCount];
            for (NSUInteger j = 0; j < costFunction.glyphCount; ++j)
                [availableEntries addObject:[NSNumber numberWithUnsignedInteger:j]];
            NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:costFunction.glyphCount];
            while (availableEntries.count > 0) {
                uint32_t index = arc4random_uniform((uint32_t)availableEntries.count);
                NSNumber *next = availableEntries[index];
                [availableEntries removeObjectAtIndex:index];
                [order addObject:next];
            }
            [generation addObject:order];
        }

        NSArray<NSNumber *> *fitnesses = computeFitnesses(costFunction, generation);
        NSLog(@"%@", fitnesses);

        unsigned long long sum = 0;
        for (NSUInteger i = 0; i < fitnesses.count; ++i)
            sum += fitnesses[i].unsignedLongLongValue;
        NSMutableArray<NSArray<NSNumber *> *> *newGeneration = [NSMutableArray arrayWithCapacity:generation.count];
        for (NSUInteger i = 0; i < generation.count; ++i) {
            NSArray<NSNumber *> *child = crossover(generation[weightedPick(fitnesses, sum)], generation[weightedPick(fitnesses, sum)]);
            child = mutate(child);
            [newGeneration addObject:child];
        }
    }
    return 0;
}
