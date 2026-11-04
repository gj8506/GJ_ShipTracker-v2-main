import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/dpa_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';

/// Admin-only editor for the Data Privacy Act text.
///
/// Saves to `app_settings/dpa`. The launch gate and the sign-up screen watch
/// the same document, so a published revision is visible immediately without
/// an app update or restart.
class DpaEditorScreen extends ConsumerStatefulWidget {
  const DpaEditorScreen({super.key});

  @override
  ConsumerState<DpaEditorScreen> createState() => _DpaEditorScreenState();
}

class _DpaEditorScreenState extends ConsumerState<DpaEditorScreen> {
  static const int _maxTitleLength = 80;
  static const int _maxBodyLength = 20000;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _load(DpaPolicy policy) {
    if (_loaded) return;
    _loaded = true;
    _titleCtrl.text = policy.title;
    _bodyCtrl.text = policy.body;
  }

  void _restoreDefaults() {
    setState(() {
      _titleCtrl.text = DpaPolicy.defaults.title;
      _bodyCtrl.text = DpaPolicy.defaults.body;
    });
  }

  Future<void> _save(DpaPolicy policy) async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      _showMessage('You must be signed in to publish the agreement.');
      return;
    }

    // Record consent for the revision being published *before* the Firestore
    // write. The policy stream can emit while the write is still completing,
    // and without this the router would briefly see an unaccepted version and
    // bounce the editor to the consent gate.
    final nextVersion = policy.version + 1;
    await ref.read(dpaServiceProvider).acceptPolicy(nextVersion);

    setState(() => _saving = true);
    try {
      final saved = await ref.read(dpaPolicyRepositoryProvider).savePolicy(
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
            currentVersion: policy.version,
            uid: uid,
          );

      // Keep the recorded version in step if another admin published first.
      await ref.read(dpaServiceProvider).acceptPolicy(saved.version);
      ref.invalidate(dpaAcceptedStatusProvider);

      if (!mounted) return;
      _showMessage(
        'Published version ${saved.version}. New and existing users now see '
        'the updated agreement.',
      );
      context.pop();
    } catch (e) {
      if (mounted) _showMessage('Could not publish the agreement: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final policyAsync = ref.watch(dpaPolicyProvider);
    final loadedPolicy = policyAsync.value;

    if (loadedPolicy != null) {
      _load(loadedPolicy);
    }

    final policy = loadedPolicy ?? DpaPolicy.defaults;
    final isReady = _loaded;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Data Privacy Editor',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: !isReady
          ? (policyAsync.hasError
              ? _ErrorState(
                  onRetry: () => ref.invalidate(dpaPolicyProvider),
                )
              : const Center(child: CircularProgressIndicator()))
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _InfoCard(policy: policy),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: _maxTitleLength,
                      decoration: const InputDecoration(
                        labelText: 'Agreement title',
                        hintText: 'Data Privacy Agreement',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter a title'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyCtrl,
                      minLines: 12,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: _maxBodyLength,
                      decoration: const InputDecoration(
                        labelText: 'Data Privacy Act text',
                        hintText:
                            'Paste the full agreement shown at launch and sign-up',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return 'Enter the agreement text';
                        if (text.length < 50) {
                          return 'The agreement is too short to be useful';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _restoreDefaults,
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('Restore default text'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _save(policy),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Publish version ${policy.version + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Publishing increments the policy version. Users who '
                      'accepted an older version will be asked to review the '
                      'agreement again at their next launch.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Could not load the current agreement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again. Editing is disabled until '
              'the live policy is available, so a save cannot overwrite it '
              'with default text.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.policy});

  final DpaPolicy policy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined,
              color: AppColors.navyPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live agreement',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current version ${policy.version}.0 • ${policy.updatedLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This text is shown on the launch gate and on the sign-up '
                  'screen. Changes go live as soon as you publish.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
