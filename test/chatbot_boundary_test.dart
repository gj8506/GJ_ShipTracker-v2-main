import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';
import 'package:gjandasher_shiptracker/features/chatbot/data/chatbot_knowledge.dart';
import 'package:gjandasher_shiptracker/features/chatbot/presentation/chatbot_provider.dart';

void main() {
  group('isDataAccessRequest', () {
    test('blocks questions about live records and figures', () {
      expect(ChatbotKnowledge.isDataAccessRequest('How many orders today?'),
          isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('list of parcels'), isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('show me all customers'),
          isTrue);
      expect(
          ChatbotKnowledge.isDataAccessRequest('query the firestore'), isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('what is the total sales'),
          isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('address of Juan'), isTrue);
      expect(
          ChatbotKnowledge.isDataAccessRequest('show me the pending parcels'),
          isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('read the database'), isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('export the data'), isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('order history'), isTrue);
      expect(ChatbotKnowledge.isDataAccessRequest('customer email'), isTrue);
    });

    test('still allows app guidance questions', () {
      expect(ChatbotKnowledge.isDataAccessRequest('how to track my order'),
          isFalse);
      expect(
          ChatbotKnowledge.isDataAccessRequest('how do I dispatch?'), isFalse);
      expect(ChatbotKnowledge.isDataAccessRequest('scan a QR code'), isFalse);
      expect(ChatbotKnowledge.isDataAccessRequest('privacy policy'), isFalse);
      expect(
          ChatbotKnowledge.isDataAccessRequest('how many days for delivery?'),
          isFalse);
      expect(ChatbotKnowledge.isDataAccessRequest('where can I see revenue?'),
          isFalse);
      expect(ChatbotKnowledge.isDataAccessRequest('how do I change my address?'),
          isFalse);
    });
  });

  test('the assistant refuses live data instead of querying Firebase',
      () async {
    final container = ProviderContainer(
      overrides: [
        // Keep the profile in its loading state so the chatbot provider is not
        // rebuilt mid-answer; the refusal does not depend on a real account.
        userProfileProvider.overrideWith(
          (ref) => const Stream<UserProfileModel?>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription =
        container.listen(chatbotControllerProvider, (_, __) {});
    addTearDown(subscription.close);

    final notifier = container.read(chatbotControllerProvider.notifier);

    // The welcome message states the boundary before the first question.
    expect(container.read(chatbotControllerProvider).first.text,
        contains('Firebase'));

    await notifier.sendMessage('How many orders were delivered today?');

    final messages = container.read(chatbotControllerProvider);
    expect(messages.last.isUser, isFalse);
    expect(messages.last.text, ChatbotKnowledge.dataAccessRefusalResponse);
  });

  test('the chatbot feature never imports or calls Firebase', () {
    final directory = Directory('lib/features/chatbot');
    expect(directory.existsSync(), isTrue,
        reason: 'Run tests from the project root');

    final dartFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty);

    const forbiddenTokens = [
      'cloud_firestore',
      'firebase_auth',
      'FirebaseFirestore',
      'FirebaseAuth',
      'package:firebase',
    ];

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final token in forbiddenTokens) {
        expect(
          source.contains(token),
          isFalse,
          reason: '${file.path} must not reference $token',
        );
      }
    }
  });
}
