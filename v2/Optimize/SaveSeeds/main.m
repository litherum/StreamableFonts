//
//  main.m
//  SaveSeeds
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Foundation;

#import "Seeds.h"
#import "BigramScores.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        BigramScores *bigramScores = [BigramScores new];
        Seeds *seeds = [[Seeds alloc] initWithGlyphData:glyphData andBigramScores:bigramScores.bigramScores];
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:seeds.seeds options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/seeds.json" atomically:NO];
    }
    return 0;
}
