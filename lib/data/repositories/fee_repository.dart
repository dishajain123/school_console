import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/fees/fee_structure_item.dart';
import 'masters_repository.dart';

class FeeRepository {
  FeeRepository(this._client) : _masters = MastersRepository(_client);

  final DioClient _client;
  final MastersRepository _masters;

  static const List<String> feeCategories = [
    'TUITION',
    'TRANSPORT',
    'LIBRARY',
    'LABORATORY',
    'SPORTS',
    'EXAMINATION',
    'MISCELLANEOUS',
  ];

  static bool isUuid(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(v);
  }

  Future<List<Map<String, dynamic>>> listYears(String schoolId) =>
      _masters.listAcademicYears(schoolId: schoolId);

  Future<List<Map<String, dynamic>>> listStandards(
    String schoolId,
    String academicYearId,
  ) =>
      _masters.listStandards(
        schoolId: schoolId,
        academicYearId: academicYearId,
      );

  Future<List<Map<String, dynamic>>> listSections({
    required String schoolId,
    required String academicYearId,
    required String standardId,
  }) =>
      _masters.listSections(
        schoolId: schoolId,
        academicYearId: academicYearId,
        standardId: standardId,
      );

  Future<List<FeeStructureItem>> listStructures(
    String standardId, {
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<dynamic>(
      ApiConstants.feeStructuresList,
      queryParameters: {
        'standard_id': standardId,
        'academic_year_id': ?academicYearId,
      },
    );
    final raw = resp.data is List
        ? resp.data as List
        : ((resp.data as Map?)?['items'] as List? ?? []);
    return raw
        .map(
          (e) => FeeStructureItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> createStructure({
    required String standardId,
    required String academicYearId,
    required String feeCategory,
    required double amount,
    required String dueDate,
    String? customFeeHead,
    String? description,
    List<Map<String, dynamic>>? installmentPlan,
  }) async {
    await _client.dio.post<dynamic>(
      ApiConstants.feeStructures,
      data: {
        'structures': [
          {
            'standard_id': standardId,
            'academic_year_id': academicYearId,
            'fee_category': feeCategory,
            'amount': amount,
            'due_date': dueDate,
            if (customFeeHead != null && customFeeHead.isNotEmpty)
              'custom_fee_head': customFeeHead,
            if (description != null && description.isNotEmpty)
              'description': description,
            if (installmentPlan != null && installmentPlan.isNotEmpty)
              'installment_plan': installmentPlan,
          },
        ],
      },
    );
  }

  Future<void> createStructuresBatch({
    required List<Map<String, dynamic>> structures,
  }) async {
    await _client.dio.post<dynamic>(
      ApiConstants.feeStructures,
      data: {'structures': structures},
    );
  }

  Future<void> updateStructure({
    required String structureId,
    double? amount,
    String? dueDate,
    String? description,
    bool? applyToAllClasses,
  }) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.feeStructureById(structureId),
      data: {
        'amount': ?amount,
        'due_date': ?dueDate,
        'description': ?description,
        'apply_to_all_classes': ?applyToAllClasses,
      },
    );
  }

  Future<void> deleteStructure(
    String structureId, {
    bool deleteLinkedEntries = false,
  }) async {
    await _client.dio.delete<dynamic>(
      ApiConstants.feeStructureById(structureId),
      queryParameters: {
        if (deleteLinkedEntries) 'delete_linked_entries': true,
      },
    );
  }

  Future<Map<String, dynamic>> generateLedger(
    String standardId, {
    String? academicYearId,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.feeLedgerGenerate,
      data: {
        'standard_id': standardId,
        'academic_year_id': ?academicYearId,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> generateStudentLedger({
    required String studentId,
    required String standardId,
    String? academicYearId,
    String? paymentCycle,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.feeLedgerGenerateStudent,
      data: {
        'student_id': studentId,
        'standard_id': standardId,
        'academic_year_id': ?academicYearId,
        if (paymentCycle != null && paymentCycle.isNotEmpty)
          'payment_cycle': paymentCycle,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> listClassFeeStudents({
    required String standardId,
    String? academicYearId,
    String? section,
    String? paymentCycle,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final safeSize = pageSize.clamp(1, 100);
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.feeLedgerClassStudents,
      queryParameters: {
        'standard_id': standardId,
        if (isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
        if (paymentCycle != null && paymentCycle.trim().isNotEmpty)
          'payment_cycle': paymentCycle.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'page_size': safeSize,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> recordPayment({
    required String studentId,
    required String feeLedgerId,
    required double amount,
    required String paymentMode,
    required String paymentDate,
    String? referenceNumber,
    String? transactionRef,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.feePayments,
      data: {
        'student_id': studentId,
        'fee_ledger_id': feeLedgerId,
        'amount': amount,
        'payment_mode': paymentMode,
        'payment_date': paymentDate,
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          'reference_number': referenceNumber,
        if (transactionRef != null && transactionRef.isNotEmpty)
          'transaction_ref': transactionRef,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> allocatePayment({
    required String studentId,
    required double amount,
    required String paymentMode,
    String? paymentCycle,
    required String paymentDate,
    String? academicYearId,
    String? referenceNumber,
    String? transactionRef,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.feePaymentsAllocate,
      data: {
        'student_id': studentId,
        'amount': amount,
        'payment_mode': paymentMode,
        if (paymentCycle != null && paymentCycle.trim().isNotEmpty)
          'payment_cycle': paymentCycle.trim(),
        'payment_date': paymentDate,
        if (isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          'reference_number': referenceNumber,
        if (transactionRef != null && transactionRef.isNotEmpty)
          'transaction_ref': transactionRef,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> getFeeAnalytics({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.feeAnalytics,
      queryParameters: {
        if (isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (isUuid(standardId)) 'standard_id': standardId,
      },
    );
    return resp.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getDefaulters({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.feeDefaulters,
      queryParameters: {
        if (isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (isUuid(standardId)) 'standard_id': standardId,
      },
    );
    return ((resp.data?['defaulters'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
