import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/image_storage_service.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/support_chat_model.dart';
import 'support_chat_providers.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String subject;

  const ChatThreadScreen(
      {super.key, required this.threadId, required this.subject});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploadingImage = false;
  late bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = ref.read(userProfileProvider).value?.role == 'admin';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(supportChatRepositoryProvider)
          .markAsRead(widget.threadId, _isAdmin);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _textController.clear();

    final msg = ChatMessageModel(
      id: '',
      senderUid: user.uid,
      senderRole: _isAdmin ? 'admin' : 'customer',
      text: text,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );

    await ref
        .read(supportChatRepositoryProvider)
        .sendMessage(widget.threadId, msg, _isAdmin);
    _scrollToBottom();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final storageService = ref.read(imageStorageServiceProvider);
      final url = await storageService.uploadImage(
        File(pickedFile.path),
        folder: 'support_chats',
      );

      if (url.isNotEmpty) {
        await _sendMessage(imageUrl: url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: AppColors.statusReturned),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageFull(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Support Chat',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
              widget.subject,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_isAdmin)
            TextButton(
              onPressed: () {
                ref
                    .read(supportChatRepositoryProvider)
                    .updateThreadStatus(widget.threadId, 'resolved');
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as Resolved')));
              },
              child: const Text('Resolve',
                  style: TextStyle(
                      color: AppColors.statusDelivered,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(supportChatRepositoryProvider)
                      .markAsRead(widget.threadId, _isAdmin);
                  _scrollToBottom();
                });

                if (messages.isEmpty) {
                  return const Center(
                      child: Text('No messages yet. Send a message to start.',
                          style: TextStyle(color: AppColors.textSecondary)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderUid == currentUid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.navyPrimary
                              : AppColors.surfaceWhite,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          border: isMe
                              ? null
                              : Border.all(color: AppColors.borderSubtle),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navyPrimary.withValues(
                                alpha: 0.06,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              Text(
                                msg.senderRole.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusInTransit),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (msg.imageUrl != null)
                              GestureDetector(
                                onTap: () => _showImageFull(msg.imageUrl!),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: msg.imageUrl!,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const SizedBox(
                                        height: 150,
                                        child: Center(
                                            child: CircularProgressIndicator()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (msg.text.isNotEmpty)
                              Text(
                                msg.text,
                                style: TextStyle(
                                    color: isMe
                                        ? AppColors.textOnPrimary
                                        : AppColors.textPrimary,
                                    fontSize: 14),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('hh:mm a').format(msg.createdAt),
                              style: TextStyle(
                                  color: isMe
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                  fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.tealDark),
                    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.navyPrimary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
