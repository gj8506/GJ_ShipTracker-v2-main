import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import 'support_chat_providers.dart';

class AdminInboxScreen extends ConsumerStatefulWidget {
  const AdminInboxScreen({super.key});

  @override
  ConsumerState<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends ConsumerState<AdminInboxScreen> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(adminThreadsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Support Inbox')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Open Tickets'),
                    selected: _filter == 'open',
                    onSelected: (val) => setState(() => _filter = 'open'),
                    selectedColor: AppColors.navyPrimary,
                    labelStyle: TextStyle(
                        color: _filter == 'open'
                            ? Colors.white
                            : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Resolved'),
                    selected: _filter == 'resolved',
                    onSelected: (val) => setState(() => _filter = 'resolved'),
                    selectedColor: AppColors.navyPrimary,
                    labelStyle: TextStyle(
                        color: _filter == 'resolved'
                            ? Colors.white
                            : AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (threads) {
                final filtered =
                    threads.where((t) => t.status == _filter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_email_read_outlined,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text('No $_filter support tickets.',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final thread = filtered[index];
                    final hasUnread = thread.unreadForAdmin > 0;

                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.borderLight)),
                      leading: CircleAvatar(
                        backgroundColor: hasUnread
                            ? AppColors.shopeeOrange
                            : AppColors.surfaceVariant,
                        child: Icon(Icons.person,
                            color: hasUnread
                                ? Colors.white
                                : AppColors.textSecondary),
                      ),
                      title: Text(thread.subject,
                          style: TextStyle(
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600)),
                      subtitle: Text(
                          '${thread.customerName} • ${thread.lastMessage ?? 'No messages'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: thread.lastMessageAt != null
                          ? Text(
                              DateFormat('MMM dd')
                                  .format(thread.lastMessageAt!),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary))
                          : null,
                      onTap: () {
                        context.push('/profile/support-inbox/${thread.id}',
                            extra: thread.subject);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
