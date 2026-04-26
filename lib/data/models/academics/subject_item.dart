class SubjectItem {
  SubjectItem({
    required this.id,
    required this.name,
    required this.code,
    required this.schoolId,
    this.standardId,
  });

  final String id;
  final String name;
  final String code;
  final String schoolId;
  final String? standardId;

  factory SubjectItem.fromJson(Map<String, dynamic> json) {
    return SubjectItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      schoolId: (json['school_id'] ?? '').toString(),
      standardId: json['standard_id']?.toString(),
    );
  }
}
