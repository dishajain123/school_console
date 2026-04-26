class RoleProfileItem {
  RoleProfileItem({
    required this.userId,
    required this.role,
    this.fullName,
    this.email,
    this.phone,
    this.identifier,
    this.admissionNumber,
    this.employeeId,
    this.parentCode,
    this.section,
    this.specialization,
    this.occupation,
    this.relation,
    this.raw = const {},
  });

  final String userId;
  final String role;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? identifier;
  final String? admissionNumber;
  final String? employeeId;
  final String? parentCode;
  final String? section;
  final String? specialization;
  final String? occupation;
  final String? relation;
  final Map<String, dynamic> raw;

  factory RoleProfileItem.fromJson(Map<String, dynamic> json) {
    return RoleProfileItem(
      userId: (json['user_id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      identifier: json['identifier'] as String?,
      admissionNumber: json['admission_number'] as String?,
      employeeId: json['employee_id'] as String?,
      parentCode: json['parent_code'] as String?,
      section: json['section'] as String?,
      specialization: json['specialization'] as String?,
      occupation: json['occupation'] as String?,
      relation: json['relation'] as String?,
      raw: json,
    );
  }
}

class RoleProfileListData {
  RoleProfileListData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<RoleProfileItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory RoleProfileListData.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const <dynamic>[];
    return RoleProfileListData(
      items: rawItems
          .whereType<Map>()
          .map((e) => RoleProfileItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
