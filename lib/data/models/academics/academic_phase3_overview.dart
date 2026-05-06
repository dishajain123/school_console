import 'academic_year_item.dart';
import 'section_item.dart';
import 'standard_item.dart';
import 'subject_item.dart';

/// Academic years screen aggregate (years, standards, sections, subjects for one preview year).
class AcademicPhase3Overview {
  AcademicPhase3Overview({
    required this.schoolId,
    required this.years,
    required this.activeYearId,
    required this.standards,
    required this.sections,
    required this.subjects,
  });

  final String schoolId;
  final List<AcademicYearItem> years;
  final String? activeYearId;
  final List<StandardItem> standards;
  final List<SectionItem> sections;
  final List<SubjectItem> subjects;
}
