class AcademicYearItem {
  AcademicYearItem({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.schoolId,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String schoolId;

  factory AcademicYearItem.fromJson(Map<String, dynamic> json) {
    return AcademicYearItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      startDate: DateTime.parse((json['start_date'] ?? '').toString()),
      endDate: DateTime.parse((json['end_date'] ?? '').toString()),
      isActive: (json['is_active'] as bool?) ?? false,
      schoolId: (json['school_id'] ?? '').toString(),
    );
  }
}
