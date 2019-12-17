//
//  main.m
//  ScoreBigrams
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Foundation;

#import "Optimize/GlyphData.h"
#import "BigramScorer.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        BigramScorer *bigramScorer = [[BigramScorer alloc] initWithGlyphData:glyphData];
        [bigramScorer computeWithCallback:^void (NSArray<NSArray<NSNumber *> *> *bigramScores) {
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:bigramScores options:0 error:&error];
            assert(error == nil);
            [data writeToFile:@"/Users/litherum/Documents/BigramScores.json" atomically:NO];
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        CFRunLoopRun();
    }
    return 0;
}
