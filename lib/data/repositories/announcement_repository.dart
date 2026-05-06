import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import 'masters_repository.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._client) : _masters = MastersRepository(_client);

  final DioClient _client;
  final MastersRepository _masters;

  Future<List<Map<String, dynamic>>> listAnnouncements({
    bool includeInactive = true,
  }) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.announcements,
      queryParameters: {'include_inactive': includeInactive},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    required String type,
    String? targetRole,
    String? targetStandardId,
    String? attachmentKey,
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.announcements,
      data: {
        'title': title,
        'body': body,
        'type': type,
        'target_role': ?targetRole,
        'target_standard_id': ?targetStandardId,
        if (attachmentKey != null && attachmentKey.trim().isNotEmpty)
          'attachment_key': attachmentKey.trim(),
      },
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<void> updateAnnouncement(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.announcementById(id),
      data: payload,
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    await _client.dio.delete<dynamic>(ApiConstants.announcementById(id));
  }

  Future<List<Map<String, dynamic>>> listAcademicYears() =>
      _masters.listAcademicYears();

  Future<List<Map<String, dynamic>>> listStandardsMaps({
    String? academicYearId,
  }) =>
      _masters.listStandards(
        academicYearId: academicYearId,
      );
}
