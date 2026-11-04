import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firestore location of the editable Data Privacy Act policy.
///
/// The document is publicly readable so the launch gate can render it before a
/// user signs in, and writable only by an admin (see `firestore.rules`).
const String kDpaSettingsCollection = 'app_settings';
const String kDpaSettingsDocId = 'dpa';

/// Seed version used when no policy has been published yet.
const int kDpaPolicyVersion = 1;

const String _kPrefDpaAcceptedKey = 'dpa_accepted_version';
const String _kPrefDpaTimestampKey = 'dpa_accepted_timestamp';

/// The Data Privacy Act text shown on the launch gate, the sign-up screen, and
/// the profile privacy sheet.
///
/// Admins replace it from Profile → Data Privacy Editor. Because both screens
/// watch [dpaPolicyProvider], a saved change appears immediately without an app
/// update or restart.
class DpaPolicy {
  final String title;
  final String body;
  final int version;
  final DateTime? updatedAt;
  final String? updatedBy;

  const DpaPolicy({
    required this.title,
    required this.body,
    required this.version,
    this.updatedAt,
    this.updatedBy,
  });

  /// Shown until an admin publishes a custom policy, and used as an offline
  /// fallback so the consent gate never blocks the app.
  static const DpaPolicy defaults = DpaPolicy(
    title: 'Data Privacy Agreement',
    body: _defaultDpaBody,
    version: kDpaPolicyVersion,
  );

  factory DpaPolicy.fromMap(Map<String, dynamic> data) {
    final version = (data['version'] as num?)?.toInt() ?? kDpaPolicyVersion;
    final title = (data['title'] as String?)?.trim() ?? '';
    final body = (data['body'] as String?)?.trim() ?? '';
    return DpaPolicy(
      title: title.isEmpty ? defaults.title : title,
      body: body.isEmpty ? defaults.body : body,
      version: version < 1 ? kDpaPolicyVersion : version,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  factory DpaPolicy.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DpaPolicy.fromMap(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'version': version,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }

  /// Formatted "Updated YYYY-MM-DD" label, or the seed label when the policy
  /// has never been edited.
  String get updatedLabel {
    final date = updatedAt;
    if (date == null) return 'Effective 2026';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return 'Updated ${date.year}-$month-$day';
  }
}

final dpaPolicyRepositoryProvider =
    Provider<DpaPolicyRepository>((ref) => DpaPolicyRepository());

/// Live policy document. Emits [DpaPolicy.defaults] while the document does not
/// exist, so the gate and sign-up screen always have text to show.
final dpaPolicyProvider = StreamProvider<DpaPolicy>((ref) {
  return ref.watch(dpaPolicyRepositoryProvider).watchPolicy();
});

class DpaPolicyRepository {
  final FirebaseFirestore _firestore;

  DpaPolicyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference get _doc =>
      _firestore.collection(kDpaSettingsCollection).doc(kDpaSettingsDocId);

  Stream<DpaPolicy> watchPolicy() {
    return _doc.snapshots().map(
          (doc) => doc.exists ? DpaPolicy.fromFirestore(doc) : DpaPolicy.defaults,
        );
  }

  Future<DpaPolicy> fetchPolicy() async {
    final doc = await _doc.get();
    return doc.exists ? DpaPolicy.fromFirestore(doc) : DpaPolicy.defaults;
  }

  /// Publishes a new revision. Every save bumps the version so existing users
  /// are asked to review the changed agreement, while new sign-ups always see
  /// the latest text.
  Future<DpaPolicy> savePolicy({
    required String title,
    required String body,
    required int currentVersion,
    required String uid,
  }) async {
    final nextVersion =
        currentVersion < 1 ? kDpaPolicyVersion : currentVersion + 1;
    final policy = DpaPolicy(
      title: title.trim(),
      body: body.trim(),
      version: nextVersion,
      updatedAt: DateTime.now(),
      updatedBy: uid,
    );

    await _doc.set(policy.toFirestore(), SetOptions(merge: true));
    return policy;
  }
}

final dpaServiceProvider = Provider<DpaService>((ref) => DpaService());

/// Resolves the stored consent against the live policy version.
///
/// A saved edit bumps [DpaPolicy.version], so this provider flips back to
/// `false` and the router sends the user to the gate to re-consent. If the
/// policy document cannot be read, the seed version is used so the app still
/// starts instead of hanging on the splash screen.
final dpaAcceptedStatusProvider = FutureProvider<bool>((ref) async {
  // Watch the AsyncValue itself (not only `.future`) so a newly published
  // revision re-evaluates consent on every device, not just after a restart.
  final policyState = ref.watch(dpaPolicyProvider);
  final service = ref.watch(dpaServiceProvider);

  var policy = policyState.value ?? DpaPolicy.defaults;
  if (!policyState.hasValue && !policyState.hasError) {
    try {
      policy = await ref
          .watch(dpaPolicyProvider.future)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      policy = DpaPolicy.defaults;
    }
  }
  return service.isPolicyAccepted(policy.version);
});

class DpaService {
  /// Highest version accepted during this app session, used when platform
  /// storage is unavailable so consent still unlocks the app.
  int _acceptedVersionInMemory = 0;

  Future<bool> isPolicyAccepted([int currentVersion = kDpaPolicyVersion]) async {
    final target = currentVersion < 1 ? kDpaPolicyVersion : currentVersion;
    if (_acceptedVersionInMemory >= target) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getInt(_kPrefDpaAcceptedKey) ?? 0;
      return savedVersion >= target;
    } catch (_) {
      // No storage plugin (e.g. widget tests) or unreadable prefs: treat the
      // agreement as not accepted so consent is always explicit.
      return false;
    }
  }

  Future<void> acceptPolicy([int version = kDpaPolicyVersion]) async {
    final accepted = version < 1 ? kDpaPolicyVersion : version;
    if (accepted > _acceptedVersionInMemory) {
      _acceptedVersionInMemory = accepted;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefDpaAcceptedKey, accepted);
      await prefs.setString(
          _kPrefDpaTimestampKey, DateTime.now().toIso8601String());
    } catch (_) {
      // The in-memory version still unlocks the app for this session.
    }
  }

  Future<void> resetPolicy() async {
    _acceptedVersionInMemory = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefDpaAcceptedKey);
      await prefs.remove(_kPrefDpaTimestampKey);
    } catch (_) {
      // Nothing to clear when storage is unavailable.
    }
  }
}

/// Seed agreement text. Kept in code so the app can render the gate offline and
/// before the first admin edit.
const String _defaultDpaBody = '''DATA PRIVACY CONSENT FORM
Pursuant to the Data Privacy Act of 2012 (Republic Act No. 10173), we are committed to protecting your personal information. By accepting this agreement, you explicitly consent to the collection, processing, and storage of your personal data by GJandAsher ShipTracker.

1. INFORMATION WE COLLECT
We collect your full name, email address, contact number, delivery address, plate customization details, and parcel tracking numbers. We do not collect highly sensitive personal information or financial data within this application.

2. PURPOSE OF PROCESSING
Your personal data is used exclusively to:
• Fulfill and deliver your customized motorcycle plate orders.
• Communicate order updates, dispatch tracking numbers, and customer support.
• Generate customer QR codes to expedite future walk-in orders.
• Maintain a secure internal registry for order analytics and forecasting.

3. DATA PROTECTION & SHARING
We implement secure technical and organizational measures to safeguard your data. Access is restricted to authorized staff and the administrative owner. We do not sell, rent, or trade your data. Data is shared with standard courier services strictly for package delivery.

4. RETENTION
Records are retained only for as long as needed to fulfill orders, comply with legal obligations, and resolve disputes. You may request deletion of your account and personal data at any time, subject to ongoing transactional and legal requirements.

5. YOUR RIGHTS
Under RA 10173, you have the right to be informed, to access, to object, to erasure or blocking, to correct your personal data, and to file a complaint. You may exercise these rights through our support channel.

6. CONTACT
For privacy questions or requests, contact GJandAsher Digital Printing through the in-app support inbox or the published support email address.''';
