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
  Future<bool> isPolicyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt(_kPrefDpaAcceptedKey) ?? 0;
    return savedVersion >= kDpaPolicyVersion;
  }

  Future<void> acceptPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefDpaAcceptedKey, kDpaPolicyVersion);
    await prefs.setString(
        _kPrefDpaTimestampKey, DateTime.now().toIso8601String());
  }

  Future<void> resetPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefDpaAcceptedKey);
    await prefs.remove(_kPrefDpaTimestampKey);
  }
}
