import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/registration/approval_action.dart';
import '../../../domains/providers/approval_provider.dart';

class DecisionPanel extends ConsumerStatefulWidget {
  const DecisionPanel({
    super.key,
    required this.userId,
    required this.canDecide,
  });

  final String userId;
  final bool canDecide;

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
              onChanged: widget.canDecide
                  ? (v) => setState(() => _overrideValidation = v ?? false)
                  : null,
              title: const Text('Override validation (Superadmin only)'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: widget.canDecide
                      ? () => _decide(ApprovalActionType.approve)
                      : null,
                  child: const Text('Approve'),
                ),
                ElevatedButton(
                  onPressed: widget.canDecide
                      ? () => _decide(ApprovalActionType.reject)
                      : null,
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: widget.canDecide
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
