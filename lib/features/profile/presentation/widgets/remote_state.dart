import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

class RemoteState<T> extends StatelessWidget {
  const RemoteState({
    super.key,
    required this.value,
    required this.retry,
    required this.builder,
  });
  final AsyncValue<T> value;
  final VoidCallback retry;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => AppCard(
      child: Column(
        children: [
          const Text('加载失败，请检查网络或配置后重试。'),
          TextButton(onPressed: retry, child: const Text('重新加载')),
        ],
      ),
    ),
  );
}
