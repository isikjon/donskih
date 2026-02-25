import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with WidgetsBindingObserver {
  final _chat = ChatService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  final _editController = TextEditingController();

  // Editing state
  ChatMessage? _editingMessage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _chat.disconnect();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    if (_editingMessage != null) {
      await _confirmEdit();
      return;
    }

    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    _inputFocus.unfocus();
    await _chat.sendTextMessage(text);
    _scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  // Image pick
  // ---------------------------------------------------------------------------

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final url = await _chat.uploadImage(file);
      if (url != null && mounted) {
        await _chat.sendImageMessage(url);
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Long press context menu
  // ---------------------------------------------------------------------------

  void _showMessageMenu(BuildContext context, ChatMessage msg) {
    if (msg.isDeleted) return;
    final isMe = _chat.isMyMessage(msg);
    if (!isMe) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (msg.text != null && !msg.isDeleted)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: Text('Редактировать', style: AppTypography.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  _startEdit(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: AppColors.textSecondary),
              title: Text('Копировать', style: AppTypography.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                if (msg.text != null) {
                  Clipboard.setData(ClipboardData(text: msg.text!));
                  _showSnack('Скопировано');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                'Удалить',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(msg);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _editController.text = msg.text ?? '';
      _inputController.text = msg.text ?? '';
    });
    _inputFocus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _inputController.clear();
    });
    _inputFocus.unfocus();
  }

  Future<void> _confirmEdit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _editingMessage == null) {
      _cancelEdit();
      return;
    }
    final msg = _editingMessage!;
    _cancelEdit();
    await _chat.editMessage(msg.id, text);
  }

  Future<void> _confirmDelete(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Удалить сообщение?', style: AppTypography.titleSmall),
        content: Text(
          'Сообщение будет удалено для всех.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _chat.deleteMessage(msg.id);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final navPad = MediaQuery.of(context).padding.bottom + 64.0;
    final bottomPad = kb > 0 ? kb : navPad;

    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _chat.stream,
            initialData: _chat.messages,
            builder: (context, snapshot) {
              final msgs = snapshot.data ?? [];
              if (msgs.isEmpty) return _buildEmpty();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  final max = _scrollController.position.maxScrollExtent;
                  final current = _scrollController.position.pixels;
                  // Auto-scroll only if near the bottom (< 120px from bottom)
                  if (max - current < 120) {
                    _scrollController.jumpTo(max);
                  }
                }
              });

              return ListView.builder(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final msg = msgs[i];
                  final showAvatar = i == 0 ||
                      msgs[i - 1].userId != msg.userId ||
                      msg.createdAt.difference(msgs[i - 1].createdAt).inMinutes > 5;

                  final showDateDivider = i == 0 ||
                      !_sameDay(msgs[i - 1].createdAt, msg.createdAt);

                  return Column(
                    children: [
                      if (showDateDivider) _DateDivider(date: msg.createdAt),
                      _MessageBubble(
                        message: msg,
                        isMe: _chat.isMyMessage(msg),
                        showAvatar: showAvatar && !_chat.isMyMessage(msg),
                        onLongPress: () => _showMessageMenu(context, msg),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        _buildInput(bottomPad),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Между нами девочка...', style: AppTypography.titleSmall),
              StreamBuilder<List<ChatMessage>>(
                stream: _chat.stream,
                initialData: const [],
                builder: (_, snap) {
                  final count = (snap.data ?? []).length;
                  return Text(
                    count > 0 ? '$count сообщений' : 'Загрузка...',
                    style: AppTypography.labelSmall,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            'Будьте первой!\nНапишите сообщение',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(double bottomPad) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: bottomPad,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editingMessage != null) _buildEditBanner(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isUploading)
                IconButton(
                  icon: const Icon(Icons.image_outlined,
                      color: AppColors.textTertiary, size: 24),
                  onPressed: _pickImage,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                )
              else
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                    onSubmitted: (_) => _send(),
                    onTapOutside: (_) => _inputFocus.unfocus(),
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: _editingMessage != null
                          ? 'Редактировать...'
                          : 'Сообщение',
                      hintStyle: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _inputController,
                builder: (_, value, __) {
                  final hasText = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: hasText ? AppColors.primary : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _editingMessage != null
                            ? Icons.check_rounded
                            : Icons.arrow_upward_rounded,
                        color: hasText
                            ? AppColors.textOnPrimary
                            : AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _editingMessage?.text ?? '',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _cancelEdit,
            child: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Date divider
// ---------------------------------------------------------------------------

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (_sameDay(date, now)) {
      label = 'Сегодня';
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Вчера';
    } else {
      final months = [
        '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];
      label = '${date.day} ${months[date.month]}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _buildDeleted();

    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 10 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              _buildAvatar()
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMe ? onLongPress : null,
              child: _buildBubble(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (message.senderPhotoUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: message.senderPhotoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              AppAvatar(name: message.senderName, size: AvatarSize.small),
        ),
      );
    }
    return AppAvatar(name: message.senderName, size: AvatarSize.small);
  }

  Widget _buildBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: message.imageUrl != null
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.myMessage : AppColors.otherMessage,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && showAvatar)
            Padding(
              padding: message.imageUrl != null
                  ? const EdgeInsets.only(left: 10, top: 6, bottom: 4)
                  : const EdgeInsets.only(bottom: 4),
              child: Text(
                message.senderName,
                style:
                    AppTypography.labelSmall.copyWith(color: AppColors.primary),
              ),
            ),
          if (message.imageUrl != null) _buildImage(),
          if (message.text != null)
            Padding(
              padding: message.imageUrl != null
                  ? const EdgeInsets.fromLTRB(10, 6, 10, 4)
                  : EdgeInsets.zero,
              child: Text(
                message.text!,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          _buildMeta(leftPad: message.imageUrl != null ? 10.0 : 0),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: message.imageUrl!,
        width: 240,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 240,
          height: 160,
          color: AppColors.surfaceTertiary,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 240,
          height: 80,
          color: AppColors.surfaceTertiary,
          child: const Icon(Icons.broken_image_outlined,
              color: AppColors.textTertiary),
        ),
      ),
    );
  }

  Widget _buildMeta({double leftPad = 0}) {
    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        right: message.imageUrl != null ? 10 : 0,
        left: leftPad,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (message.isEdited)
            Text(
              'ред. ',
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          Text(
            message.timeFormatted,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleted() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Сообщение удалено',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
