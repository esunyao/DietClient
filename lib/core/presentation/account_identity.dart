import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

import '../network/api_client.dart';
import '../config/ui_preview_config.dart';
import '../session/session_controller.dart';

/// 共享真实账户身份模型，名称只读且与演示身份隔离。
class AccountIdentity {
  const AccountIdentity({
    this.name = '姓名未提供',
    this.email = '邮箱未提供',
    this.avatarUrl,
  });
  final String name;
  final String email;
  final String? avatarUrl;
}

/// 共享账户身份信息 Provider；优先采用非空 `displayName`，缺失时回退 `username`。
final accountIdentityProvider = FutureProvider<AccountIdentity>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return const AccountIdentity();
  final user = await api.request('v1/users/self') as Map<String, dynamic>;
  String? avatar;
  if (user['avatarUrl'] != null) {
    try {
      avatar = await api.request('v1/files/avatar') as String?;
    } on ApiFailure {
      /* 身份与头像独立，头像可在刷新后重取。 */
    }
  }
  final displayName = (user['displayName'] as String?)?.trim() ?? '';
  final username = (user['username'] as String?)?.trim() ?? '';
  return AccountIdentity(
    name: displayName.isNotEmpty
        ? displayName
        : username.isNotEmpty
        ? username
        : '姓名未提供',
    email: user['email'] as String? ?? '邮箱未提供',
    avatarUrl: safeAvatarUrl(avatar),
  );
});

final confirmedAvatarProvider = NotifierProvider<ConfirmedAvatar, String?>(
  ConfirmedAvatar.new,
);

/// 已确认头像地址状态控制器；登录代次变化时自动清空。
class ConfirmedAvatar extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  void setUrl(String? url) => state = safeAvatarUrl(url);
}

/// 校验并过滤可用的 HTTP(S) 头像地址，拒绝空权限部分或包含用户凭据的 URL。
String? safeAvatarUrl(String? value) {
  final uri = Uri.tryParse(value ?? '');
  return uri != null &&
          uri.hasAuthority &&
          uri.userInfo.isEmpty &&
          ['https', 'http'].contains(uri.scheme)
      ? value
      : null;
}

/// 账户头像展示组件；预览模式显示插画，真实界面优先显示已确认头像，缺失时显示占位图标。
class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(uiPreviewProvider)) return AvatarIllustration(size: size);
    final identity = ref.watch(accountIdentityProvider).asData?.value;
    final url = ref.watch(confirmedAvatarProvider) ?? identity?.avatarUrl;
    final fallback = Icon(
      Icons.person_outline,
      size: size * .65,
      color: AppColors.primary,
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
