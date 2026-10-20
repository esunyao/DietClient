import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCard Material surface', () {
    testWidgets('supports a tappable ListTile', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: ListTile(
                title: const Text('List tile'),
                tileColor: Colors.green.shade50,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('List tile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(taps, 1);
    });

    testWidgets('supports a tappable AppListRow', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: AppListRow(title: 'App row', onTap: () => taps++),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('App row'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(taps, 1);
    });

    testWidgets('supports a SwitchListTile toggle', (tester) async {
      var enabled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppCard(
                child: SwitchListTile(
                  title: const Text('Switch tile'),
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(enabled, isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets(
      'preserves padding, border inset, size and surface appearance',
      (tester) async {
        const contentKey = Key('content');
        const customPadding = EdgeInsetsDirectional.fromSTEB(3, 5, 7, 11);
        for (final padding in <EdgeInsetsGeometry?>[
          null,
          EdgeInsets.zero,
          customPadding,
        ]) {
          final color = padding == customPadding ? Colors.amber : null;
          const content = SizedBox(key: contentKey, width: 80, height: 40);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Center(
                    child: padding == null
                        ? const AppCard(child: content)
                        : AppCard(
                            padding: padding,
                            color: color,
                            child: content,
                          ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final inset = (padding ?? const EdgeInsets.all(20)).resolve(
            TextDirection.rtl,
          );
          final cardRect = tester.getRect(find.byType(AppCard));
          final contentRect = tester.getRect(find.byKey(contentKey));
          expect(
            cardRect.size,
            Size(82 + inset.horizontal, 42 + inset.vertical),
          );
          expect(
            contentRect.topLeft - cardRect.topLeft,
            Offset(inset.left + 1, inset.top + 1),
          );
          final material = tester.widget<Material>(
            find.descendant(
              of: find.byType(AppCard),
              matching: find.byType(Material),
            ),
          );
          expect(material.color, color ?? AppColors.surface);
          expect(material.elevation, 0);
          expect(material.surfaceTintColor, Colors.transparent);
          expect(material.clipBehavior, Clip.antiAlias);
          final shape = material.shape! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(20));
          expect(shape.side.width, 1);
          expect(shape.side.color, AppColors.line.withValues(alpha: 0.08));
        }
      },
    );
  });
}
