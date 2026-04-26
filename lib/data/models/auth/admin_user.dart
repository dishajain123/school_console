class AdminUser {
  AdminUser({
    required this.id,
    required this.role,
    required this.email,
    required this.phone,
    required this.schoolId,
    required this.status,
    required this.isActive,
    required this.permissions,
  });

  final String id;
  final String role;
  final String? email;
  final String? phone;
  final String? schoolId;
  final String status;
  final bool isActive;
  final List<String> permissions;

  bool get canReview => permissions.contains('approval:review');
  bool get canDecide => permissions.contains('approval:decide');

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      role: json['role'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      schoolId: json['school_id'] as String?,
      status: (json['status'] as String?) ?? 'UNKNOWN',
      isActive: (json['is_active'] as bool?) ?? false,
      permissions: ((json['permissions'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
