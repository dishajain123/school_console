//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/widgets/decision_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../data/models/registration/approval_action.dart';
import '../../../domains/providers/approval_provider.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

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
    final theme = Theme.of(context);
    final blocked = widget.currentStatus.toUpperCase() == 'ACTIVE';

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decision',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: AdminSpacing.md),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason / note',
            ),
          ),
          const SizedBox(height: AdminSpacing.sm),
          CheckboxListTile(
            value: _overrideValidation,
            onChanged: (widget.canDecide && widget.isSuperAdmin)
                ? (v) => setState(() => _overrideValidation = v ?? false)
                : null,
            title: Text(
              'Override validation (Staff Admin only)',
              style: theme.textTheme.bodySmall,
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AdminColors.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AdminColors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AdminSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AdminColors.danger,
                      ),
                      const SizedBox(width: AdminSpacing.sm),
                      Expanded(
                        child: Text(
                          'This user is already ACTIVE. Further approval decisions are blocked.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AdminColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            children: [
              FilledButton(
                onPressed: (widget.canDecide && !blocked)
                    ? () => _decide(ApprovalActionType.approve)
                    : null,
                child: const Text('Approve'),
              ),
              FilledButton(
                onPressed: (widget.canDecide && !blocked)
                    ? () => _decide(ApprovalActionType.reject)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.danger,
                  foregroundColor: AdminColors.textOnPrimary,
                ),
                child: const Text('Reject'),
              ),
              OutlinedButton(
                onPressed: (widget.canDecide && !blocked)
                    ? () => _decide(ApprovalActionType.hold)
                    : null,
                child: const Text('Hold'),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: AdminSpacing.sm),
            SelectableText(
              _status!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _status == 'Action submitted successfully'
                    ? AdminColors.success
                    : AdminColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
