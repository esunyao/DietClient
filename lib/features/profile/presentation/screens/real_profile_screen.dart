import 'package:diet_models/diet_models.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/account_identity.dart';
import '../../../../core/presentation/display_state.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../application/profile_state.dart';
import '../../data/health_fields.dart';
import '../../data/profile_api.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/health_kind.dart';
import '../widgets/profile_cards.dart';
import '../widgets/profile_services.dart';
import '../widgets/remote_state.dart';
import 'profile_screen.dart' show ProfileSection, ProfileShortcuts;
import 'real_edit_profile_screen.dart';

PersonProfile _displayProfile(AccountIdentity account, Json data) =>
    PersonProfile(
      name: account.name,
      email: account.email,
      birthday: data['birthDate'] as String? ?? '未填写',
      gender: genderOptions[data['gender']] ?? '未填写',
      height: (data['heightCm'] as num?)?.toDouble() ?? 0,
      activity: activityOptions[data['activityLevel']] ?? '未填写',
      waterGoal: (data['dailyWaterTargetMl'] as num?)?.toInt() ?? 0,
      weight: 0,
      goal: '未填写',
    );

HealthRecordPreview _previewHealthRecord(String kind, Json record) {
  String field(String key) => record[key]?.toString() ?? '';
  final fields = fieldsByKind[kind]!;
  final numeric = fields
      .where((f) => f.min != null && record[f.key] != null)
      .toList();
  final measurement = numeric.isEmpty
      ? null
      : numeric.firstWhere(
          (f) => f.key == 'weightKg',
          orElse: () => numeric.first,
        );
  final unit = measurement == null
      ? null
      : RegExp(r'（([^）]+)）').firstMatch(measurement.label)?.group(1);
  final title = switch (kind) {
    'measurement' => measurement?.label ?? '身体测量',
    'goal' => fields.first.options?[field('goalType')] ?? '健康目标',
    'allergy' => field('allergenName'),
    'disease' => field('conditionName'),
    _ => field('restrictionName'),
  };
  final value = kind == 'measurement'
      ? (measurement == null
            ? '未填写'
            : '${field(measurement.key)}${unit == null ? '' : ' $unit'}')
      : kind == 'goal'
      ? title
      : kind == 'allergy'
      ? (fields.firstWhere((f) => f.key == 'severity').options?[field(
              'severity',
            )] ??
            '严重程度未知')
      : title;
  return HealthRecordPreview(
    id: field(healthIdKeys[kind]!),
    kind: kind,
    title: title,
    value: value,
    note: field('notes'),
    date: field(switch (kind) {
      'measurement' => 'measuredAt',
      'goal' => 'startedOn',
      'allergy' => 'recordedOn',
      'disease' => 'diagnosedOn',
      _ => 'startsOn',
    }),
  );
}

/// 真实“我的”个人中心页面，组合真实身份、基础资料、五类健康档案与 AI 同意状态。
class RealProfileScreen extends ConsumerWidget {
  const RealProfileScreen({super.key});

  Future<void> _openAvatarDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('更换头像'),
      scrollable: true,
      content: const SizedBox(width: 380, child: AvatarEditor()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('完成'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final native = ref.watch(nativeNutritionEnabledProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final institution = ref.watch(
      displayStateProvider.select((s) => s.isInstitution),
    );
    final profileData =
        ref.watch(profileProvider).asData?.value ?? <String, dynamic>{};
    final account =
        ref.watch(accountIdentityProvider).asData?.value ??
        const AccountIdentity();
    final person = _displayProfile(account, profileData);
    final heightLabel = profileData['heightCm'] == null
        ? '身高未填写'
        : '${profileData['heightCm']} cm';
    final manager = ref.read(profileManagerProvider);
    final navigation = ref.read(navigationManagerProvider);

    final identity = RemoteState(
      value: ref.watch(accountIdentityProvider),
      retry: manager.refreshIdentity,
      builder: (resolvedAccount) => ProfileIdentityCard(
        profile: _displayProfile(resolvedAccount, profileData),
        wide: wide,
        heightLabel: heightLabel,
        identityLabel: '当前账户',
        avatar: _AvatarTrigger(
          size: wide ? 76 : 65,
          onTap: () => _openAvatarDialog(context),
        ),
      ),
    );
    final facts = RemoteState(
      value: ref.watch(profileProvider),
      retry: manager.refreshProfile,
      builder: (data) => ProfileFactsCard(
        profile: person,
        heightLabel: heightLabel,
        waterLabel: data['dailyWaterTargetMl'] == null
            ? '未填写'
            : '${data['dailyWaterTargetMl']} ml / 用户设置',
      ),
    );
    final health = _RealHealthSummarySection(wide: wide);
    final privacy = RemoteState(
      value: ref.watch(consentsProvider),
      retry: manager.refreshConsents,
      builder: (records) => AppCard(
        radius: wide ? 16 : 20,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ProfileEntryRow(
          title: 'AI 数据与隐私',
          value: consentStatus(records),
          icon: AppIcons.shield,
          onTap: () => navigation.openAiConsent(context),
        ),
      ),
    );
    final basics = ProfileSection(
      title: '基础资料',
      action: '编辑',
      onTap: () => navigation.openEditProfile(context),
      child: facts,
    );

    return AppPage(
      demoLabel: null,
      title: wide ? '你的资料与服务' : '我的',
      eyebrow: wide ? null : '资料与健康管理',
      subtitle: wide ? '个人档案与机构服务分开管理，健康资料按用途授权。' : null,
      children: [
        if (wide)
          AdaptiveColumns(
            main: [
              identity,
              ProfileSection(
                title: '健康档案',
                action: '查看全部',
                onTap: () => navigation.openHealthRecords(context),
                child: health,
              ),
              ProfileSection(
                title: native ? '常用入口' : '常用入口（报告、饮食与机构仍演示）',
                child: ProfileServiceEntries(
                  institution: institution,
                  real: native,
                ),
              ),
              basics,
            ],
            aside: [
              if (institution) ProfileInstitutionCard(demo: !native),
              if (institution) const ProfilePrivacyCard(),
              privacy,
              const ProfileAccountCard(),
            ],
          )
        else
          _CompactRealProfileBody(
            identity: identity,
            basics: basics,
            health: health,
            privacy: privacy,
            native: native,
            institution: institution,
            onOpenHealthRecords: () => navigation.openHealthRecords(context),
          ),
        TextButton(
          onPressed: () => manager.refreshAll(healthKinds.keys),
          child: const Text('刷新资料'),
        ),
        Text(
          native
              ? '资料未填写，不等于已确认无相关健康限制。机构服务暂未支持。'
              : '资料未填写，不等于已确认无相关健康限制。机构服务仍为演示。',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.8,
          ),
        ),
      ],
    );
  }
}

class _AvatarTrigger extends StatelessWidget {
  const _AvatarTrigger({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '更换头像',
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: AccountAvatar(size: size),
    ),
  );
}

class _RealHealthSummarySection extends ConsumerWidget {
  const _RealHealthSummarySection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = <HealthRecordPreview>[];
    final healthErrors = <String>[];
    var loading = false;
    for (final kind in healthKinds.keys) {
      final value = ref.watch(healthRecordsProvider(kind));
      if (value.isLoading) loading = true;
      if (value.hasError) healthErrors.add(kind);
      records.addAll(
        (value.asData?.value ?? <Json>[]).map(
          (r) => _previewHealthRecord(kind, r),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (healthErrors.isNotEmpty)
          AppCard(
            child: Row(
              children: [
                const Expanded(child: Text('部分健康资料加载失败，摘要暂不完整。')),
                TextButton(
                  onPressed: () => ref
                      .read(profileManagerProvider)
                      .refreshHealthCategories(healthErrors),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ProfileHealthSummary(records: records, wide: wide, real: true),
      ],
    );
  }
}

class _CompactRealProfileBody extends StatelessWidget {
  const _CompactRealProfileBody({
    required this.identity,
    required this.basics,
    required this.health,
    required this.privacy,
    required this.native,
    required this.institution,
    required this.onOpenHealthRecords,
  });

  final Widget identity;
  final Widget basics;
  final Widget health;
  final Widget privacy;
  final bool native;
  final bool institution;
  final VoidCallback onOpenHealthRecords;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      identity,
      const SizedBox(height: 14),
      const ProfileShortcuts(),
      const SizedBox(height: 12),
      basics,
      const SizedBox(height: 16),
      ProfileSection(
        title: '健康资料',
        action: '管理',
        onTap: onOpenHealthRecords,
        child: health,
      ),
      const SizedBox(height: 16),
      privacy,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Text(
          native ? '资料录入不等于授权；餐食分析前需单独确认 AI 数据同意。' : '资料录入不等于授权；报告与饮食历史仍为演示',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
      if (institution) ...[
        ProfileInstitutionCard(demo: !native),
        const SizedBox(height: 16),
        const ProfilePrivacyCard(),
        const SizedBox(height: 16),
      ],
      const ProfileSection(title: '账户与帮助', child: ProfileAccountCard()),
    ],
  );
}
