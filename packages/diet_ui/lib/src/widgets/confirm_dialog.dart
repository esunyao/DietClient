import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 显示统一的二次确认对话框，用户取消或关闭弹窗时返回 `false`。
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool filledConfirm = false,
  bool destructive = false,
}) async {
  final confirmText = Text(
    confirmLabel,
    style: destructive ? const TextStyle(color: AppColors.red) : null,
  );
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        if (filledConfirm)
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: confirmText,
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: confirmText,
          ),
      ],
    ),
  );
  return result == true;
}
