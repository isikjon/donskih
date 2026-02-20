import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';

/// Комната чата — минималистичная
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_Message>[
    _Message('Всем привет! 👋', 'Анна', '10:30'),
    _Message('Кто пробовал новую линейку?', 'Анна', '10:31'),
    _Message('Я заказала, жду доставку 😊', 'Мария', '10:45'),
    _Message('Уже использую неделю, нравится!', 'Елена', '11:02'),
    _Message('Подойдёт для комбинированной кожи?', 'Анна', '11:15'),
    _Message('Да, отлично работает)', 'Вы', '12:30', isMe: true),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(_controller.text.trim(), 'Вы', 'Сейчас', isMe: true));
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_outline, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Клуб • Общий чат', style: AppTypography.titleSmall),
                Text('128 участников', style: AppTypography.labelSmall),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final showAvatar = i == 0 || _messages[i - 1].sender != msg.sender;
                return _MessageBubble(message: msg, showAvatar: showAvatar && !msg.isMe);
              },
            ),
          ),
          // Input
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.textTertiary),
                  onPressed: () {},
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      style: AppTypography.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Сообщение...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_outlined, color: AppColors.primary),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final String sender;
  final String time;
  final bool isMe;

  _Message(this.text, this.sender, this.time, {this.isMe = false});
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final bool showAvatar;

  const _MessageBubble({required this.message, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 12 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            if (showAvatar)
              AppAvatar(name: message.sender, size: AvatarSize.small)
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isMe ? AppColors.primary : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isMe ? 16 : 4),
                  bottomRight: Radius.circular(message.isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender,
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  Text(
                    message.text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: message.isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      message.time,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: message.isMe ? Colors.white70 : AppColors.textTertiary,
                      ),
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
