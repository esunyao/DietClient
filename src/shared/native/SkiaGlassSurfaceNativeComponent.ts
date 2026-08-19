import { codegenNativeComponent, type CodegenTypes, type ViewProps } from 'react-native';

/**
 * 背景快照事件负载（jpeg 为 base64 编码的 0.5x JPEG）。
 * 注意：codegen 事件解析器只接受 Int32/Double/Float 类型引用，不能用裸 number
 * （TSNumberKeyword 在 RN 0.86 的 events 解析器顶层属性分支缺失，会抛
 * "Unable to determine event type"）。
 */
export interface SnapshotPayload {
  jpeg: string;
  /** 快照位图宽（像素）。 */
  width: CodegenTypes.Double;
  /** 快照位图高（像素）。 */
  height: CodegenTypes.Double;
  /** 玻璃区域相对快照区域左上角的偏移（content 单位：Android px / iOS points）。 */
  sourceOffsetX: CodegenTypes.Double;
  sourceOffsetY: CodegenTypes.Double;
  /** 快照降采样比例（0.5）。 */
  contentScale: CodegenTypes.Double;
  /** 快照版本号，用于 JS 侧去重。 */
  version: CodegenTypes.Double;
}

export interface NativeProps extends ViewProps {
  cornerRadius?: CodegenTypes.WithDefault<CodegenTypes.Double, 26.0>;
  elevated?: CodegenTypes.WithDefault<boolean, false>;
  /** 持续捕获模式（滚动中的导航浮层）。 */
  live?: CodegenTypes.WithDefault<boolean, false>;
  /** 一次性捕获模式：首帧快照发出后自动注销。 */
  oneShot?: CodegenTypes.WithDefault<boolean, false>;
  /** 液态模式：捕获区域按折射参数外扩，供 SkSL 折射边缘采样。 */
  liquidEnabled?: CodegenTypes.WithDefault<boolean, false>;
  liquidCaptureGroup?: CodegenTypes.WithDefault<'header' | 'tab', 'tab'>;
  liquidRefractionHeight?: CodegenTypes.WithDefault<CodegenTypes.Double, 20.0>;
  liquidRefractionOffset?: CodegenTypes.WithDefault<CodegenTypes.Double, 70.0>;
  liquidBlurRadius?: CodegenTypes.WithDefault<CodegenTypes.Double, 10.0>;
  liquidDispersion?: CodegenTypes.WithDefault<CodegenTypes.Double, 0.5>;
  onSnapshot?: CodegenTypes.DirectEventHandler<SnapshotPayload>;
}

export default codegenNativeComponent<NativeProps>('SkiaGlassSurface');
