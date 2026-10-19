import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UnsavedForm extends StatefulWidget {
  const UnsavedForm({super.key, required this.dirty, required this.child});
  final bool dirty;
  final Widget child;
  @override
  State<UnsavedForm> createState() => _UnsavedFormState();
}

class _UnsavedFormState extends State<UnsavedForm> {
  bool _discard = false;
  bool _asking = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.dirty || _discard,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _asking) return;
      _asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('放弃未保留的修改？'),
          content: const Text('继续编辑会保留当前输入；放弃后不会更新演示资料。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      _asking = false;
      if (discard == true && mounted) {
        setState(() => _discard = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }
    },
    child: widget.child,
  );
}
