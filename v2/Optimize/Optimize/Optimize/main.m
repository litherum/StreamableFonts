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

NSArray<NSArray<NSNumber *> *> *seedGeneration(NSUInteger glyphCount) {
    NSUInteger populationCount = 10;
    NSMutableArray<NSArray<NSNumber *> *> *generation = [NSMutableArray arrayWithCapacity:populationCount];
    for (NSUInteger i = 0; i < populationCount; ++i) {
        NSMutableArray *availableEntries = [NSMutableArray arrayWithCapacity:glyphCount];
        for (NSUInteger j = 0; j < glyphCount; ++j)
            [availableEntries addObject:[NSNumber numberWithUnsignedInteger:j]];
        NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphCount];
        while (availableEntries.count > 0) {
            uint32_t index = arc4random_uniform((uint32_t)availableEntries.count);
            NSNumber *next = availableEntries[index];
            [availableEntries removeObjectAtIndex:index];
            [order addObject:next];
        }
        [generation addObject:order];
    }
    return generation;
}

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
    assert(parent0.count == parent1.count);
    return parent0;
}

NSArray<NSNumber *> *mutate(NSArray<NSNumber *> *child) {
    NSMutableArray<NSNumber *> *copy = [child mutableCopy];
    for (NSUInteger i = 0; i < child.count / 10; ++i) {
        uint32_t index0 = arc4random_uniform((uint32_t)copy.count);
        uint32_t index1 = arc4random_uniform((uint32_t)copy.count);
        NSNumber *temp = copy[index0];
        copy[index0] = copy[index1];
        copy[index1] = temp;
    }
    return copy;
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
        
        NSArray<NSArray<NSNumber *> *> *generation = seedGeneration(costFunction.glyphCount);

        unsigned long long best = 0;
        for (NSUInteger i = 0; i < 10; ++i) {
            NSArray<NSNumber *> *fitnesses = computeFitnesses(costFunction, generation);
            for (NSNumber *fitness in fitnesses) {
                if (fitness.unsignedLongLongValue > best)
                    best = fitness.unsignedLongLongValue;
            }
            NSLog(@"Best: %llu", best);

            unsigned long long sum = 0;
            for (NSUInteger i = 0; i < fitnesses.count; ++i)
                sum += fitnesses[i].unsignedLongLongValue;
            NSMutableArray<NSArray<NSNumber *> *> *newGeneration = [NSMutableArray arrayWithCapacity:generation.count];
            for (NSUInteger i = 0; i < generation.count; ++i) {
                NSArray<NSNumber *> *child = crossover(generation[weightedPick(fitnesses, sum)], generation[weightedPick(fitnesses, sum)]);
                child = mutate(child);
                [newGeneration addObject:child];
            }
            generation = newGeneration;
        }
    }
    return 0;
}
