import 'package:flutter_test/flutter_test.dart';

/// Prevent integration tests from contacting an external API by default.
bool requireRemoteIntegrationOptIn({bool requiresExistingAccount = false}) {
  const enabled = bool.fromEnvironment(
    'ENABLE_REMOTE_INTEGRATION_TESTS',
    defaultValue: false,
  );
  const password = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');
  const email = String.fromEnvironment('INTEGRATION_TEST_EMAIL');

  if (enabled &&
      password.isNotEmpty &&
      (!requiresExistingAccount || email.isNotEmpty)) {
    return true;
  }

  test(
    'remote integration requires explicit environment configuration',
    () {},
    skip:
        'Set ENABLE_REMOTE_INTEGRATION_TESTS, INTEGRATION_TEST_PASSWORD, and where needed INTEGRATION_TEST_EMAIL.',
  );
  return false;
}
