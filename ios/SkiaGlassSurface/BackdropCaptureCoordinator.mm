#import "BackdropCaptureCoordinator.h"

#import <QuartzCore/QuartzCore.h>

// 捕获参数与 Android RootBackdropSnapshotPolicy 对齐
static const CGFloat SKGCaptureScale = 0.5f;      // 降采样比例
static const NSTimeInterval SKGCaptureThrottle = 0.083; // ~12fps 节流
static const NSUInteger SKGMaxJpegBytes = 60 * 1024; // 事件负载保护

@interface SKGBackdropCaptureRegistration ()
@property (nonatomic, weak) UIView *host;
@property (nonatomic, copy) SKGCaptureRectProvider rectProvider;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) NSTimeInterval throttleMs;
@property (nonatomic, assign) CGFloat refractionHeight;
@property (nonatomic, assign) CGFloat refractionOffset;
@property (nonatomic, assign) CGFloat blurRadius;
@property (nonatomic, assign) BOOL liquidEnabled;
@property (nonatomic, copy) SKGSnapshotHandler handler;
@property (nonatomic, assign) NSInteger version;
@end

@implementation SKGBackdropCaptureRegistration
@end

static void SKGNotifyInvalidSnapshot(SKGBackdropCaptureRegistration *registration, CGFloat scale)
{
  registration.version += 1;
  if (registration.handler != nil) {
    registration.handler(nil, CGSizeZero, CGPointZero, scale, registration.version);
  }
}

@implementation SKGBackdropCaptureCoordinator {
  NSMutableArray<SKGBackdropCaptureRegistration *> *_hosts;
  CADisplayLink *_displayLink;
  CFTimeInterval _lastCaptureAt;
}

+ (instancetype)sharedInstance
{
  static SKGBackdropCaptureCoordinator *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [SKGBackdropCaptureCoordinator new];
  });
  return instance;
}

- (instancetype)init
{
  if (self = [super init]) {
    _hosts = [NSMutableArray new];
    _lastCaptureAt = 0;
  }
  return self;
}

- (SKGBackdropCaptureRegistration *)registerHost:(UIView *)host
                               captureRectProvider:(SKGCaptureRectProvider)provider
                                  liquidEnabled:(BOOL)liquidEnabled
                                 refractionHeight:(CGFloat)refractionHeight
                                 refractionOffset:(CGFloat)refractionOffset
                                      blurRadius:(CGFloat)blurRadius
                                       onSnapshot:(SKGSnapshotHandler)handler
{
  NSAssert([NSThread isMainThread], @"capture registration must happen on main thread");
  SKGBackdropCaptureRegistration *registration = [SKGBackdropCaptureRegistration new];
  registration.host = host;
  registration.rectProvider = provider;
  registration.liquidEnabled = liquidEnabled;
  registration.scale = SKGCaptureScale;
  registration.throttleMs = SKGCaptureThrottle;
  registration.refractionHeight = refractionHeight;
  registration.refractionOffset = refractionOffset;
  registration.blurRadius = blurRadius;
  registration.handler = handler;
  [_hosts addObject:registration];
  [self ensureDisplayLink];
  return registration;
}

- (void)unregisterHost:(SKGBackdropCaptureRegistration *)registration
{
  NSAssert([NSThread isMainThread], @"capture unregistration must happen on main thread");
  if (registration == nil) {
    return;
  }
  [_hosts removeObject:registration];
  [self pruneDisplayLink];
}

- (void)ensureDisplayLink
{
  if (_displayLink != nil) {
    return;
  }
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)pruneDisplayLink
{
  // 惰性清理：主机全部失效后才停表
  NSMutableArray *dead = [NSMutableArray new];
  BOOL anyActive = NO;
  for (SKGBackdropCaptureRegistration *registration in _hosts) {
    if (registration.host == nil) {
      [dead addObject:registration];
      continue;
    }
    anyActive = YES;
  }
  [_hosts removeObjectsInArray:dead];
  if (!anyActive && _displayLink != nil) {
    [_displayLink invalidate];
    _displayLink = nil;
  }
}

- (void)tick:(CADisplayLink *)link
{
  if (_hosts.count == 0) {
    return;
  }
  CFTimeInterval now = CACurrentMediaTime();
  if (now - _lastCaptureAt < SKGCaptureThrottle) {
    return;
  }

  for (SKGBackdropCaptureRegistration *registration in [_hosts copy]) {
    UIView *host = registration.host;
    if (host == nil || host.window == nil) {
      continue;
    }
    CGRect glassRect = registration.rectProvider();
    if (CGRectIsEmpty(glassRect) || CGRectIsNull(glassRect)) {
      SKGNotifyInvalidSnapshot(registration, registration.scale);
      continue;
    }

    // 只有显式液态模式才需要采样玻璃边缘之外的背景；普通导航玻璃精确捕获自身矩形。
    CGFloat padding = registration.liquidEnabled
        ? MAX(registration.refractionHeight, registration.refractionOffset) + registration.blurRadius * 2.0 + 4.0
        : 0.0;
    CGRect paddedRect = CGRectInset(glassRect, -padding, -padding);
    // 捕获范围不能超出窗口，否则 renderer 会把窗口外的透明像素编码进 JPEG，
    // 再经过 sourceOffset 换算后形成截图中的灰色斜切/白雾伪影。
    CGRect captureRect = CGRectIntersection(paddedRect, host.window.bounds);
    if (CGRectIsNull(captureRect) || CGRectIsEmpty(captureRect)) {
      SKGNotifyInvalidSnapshot(registration, registration.scale);
      continue;
    }
    CGPoint sourceOffset = CGPointMake(glassRect.origin.x - captureRect.origin.x, glassRect.origin.y - captureRect.origin.y);

    CGFloat scale = registration.scale;
    CGSize pixelSize = CGSizeMake(ceil(captureRect.size.width * scale), ceil(captureRect.size.height * scale));
    if (pixelSize.width < 1 || pixelSize.height < 1) {
      SKGNotifyInvalidSnapshot(registration, scale);
      continue;
    }

    // 排除玻璃自身子树：同步绘制不上屏，捕获后立即恢复，无闪烁。
    BOOL wasHidden = host.hidden;
    UIImage *image = nil;
    host.hidden = YES;
    @try {
      UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
      format.scale = 1.0; // 自行按 0.5 缩放，避免 renderer 再叠加屏幕 scale
      UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:pixelSize format:format];
      image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        CGContextRef context = rendererContext.CGContext;
        CGContextScaleCTM(context, scale, scale);
        CGContextTranslateCTM(context, -captureRect.origin.x, -captureRect.origin.y);
        [host.window drawViewHierarchyInRect:host.window.bounds afterScreenUpdates:NO];
      }];
    }
    @finally {
      host.hidden = wasHidden;
    }

    if (image == nil) {
      SKGNotifyInvalidSnapshot(registration, scale);
      continue;
    }
    NSData *jpeg = UIImageJPEGRepresentation(image, 0.7);
    if (jpeg == nil || jpeg.length > SKGMaxJpegBytes) {
      SKGNotifyInvalidSnapshot(registration, scale);
      continue;
    }

    registration.version += 1;
    if (registration.handler != nil) {
      registration.handler(jpeg, image.size, sourceOffset, scale, registration.version);
    }
  }
  _lastCaptureAt = now;
}

@end
