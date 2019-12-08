//
//  main.m
//  PickAndPlace
//
//  Created by Litherum on 12/6/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Foundation;

#import "GlyphData.h"
#import "Seeds.h"
#import "PickAndPlace.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        Seeds *seeds = [Seeds new];
        PickAndPlace *pickAndPlace = [[PickAndPlace alloc] initWithGlyphData:glyphData andSeeds:seeds.seeds];
        NSUInteger indexCount = 1;
        NSMutableArray<NSNumber *> *indices = [NSMutableArray arrayWithCapacity:indexCount];
        for (NSUInteger i = 0; i < indexCount; ++i)
            [indices addObject:[NSNumber numberWithUnsignedInt:arc4random_uniform((uint32_t)glyphData.glyphCount)]];
        NSDate *start = [NSDate date];
        [pickAndPlace runWithGlyphIndices:indices andCallback:^void (void) {
            NSDate *end = [NSDate date];
            NSLog(@"Complete. %f ms", [end timeIntervalSinceDate:start] * 1000);
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        CFRunLoopRun();
    }
    return 0;
}
