//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TSMessage;
@class TSThread;
@class YapDatabaseReadTransaction;

@interface OWSMessageUtils : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)sharedManager;

- (NSUInteger)unreadMessagesCount;
- (NSUInteger)unreadMessageRequestCount;
- (NSUInteger)unreadMessagesCountExcept:(TSThread *)thread;

- (void)updateApplicationBadgeCount;

@end

NS_ASSUME_NONNULL_END
