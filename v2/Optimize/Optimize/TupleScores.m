//
//  TupleScores.m
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import "TupleScores.h"

@implementation TupleScores

- (instancetype)initWithBigramScores
{
    self = [super init];
    
    if (self != nil) {
        NSData *seedsContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Library/Mobile Documents/com~apple~CloudDocs/Documents/BigramScores.json"];
        assert(seedsContents != nil);
        NSError *error = nil;
        _tupleScores = [NSJSONSerialization JSONObjectWithData:seedsContents options:0 error:&error];
        assert(error == nil);
        assert(self.tupleScores != nil);
    }

    return self;
}

- (instancetype)initWithFastTextScores
{
    self = [super init];
    
    if (self != nil) {
        NSData *seedsContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Library/Mobile Documents/com~apple~CloudDocs/Documents/semanticDistances.json"];
        assert(seedsContents != nil);
        NSError *error = nil;
        _tupleScores = [NSJSONSerialization JSONObjectWithData:seedsContents options:0 error:&error];
        assert(error == nil);
        assert(self.tupleScores != nil);
    }

    return self;
}

@end
