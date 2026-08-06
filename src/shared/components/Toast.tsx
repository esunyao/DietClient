import React, { createContext, useCallback, useContext, useMemo, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, fonts, radii, spacing } from '../theme/tokens';

type ToastTone = 'success' | 'error' | 'info';
type ToastApi = { show: (message: string, tone?: ToastTone) => void };

const ToastContext = createContext<ToastApi | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toast, setToast] = useState<{ message: string; tone: ToastTone } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const show = useCallback((message: string, tone: ToastTone = 'info') => {
    if (timer.current) {
      clearTimeout(timer.current);
    }
    setToast({ message, tone });
    timer.current = setTimeout(() => setToast(null), 2_600);
  }, []);

  const value = useMemo(() => ({ show }), [show]);

  return (
    <ToastContext.Provider value={value}>
      <View style={styles.host}>
        {children}
        {toast ? (
          <View pointerEvents="none" style={styles.layer}>
            <View
              style={[
                styles.toast,
                toast.tone === 'success' && styles.success,
                toast.tone === 'error' && styles.error,
              ]}
            >
              <Text style={styles.message}>{toast.message}</Text>
            </View>
          </View>
        ) : null}
      </View>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const value = useContext(ToastContext);
  if (!value) {
    throw new Error('useToast 必须在 ToastProvider 内使用');
  }
  return value;
}

const styles = StyleSheet.create({
  host: { flex: 1 },
  layer: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    paddingTop: 58,
    zIndex: 100,
  },
  toast: {
    backgroundColor: colors.ink,
    borderRadius: radii.pill,
    maxWidth: '88%',
    paddingHorizontal: spacing.lg,
    paddingVertical: 11,
    boxShadow: '0 8px 16px rgba(15, 23, 42, 0.20)',
  },
  success: { backgroundColor: '#167A3A' },
  error: { backgroundColor: '#C93025' },
  message: { color: '#FFFFFF', fontFamily: fonts.body, fontSize: 13, fontWeight: '600' },
});
