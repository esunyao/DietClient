import React, { memo, useCallback, useEffect, useState } from 'react';
import { Platform, StyleSheet, Text, View } from 'react-native';
import {
  BottomSheetBackdrop,
  BottomSheetModal,
  BottomSheetView,
  type BottomSheetBackdropProps,
} from '@gorhom/bottom-sheet';
import { launchCamera, launchImageLibrary, type Asset } from 'react-native-image-picker';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, Avatar, useToast } from '../../../shared/components';
import { useScrollChrome } from '../../../shared/scrollChrome/ScrollChromeProvider';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import { useSessionStore } from '../../../app/session/sessionStore';
import { userApi } from '../api/userApi';
import { prepareAvatarFile, uploadAvatarBinary } from '../services/avatar';
export const AvatarEditor = memo(function ({ size = 60 }: { size?: number }) {
  const sheetRef = React.useRef<BottomSheetModal>(null);
  const { setTabHidden } = useScrollChrome();
  const user = useSessionStore(state => state.user);
  const avatarPreviewUrl = useSessionStore(state => state.avatarPreviewUrl);
  const setUser = useSessionStore(state => state.setUser);
  const setAvatarPreviewUrl = useSessionStore(state => state.setAvatarPreviewUrl);
  const refreshUserData = useSessionStore(state => state.refreshUserData);
  const { show } = useToast();
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [sheetMounted, setSheetMounted] = useState(false);
  useEffect(() => {
    if (sheetMounted) sheetRef.current?.present();
  }, [sheetMounted]);
  const renderBackdrop = useCallback(
    (props: BottomSheetBackdropProps) => (
      <BottomSheetBackdrop
        {...props}
        appearsOnIndex={0}
        disappearsOnIndex={-1}
        opacity={0.28}
        pressBehavior="close"
      />
    ),
    [],
  );
  const upload = useCallback(
    async (asset?: Asset) => {
      if (!asset || !user) return;
      setUploading(true);
      setProgress(0);
      try {
        const file = await prepareAvatarFile(asset);
        const presign = await userApi.createAvatarUpload({
          fileName: file.fileName,
          contentType: file.contentType,
        });
        await uploadAvatarBinary(file, presign.uploadUrl, setProgress);
        const confirmed = await userApi.confirmAvatarUpload(presign.objectKey);
        setUser({
          ...user,
          avatarUrl: confirmed.avatarUrl,
        });
        setAvatarPreviewUrl(confirmed.avatarUrl);
        refreshUserData().catch(() => undefined);
        show('头像已更新', 'success');
      } catch (error) {
        show(getErrorMessage(error), 'error');
      } finally {
        setUploading(false);
        setProgress(0);
      }
    },
    [refreshUserData, setAvatarPreviewUrl, setUser, show, user],
  );
  const pickFromLibrary = useCallback(async () => {
    sheetRef.current?.dismiss();
    const response = await launchImageLibrary({
      mediaType: 'photo',
      selectionLimit: 1,
      quality: 0.9,
      assetRepresentationMode: 'compatible',
    });
    if (response.errorMessage) return show(response.errorMessage, 'error');
    await upload(response.assets?.[0]);
  }, [show, upload]);
  const takePhoto = useCallback(async () => {
    sheetRef.current?.dismiss();
    const response = await launchCamera({
      mediaType: 'photo',
      quality: 0.9,
      saveToPhotos: false,
      assetRepresentationMode: 'compatible',
    });
    if (response.errorMessage) return show(response.errorMessage, 'error');
    await upload(response.assets?.[0]);
  }, [show, upload]);
  if (!user) return null;
  return (
    <>
      <View style={styles.avatarEditor}>
        <Avatar
          avatarUrl={avatarPreviewUrl}
          name={user.displayName || user.username}
          onImageError={() => setAvatarPreviewUrl(null)}
          onPress={() => {
            if (!uploading) {
              setTabHidden(true);
              setSheetMounted(true);
            }
          }}
          showEditBadge
          size={size}
        />
        {uploading ? <Text style={styles.uploadProgressText}>上传中 {progress}%</Text> : null}
      </View>
      {sheetMounted ? (
        <BottomSheetModal
          ref={sheetRef}
          backdropComponent={renderBackdrop}
          enableDynamicSizing
          enablePanDownToClose
          onChange={index => setTabHidden(index >= 0)}
          onDismiss={() => {
            setTabHidden(false);
            setSheetMounted(false);
          }}
          backgroundStyle={styles.sheetBackground}
          handleIndicatorStyle={styles.sheetHandle}
        >
          <BottomSheetView style={styles.sheetContent}>
            <Text style={styles.sheetTitle}>更新头像</Text>
            <Text style={styles.sheetCaption}>支持 JPG、PNG、WebP，图片不超过 5 MB</Text>
            <View style={styles.sheetActions}>
              {Platform.OS !== 'web' ? (
                <AppButton
                  label="拍照"
                  onPress={takePhoto}
                  variant="secondary"
                  style={styles.sheetButton}
                />
              ) : null}
              <AppButton label="从相册选择" onPress={pickFromLibrary} style={styles.sheetButton} />
            </View>
          </BottomSheetView>
        </BottomSheetModal>
      ) : null}
    </>
  );
});
const styles = StyleSheet.create({
  avatarEditor: {
    alignItems: 'center',
  },
  uploadProgressText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 10,
    fontWeight: '800',
    marginTop: 6,
  },
  sheetBackground: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D4E2EF',
    borderRadius: radii.lg,
    borderWidth: 1,
  },
  sheetHandle: {
    backgroundColor: '#CBD5E1',
    width: 38,
  },
  sheetContent: {
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.xl,
  },
  sheetTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
    textAlign: 'center',
  },
  sheetCaption: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    textAlign: 'center',
    marginTop: 6,
  },
  sheetActions: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  sheetButton: {
    flex: 1,
  },
});
