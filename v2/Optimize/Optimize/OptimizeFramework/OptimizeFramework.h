//
//  OptimizeFramework.h
//  OptimizeFramework
//
//  Created by Litherum on 11/1/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for OptimizeFramework.
FOUNDATION_EXPORT double OptimizeFrameworkVersionNumber;

//! Project version string for OptimizeFramework.
FOUNDATION_EXPORT const unsigned char OptimizeFrameworkVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <OptimizeFramework/PublicHeader.h>

@interface CostFunction: NSObject
- (instancetype)init;
- (void)loadData;
- (uint64_t)totalDataSize;
- (void)createResources;
@property NSUInteger glyphCount;
@property NSUInteger urlCount;
@property NSString *deviceName;
- (void)calculateAsync:(NSArray<NSNumber *> *)order callback:(void (^)(uint64_t))callback;
- (uint64_t)calculate:(NSArray<NSNumber *> *)order;
@end

