import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../support_chat/presentation/support_chat_providers.dart';

class CustomerSupportScreen extends ConsumerWidget {
  const CustomerSupportScreen({super.key});

  void _showCreateThreadDialog(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final subjectCtrl = TextEditingController();
    final parcelCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Report an Issue',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subject / Issue type',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: parcelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Related Tracking # (Optional)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (subjectCtrl.text.trim().isEmpty) return;
                      setState(() => isSaving = true);
                      try {
                        final threadId = await ref
                            .read(supportChatRepositoryProvider)
                            .createThread(
                              customerUid: user.uid,
                              customerName: user.displayName ?? 'Customer',
                              subject: subjectCtrl.text.trim(),
                              parcelId: parcelCtrl.text.trim().isEmpty
                                  ? null
                                  : parcelCtrl.text.trim(),
                            );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ctx.push('/customer/support/thread/$threadId',
                              extra: subjectCtrl.text.trim());
                        }
                      } finally {
                        setState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Start Chat'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(customerThreadsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Support & Defects',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // MOVED: "Report Issue" action is now safely in the app bar to avoid FAB collisions
          IconButton(
            tooltip: 'Report Issue',
            icon: const Icon(Icons.add_comment_rounded),
            onPressed: () => _showCreateThreadDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: threadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    size: 80,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active support tickets.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below or the + icon above\nto chat with Admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  // ADDED: Convenient inline button for empty states
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_comment_rounded, size: 18),
                    label: const Text('Report Issue',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showCreateThreadDialog(context, ref),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final hasUnread = thread.unreadForCustomer > 0;

              return ListTile(
                tileColor: AppColors.surfaceWhite,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                leading: CircleAvatar(
                  backgroundColor: thread.status == 'resolved'
                      ? AppColors.statusDeliveredContainer
                      : AppColors.tealContainer,
                  child: Icon(
                    thread.status == 'resolved'
                        ? Icons.check
                        : Icons.chat_bubble_outline,
                    color: AppColors.navyPrimary,
                  ),
                ),
                title: Text(
                  thread.subject,
                  style: TextStyle(
                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  thread.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: thread.lastMessageAt != null
                    ? Text(
                        DateFormat('MMM dd').format(thread.lastMessageAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      )
                    : null,
                onTap: () {
                  context.push('/customer/support/thread/${thread.id}',
                      extra: thread.subject);
                },
              );
            },
          );
        },
      ),
    );
  }
}
