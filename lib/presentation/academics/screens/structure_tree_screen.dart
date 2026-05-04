// lib/presentation/academics/screens/structure_tree_screen.dart  [Admin Console]
// Phase 3: Academic Structure Tree visualization.
// Displays a hierarchical tree of academic standards (classes), sections, and subjects.
// Only PRINCIPAL and STAFF_ADMIN can view; STAFF with settings:manage can view.
// Navigation: context.push('/academics/structure-tree')
import 'package:flutter/material.dart';

import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

class StructureTreeScreen extends StatelessWidget {
  const StructureTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Structure tree',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Structure tree',
              subtitle:
                  'Visual hierarchy of classes, sections, and subjects. '
                  'Interactive tree editing ships in a later phase.',
            ),
            Expanded(
              child: AdminSurfaceCard(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: const AdminEmptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'Under construction',
                  message:
                      'This screen will render the read-only academic structure tree when the API is wired.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
