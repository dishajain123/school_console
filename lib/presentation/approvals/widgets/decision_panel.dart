//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/widgets/decision_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/registration/approval_action.dart';
import '../../../domains/providers/approval_provider.dart';

class DecisionPanel extends ConsumerStatefulWidget {
  const DecisionPanel({
    super.key,
    required this.userId,
    required this.canDecide,
    required this.isSuperAdmin,
    required this.currentStatus,
  });

  final String userId;
  final bool canDecide;
  final bool isSuperAdmin;
  final String currentStatus;

  @override
  ConsumerState<DecisionPanel> createState() => _DecisionPanelState();
}

class _DecisionPanelState extends ConsumerState<DecisionPanel> {
  final _noteController = TextEditingController();
  bool _overrideValidation = false;
  String? _status;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _decide(ApprovalActionType action) async {
    setState(() {
      _status = null;
    });
    try {
      await ref
          .read(approvalRepositoryProvider)
          .decide(
            userId: widget.userId,
            action: action,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            overrideValidation: _overrideValidation,
          );
      if (!mounted) return;
      setState(() {
        _status = 'Action submitted successfully';
      });
      ref.invalidate(approvalDetailProvider(widget.userId));
      ref.invalidate(approvalQueueProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decision', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Reason/Note',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _overrideValidation,
              onChanged: (widget.canDecide && widget.isSuperAdmin)
                  ? (v) => setState(() => _overrideValidation = v ?? false)
                  : null,
              title: const Text('Override validation (Superadmin only)'),
              contentPadding: EdgeInsets.zero,
            ),
            if (widget.currentStatus.toUpperCase() == 'ACTIVE')
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'This user is already ACTIVE. Further approval decisions are blocked.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: (widget.canDecide &&
                          widget.currentStatus.toUpperCase() != 'ACTIVE')
                      ? () => _decide(ApprovalActionType.approve)
                      : null,
                  child: const Text('Approve'),
                ),
                ElevatedButton(
                  onPressed: (widget.canDecide &&
                          widget.currentStatus.toUpperCase() != 'ACTIVE')
                      ? () => _decide(ApprovalActionType.reject)
                      : null,
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: (widget.canDecide &&
                          widget.currentStatus.toUpperCase() != 'ACTIVE')
                      ? () => _decide(ApprovalActionType.hold)
                      : null,
                  child: const Text('Hold'),
                ),
              ],
            ),
            if (_status != null) ...[const SizedBox(height: 8), Text(_status!)],
          ],
        ),
      ),
    );
  }
}
