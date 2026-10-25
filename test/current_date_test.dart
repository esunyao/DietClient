import 'package:diet_client/core/presentation/current_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local date changes at midnight without a page rebuild', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 25, 23, 59, 59);
    final container = ProviderContainer(
      overrides: [localNowProvider.overrideWithValue(() => now)],
    );
    container.listen(currentDateProvider, (_, _) {});
    expect(container.read(currentDateProvider), DateTime(2026, 10, 25));
    now = DateTime(2026, 10, 26);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(currentDateProvider), DateTime(2026, 10, 26));
    container.dispose();
  });

  testWidgets('foreground refresh catches up after sleep and clock changes', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 25, 12);
    final container = ProviderContainer(
      overrides: [localNowProvider.overrideWithValue(() => now)],
    );
    container.listen(currentDateProvider, (_, _) {});
    now = DateTime(2026, 10, 27, 8);
    container.read(currentDateProvider.notifier).refresh();
    expect(container.read(currentDateProvider), DateTime(2026, 10, 27));
    now = DateTime(2026, 10, 26, 23, 59, 59);
    container.read(currentDateProvider.notifier).refresh();
    expect(container.read(currentDateProvider), DateTime(2026, 10, 26));
    now = DateTime(2026, 10, 27);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(currentDateProvider), DateTime(2026, 10, 27));
    container.dispose();
  });
}
