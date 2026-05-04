import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../data/models/role_profiles/identifier_config_item.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/role_profile_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

class IdentifierConfigScreen extends ConsumerStatefulWidget {
  const IdentifierConfigScreen({super.key});

  @override
  ConsumerState<IdentifierConfigScreen> createState() => _IdentifierConfigScreenState();
}

class _IdentifierConfigScreenState extends ConsumerState<IdentifierConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(roleProfileRepositoryProvider);

    return AdminScaffold(
      title: 'Identifier configuration',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Identifier configuration',
              subtitle:
                  'Define how admission numbers, employee IDs, and parent codes are generated. Locked types are read-only.',
            ),
            Expanded(
              child: FutureBuilder<List<IdentifierConfigItem>>(
                future: repo.getIdentifierConfigs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AdminLoadingPlaceholder(
                      message: 'Loading identifier rules…',
                      height: 320,
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Material(
                            color: AdminColors.dangerSurface,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(AdminSpacing.md),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: AdminColors.danger,
                                        size: 28,
                                      ),
                                      const SizedBox(width: AdminSpacing.sm),
                                      Text(
                                        'Could not load configuration',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AdminSpacing.sm),
                                  SelectableText(
                                    snapshot.error.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AdminColors.danger,
                                          height: 1.4,
                                        ),
                                  ),
                                  const SizedBox(height: AdminSpacing.md),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.icon(
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Retry'),
                                      onPressed: () => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final configs = snapshot.data ?? const <IdentifierConfigItem>[];
                  if (configs.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.tag_outlined,
                      title: 'No identifier rules',
                      message:
                          'Rules will appear here once the school is provisioned for ID generation.',
                    );
                  }

                  return ListView.separated(
                    itemCount: configs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AdminSpacing.sm),
                    itemBuilder: (context, index) {
                      return _ConfigCard(
                        config: configs[index],
                        onSaved: () => setState(() {}),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigCard extends ConsumerStatefulWidget {
  const _ConfigCard({required this.config, required this.onSaved});

  final IdentifierConfigItem config;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends ConsumerState<_ConfigCard> {
  late final TextEditingController _templateCtrl;
  late final TextEditingController _prefixCtrl;
  late int _padding;
  late bool _resetYearly;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _templateCtrl = TextEditingController(text: widget.config.formatTemplate);
    _prefixCtrl = TextEditingController(text: widget.config.prefix ?? '');
    _padding = widget.config.sequencePadding;
    _resetYearly = widget.config.resetYearly;
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.config.isLocked;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _title(widget.config.identifierType),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (widget.config.previewNext != null)
                  Text(
                    'Next: ${widget.config.previewNext}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdminColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
              ],
            ),
            if (widget.config.warning != null) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                widget.config.warning!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEA580C),
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: AdminSpacing.sm),
            TextField(
              controller: _templateCtrl,
              enabled: !isLocked,
              decoration: const InputDecoration(
                labelText: 'Format template',
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '{YEAR}/{SEQ}',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            TextField(
              controller: _prefixCtrl,
              enabled: !isLocked,
              decoration: const InputDecoration(
                labelText: 'Prefix (optional)',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              'Sequence digits: $_padding',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Slider(
              value: _padding.toDouble(),
              min: 3,
              max: 6,
              divisions: 3,
              activeColor: AdminColors.primaryAction,
              onChanged:
                  isLocked ? null : (v) => setState(() => _padding = v.toInt()),
            ),
            Row(
              children: [
                Text(
                  'Reset yearly',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AdminColors.textPrimary,
                      ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Switch(
                  value: _resetYearly,
                  activeTrackColor:
                      AdminColors.primaryAction.withValues(alpha: 0.45),
                  activeThumbColor: AdminColors.textOnPrimary,
                  onChanged:
                      isLocked ? null : (v) => setState(() => _resetYearly = v),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: isLocked || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AdminColors.textOnPrimary,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    try {
      final auth = ref.read(authControllerProvider).valueOrNull;
      await ref.read(roleProfileRepositoryProvider).saveIdentifierConfig(
            identifierType: widget.config.identifierType,
            formatTemplate: _templateCtrl.text.trim(),
            sequencePadding: _padding,
            resetYearly: _resetYearly,
            prefix: _prefixCtrl.text.trim().isEmpty ? null : _prefixCtrl.text.trim(),
            schoolId: auth?.schoolId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifier config saved')),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _title(String identifierType) {
    switch (identifierType) {
      case 'ADMISSION_NUMBER':
        return 'Student Admission Number';
      case 'EMPLOYEE_ID':
        return 'Teacher Employee ID';
      case 'PARENT_CODE':
        return 'Parent Code';
      default:
        return identifierType;
    }
  }
}
