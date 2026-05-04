import 'package:flutter/material.dart';

import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

class TeacherAssignmentMatrixScreen extends StatelessWidget {
  const TeacherAssignmentMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Teacher assignment matrix',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Assignment matrix',
              subtitle:
                  'Cross-view of teachers, classes, and subjects. Full editor ships in a later phase.',
            ),
            Expanded(
              child: AdminSurfaceCard(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: const AdminEmptyState(
                  icon: Icons.grid_on_outlined,
                  title: 'Under construction',
                  message:
                      'This screen will host the bulk assignment matrix when the workflow is wired.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
