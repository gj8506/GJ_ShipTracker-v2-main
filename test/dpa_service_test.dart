import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/services/dpa_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DpaService', () {
    test('is not accepted on a fresh install', () async {
      final service = DpaService();
      expect(await service.isPolicyAccepted(), isFalse);
    });

    test('accepting the policy is remembered for the next launch', () async {
      final service = DpaService();
      await service.acceptPolicy();

      expect(await service.isPolicyAccepted(), isTrue);

      // A new service instance (a fresh launch) reads the stored version.
      final nextLaunch = DpaService();
      expect(await nextLaunch.isPolicyAccepted(), isTrue);
    });

    test('accepting the policy stores the version and timestamp', () async {
      final service = DpaService();
      await service.acceptPolicy();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('dpa_accepted_version'), kDpaPolicyVersion);
      expect(prefs.getString('dpa_accepted_timestamp'), isNotNull);
    });

    test('an older accepted version does not satisfy the current policy',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dpa_accepted_version': kDpaPolicyVersion - 1,
      });

      final service = DpaService();
      expect(await service.isPolicyAccepted(), isFalse);
    });

    test('resetting the policy asks for consent again', () async {
      final service = DpaService();
      await service.acceptPolicy();
      await service.resetPolicy();

      expect(await service.isPolicyAccepted(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('dpa_accepted_version'), isNull);
      expect(prefs.getString('dpa_accepted_timestamp'), isNull);
    });

    test('accepting unlocks the current session even if storage is cleared',
        () async {
      final service = DpaService();
      await service.acceptPolicy();

      // Simulate the platform store being unavailable on a later read while
      // the service object is still alive (session fallback).
      SharedPreferences.setMockInitialValues(<String, Object>{});

      expect(await service.isPolicyAccepted(), isTrue);
    });
  });
}
