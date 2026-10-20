import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

class AuthPreviewPanel extends StatelessWidget {
  const AuthPreviewPanel({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.actions,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 490),
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 34, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              actions[i],
            ],
          ],
        ),
      ),
    ),
  );
}
