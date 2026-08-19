#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef CGRect (^SKGCaptureRectProvider)(void);
typedef void (^SKGSnapshotHandler)(NSData *jpeg, CGSize size, CGPoint sourceOffset, CGFloat contentScale, NSInteger version);

/** 一次注册的生命周期句柄；由视图持有，注销时交还协调器。 */
@interface SKGBackdropCaptureRegistration : NSObject
@property (nonatomic, weak, readonly) UIView *host;
@property (nonatomic, copy, readonly) SKGCaptureRectProvider rectProvider;
@property (nonatomic, assign, readonly) CGFloat scale;
@property (nonatomic, assign, readonly) NSTimeInterval throttleMs;
@property (nonatomic, assign, readonly) CGFloat refractionHeight;
@property (nonatomic, assign, readonly) CGFloat refractionOffset;
@property (nonatomic, assign, readonly) CGFloat blurRadius;
@property (nonatomic, copy, readonly) SKGSnapshotHandler handler;
@property (nonatomic, assign, readonly) NSInteger version;
@end

/**
 * iOS 背景捕获协调器（对等 Android RootBackdropSnapshotCoordinator）。
 * - 有宿主注册时跑 CADisplayLink，按 throttleMs（约 12fps）节流；
 * - 捕获 = UIGraphicsImageRenderer 0.5x + drawHierarchy(afterScreenUpdates:NO)；
 * - 捕获前把玻璃自身子树 hidden=YES 排除，同步绘制不上屏，无闪烁；
 * - 输出 JPEG(base64 由 JS 侧编码) 经 handler 回调（主线程）。
 */
@interface SKGBackdropCaptureCoordinator : NSObject

+ (instancetype)sharedInstance;

- (SKGBackdropCaptureRegistration *)registerHost:(UIView *)host
                               captureRectProvider:(SKGCaptureRectProvider)provider
                                 refractionHeight:(CGFloat)refractionHeight
                                 refractionOffset:(CGFloat)refractionOffset
                                      blurRadius:(CGFloat)blurRadius
                                       onSnapshot:(SKGSnapshotHandler)handler;

- (void)unregisterHost:(SKGBackdropCaptureRegistration *)registration;

@end

NS_ASSUME_NONNULL_END
