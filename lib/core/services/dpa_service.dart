import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kDpaPolicyVersion = 1;
const String _kPrefDpaAcceptedKey = 'dpa_accepted_version';
const String _kPrefDpaTimestampKey = 'dpa_accepted_timestamp';

final dpaServiceProvider = Provider<DpaService>((ref) => DpaService());

final dpaAcceptedStatusProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(dpaServiceProvider);
  return service.isPolicyAccepted();
});

class DpaService {
  /// Session fallback used when platform storage is unavailable, so accepting
  /// the agreement still unlocks the app instead of trapping the user on the
  /// gate. A real device persists the version through shared_preferences.
  bool _acceptedInMemory = false;

  Future<bool> isPolicyAccepted() async {
    if (_acceptedInMemory) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getInt(_kPrefDpaAcceptedKey) ?? 0;
      return savedVersion >= kDpaPolicyVersion;
    } catch (_) {
      // No storage plugin (e.g. widget tests) or unreadable prefs: treat the
      // agreement as not accepted so consent is always explicit.
      return false;
    }
  }

  Future<void> acceptPolicy() async {
    _acceptedInMemory = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefDpaAcceptedKey, kDpaPolicyVersion);
      await prefs.setString(
          _kPrefDpaTimestampKey, DateTime.now().toIso8601String());
    } catch (_) {
      // The in-memory flag still unlocks the app for this session.
    }
  }

  Future<void> resetPolicy() async {
    _acceptedInMemory = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefDpaAcceptedKey);
      await prefs.remove(_kPrefDpaTimestampKey);
    } catch (_) {
      // Nothing to clear when storage is unavailable.
    }
  }
}
