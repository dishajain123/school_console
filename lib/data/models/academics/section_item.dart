class SectionItem {
  SectionItem({
    required this.id,
    required this.standardId,
    required this.academicYearId,
    required this.name,
    required this.isActive,
    this.capacity,
  });

  final String id;
  final String standardId;
  final String academicYearId;
  final String name;
  final bool isActive;
  final int? capacity;

  factory SectionItem.fromJson(Map<String, dynamic> json) {
    return SectionItem(
      id: (json['id'] ?? '').toString(),
      standardId: (json['standard_id'] ?? '').toString(),
      academicYearId: (json['academic_year_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isActive: (json['is_active'] as bool?) ?? true,
      capacity: (json['capacity'] as num?)?.toInt(),
    );
  }
}
