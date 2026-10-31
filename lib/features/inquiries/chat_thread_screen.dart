import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage5_models.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../stage5_providers.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String inquiryId;
  const ChatThreadScreen({super.key, required this.inquiryId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _sending = false;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(chatMessagesProvider(widget.inquiryId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String userId) async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(inquiryRepoProvider).sendMessage(
            inquiryId: widget.inquiryId,
            senderId: userId,
            body: body,
          );
      _message.clear();
      ref.invalidate(chatMessagesProvider(widget.inquiryId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markRead() async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null || _markingRead) return;
    _markingRead = true;
    try {
      await ref.read(inquiryRepoProvider).markMessagesRead(widget.inquiryId, userId);
      ref.invalidate(chatUnreadCountProvider);
      ref.invalidate(chatMessagesProvider(widget.inquiryId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    } finally {
      _markingRead = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatMessagesProvider(widget.inquiryId), (_, next) {
      if (next.hasValue &&
          next.value!.any((message) => message.senderId != ref.read(sessionProvider).user?.id && message.readAt == null)) {
        _markRead();
      }
    });
    final userId = ref.watch(sessionProvider).user?.id;
    final inquiries = ref.watch(inquiriesProvider);
    final inquiry = inquiries.valueOrNull?.where((item) => item.id == widget.inquiryId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(inquiry?.productTitle ?? context.tr('chat_title')),
        actions: [
          IconButton(
            tooltip: context.tr('chat_inquiries'),
            onPressed: () => context.go('/inquiries'),
            icon: const Icon(Icons.forum_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (inquiry != null && (inquiry.message ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('chat_original_inquiry'), style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(inquiry.message!),
                  ],
                ),
              ),
            ),
          Expanded(
            child: AsyncValueView<List<ChatMessage>>(
              value: ref.watch(chatMessagesProvider(widget.inquiryId)),
              onRetry: () => ref.invalidate(chatMessagesProvider(widget.inquiryId)),
              isEmpty: (messages) => messages.isEmpty,
              data: (messages) => ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final item = messages[index];
                  final own = item.senderId == userId;
                  return Align(
                    alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: own ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: Text(item.body)),
                          const SizedBox(height: 4),
                          Text(item.createdAt.toLocal().toString().substring(11, 16),
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        hintText: context.tr('chat_write'),
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: context.tr('chat_send'),
                    onPressed: userId == null || _sending ? null : () => _send(userId),
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
