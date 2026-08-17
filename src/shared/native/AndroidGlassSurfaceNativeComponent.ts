import { codegenNativeComponent, type CodegenTypes, type ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  variant?: CodegenTypes.WithDefault<'soft' | 'navigation', 'soft'>;
  elevated?: CodegenTypes.WithDefault<boolean, false>;
  cornerRadius?: CodegenTypes.WithDefault<CodegenTypes.Double, 26.0>;
  liquidEnabled?: CodegenTypes.WithDefault<boolean, false>;
  liquidTouchEffect?: CodegenTypes.WithDefault<boolean, false>;
  liquidElasticEffect?: CodegenTypes.WithDefault<boolean, false>;
  liquidCaptureGroup?: CodegenTypes.WithDefault<'header' | 'tab', 'tab'>;
  liquidRefractionHeight?: CodegenTypes.WithDefault<CodegenTypes.Double, 20.0>;
  liquidRefractionOffset?: CodegenTypes.WithDefault<CodegenTypes.Double, 70.0>;
  liquidBlurRadius?: CodegenTypes.WithDefault<CodegenTypes.Double, 0.01>;
  liquidDispersion?: CodegenTypes.WithDefault<CodegenTypes.Double, 0.5>;
}

export default codegenNativeComponent<NativeProps>('AndroidGlassSurface');
