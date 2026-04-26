// lib/presentation/role_profiles/screens/identifier_config_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/layout/admin_scaffold.dart';
import '../providers/identifier_config_provider.dart';

class IdentifierConfigScreen extends ConsumerWidget {
  const IdentifierConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(identifierConfigProvider);

    return AdminScaffold(
      title: 'Identifier Format Configuration',
      body: configs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(),
            const SizedBox(height: 20),
            ...items.map((config) => _ConfigCard(config: config)).toList(),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Identifier formats are LOCKED once the first identifier is issued. '
              'Configure formats before approving your first registration.',
              style: TextStyle(
                  color: Color(0xFF1D4ED8), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> config;
  const _ConfigCard({required this.config});

  @override
  ConsumerState<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends ConsumerState<_ConfigCard> {
  late final TextEditingController _templateCtrl;
  late final TextEditingController _prefixCtrl;
  late int _padding;
  late bool _resetYearly;

  @override
  void initState() {
    super.initState();
    _templateCtrl = TextEditingController(
        text: widget.config['format_template'] as String);
    _prefixCtrl = TextEditingController(
        text: widget.config['prefix'] as String? ?? '');
    _padding = widget.config['sequence_padding'] as int? ?? 4;
    _resetYearly = widget.config['reset_yearly'] as bool? ?? true;
  }

  String get _preview {
    final year = DateTime.now().year.toString();
    final seq = '1'.padLeft(_padding, '0');
    var tpl = _templateCtrl.text;
    tpl = tpl.replaceAll('{YEAR}', year);
    tpl = tpl.replaceAll('{SEQ}', seq);
    tpl = tpl.replaceAll('{PREFIX}', _prefixCtrl.text);
    return tpl.isEmpty ? '—' : tpl;
  }

  bool get _isLocked => widget.config['is_locked'] as bool? ?? false;

  String get _title {
    switch (widget.config['identifier_type']) {
      case 'ADMISSION_NUMBER': return 'Student Admission Number';
      case 'EMPLOYEE_ID':      return 'Teacher Employee ID';
      case 'PARENT_CODE':      return 'Parent Code';
      default:                 return widget.config['identifier_type'] as String;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLocked
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
          width: _isLocked ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              _isLocked
                  ? const _LockedBadge()
                  : const _UnlockedBadge(),
            ],
          ),
          const SizedBox(height: 16),

          // Format Template
          _FieldLabel('Format Template'),
          const SizedBox(height: 6),
          TextField(
            controller: _templateCtrl,
            enabled: !_isLocked,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: _isLocked ? const Color(0xFFF8FAFC) : Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              hintText: '{YEAR}/{SEQ}',
              suffixIcon: Tooltip(
                message: 'Tokens: {YEAR}, {SEQ}, {PREFIX}',
                child: Icon(Icons.help_outline_rounded,
                    size: 18, color: Colors.grey[400]),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              const Text('Preview: ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(
                _preview,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Padding + Reset Yearly
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Sequence Digits: $_padding'),
                  Slider(
                    value: _padding.toDouble(),
                    min: 3, max: 6, divisions: 3,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: _isLocked ? null : (v) =>
                        setState(() => _padding = v.toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Reset Yearly'),
                Switch(
                  value: _resetYearly,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: _isLocked ? null : (v) =>
                      setState(() => _resetYearly = v),
                ),
              ],
            ),
          ]),

          if (!_isLocked) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _save,
                child: const Text('Save Format'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _save() {
    ref.read(identifierConfigProvider.notifier).save(
      identifierType: widget.config['identifier_type'] as String,
      formatTemplate: _templateCtrl.text,
      sequencePadding: _padding,
      resetYearly: _resetYearly,
      prefix: _prefixCtrl.text.isEmpty ? null : _prefixCtrl.text,
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: 13, color: Color(0xFFDC2626)),
        SizedBox(width: 5),
        Text('Format Locked',
            style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _UnlockedBadge extends StatelessWidget {
  const _UnlockedBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_open_rounded, size: 13, color: Color(0xFF16A34A)),
        SizedBox(width: 5),
        Text('Configurable',
            style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

Widget _FieldLabel(String text) => Text(
  text,
  style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
);