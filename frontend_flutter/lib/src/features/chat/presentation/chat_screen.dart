import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../../core/widgets/uniassist_logo.dart';
import '../../auth/application/auth_provider.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.intent,
    this.sentiment,
    this.quickReplies = const [],
  });

  final String text;
  final bool isUser;
  final String? intent;
  final String? sentiment;
  final List<String> quickReplies;
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.sessionId,
    this.isSending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final String? sessionId;
  final bool isSending;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      sessionId: sessionId ?? this.sessionId,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._dio, this._studentId)
      : super(
          const ChatState(
            messages: [
              ChatMessage(
                text:
                    'Welcome to the UniAssist advisor. I can guide you through withdrawal, documents, grievances, scholarships, academics, notices, fee status, and hostel support.',
                isUser: false,
                quickReplies: [
                  'Withdrawal checklist',
                  'Check CGPA',
                  'File grievance',
                  'Scholarship eligibility',
                  'Document verification',
                ],
              ),
            ],
          ),
        );

  final Dio _dio;
  final String? _studentId;

  Future<String> _ensureSession() async {
    if (state.sessionId != null) return state.sessionId!;
    final response = await _dio.post('/auth/verify', data: {
      'student_id': _studentId ?? 'STU001',
    });
    final sessionId = response.data['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Unable to start advisor session.');
    }
    state = state.copyWith(sessionId: sessionId);
    return sessionId;
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    state = state.copyWith(
      isSending: true,
      error: null,
      messages: [...state.messages, ChatMessage(text: trimmed, isUser: true)],
    );

    try {
      final sessionId = await _ensureSession();
      final response = await _dio.post('/chat/message', data: {
        'session_id': sessionId,
        'message': trimmed,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final reply = _cleanText(data['reply']?.toString() ?? 'I could not prepare a response. Please try again.');
      final quickReplies = _quickRepliesFor(data['intent']?.toString(), data['state']?.toString());

      state = state.copyWith(
        isSending: false,
        messages: [
          ...state.messages,
          ChatMessage(
            text: reply,
            isUser: false,
            intent: data['intent']?.toString(),
            sentiment: data['sentiment']?.toString(),
            quickReplies: quickReplies,
          ),
        ],
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isSending: false,
        error: 'Advisor service is unavailable. Please check the backend connection.',
        messages: [
          ...state.messages,
          ChatMessage(text: 'Advisor service is unavailable. ${error.message ?? ''}'.trim(), isUser: false),
        ],
      );
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        error: 'Unable to send the message.',
        messages: [...state.messages, const ChatMessage(text: 'Unable to send the message. Please try again.', isUser: false)],
      );
    }
  }

  static String _cleanText(String value) {
    return value
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\u0900-\u097F]'), '')
        .replaceAll(RegExp(r'\*\*|`'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static List<String> _quickRepliesFor(String? intent, String? state) {
    if (state == 'CONFIRM') return ['CONFIRM', 'CANCEL'];
    switch (intent) {
      case 'scholarships':
        return ['Apply scholarship', 'Show eligibility'];
      case 'exams':
        return ['Register backpaper', 'Show exam results'];
      case 'grievances':
        return ['Academic', 'Fee', 'Hostel', 'Exam'];
      case 'withdrawals':
      case 'financial':
      case 'academic':
      case 'personal':
      case 'health':
      case 'career':
        return ['Show checklist', 'Refund guidance', 'Request status'];
      default:
        return ['Withdrawal checklist', 'Document upload', 'Notices', 'Fee status'];
    }
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  final dio = ref.watch(apiClientProvider);
  final studentId = ref.watch(authProvider).studentId;
  return ChatNotifier(dio, studentId);
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? value]) async {
    final text = value ?? _controller.text;
    _controller.clear();
    await ref.read(chatProvider.notifier).sendMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const UniAssistLogo(size: 42, showWordmark: true),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            children: [
              _AdvisorHeader(error: chat.error),
              const SizedBox(height: 14),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(18),
                    itemCount: chat.messages.length + (chat.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= chat.messages.length) {
                        return const _TypingRow();
                      }
                      final message = chat.messages[index];
                      return _ChatBubble(
                        message: message,
                        onQuickReply: _send,
                      ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.03);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Composer(
                controller: _controller,
                enabled: !chat.isSending,
                onSend: () => _send(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisorHeader extends StatelessWidget {
  const _AdvisorHeader({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.support_agent_rounded, color: AppColors.teal, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UniAssist Advisor', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(
                  error ?? 'Ask a service question. The advisor keeps answers inside university workflows.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: error == null ? AppColors.muted : AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onQuickReply});

  final ChatMessage message;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 80 : 0,
        right: isUser ? 0 : 80,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isUser ? AppColors.primary : AppColors.line),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.ink,
                fontSize: 15.5,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!isUser && (message.intent != null || message.sentiment != null)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (message.intent != null) _MetaPill(label: message.intent!),
                if (message.sentiment != null) _MetaPill(label: message.sentiment!),
              ],
            ),
          ],
          if (!isUser && message.quickReplies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.quickReplies
                  .map(
                    (reply) => ActionChip(
                      label: Text(reply),
                      avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                      onPressed: () => onQuickReply(reply),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Ask about withdrawal, documents, grievances, scholarships, or exams',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              height: 58,
              child: FilledButton(
                onPressed: enabled ? onSend : null,
                child: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: const Text('Preparing answer...', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}
