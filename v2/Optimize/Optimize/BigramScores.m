//
//  BigramScores.m
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import "BigramScores.h"

@implementation BigramScores

- (instancetype)init
{
    self = [super init];
    
    if (self != nil) {
        NSData *seedsContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Library/Mobile Documents/com~apple~CloudDocs/Documents/bigramScores.json"];
        assert(seedsContents != nil);
        NSError *error = nil;
        _bigramScores = [NSJSONSerialization JSONObjectWithData:seedsContents options:0 error:&error];
        assert(error == nil);
        assert(self.bigramScores != nil);
    }

    return self;
}

@end
