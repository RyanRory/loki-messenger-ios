//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "OWSPreferences.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSPreferencesSignalDatabaseCollection = @"SignalPreferences";
NSString *const OWSPreferencesCallLoggingDidChangeNotification = @"OWSPreferencesCallLoggingDidChangeNotification";
NSString *const OWSPreferencesKeyCallKitEnabled = @"CallKitEnabled";
NSString *const OWSPreferencesKeyCallKitPrivacyEnabled = @"CallKitPrivacyEnabled";
NSString *const OWSPreferencesKeyCallsHideIPAddress = @"CallsHideIPAddress";
NSString *const OWSPreferencesKeyHasDeclinedNoContactsView = @"hasDeclinedNoContactsView";
NSString *const OWSPreferencesKeyHasGeneratedThumbnails = @"OWSPreferencesKeyHasGeneratedThumbnails";
NSString *const OWSPreferencesKeyShouldShowUnidentifiedDeliveryIndicators
    = @"OWSPreferencesKeyShouldShowUnidentifiedDeliveryIndicators";
NSString *const OWSPreferencesKeyIOSUpgradeNagDate = @"iOSUpgradeNagDate";
NSString *const OWSPreferencesKey_IsReadyForAppExtensions = @"isReadyForAppExtensions_5";
NSString *const OWSPreferencesKeySystemCallLogEnabled = @"OWSPreferencesKeySystemCallLogEnabled";

@implementation OWSPreferences

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    return self;
}

#pragma mark - Helpers

- (void)clear
{
    [NSUserDefaults removeAll];
}

- (nullable id)tryGetValueForKey:(NSString *)key
{
    __block id result;
    [LKStorage readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        result = [self tryGetValueForKey:key transaction:transaction];
    }];
    return result;
}

- (nullable id)tryGetValueForKey:(NSString *)key transaction:(YapDatabaseReadTransaction *)transaction
{
    return [transaction objectForKey:key inCollection:OWSPreferencesSignalDatabaseCollection];
}

- (void)setValueForKey:(NSString *)key toValue:(nullable id)value
{
    [LKStorage writeSyncWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self setValueForKey:key toValue:value transaction:transaction];
    }];
}

- (void)setValueForKey:(NSString *)key
               toValue:(nullable id)value
           transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [transaction setObject:value forKey:key inCollection:OWSPreferencesSignalDatabaseCollection];
}

#pragma mark - Specific Preferences

+ (BOOL)isReadyForAppExtensions
{
    NSNumber *preference = [NSUserDefaults.appUserDefaults objectForKey:OWSPreferencesKey_IsReadyForAppExtensions];

    if (preference) {
        return [preference boolValue];
    } else {
        return NO;
    }
}

+ (void)setIsReadyForAppExtensions
{
    [NSUserDefaults.appUserDefaults setObject:@(YES) forKey:OWSPreferencesKey_IsReadyForAppExtensions];
    [NSUserDefaults.appUserDefaults synchronize];
}

- (BOOL)hasDeclinedNoContactsView
{
    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyHasDeclinedNoContactsView];
    // Default to NO.
    return preference ? [preference boolValue] : NO;
}

- (void)setHasDeclinedNoContactsView:(BOOL)value
{
    [self setValueForKey:OWSPreferencesKeyHasDeclinedNoContactsView toValue:@(value)];
}

- (BOOL)hasGeneratedThumbnails
{
    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyHasGeneratedThumbnails];
    // Default to NO.
    return preference ? [preference boolValue] : NO;
}

- (void)setHasGeneratedThumbnails:(BOOL)value
{
    [self setValueForKey:OWSPreferencesKeyHasGeneratedThumbnails toValue:@(value)];
}

- (void)setIOSUpgradeNagDate:(NSDate *)value
{
    [self setValueForKey:OWSPreferencesKeyIOSUpgradeNagDate toValue:value];
}

- (nullable NSDate *)iOSUpgradeNagDate
{
    return [self tryGetValueForKey:OWSPreferencesKeyIOSUpgradeNagDate];
}

- (BOOL)shouldShowUnidentifiedDeliveryIndicators
{
    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyShouldShowUnidentifiedDeliveryIndicators];
    return preference ? [preference boolValue] : NO;
}

- (void)setShouldShowUnidentifiedDeliveryIndicators:(BOOL)value
{
    [self setValueForKey:OWSPreferencesKeyShouldShowUnidentifiedDeliveryIndicators toValue:@(value)];
}

#pragma mark - Calling

#pragma mark CallKit

- (BOOL)isSystemCallLogEnabled
{
    if (@available(iOS 11, *)) {
        // do nothing
    } else {
        return NO;
    }

    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeySystemCallLogEnabled];
    return preference ? preference.boolValue : YES;
}

- (void)setIsSystemCallLogEnabled:(BOOL)flag
{
    if (@available(iOS 11, *)) {
        // do nothing
    } else {
        return;
    }

    [self setValueForKey:OWSPreferencesKeySystemCallLogEnabled toValue:@(flag)];
}

// In iOS 10.2.1, Apple fixed a bug wherein call history was backed up to iCloud.
//
// See: https://support.apple.com/en-us/HT207482
//
// In iOS 11, Apple introduced a property CXProviderConfiguration.includesCallsInRecents
// that allows us to prevent Signal calls made with CallKit from showing up in the device's
// call history.
//
// Therefore in versions of iOS after 11, we have no need of call privacy.
#pragma mark Legacy CallKit

// Be a little conservative with system call logging with legacy users, even though it's
// not synced to iCloud, users could be concerned to suddenly see caller names in their
// recent calls list.
- (void)applyCallLoggingSettingsForLegacyUsersWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    NSNumber *_Nullable callKitPreference =
        [self tryGetValueForKey:OWSPreferencesKeyCallKitEnabled transaction:transaction];
    BOOL wasUsingCallKit = callKitPreference ? [callKitPreference boolValue] : YES;

    NSNumber *_Nullable callKitPrivacyPreference =
        [self tryGetValueForKey:OWSPreferencesKeyCallKitPrivacyEnabled transaction:transaction];
    BOOL wasUsingCallKitPrivacy = callKitPrivacyPreference ? callKitPrivacyPreference.boolValue : YES;

    BOOL shouldLogCallsInRecents = ^{
        if (wasUsingCallKit && !wasUsingCallKitPrivacy) {
            // User was using CallKit and explicitly opted in to showing names/numbers,
            // so it's OK to continue to show names/numbers in the system recents list.
            return YES;
        } else {
            // User was not previously showing names/numbers in the system
            // recents list, so don't opt them in.
            return NO;
        }
    }();

    [self setValueForKey:OWSPreferencesKeySystemCallLogEnabled
                 toValue:@(shouldLogCallsInRecents)
             transaction:transaction];
    
    // We need to reload the callService.callUIAdapter here, but SignalMessaging doesn't know about CallService, so we use
    // notifications to decouple the code. This is admittedly awkward, but it only happens once, and the alternative would
    // be importing all the call related classes into SignalMessaging.
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:OWSPreferencesCallLoggingDidChangeNotification object:nil];
}

- (BOOL)isCallKitEnabled
{
    if (@available(iOS 11, *)) {
        return YES;
    }

    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyCallKitEnabled];
    return preference ? [preference boolValue] : YES;
}

- (void)setIsCallKitEnabled:(BOOL)flag
{
    if (@available(iOS 11, *)) {
        return;
    }

    [self setValueForKey:OWSPreferencesKeyCallKitEnabled toValue:@(flag)];
    // Rev callUIAdaptee to get new setting
}

- (BOOL)isCallKitEnabledSet
{
    if (@available(iOS 11, *)) {
        return NO;
    }

    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyCallKitEnabled];
    return preference != nil;
}

- (BOOL)isCallKitPrivacyEnabled
{
    if (@available(iOS 11, *)) {
        return NO;
    }

    NSNumber *_Nullable preference = [self tryGetValueForKey:OWSPreferencesKeyCallKitPrivacyEnabled];
    if (preference) {
        return [preference boolValue];
    } else {
        // Private by default.
        return YES;
    }
}

- (void)setIsCallKitPrivacyEnabled:(BOOL)flag
{
    if (@available(iOS 11, *)) {
        return;
    }

    [self setValueForKey:OWSPreferencesKeyCallKitPrivacyEnabled toValue:@(flag)];
}

- (BOOL)isCallKitPrivacySet
{
    if (@available(iOS 11, *)) {
        return NO;
    }

    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyCallKitPrivacyEnabled];
    return preference != nil;
}

#pragma mark direct call connectivity (non-TURN)

// Allow callers to connect directly, when desirable, vs. enforcing TURN only proxy connectivity

- (BOOL)doCallsHideIPAddress
{
    NSNumber *preference = [self tryGetValueForKey:OWSPreferencesKeyCallsHideIPAddress];
    return preference ? [preference boolValue] : NO;
}

- (void)setDoCallsHideIPAddress:(BOOL)flag
{
    [self setValueForKey:OWSPreferencesKeyCallsHideIPAddress toValue:@(flag)];
}

@end

NS_ASSUME_NONNULL_END
