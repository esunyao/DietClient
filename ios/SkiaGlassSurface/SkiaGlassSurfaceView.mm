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
  BOOL _liquidEnabled;
  CGFloat _cornerRadius;
  CGFloat _refractionHeight;
  CGFloat _refractionOffset;
  CGFloat _blurRadius;
  NSInteger _captureGeneration;
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
    _liquidEnabled = NO;
    _captureGeneration = 0;
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newProps = static_cast<const SkiaGlassSurfaceProps &>(*props);

  BOOL capturePropsChanged = _live != newProps.live ||
      _liquidEnabled != newProps.liquidEnabled ||
      _refractionHeight != newProps.liquidRefractionHeight ||
      _refractionOffset != newProps.liquidRefractionOffset ||
      _blurRadius != newProps.liquidBlurRadius;

  _live = newProps.live;
  _oneShot = newProps.oneShot;
  _liquidEnabled = newProps.liquidEnabled;
  _cornerRadius = newProps.cornerRadius;
  _refractionHeight = newProps.liquidRefractionHeight;
  _refractionOffset = newProps.liquidRefractionOffset;
  _blurRadius = newProps.liquidBlurRadius;

  self.layer.cornerRadius = _cornerRadius;
  // 捕获宿主本身保持纯裁剪层。原生 shadow 会在 drawViewHierarchy 的隐藏/恢复边界
  // 被采样进快照，形成截图中的灰色斜切块；深度由上层 tokenized surface 表达。
  self.layer.shadowOpacity = 0.0f;
  self.layer.shadowPath = nil;

  if (capturePropsChanged && _registration != nil) {
    _captureGeneration += 1;
    [[SKGBackdropCaptureCoordinator sharedInstance] unregisterHost:_registration];
    _registration = nil;
  }

  [self updateCaptureRegistration];

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self updateCaptureRegistration];
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  [self updateCaptureRegistration];
}

/** 注册/注销捕获：live 且已挂窗且尺寸有效时注册，否则注销。 */
- (void)updateCaptureRegistration
{
  BOOL shouldCapture = _live && self.window != nil && self.bounds.size.width > 0 && self.bounds.size.height > 0;
  if (shouldCapture && _registration == nil) {
    __weak RCTSkiaGlassSurface *weakSelf = self;
    NSInteger generation = ++_captureGeneration;
    _registration = [[SKGBackdropCaptureCoordinator sharedInstance]
        registerHost:self
        captureRectProvider:^CGRect {
          RCTSkiaGlassSurface *strongSelf = weakSelf;
          if (strongSelf == nil || strongSelf.window == nil) {
            return CGRectZero;
          }
          return [strongSelf.window convertRect:strongSelf.bounds fromView:strongSelf];
        }
        liquidEnabled:_liquidEnabled
        refractionHeight:_refractionHeight
        refractionOffset:_refractionOffset
        blurRadius:_blurRadius
        onSnapshot:^(NSData * _Nullable jpeg, CGSize size, CGPoint sourceOffset, CGFloat contentScale, NSInteger version) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf dispatchSnapshot:jpeg size:size sourceOffset:sourceOffset contentScale:contentScale version:version generation:generation];
          });
        }];
  } else if (!shouldCapture && _registration != nil) {
    _captureGeneration += 1;
    [[SKGBackdropCaptureCoordinator sharedInstance] unregisterHost:_registration];
    _registration = nil;
  }
}

- (void)dispatchSnapshot:(NSData * _Nullable)jpeg
                    size:(CGSize)size
            sourceOffset:(CGPoint)sourceOffset
            contentScale:(CGFloat)contentScale
            version:(NSInteger)version
        generation:(NSInteger)generation
{
  if (_registration == nil || generation != _captureGeneration) {
    return; // 已注销（oneShot 完成或离屏）
  }
  auto eventEmitter = std::static_pointer_cast<SkiaGlassSurfaceEventEmitter const>(_eventEmitter);
  if (!eventEmitter) {
    return;
  }

  NSString *base64 = jpeg != nil ? [jpeg base64EncodedStringWithOptions:0] : @"";
  const char *base64CString = base64.UTF8String != nullptr ? base64.UTF8String : "";
  SkiaGlassSurfaceEventEmitter::OnSnapshot payload = {
      .jpeg = std::string(base64CString),
      .width = jpeg != nil ? size.width : 0,
      .height = jpeg != nil ? size.height : 0,
      .sourceOffsetX = sourceOffset.x,
      .sourceOffsetY = sourceOffset.y,
      .contentScale = jpeg != nil ? contentScale : 0,
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
