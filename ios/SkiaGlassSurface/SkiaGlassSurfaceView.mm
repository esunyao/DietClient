#import "SkiaGlassSurfaceView.h"

#import <React/RCTComponentViewProtocol.h>

#import <react/renderer/components/DietClientNative/ComponentDescriptors.h>
#import <react/renderer/components/DietClientNative/EventEmitters.h>
#import <react/renderer/components/DietClientNative/Props.h>

#import "BackdropCaptureCoordinator.h"

using namespace facebook::react;

@implementation RCTSkiaGlassSurface {
  BOOL _live;
  BOOL _oneShot;
  CGFloat _cornerRadius;
  CGFloat _refractionHeight;
  CGFloat _refractionOffset;
  CGFloat _blurRadius;
  SKGBackdropCaptureRegistration *_registration;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<SkiaGlassSurfaceComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.layer.masksToBounds = YES; // 圆角裁剪（玻璃容器）
    _cornerRadius = 26.0;
    _refractionHeight = 20.0;
    _refractionOffset = 70.0;
    _blurRadius = 10.0;
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newProps = static_cast<const SkiaGlassSurfaceProps &>(*props);

  _live = newProps.live;
  _oneShot = newProps.oneShot;
  _cornerRadius = newProps.cornerRadius;
  _refractionHeight = newProps.liquidRefractionHeight;
  _refractionOffset = newProps.liquidRefractionOffset;
  _blurRadius = newProps.liquidBlurRadius;

  self.layer.cornerRadius = _cornerRadius;
  if (newProps.elevated) {
    self.layer.shadowColor = [UIColor colorWithRed:0.227 green:0.353 blue:0.471 alpha:1.0].CGColor;
    self.layer.shadowOpacity = 0.16f;
    self.layer.shadowRadius = 14.0;
    self.layer.shadowOffset = CGSizeMake(0, 6);
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadius].CGPath;
  } else {
    self.layer.shadowOpacity = 0.0f;
  }

  [self updateCaptureRegistration];

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self updateCaptureRegistration];
}

/** 注册/注销捕获：live 且已挂窗且尺寸有效时注册，否则注销。 */
- (void)updateCaptureRegistration
{
  BOOL shouldCapture = _live && self.window != nil && self.bounds.size.width > 0 && self.bounds.size.height > 0;
  if (shouldCapture && _registration == nil) {
    __weak RCTSkiaGlassSurface *weakSelf = self;
    _registration = [[SKGBackdropCaptureCoordinator sharedInstance]
        registerHost:self
        captureRectProvider:^CGRect {
          RCTSkiaGlassSurface *strongSelf = weakSelf;
          if (strongSelf == nil || strongSelf.window == nil) {
            return CGRectZero;
          }
          return [strongSelf.window convertRect:strongSelf.bounds fromView:strongSelf];
        }
        refractionHeight:_refractionHeight
        refractionOffset:_refractionOffset
        blurRadius:_blurRadius
        onSnapshot:^(NSData *jpeg, CGSize size, CGPoint sourceOffset, CGFloat contentScale, NSInteger version) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf dispatchSnapshot:jpeg size:size sourceOffset:sourceOffset contentScale:contentScale version:version];
          });
        }];
  } else if (!shouldCapture && _registration != nil) {
    [[SKGBackdropCaptureCoordinator sharedInstance] unregisterHost:_registration];
    _registration = nil;
  }
}

- (void)dispatchSnapshot:(NSData *)jpeg
                    size:(CGSize)size
            sourceOffset:(CGPoint)sourceOffset
            contentScale:(CGFloat)contentScale
                 version:(NSInteger)version
{
  if (_registration == nil) {
    return; // 已注销（oneShot 完成或离屏）
  }
  auto eventEmitter = std::static_pointer_cast<SkiaGlassSurfaceEventEmitter const>(_eventEmitter);
  if (!eventEmitter) {
    return;
  }

  NSString *base64 = [jpeg base64EncodedStringWithOptions:0];
  SkiaGlassSurfaceEventEmitter::OnSnapshot payload = {
      .jpeg = std::string([base64 UTF8String]),
      .width = size.width,
      .height = size.height,
      .sourceOffsetX = sourceOffset.x,
      .sourceOffsetY = sourceOffset.y,
      .contentScale = contentScale,
      .version = (Float)version,
  };
  eventEmitter->onSnapshot(payload);

  if (_oneShot) {
    [[SKGBackdropCaptureCoordinator sharedInstance] unregisterHost:_registration];
    _registration = nil;
  }
}

@end

// codegen 生成的 provider 通过此函数查找组件视图类（RCTThirdPartyFabricComponentsProvider.mm）。
Class<RCTComponentViewProtocol> SkiaGlassSurfaceCls(void)
{
  return RCTSkiaGlassSurface.class;
}
