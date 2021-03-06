#import "NSSet+Functional.h"

@implementation NSSet (Functional)

- (BOOL)contains:(BOOL (^)(NSObject *))predicate {
    for (NSObject *object in self) {
        BOOL isPredicateSatisfied = predicate(object);
        if (isPredicateSatisfied) { return YES; }
    }
    return NO;
}

- (NSSet *)filtered:(BOOL (^)(NSObject *))isIncluded {
    NSMutableSet *result = [NSMutableSet new];
    for (NSObject *object in self) {
        if (isIncluded(object)) {
            [result addObject:object];
        }
    }
    return result;
}

@end
