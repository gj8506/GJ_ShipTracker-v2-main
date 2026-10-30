import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/chat_message_model.dart';
import '../data/chatbot_knowledge.dart';

final isTypingProvider = StateProvider<bool>((ref) => false);

final chatbotControllerProvider =
    StateNotifierProvider.autoDispose<ChatbotNotifier, List<ChatMessage>>(
        (ref) {
  final role =
      ref.watch(userProfileProvider).value?.role.toLowerCase() ?? 'customer';
  return ChatbotNotifier(ref, role);
});

class ChatbotNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  final String userRole;

  ChatbotNotifier(this.ref, this.userRole) : super([]) {
    _sendWelcomeMessage();
  }

  void _sendWelcomeMessage() {
    final defaultReplies = userRole == 'customer'
        ? ['How to order?', 'Track my order', 'Report a defect']
        : ['How to dispatch?', 'Scan QR', 'View Analytics'];

    state = [
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Hi! I'm the GJandAsher Assistant. How can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: defaultReplies,
      )
    ];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add User Message
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    // Simulate thinking delay
    ref.read(isTypingProvider.notifier).state = true;
    await Future.delayed(const Duration(milliseconds: 800));
    ref.read(isTypingProvider.notifier).state = false;

    // Determine Response
    _processIntent(text);
  }

  void _processIntent(String input) {
    final lowerInput = input.toLowerCase();

    ChatIntent? bestMatch;
    int maxMatches = 0;

    for (var intent in ChatbotKnowledge.intents) {
      if (!intent.allowedRoles.contains(userRole) &&
          !intent.allowedRoles.contains('admin')) {
        continue; // Skip intents not allowed for this role
      }

      int matches = 0;
      for (var keyword in intent.keywords) {
        if (lowerInput.contains(keyword)) {
          matches++;
        }
      }

      if (matches > maxMatches) {
        maxMatches = matches;
        bestMatch = intent;
      }
    }

    final responseMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: bestMatch?.response ?? ChatbotKnowledge.fallbackResponse,
      isUser: false,
      timestamp: DateTime.now(),
      quickReplies: bestMatch?.quickReplies ??
          (userRole == 'customer'
              ? ['Order a plate', 'Track order']
              : ['Dispatch', 'Scan QR']),
      actionLabel: bestMatch?.actionLabel,
      actionRoute: bestMatch?.actionRoute,
    );

    state = [...state, responseMsg];
  }
}
