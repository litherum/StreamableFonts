//
//  Seeds.m
//  Optimize
//
//  Created by Litherum on 12/7/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import "Seeds.h"

@implementation Seeds

- (instancetype)init
{
    self = [super init];
    
    if (self != nil) {
        NSData *seedsContents = [NSData dataWithContentsOfFile:@"/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/seeds.json"];
        assert(seedsContents != nil);
        NSError *error = nil;
        _seeds = [NSJSONSerialization JSONObjectWithData:seedsContents options:0 error:&error];
        assert(error == nil);
        assert(self.seeds != nil);
    }

    return self;
}

- (instancetype)initWithGlyphData:(GlyphData *)glyphData andTupleScores:(NSArray<NSArray<NSNumber *> *> *)tupleScores
{
    self = [super init];

    if (self != nil) {        
        NSMutableArray<NSArray<NSNumber *> *> *result = [NSMutableArray array];
        [result addObject:[self frequencyOrderWithGlyphData:glyphData andTupleScores:tupleScores]];
        [result addObject:[self mostRecentBuddyOrderWithGlyphData:glyphData andTupleScores:tupleScores]];
        [result addObject:[self allPlacedBuddyOrderWithGlyphData:glyphData andTupleScores:tupleScores]];
        [result addObject:[self allBuddyOrderWithGlyphData:glyphData andTupleScores:tupleScores]];
        // FIXME: Consider a sliding window approach, to interpolate between the two above approaches.
        _seeds = result;
    }

    return self;
}

- (NSArray<NSNumber *> *)frequencyOrderWithGlyphData:(GlyphData *)glyphData andTupleScores:(NSArray<NSArray<NSNumber *> *> *)tupleScores
{
    // Pick the most frequent glyph.
    uint32_t frequency[glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i)
        frequency[i] = 0;
    for (NSDictionary<NSString *, id> *urlInfo in glyphData.urlData) {
        NSArray<NSNumber *> *glyphs = urlInfo[@"Glyphs"];
        for (NSNumber *glyph in glyphs) {
            if (glyph.unsignedShortValue == 0xFFFF)
                continue;
            assert(glyph.unsignedShortValue < glyphData.glyphCount);
            ++frequency[glyph.unsignedShortValue];
        }
    }
    NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphData.glyphCount];
    NSMutableSet<NSNumber *> *spent = [NSMutableSet setWithCapacity:glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i) {
        uint32_t bestIndex = 0;
        uint32_t best = 0;
        for (uint32_t j = 0; j < glyphData.glyphCount; ++j) {
            if ([spent containsObject:[NSNumber numberWithUnsignedInt:j]])
                continue;
            if (frequency[j] >= best) {
                best = frequency[j];
                bestIndex = j;
            }
        }
        [spent addObject:[NSNumber numberWithUnsignedInt:bestIndex]];
        [order addObject:[NSNumber numberWithUnsignedInt:bestIndex]];
    }
    return order;
}

- (uint32_t)seedGlyphFromTupleScores:(NSArray<NSArray<NSNumber *> *> *)tupleScores andGlyphCount:(NSUInteger)glyphCount
{
    // There are probably a lot of 1.0 scores which tie for best.
    // We could be more sophisticated here and pick the glyph which is in the most number of documents, or something.
    float bestScore = 0;
    uint32_t bestGlyph = 0;
    for (uint32_t i = 0; i < glyphCount; ++i) {
        NSArray<NSNumber *> *row = tupleScores[i];
        for (uint32_t j = 0; j < glyphCount; ++j) {
            if (i == j)
                continue;
            float score = row[j].floatValue;
            if (score >= bestScore) {
                bestScore = score;
                bestGlyph = i;
            }
        }
    }
    return bestGlyph;
}

- (NSArray<NSNumber *> *)mostRecentBuddyOrderWithGlyphData:(GlyphData *)glyphData andTupleScores:(NSArray<NSArray<NSNumber *> *> *)tupleScores
{
    // Pick the best buddy of the most-recently-placed glyph.
    NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphData.glyphCount];
    BOOL spent[glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i)
        spent[i] = NO;
    uint32_t currentGlyph = [self seedGlyphFromTupleScores:tupleScores andGlyphCount:glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i) {
        [order addObject:[NSNumber numberWithUnsignedInt:currentGlyph]];
        spent[currentGlyph] = YES;
        float bestScore = 0;
        uint32_t bestGlyph = (uint32_t)glyphData.glyphCount;
        for (uint32_t j = 0; j < glyphData.glyphCount; ++j) {
            if (spent[j])
                continue;
            float score = tupleScores[currentGlyph][j].floatValue;
            if (score >= bestScore) {
                bestScore = score;
                bestGlyph = j;
            }
        }
        currentGlyph = bestGlyph;
    }
    return order;
}

- (NSArray<NSNumber *> *)allPlacedBuddyOrderWithGlyphData:(GlyphData *)glyphData andTupleScores:(NSArray<NSArray<NSNumber *> *> *)tupleScores
{
    // Pick the best buddy of any of the placed glyphs.
    uint32_t orderData[glyphData.glyphCount];
    uint32_t candidates[glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i)
        candidates[i] = i;
    uint32_t currentGlyph = [self seedGlyphFromTupleScores:tupleScores andGlyphCount:glyphData.glyphCount];
    uint32_t candidateIndex = currentGlyph;
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i) {
        orderData[i] = currentGlyph;

        for (uint32_t j = candidateIndex; j < glyphData.glyphCount - i - 1; ++j)
            candidates[j] = candidates[j + 1];

        float bestScore = 0;
        uint32_t bestGlyph = (uint32_t)glyphData.glyphCount;
        candidateIndex = 0;
        for (uint32_t j = 0; j < i + 1; ++j) {
            uint32_t placedGlyph = orderData[j];
            for (uint32_t j = 0; j < glyphData.glyphCount - i - 1; ++j) {
                float score = tupleScores[placedGlyph][candidates[j]].floatValue;
                if (score >= bestScore) {
                    bestScore = score;
                    bestGlyph = candidates[j];
                    candidateIndex = j;
                }
            }
        }
        NSLog(@"Best score: %" PRIu32 " %f", i, bestScore);
        currentGlyph = bestGlyph;
    }
    NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i)
        [order addObject:[NSNumber numberWithUnsignedInt:orderData[i]]];
    return order;
}

- (NSArray<NSNumber *> *)allBuddyOrderWithGlyphData:(GlyphData *)glyphData andTupleScores:(NSArray<NSArray<NSNumber *> *> *)tupleScores
{
    // Best bigram score, regardless of what's already been placed
    float bestScores[glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i) {
        bestScores[i] = 0;
        NSArray<NSNumber *> *row = tupleScores[i];
        for (uint32_t j = 0; j < glyphData.glyphCount; ++j) {
            if (i == j)
                continue;
            float score = row[j].floatValue;
            if (score > bestScores[i])
                bestScores[i] = score;
        }
    }
    NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphData.glyphCount];
    for (uint32_t i = 0; i < glyphData.glyphCount; ++i) {
        float best = 0;
        uint32_t bestIndex = 0;
        for (uint32_t j = 0; j < glyphData.glyphCount; ++j) {
            if (best <= bestScores[j]) {
                best = bestScores[j];
                bestIndex = j;
            }
        }
        [order addObject:[NSNumber numberWithUnsignedInt:bestIndex]];
        bestScores[bestIndex] = -1;
    }
    return order;
}

+ (void)fillWithRandomSeeds:(NSMutableArray<NSArray<NSNumber *> *> *)array withGlyphCount:(NSUInteger)glyphCount untilCount:(NSUInteger)count
{
    assert(array.count <= count);
    while (array.count < count) {
        NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:glyphCount];
        NSMutableArray<NSNumber *> *candidates = [NSMutableArray arrayWithCapacity:glyphCount];
        for (uint32_t j = 0; j < glyphCount; ++j)
            [candidates addObject:[NSNumber numberWithUnsignedInt:j]];
        for (uint32_t j = 0; j < glyphCount; ++j) {
            assert(candidates.count == glyphCount - j);
            uint32_t index = arc4random_uniform((uint32_t)glyphCount - j);
            [order addObject:candidates[index]];
            [candidates removeObjectAtIndex:index];
        }
        [array addObject:order];
    }
}

@end
