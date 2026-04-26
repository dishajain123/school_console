import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/role_profiles/identifier_config_item.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/role_profile_provider.dart';
import '../../common/layout/admin_scaffold.dart';

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
      title: 'Identifier Format Configuration',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<IdentifierConfigItem>>(
          future: repo.getIdentifierConfigs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }

            final configs = snapshot.data ?? const <IdentifierConfigItem>[];
            if (configs.isEmpty) {
              return const Center(child: Text('No identifier configurations found'));
            }

            return ListView.separated(
              itemCount: configs.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title(widget.config.identifierType),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.config.previewNext != null)
                  Text('Next: ${widget.config.previewNext}'),
              ],
            ),
            if (widget.config.warning != null) ...[
              const SizedBox(height: 8),
              Text(widget.config.warning!, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _templateCtrl,
              enabled: !isLocked,
              decoration: const InputDecoration(
                labelText: 'Format Template',
                border: OutlineInputBorder(),
                hintText: '{YEAR}/{SEQ}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prefixCtrl,
              enabled: !isLocked,
              decoration: const InputDecoration(
                labelText: 'Prefix (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Sequence Digits: $_padding'),
            Slider(
              value: _padding.toDouble(),
              min: 3,
              max: 6,
              divisions: 3,
              onChanged: isLocked ? null : (v) => setState(() => _padding = v.toInt()),
            ),
            Row(
              children: [
                const Text('Reset Yearly'),
                const SizedBox(width: 8),
                Switch(
                  value: _resetYearly,
                  onChanged: isLocked ? null : (v) => setState(() => _resetYearly = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: isLocked || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
