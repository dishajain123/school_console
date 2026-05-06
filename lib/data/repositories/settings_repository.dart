import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

class SettingsRepository {
  SettingsRepository(this._client);

  final DioClient _client;

  Future<List<Map<String, dynamic>>> getSettings() async {
    final resp = await _client.dio.get<Map<String, dynamic>>(ApiConstants.settings);
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> updateSettings(List<Map<String, String>> items) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.settings,
      data: {'items': items},
    );
  }
}
