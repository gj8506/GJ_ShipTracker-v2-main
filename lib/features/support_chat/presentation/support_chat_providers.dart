import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/support_chat_repository.dart';
import '../domain/support_chat_model.dart';

final supportChatRepositoryProvider =
    Provider((ref) => SupportChatRepository());

final customerThreadsProvider =
    StreamProvider.autoDispose<List<SupportChatThread>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  return ref.watch(supportChatRepositoryProvider).getCustomerThreads(user.uid);
});

final adminThreadsProvider =
    StreamProvider.autoDispose<List<SupportChatThread>>((ref) {
  return ref.watch(supportChatRepositoryProvider).getAdminThreads();
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, String>((ref, threadId) {
  return ref.watch(supportChatRepositoryProvider).getMessages(threadId);
});
