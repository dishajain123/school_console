import 'package:flutter_test/flutter_test.dart';

import 'package:admin_console/data/models/auth/token_response.dart';

void main() {
  test('TokenResponse parses correctly', () {
    final token = TokenResponse.fromJson({
      'access_token': 'a',
      'refresh_token': 'r',
      'token_type': 'bearer',
      'expires_in': 3600,
    });
    expect(token.accessToken, 'a');
    expect(token.refreshToken, 'r');
    expect(token.tokenType, 'bearer');
    expect(token.expiresIn, 3600);
  });
}
