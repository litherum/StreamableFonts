//
//  main.m
//  GeneticAlgorithm
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Foundation;

#import "GlyphData.h"
#import "Seeds.h"
#import "GeneticAlgorithm.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        Seeds *seeds = [Seeds new];
        GeneticAlgorithm *geneticAlgorithm = [[GeneticAlgorithm alloc] initWithGlyphData:glyphData andSeeds:seeds.seeds];
        NSDate *start = [NSDate date];
        [geneticAlgorithm runIterations:1 withCallback:^void (void) {
            NSDate *end = [NSDate date];
            NSLog(@"Complete. %f ms", [end timeIntervalSinceDate:start] * 1000);
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        CFRunLoopRun();
    }
    return 0;
}
