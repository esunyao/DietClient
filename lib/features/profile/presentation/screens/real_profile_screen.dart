import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/presentation/account_identity.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import '../../application/profile_state.dart';
import '../../data/profile_api.dart';
import '../../data/health_fields.dart';
import '../widgets/remote_state.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/profile_cards.dart';
import '../widgets/profile_services.dart';
import '../widgets/health_kind.dart';
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

HealthRecordPreview _preview(String kind, Json record) {
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

class RealProfileScreen extends ConsumerWidget {
  const RealProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final institution = ref.watch(demoProvider.select((s) => s.isInstitution));
    final data =
        ref.watch(profileProvider).asData?.value ?? <String, dynamic>{};
    final account =
        ref.watch(accountIdentityProvider).asData?.value ??
        const AccountIdentity();
    final person = _displayProfile(account, data);
    final height = data['heightCm'] == null
        ? '身高未填写'
        : '${data['heightCm']} cm';
    final identity = RemoteState(
      value: ref.watch(accountIdentityProvider),
      retry: () => ref.invalidate(accountIdentityProvider),
      builder: (account) => ProfileIdentityCard(
        profile: _displayProfile(account, data),
        wide: wide,
        heightLabel: height,
        identityLabel: '当前账户',
        avatar: Semantics(
          label: '更换头像',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('更换头像'),
                scrollable: true,
                content: const SizedBox(width: 380, child: AvatarEditor()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            child: AccountAvatar(size: wide ? 76 : 65),
          ),
        ),
      ),
    );
    final facts = RemoteState(
      value: ref.watch(profileProvider),
      retry: () => ref.invalidate(profileProvider),
      builder: (data) => ProfileFactsCard(
        profile: person,
        heightLabel: height,
        waterLabel: data['dailyWaterTargetMl'] == null
            ? '未填写'
            : '${data['dailyWaterTargetMl']} ml / 用户设置',
      ),
    );
    final records = <HealthRecordPreview>[];
    final healthErrors = <String>[];
    var loading = false;
    for (final kind in healthKinds.keys) {
      final value = ref.watch(healthRecordsProvider(kind));
      if (value.isLoading) loading = true;
      if (value.hasError) healthErrors.add(kind);
      records.addAll(
        (value.asData?.value ?? <Json>[]).map((r) => _preview(kind, r)),
      );
    }
    final health = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (healthErrors.isNotEmpty)
          AppCard(
            child: Row(
              children: [
                const Expanded(child: Text('部分健康资料加载失败，摘要暂不完整。')),
                TextButton(
                  onPressed: () {
                    for (final kind in healthErrors) {
                      ref.invalidate(healthRecordsProvider(kind));
                    }
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ProfileHealthSummary(records: records, wide: wide, real: true),
      ],
    );
    final privacy = RemoteState(
      value: ref.watch(consentsProvider),
      retry: () => ref.invalidate(consentsProvider),
      builder: (records) => AppCard(
        radius: wide ? 16 : 20,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ProfileEntryRow(
          title: 'AI 数据与隐私',
          value: consentStatus(records),
          icon: AppIcons.shield,
          onTap: () => context.push(AppRoutes.aiConsent),
        ),
      ),
    );
    final basics = ProfileSection(
      title: '基础资料',
      action: '编辑',
      onTap: () => context.push(AppRoutes.editProfile),
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
                onTap: () => context.push(AppRoutes.healthRecords),
                child: health,
              ),
              ProfileSection(
                title: '常用入口（报告、饮食与机构仍演示）',
                child: ProfileServiceEntries(institution: institution),
              ),
              basics,
            ],
            aside: [
              if (institution) const ProfileInstitutionCard(),
              if (institution) const ProfilePrivacyCard(),
              privacy,
              const ProfileAccountCard(),
            ],
          )
        else
          Column(
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
                onTap: () => context.push(AppRoutes.healthRecords),
                child: health,
              ),
              const SizedBox(height: 16),
              privacy,
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Text(
                  '资料录入不等于授权；报告与饮食历史仍为演示',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              if (institution) ...[
                const ProfileInstitutionCard(),
                const SizedBox(height: 16),
                const ProfilePrivacyCard(),
                const SizedBox(height: 16),
              ],
              const ProfileSection(title: '账户与帮助', child: ProfileAccountCard()),
            ],
          ),
        TextButton(
          onPressed: () {
            ref.read(confirmedAvatarProvider.notifier).setUrl(null);
            ref.read(confirmedProfileProvider.notifier).clear();
            ref.invalidate(accountIdentityProvider);
            ref.invalidate(profileProvider);
            for (final kind in healthKinds.keys) {
              ref.invalidate(healthRecordsProvider(kind));
            }
            ref.invalidate(consentsProvider);
          },
          child: const Text('刷新资料'),
        ),
        const Text(
          '资料未填写，不等于已确认无相关健康限制。机构服务仍为演示。',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.8),
        ),
      ],
    );
  }
}
