//
//  main.m
//  SemanticDistances
//
//  Created by Litherum on 12/8/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FastText/FastText.h>
#import <string>
#import <cassert>

static std::string convertSingleCodePointString(NSString *string) {
    char codeUnits[5];
    NSUInteger usedLength;
    NSRange remainingRange;
    BOOL success = [string getBytes:codeUnits maxLength:sizeof(codeUnits) usedLength:&usedLength encoding:NSUTF8StringEncoding options:0 range:NSMakeRange(0, string.length) remainingRange:&remainingRange];
    assert(success == YES);
    assert(remainingRange.length == 0);
    return std::string(codeUnits, sizeof(codeUnits));
}

static float distance(const fasttext::Vector& vector1, const fasttext::Vector& vector2) {
    assert(vector1.size() == vector2.size());
    float distance = 0;
    for (int64_t i = 0; i < vector1.size(); ++i)
        distance += (vector1[i] - vector2[i]) * (vector1[i] - vector2[i]);
    return distance;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSData *mappingContents = [NSData dataWithContentsOfFile:@"/Users/litherum/Library/Mobile Documents/com~apple~CloudDocs/Documents/glyphUnicodeMapping.json"];
        assert(mappingContents != nil);
        NSError *error = nil;
        NSArray<id> *mapping = [NSJSONSerialization JSONObjectWithData:mappingContents options:0 error:&error];
        assert(error == nil);
        assert(mapping != nil);

        NSMutableArray<id> *vectors = [NSMutableArray arrayWithCapacity:mapping.count];
        fasttext::FastText fastText;
        fastText.loadModel("/Users/litherum/Downloads/cc.zh.300.bin");
        for (id object in mapping) {
            if ([object isEqual:[NSNull null]]) {
                [vectors addObject:[NSNull null]];
                continue;
            }
            NSString *string = object;
            fasttext::Vector fastTextVector(fastText.getDimension());
            std::string word = convertSingleCodePointString(string);
            fastText.getWordVector(fastTextVector, word);
            NSMutableArray<NSNumber *> *vector = [NSMutableArray arrayWithCapacity:fastText.getDimension()];
            for (int64_t i = 0; i < fastTextVector.size(); ++i)
                [vector addObject:[NSNumber numberWithFloat:fastTextVector[i]]];
            [vectors addObject:vector];
        }

        NSMutableArray<NSMutableArray<NSNumber *> *> *distances = [NSMutableArray arrayWithCapacity:mapping.count];
        for (NSUInteger i = 0; i < mapping.count; ++i) {
            NSMutableArray<NSNumber *> *row = [NSMutableArray arrayWithCapacity:mapping.count];
            for (NSUInteger j = 0; j < mapping.count; ++j)
                [row addObject:[NSNumber numberWithFloat:0]];
            [distances addObject:row];
        }
        for (NSUInteger i = 0; i < mapping.count; ++i) {
            id object1 = mapping[i];
            if ([object1 isEqual:[NSNull null]]) {
                for (NSUInteger j = i + 1; j < mapping.count; ++j) {
                    distances[i][j] = [NSNumber numberWithFloat:-1];
                    distances[j][i] = [NSNumber numberWithFloat:-1];
                }
            } else {
                NSString *string1 = object1;
                fasttext::Vector vector1(fastText.getDimension());
                std::string word1 = convertSingleCodePointString(string1);
                fastText.getWordVector(vector1, word1);
                for (NSUInteger j = i + 1; j < mapping.count; ++j) {
                    id object2 = mapping[j];
                    if ([object2 isEqual:[NSNull null]]) {
                        distances[i][j] = [NSNumber numberWithFloat:-1];
                        distances[j][i] = [NSNumber numberWithFloat:-1];
                    } else {
                        NSString *string2 = object2;
                        fasttext::Vector vector2(fastText.getDimension());
                        std::string word2 = convertSingleCodePointString(string2);
                        fastText.getWordVector(vector2, word2);
                        float distance = ::distance(vector1, vector2);
                        distances[i][j] = [NSNumber numberWithFloat:distance];
                        distances[j][i] = [NSNumber numberWithFloat:distance];
                    }
                }
            }
            NSLog(@"%lu", (unsigned long)i);
        }

        NSData *data = [NSJSONSerialization dataWithJSONObject:vectors options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/glyphVectors.json" atomically:NO];

        data = [NSJSONSerialization dataWithJSONObject:distances options:0 error:&error];
        assert(error == nil);
        [data writeToFile:@"/Users/litherum/Documents/semanticDistances.json" atomically:NO];
    }
    return 0;
}
