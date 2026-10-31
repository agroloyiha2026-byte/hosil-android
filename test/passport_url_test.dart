import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/core/config/env.dart';

void main() {
  test('passport URL uses the deployed HTML verifier and exact token parameter', () {
    const id = '8d6a1c2e-57f3-4ea1-9c21-d3c15a9a4f11';
    final uri = Uri.parse(Env.harvestPassportVerificationUrl(id));

    expect(uri.scheme, 'https');
    expect(uri.path, '/functions/v1/verify-harvest-passport');
    expect(uri.queryParameters, {'token': id});
  });

  test('passport URL rejects a malformed identifier', () {
    expect(() => Env.harvestPassportVerificationUrl('not-a-uuid'), throwsArgumentError);
  });
}
