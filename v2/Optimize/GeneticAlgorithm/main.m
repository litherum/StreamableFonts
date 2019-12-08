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
        [geneticAlgorithm runIterations:10 withCallback:^void (void) {
            NSLog(@"Complete.");
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        CFRunLoopRun();
    }
    return 0;
}
