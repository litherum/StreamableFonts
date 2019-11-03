//
//  main.m
//  Optimize
//
//  Created by Litherum on 11/3/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OptimizeFramework.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CostFunction *costFunction = [[CostFunction alloc] init];
        [costFunction loadData];
        
        NSUInteger originalURLCount = costFunction.urlCount;
        NSLog(@"Original glyph count: %lu", (unsigned long)originalURLCount);
        for (NSUInteger i = 1; i < originalURLCount; i += 1000) {
            costFunction.urlCount = i;
            [costFunction createResources];
            NSUInteger glyphCount = costFunction.glyphCount;
            NSMutableArray *order = [NSMutableArray arrayWithCapacity:glyphCount];
            for (NSUInteger i = 0; i < glyphCount; ++i)
                [order addObject:[NSNumber numberWithUnsignedInteger:i]];
            [costFunction calculate:order];
        }
    }
    return 0;
}
