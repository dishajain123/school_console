class StandardItem {
  StandardItem({
    required this.id,
    required this.name,
    required this.level,
    required this.schoolId,
    this.academicYearId,
  });

  final String id;
  final String name;
  final int level;
  final String schoolId;
  final String? academicYearId;

  factory StandardItem.fromJson(Map<String, dynamic> json) {
    return StandardItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      level: (json['level'] as num?)?.toInt() ?? 0,
      schoolId: (json['school_id'] ?? '').toString(),
      academicYearId: json['academic_year_id']?.toString(),
    );
  }
}
