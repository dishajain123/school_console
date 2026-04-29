class RegistrationRequest {
  RegistrationRequest({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.registrationSource,
    this.requestedStudentAdmissionNumber,
    required this.createdAt,
    this.rejectionReason,
    this.holdReason,
    this.submittedData,
    this.validationIssues = const [],
    this.duplicateMatches = const [],
  });

  final String userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String role;
  final String status;
  final String registrationSource;
  final String? requestedStudentAdmissionNumber;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? holdReason;
  final Map<String, dynamic>? submittedData;
  final List<Map<String, dynamic>> validationIssues;
  final List<Map<String, dynamic>> duplicateMatches;

  factory RegistrationRequest.fromQueueJson(Map<String, dynamic> json) {
    return RegistrationRequest(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
      registrationSource: json['registration_source'] as String,
      requestedStudentAdmissionNumber:
          json['requested_student_admission_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      holdReason: json['hold_reason'] as String?,
    );
  }

  factory RegistrationRequest.fromDetailJson(Map<String, dynamic> json) {
    final issues = ((json['validation_issues'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    final duplicates =
        ((json['duplicate_matches'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

    return RegistrationRequest(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
      registrationSource: json['registration_source'] as String,
      requestedStudentAdmissionNumber:
          json['requested_student_admission_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      holdReason: json['hold_reason'] as String?,
      submittedData: (json['submitted_data'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      validationIssues: issues,
      duplicateMatches: duplicates,
    );
  }
}
