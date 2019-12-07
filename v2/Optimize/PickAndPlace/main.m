//
//  main.m
//  PickAndPlace
//
//  Created by Litherum on 12/6/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

@import Foundation;

#import "GlyphData.h"
#import "PickAndPlace.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        GlyphData *glyphData = [GlyphData new];
        PickAndPlace *pickAndPlace = [[PickAndPlace alloc] initWithGlyphData:glyphData];
    }
    return 0;
}
