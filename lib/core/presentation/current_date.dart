import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 提供可替换的本地时钟，供日期计算和刷新使用。
final localNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 使用本地日历的下一天，避免夏令时下固定 24 小时造成偏移。
class CurrentDate extends Notifier<DateTime> {
  Timer? _midnight;
  @override
  DateTime build() {
    // 无订阅或销毁时取消定时器；恢复订阅后异步复核日期并重新安排。
    ref.onDispose(() => _midnight?.cancel());
    ref.onCancel(() => _midnight?.cancel());
    ref.onResume(() {
      _midnight?.cancel();
      _midnight = Timer(Duration.zero, () {
        if (ref.mounted) refresh();
      });
    });
    final now = ref.watch(localNowProvider)();
    _schedule(now);
    return DateTime(now.year, now.month, now.day);
  }

  /// 复核本地日期，即使日期未变也会重新安排下一次午夜刷新。
  void refresh() {
    final now = ref.read(localNowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    if (state != today) state = today;
    _schedule(now);
  }

  void _schedule(DateTime now) {
    _midnight?.cancel();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      if (ref.mounted) refresh();
    });
  }
}

final currentDateProvider = NotifierProvider<CurrentDate, DateTime>(
  CurrentDate.new,
);
