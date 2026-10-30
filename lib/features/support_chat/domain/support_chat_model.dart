import 'package:cloud_firestore/cloud_firestore.dart';

class SupportChatThread {
  final String id;
  final String customerUid;
  final String customerName;
  final String? parcelId;
  final String subject;
  final String status;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadForAdmin;
  final int unreadForCustomer;
  final DateTime createdAt;

  SupportChatThread({
    required this.id,
    required this.customerUid,
    required this.customerName,
    this.parcelId,
    required this.subject,
    required this.status,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadForAdmin,
    required this.unreadForCustomer,
    required this.createdAt,
  });

  factory SupportChatThread.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupportChatThread(
      id: doc.id,
      customerUid: data['customerUid'] ?? '',
      customerName: data['customerName'] ?? 'Customer',
      parcelId: data['parcelId'],
      subject: data['subject'] ?? '',
      status: data['status'] ?? 'open',
      lastMessage: data['lastMessage'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadForAdmin: data['unreadForAdmin'] ?? 0,
      unreadForCustomer: data['unreadForCustomer'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerUid': customerUid,
      'customerName': customerName,
      'parcelId': parcelId,
      'subject': subject,
      'status': status,
      'lastMessage': lastMessage,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'unreadForAdmin': unreadForAdmin,
      'unreadForCustomer': unreadForCustomer,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ChatMessageModel {
  final String id;
  final String senderUid;
  final String senderRole;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    this.imageUrl,
    required this.createdAt,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessageModel(
      id: doc.id,
      senderUid: data['senderUid'] ?? '',
      senderRole: data['senderRole'] ?? 'customer',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderUid': senderUid,
      'senderRole': senderRole,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
