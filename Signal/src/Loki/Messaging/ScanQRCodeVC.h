#import <SignalMessaging/OWSViewController.h>
#import "OWSQRCodeScanningViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScanQRCodeVC : OWSViewController

@property (nonatomic, weak) UIViewController<OWSQRScannerDelegate> *delegate;

@end

NS_ASSUME_NONNULL_END
