import { codegenNativeComponent, type CodegenTypes, type ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  variant?: CodegenTypes.WithDefault<'soft' | 'navigation', 'soft'>;
  elevated?: CodegenTypes.WithDefault<boolean, false>;
  cornerRadius?: CodegenTypes.WithDefault<CodegenTypes.Double, 26.0>;
}

export default codegenNativeComponent<NativeProps>('AndroidGlassSurface');
