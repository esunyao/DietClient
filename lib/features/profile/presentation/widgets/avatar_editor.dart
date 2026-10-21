import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/presentation/account_identity.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/media/media_coordinator.dart';
import '../../application/profile_state.dart';
import '../../data/avatar_image.dart';

class AvatarEditor extends ConsumerStatefulWidget {
  const AvatarEditor({super.key});
  @override
  ConsumerState<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<AvatarEditor> {
  Uint8List? _pending;
  CancelToken? _cancel;
  bool _busy = false;
  double? _progress;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _recover() async {
    try {
      final files = await ref
          .read(mediaCoordinatorProvider)
          .recover(purpose: MediaPurpose.avatar);
      if (!mounted) return;
      if (files.isNotEmpty) {
        await _crop(files.first);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '未能恢复所选图片，请重新选择。');
    }
  }

  Future<void> _choose(ImageSource source) async {
    try {
      final file = await ref
          .read(mediaCoordinatorProvider)
          .pick(purpose: MediaPurpose.avatar, source: source);
      if (file == null || !mounted) return;
      await _crop(file);
    } catch (_) {
      if (mounted) setState(() => _error = '无法选择图片，请检查相册或相机权限。');
    }
  }

  Future<void> _crop(XFile file) async {
    final session = ref.read(sessionEpochProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('图片不能超过 5 MiB');
      }
      final prepared = await compute(prepareAvatar, await file.readAsBytes());
      if (!mounted || session != ref.read(sessionEpochProvider)) return;
      final cropped = await showSquareImageCrop(context, prepared);
      if (cropped == null ||
          !mounted ||
          session != ref.read(sessionEpochProvider)) {
        return;
      }
      final result = await compute(finishAvatar, cropped);
      if (mounted && session == ref.read(sessionEpochProvider)) {
        setState(() => _pending = result);
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '图片处理失败，请重新选择。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final bytes = _pending;
    if (bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    _cancel = CancelToken();
    try {
      final api = ref.read(profileApiProvider);
      if (api == null) throw StateError('会话不可用');
      final url = await api.uploadAvatar(bytes, (sent, total) {
        if (mounted && total > 0) setState(() => _progress = sent / total);
      }, _cancel!);
      if (!mounted || !identical(api, ref.read(profileApiProvider))) return;
      ref.read(confirmedAvatarProvider.notifier).setUrl(url);
      setState(() => _pending = null);
      ref.invalidate(accountIdentityProvider);
    } catch (_) {
      if (mounted) setState(() => _error = '上传失败，裁剪结果已保留，可重试。');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionEpochProvider, (_, next) {
      _cancel?.cancel();
      setState(() {
        _pending = null;
        _error = null;
        _busy = false;
        _progress = null;
      });
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_pending != null)
              ClipOval(
                child: Image.memory(
                  _pending!,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              )
            else
              const AccountAvatar(size: 76),
            const SizedBox(width: 12),
            Flexible(
              child: Wrap(
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _choose(ImageSource.gallery),
                    child: const Text('选择头像'),
                  ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _choose(ImageSource.camera),
                      child: const Text('拍照'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_pending != null) ...[
          const SizedBox(height: 12),
          const Text('预览确认后才会上传。'),
          Wrap(
            children: [
              TextButton(
                onPressed: _busy ? null : _upload,
                child: const Text('确认上传'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _pending = null),
                child: const Text('放弃此图片'),
              ),
            ],
          ),
        ],
        if (_busy) LinearProgressIndicator(value: _progress),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.amberInk)),
      ],
    );
  }
}
