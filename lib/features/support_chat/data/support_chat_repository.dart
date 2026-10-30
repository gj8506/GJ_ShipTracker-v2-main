import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import '../domain/support_chat_model.dart';

class SupportChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SupportChatThread>> getCustomerThreads(String uid) {
    return _firestore
        .collection('support_chats')
        .where('customerUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final threads =
          snap.docs.map((doc) => SupportChatThread.fromFirestore(doc)).toList();
      threads.sort((a, b) {
        final aTime = a.lastMessageAt;
        final bTime = b.lastMessageAt;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return threads;
    });
  }

  Stream<List<SupportChatThread>> getAdminThreads() {
    return _firestore
        .collection('support_chats')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SupportChatThread.fromFirestore(doc))
            .toList());
  }

  Stream<List<ChatMessageModel>> getMessages(String threadId) {
    return _firestore
        .collection('support_chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessageModel.fromFirestore(doc))
            .toList());
  }

  Future<String> createThread({
    required String customerUid,
    required String customerName,
    required String subject,
    String? parcelId,
  }) async {
    final docRef = _firestore.collection('support_chats').doc();
    final thread = SupportChatThread(
      id: docRef.id,
      customerUid: customerUid,
      customerName: customerName,
      parcelId: parcelId,
      subject: subject,
      status: 'open',
      unreadForAdmin: 0,
      unreadForCustomer: 0,
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
    );
    await docRef.set(thread.toFirestore());
    return docRef.id;
  }

  Future<void> sendMessage(
      String threadId, ChatMessageModel msg, bool isAdmin) async {
    final threadRef = _firestore.collection('support_chats').doc(threadId);
    final batch = _firestore.batch();

    final msgRef = threadRef.collection('messages').doc();
    batch.set(msgRef, msg.toFirestore());

    final updateData = {
      'lastMessage': msg.imageUrl != null ? '[Image attached]' : msg.text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'status': 'open',
    };

    if (isAdmin) {
      updateData['unreadForCustomer'] = FieldValue.increment(1);
    } else {
      updateData['unreadForAdmin'] = FieldValue.increment(1);
    }

    batch.update(threadRef, updateData);
    await batch.commit();

    // TRIGGER NOTIFICATIONS AFTER DB COMMIT
    _triggerPushNotification(threadId, msg, isAdmin);
  }

  Future<void> markAsRead(String threadId, bool isAdmin) async {
    final field = isAdmin ? 'unreadForAdmin' : 'unreadForCustomer';
    await _firestore
        .collection('support_chats')
        .doc(threadId)
        .update({field: 0});
  }

  Future<void> updateThreadStatus(String threadId, String status) async {
    await _firestore
        .collection('support_chats')
        .doc(threadId)
        .update({'status': status});
  }

  // --- INTERNAL HELPER FOR CLOUDFLARE WEBHOOK ---
  Future<void> _triggerPushNotification(
      String threadId, ChatMessageModel msg, bool isAdmin) async {
    try {
      List<String> targetTokens = [];
      String title = isAdmin ? 'Support Reply' : 'New Defect Report';
      String body = msg.imageUrl != null ? '🖼️ [Image Attached]' : msg.text;

      if (isAdmin) {
        // Admin replying -> fetch the customer's token
        final threadDoc =
            await _firestore.collection('support_chats').doc(threadId).get();
        final customerUid = threadDoc.data()?['customerUid'];
        if (customerUid != null) {
          final userDoc =
              await _firestore.collection('users').doc(customerUid).get();
          final token = userDoc.data()?['fcmToken'];
          if (token != null) targetTokens.add(token as String);
        }
      } else {
        // Customer sending -> fetch all admin/staff tokens
        final adminQuery = await _firestore
            .collection('users')
            .where('role', whereIn: ['admin', 'staff']).get();
        for (var doc in adminQuery.docs) {
          final token = doc.data()['fcmToken'];
          if (token != null) targetTokens.add(token as String);
        }
      }

      // Fire off webhook for each target token
      for (var token in targetTokens) {
        await http.post(
          Uri.parse(
              'https://shiptracker-fcm.artlorence-hveridiano.workers.dev/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'title': title,
            'body': body,
          }),
        );
      }
    } catch (e) {
      developer.log(
        'Failed to send push notification',
        name: 'support_chat_repository',
        error: e,
      );
    }
  }
}
