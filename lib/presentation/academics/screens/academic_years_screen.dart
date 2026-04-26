// lib/presentation/academics/screens/academic_years_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../common/layout/admin_scaffold.dart';
import '../providers/academic_year_provider.dart';
import '../widgets/academic_year_card.dart';
import '../widgets/create_year_dialog.dart';

class AcademicYearsScreen extends ConsumerWidget {
  const AcademicYearsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAcademicYearProvider);

    return AdminScaffold(
      title: 'Academic Years',
      actions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _showCreateDialog(context, ref),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Academic Year'),
        ),
      ],
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(e.toString(), () =>
            ref.read(adminAcademicYearProvider.notifier).load()),
        data: (years) => years.isEmpty
            ? const _EmptyYears()
            : _YearTimeline(years: years),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => CreateYearDialog(
        onCreated: () =>
            ref.read(adminAcademicYearProvider.notifier).load(),
      ),
    );
  }
}

class _YearTimeline extends ConsumerWidget {
  final List<AcademicYearAdminModel> years;
  const _YearTimeline({required this.years});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = years.indexWhere((y) => y.isActive);

    return ListView.builder(
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Timeline Line ──────────────────────────
            SizedBox(
              width: 40,
              child: Column(children: [
                const SizedBox(height: 20),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: year.isActive
                        ? const Color(0xFF6366F1)
                        : year.isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFCBD5E1),
                  ),
                ),
                if (index < years.length - 1)
                  Container(
                    width: 2, height: 100,
                    color: const Color(0xFFE2E8F0),
                  ),
              ]),
            ),
            // ── Year Card ──────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AcademicYearCard(
                  year: year,
                  isActive: year.isActive,
                  onViewStructure: () =>
                      context.push('/academics/structure/${year.id}'),
                  onActivate: year.isActive ? null : () =>
                      _activateYear(context, ref, year),
                  onCopyStructure: () =>
                      _showCopyDialog(context, ref, year),
                  onEdit: () => _showEditDialog(context, ref, year),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _activateYear(BuildContext context, WidgetRef ref, AcademicYearAdminModel year) async {
    // Show validate first
    final validation = await ref
        .read(adminAcademicYearProvider.notifier)
        .validate(year.id);

    if (!context.mounted) return;

    if (!validation.isValid) {
      showDialog(
        context: context,
        builder: (_) => _ValidationModal(
          validation: validation,
          yearName: year.name,
          onForceActivate: () async {
            Navigator.pop(context);
            await ref
                .read(adminAcademicYearProvider.notifier)
                .activate(year.id);
          },
        ),
      );
      return;
    }

    await ref.read(adminAcademicYearProvider.notifier).activate(year.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${year.name}" is now the active academic year'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _showCopyDialog(BuildContext context, WidgetRef ref, AcademicYearAdminModel year) {
    showDialog(
      context: context,
      builder: (_) => CopyStructureDialog(
        targetYear: year,
        onCopied: (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Copied ${result.standardsCopied} classes, '
                '${result.subjectsCopied} subjects, '
                '${result.sectionsCopied} sections',
              ),
              backgroundColor: const Color(0xFF6366F1),
            ),
          );
          ref.read(adminAcademicYearProvider.notifier).load();
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, AcademicYearAdminModel year) {
    // Edit sheet
  }
}