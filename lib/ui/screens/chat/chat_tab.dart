import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';

// ---------------------------------------------------------------------------
// Display item types — single message or a photo group
// ---------------------------------------------------------------------------

sealed class _DisplayItem {}

class _SingleItem extends _DisplayItem {
  final ChatMessage message;
  _SingleItem(this.message);
}

class _GroupItem extends _DisplayItem {
  final String groupId;
  final List<ChatMessage> messages; // all image messages with same groupId
  final String? caption; // last message's text, if any
  _GroupItem(
      {required this.groupId,
      required this.messages,
      required this.caption});
}

// ---------------------------------------------------------------------------
// Preview result
// ---------------------------------------------------------------------------

class _PreviewResult {
  final List<XFile> images;
  final String caption;
  const _PreviewResult({required this.images, required this.caption});
}

// ---------------------------------------------------------------------------
// ChatTab
// ---------------------------------------------------------------------------

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
  static const _uuid = Uuid();

  ChatMessage? _editingMessage;
  bool _isUploading = false;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat.connect();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _chat.disconnect();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // In reversed list "bottom" = pixels 0; show FAB when user scrolled UP
    final cur = _scrollController.position.pixels;
    final show = cur > 220;
    if (show != _showScrollToBottom && mounted) {
      setState(() => _showScrollToBottom = show);
    }
  }

  /// In reverse: true list, "scroll to bottom" = scroll to offset 0.
  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animate) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(0);
      }
    });
  }

  /// Scroll to bottom when keyboard appears/disappears.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // Only auto-scroll if already near the bottom (not if user scrolled up to read)
      if (_scrollController.position.pixels < 300) {
        _scrollController.jumpTo(0);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Preprocess messages → display items (group by groupId)
  // ---------------------------------------------------------------------------

  List<_DisplayItem> _buildDisplayItems(List<ChatMessage> msgs) {
    final items = <_DisplayItem>[];
    int i = 0;
    while (i < msgs.length) {
      final msg = msgs[i];
      final gid = msg.groupId;
      if (gid != null && !msg.isDeleted && msg.imageUrl != null) {
        // Collect all consecutive messages with the same groupId
        final group = <ChatMessage>[];
        while (i < msgs.length && msgs[i].groupId == gid) {
          group.add(msgs[i]);
          i++;
        }
        // Caption = last message's text (if any)
        String? caption;
        for (final m in group.reversed) {
          if (m.text != null && m.text!.isNotEmpty) {
            caption = m.text;
            break;
          }
        }
        items.add(
            _GroupItem(groupId: gid, messages: group, caption: caption));
      } else {
        items.add(_SingleItem(msg));
        i++;
      }
    }
    return items;
  }

  // ---------------------------------------------------------------------------
  // Send text
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
  // Multi-photo pick → preview → send as group
  // ---------------------------------------------------------------------------

  Future<void> _pickImages() async {
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (files.isEmpty || !mounted) return;

    final result = await Navigator.of(context).push<_PreviewResult>(
      PageRouteBuilder<_PreviewResult>(
        pageBuilder: (_, __, ___) => _PhotoPreviewPage(images: files),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final groupId =
          result.images.length > 1 ? _uuid.v4() : null;

      for (int i = 0; i < result.images.length; i++) {
        final url = await _chat.uploadImage(result.images[i]);
        if (url != null && mounted) {
          // Caption only on the last image
          final cap =
              (i == result.images.length - 1 && result.caption.isNotEmpty)
                  ? result.caption
                  : null;
          await _chat.sendImageMessage(url, caption: cap, groupId: groupId);
        }
      }
      if (mounted) _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Long press menu
  // ---------------------------------------------------------------------------

  void _showMessageMenu(ChatMessage msg) {
    if (msg.isDeleted) return;
    final isMe = _chat.isMyMessage(msg);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageMenuSheet(
        message: msg,
        isMe: isMe,
        onCopy: msg.text != null
            ? () {
                Clipboard.setData(ClipboardData(text: msg.text!));
                _showSnack('Скопировано');
              }
            : null,
        onEdit: (isMe && msg.text != null) ? () => _startEdit(msg) : null,
        onDelete: isMe ? () => _confirmDelete(msg) : null,
      ),
    );
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
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
        content: Text('Сообщение будет удалено для всех.',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _chat.deleteMessage(msg.id);
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
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
          child: Stack(
            children: [
              StreamBuilder<List<ChatMessage>>(
                stream: _chat.stream,
                initialData: _chat.messages,
                builder: (context, snapshot) {
                  final msgs = snapshot.data ?? [];
                  if (msgs.isEmpty) return _buildEmpty();

                  final items = _buildDisplayItems(msgs);

                  // Auto-scroll only when near bottom (pixels ≈ 0 in reversed list)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    if (_scrollController.position.pixels < 140) {
                      _scrollController.jumpTo(0);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    // reverse: true → item 0 at BOTTOM (newest), N-1 at TOP (oldest)
                    // This makes messages stick to the bottom naturally
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: items.length,
                    itemBuilder: (context, revIdx) {
                      // origIdx: 0 = oldest (TOP), N-1 = newest (BOTTOM)
                      final origIdx = items.length - 1 - revIdx;
                      final item = items[origIdx];

                      final DateTime thisDate = _itemDate(item);

                      // Date divider: show ABOVE this item when day changes going up
                      // "above" in reversed display = origIdx-1 (older)
                      final olderItem =
                          origIdx > 0 ? items[origIdx - 1] : null;
                      final showDateDivider = olderItem == null ||
                          !_sameDay(_itemDate(olderItem), thisDate);

                      Widget child;
                      if (item is _SingleItem) {
                        final msg = item.message;
                        final isMe = _chat.isMyMessage(msg);

                        // Avatar at BOTTOM of group = when next newer item (origIdx+1)
                        // is from different user OR this is the newest message
                        final newerItem = origIdx < items.length - 1
                            ? items[origIdx + 1]
                            : null;
                        final showAvatar = !isMe &&
                            (newerItem == null ||
                                _itemUserId(newerItem) != msg.userId);
                        final isTail = showAvatar;

                        child = _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showAvatar: showAvatar,
                          isTail: isTail,
                          onLongPress: () => _showMessageMenu(msg),
                        );
                      } else {
                        final g = item as _GroupItem;
                        final isMe = _chat.isMyMessage(g.messages.first);
                        final newerItem = origIdx < items.length - 1
                            ? items[origIdx + 1]
                            : null;
                        final showAvatar = !isMe &&
                            (newerItem == null ||
                                _itemUserId(newerItem) !=
                                    g.messages.first.userId);

                        child = _MediaGroupBubble(
                          group: g,
                          isMe: isMe,
                          showAvatar: showAvatar,
                          onLongPress: (msg) => _showMessageMenu(msg),
                        );
                      }

                      return Column(
                        children: [
                          // In reversed list, the Column renders top→bottom,
                          // but items flow bottom→top. Divider goes above the item.
                          if (showDateDivider) _DateDivider(date: thisDate),
                          child,
                        ],
                      );
                    },
                  );
                },
              ),

              // Scroll-to-bottom button
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                right: 14,
                bottom: _showScrollToBottom ? 14 : -60,
                child: _ScrollToBottomButton(
                  onTap: () => _scrollToBottom(animate: true),
                ),
              ),
            ],
          ),
        ),
        _buildInput(bottomPad),
      ],
    );
  }

  /// Date of the first (chronologically oldest) message in a display item.
  DateTime _itemDate(_DisplayItem item) => switch (item) {
        _SingleItem s => s.message.createdAt,
        _GroupItem g => g.messages.first.createdAt,
      };

  /// User-id of the sender for the most recent message in a display item.
  String? _itemUserId(_DisplayItem item) => switch (item) {
        _SingleItem s => s.message.userId,
        _GroupItem g => g.messages.last.userId,
      };

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Между нами девочка...', style: AppTypography.titleSmall),
              Text('Групповой чат',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textTertiary)),
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
              size: 56, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Начните общение!\nНапишите первое сообщение',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildInput(double bottomPad) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(left: 8, right: 8, top: 8, bottom: bottomPad + 4),
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
              _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.image_outlined,
                          color: AppColors.textTertiary, size: 24),
                      onPressed: _pickImages,
                      padding: const EdgeInsets.all(8),
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
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
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _inputController,
                builder: (_, value, __) {
                  final hasText = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
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
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
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
            child: const Icon(Icons.close,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Scroll-to-bottom FAB
// ---------------------------------------------------------------------------

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScrollToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: Color(0x20000000),
                blurRadius: 8,
                offset: Offset(0, 2))
          ],
        ),
        child: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary, size: 22),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message menu bottom sheet
// ---------------------------------------------------------------------------

class _MessageMenuSheet extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageMenuSheet({
    required this.message,
    required this.isMe,
    this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (message.text != null) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(message.text!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
            if (onCopy != null)
              _MenuItem(
                icon: Icons.copy_outlined,
                label: 'Копировать',
                color: AppColors.textPrimary,
                onTap: () {
                  Navigator.pop(context);
                  onCopy!();
                },
              ),
            if (onEdit != null)
              _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Редактировать',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            if (onDelete != null)
              _MenuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Удалить',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title:
          Text(label, style: AppTypography.bodyMedium.copyWith(color: color)),
      onTap: onTap,
    );
  }
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
      const months = [
        '',
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря'
      ];
      label = '${date.day} ${months[date.month]}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 12)),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Media group bubble — Telegram-style photo grid
// ---------------------------------------------------------------------------

class _MediaGroupBubble extends StatelessWidget {
  final _GroupItem group;
  final bool isMe;
  final bool showAvatar;
  final void Function(ChatMessage) onLongPress;

  static const double _maxWidth = 260;
  static const double _gap = 2;

  const _MediaGroupBubble({
    required this.group,
    required this.isMe,
    required this.showAvatar,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final firstMsg = group.messages.first;

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 8 : 2,
        bottom: 4,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: showAvatar ? _buildAvatar(firstMsg) : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => onLongPress(firstMsg),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        firstMsg.senderName,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _buildGrid(),
                  ),
                  if (group.caption != null && group.caption!.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.myMessage
                            : AppColors.otherMessage,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 3,
                              offset: Offset(0, 1))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              group.caption!,
                              style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary, height: 1.35),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.messages.last.timeFormatted,
                            style: AppTypography.labelSmall.copyWith(
                                fontSize: 10, color: AppColors.textTertiary),
                          ),
                        ],
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

  Widget _buildAvatar(ChatMessage msg) {
    if (msg.senderPhotoUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: msg.senderPhotoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              AppAvatar(name: msg.senderName, size: AvatarSize.small),
        ),
      );
    }
    return AppAvatar(name: msg.senderName, size: AvatarSize.small);
  }

  Widget _buildGrid() {
    final urls = group.messages
        .where((m) => m.imageUrl != null)
        .map((m) => m.imageUrl!)
        .toList();
    final n = urls.length;
    final time = group.messages.last.timeFormatted;
    final hasCaption = group.caption != null && group.caption!.isNotEmpty;

    if (n == 1) {
      return _gridPhoto(urls[0], _maxWidth, 200, showTime: !hasCaption, time: time);
    }
    if (n == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gridPhoto(urls[0], (_maxWidth - _gap) / 2, 180),
          const SizedBox(width: _gap),
          _gridPhoto(urls[1], (_maxWidth - _gap) / 2, 180,
              showTime: !hasCaption, time: time),
        ],
      );
    }
    if (n == 3) {
      // 1 tall on left + 2 stacked on right
      final half = (_maxWidth - _gap) / 2;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _gridPhoto(urls[0], half, 180 + _gap + 130),
          const SizedBox(width: _gap),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _gridPhoto(urls[1], half, 180),
              const SizedBox(height: _gap),
              _gridPhoto(urls[2], half, 130,
                  showTime: !hasCaption, time: time),
            ],
          ),
        ],
      );
    }
    // 4+ → 2-column grid, last cell shows "+N" if more than 4
    final showCount = n > 4 ? n - 4 : 0;
    final displayUrls = urls.take(4).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gridPhoto(displayUrls[0], (_maxWidth - _gap) / 2, 130),
            const SizedBox(width: _gap),
            _gridPhoto(displayUrls[1], (_maxWidth - _gap) / 2, 130),
          ],
        ),
        const SizedBox(height: _gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gridPhoto(displayUrls[2], (_maxWidth - _gap) / 2, 130),
            const SizedBox(width: _gap),
            _gridPhotoWithOverlay(
              displayUrls[3],
              (_maxWidth - _gap) / 2,
              130,
              showTime: !hasCaption,
              time: time,
              overlapCount: showCount,
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridPhoto(
    String url,
    double w,
    double h, {
    bool showTime = false,
    String? time,
  }) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.surfaceTertiary),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceTertiary,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.textTertiary),
            ),
          ),
          if (showTime && time != null)
            Positioned(
              bottom: 6,
              right: 8,
              child: _overlaidTime(time),
            ),
        ],
      ),
    );
  }

  Widget _gridPhotoWithOverlay(
    String url,
    double w,
    double h, {
    bool showTime = false,
    String? time,
    int overlapCount = 0,
  }) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.surfaceTertiary),
            errorWidget: (_, __, ___) => Container(color: AppColors.surfaceTertiary),
          ),
          if (overlapCount > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '+$overlapCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (showTime && time != null && overlapCount == 0)
            Positioned(
              bottom: 6,
              right: 8,
              child: _overlaidTime(time),
            ),
        ],
      ),
    );
  }

  Widget _overlaidTime(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(time,
          style: const TextStyle(fontSize: 10, color: Colors.white)),
    );
  }
}

// ---------------------------------------------------------------------------
// Single message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final bool isTail;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.isTail,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _buildDeleted();

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 8 : 2,
        bottom: isTail ? 4 : 1,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: showAvatar ? _buildAvatar() : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
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
    final hasImage = message.imageUrl != null;
    final hasText = message.text != null && message.text!.isNotEmpty;

    if (hasImage && !hasText) return _buildImageOnlyBubble();
    if (hasImage && hasText) return _buildImageCaptionBubble();
    return _buildTextBubble();
  }

  Widget _buildTextBubble() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: _bubbleDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe && showAvatar) ...[
                _senderName(),
                const SizedBox(height: 2),
              ],
              _buildTextWithTime(message.text!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextWithTime(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textPrimary, height: 1.35)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_inlineMeta()],
        ),
      ],
    );
  }

  Widget _buildImageOnlyBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: _bubbleDecoration(noPadding: true),
      child: ClipRRect(
        borderRadius: _bubbleBorderRadius(),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: message.imageUrl!,
              fit: BoxFit.cover,
              width: 260,
              placeholder: (_, __) => Container(
                width: 260,
                height: 180,
                color: AppColors.surfaceTertiary,
                child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 260,
                height: 80,
                color: AppColors.surfaceTertiary,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 8,
              child: _overlaidTime(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCaptionBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: _bubbleDecoration(noPadding: true),
      child: ClipRRect(
        borderRadius: _bubbleBorderRadius(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && showAvatar)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _senderName(),
              ),
            CachedNetworkImage(
              imageUrl: message.imageUrl!,
              fit: BoxFit.cover,
              width: 260,
              placeholder: (_, __) => Container(
                width: 260,
                height: 180,
                color: AppColors.surfaceTertiary,
                child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: _buildTextWithTime(message.text!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _senderName() {
    return Text(message.senderName,
        style: AppTypography.labelSmall.copyWith(
            color: AppColors.primary, fontWeight: FontWeight.w700));
  }

  Widget _inlineMeta() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Text('изм. ',
              style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic)),
        Text(message.timeFormatted,
            style: AppTypography.labelSmall
                .copyWith(fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _overlaidTime() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEdited)
            const Text('изм. ',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic)),
          Text(message.timeFormatted,
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        ],
      ),
    );
  }

  BoxDecoration _bubbleDecoration({bool noPadding = false}) {
    return BoxDecoration(
      color: isMe ? AppColors.myMessage : AppColors.otherMessage,
      borderRadius: _bubbleBorderRadius(),
      boxShadow: const [
        BoxShadow(
            color: AppColors.shadow, blurRadius: 3, offset: Offset(0, 1))
      ],
    );
  }

  BorderRadius _bubbleBorderRadius() {
    const r = Radius.circular(18);
    const rSmall = Radius.circular(4);
    if (isMe) {
      return BorderRadius.only(
        topLeft: r,
        topRight: r,
        bottomLeft: r,
        bottomRight: isTail ? rSmall : r,
      );
    } else {
      return BorderRadius.only(
        topLeft: r,
        topRight: r,
        bottomLeft: isTail ? rSmall : r,
        bottomRight: r,
      );
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text('Сообщение удалено',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo preview page — multi-select, Telegram style
// ---------------------------------------------------------------------------

class _PhotoPreviewPage extends StatefulWidget {
  final List<XFile> images;
  const _PhotoPreviewPage({required this.images});

  @override
  State<_PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<_PhotoPreviewPage> {
  final _captionCtrl = TextEditingController();
  final _captionFocus = FocusNode();
  late final PageController _pageCtrl;

  late List<XFile> _images;
  int _currentIndex = 0;
  final Map<String, Uint8List> _cache = {};

  @override
  void initState() {
    super.initState();
    _images = List<XFile>.from(widget.images);
    _pageCtrl = PageController();
    _preloadAll();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _captionFocus.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _preloadAll() async {
    for (final f in _images) {
      if (!_cache.containsKey(f.path)) {
        final bytes = await f.readAsBytes();
        if (mounted) setState(() => _cache[f.path] = bytes);
      }
    }
  }

  void _removeImage(int index) {
    if (_images.length == 1) {
      Navigator.pop(context, null);
      return;
    }
    setState(() {
      _images.removeAt(index);
      if (_currentIndex >= _images.length) {
        _currentIndex = _images.length - 1;
      }
      _pageCtrl.jumpToPage(_currentIndex);
    });
  }

  void _send() => Navigator.pop(
      context,
      _PreviewResult(
          images: _images, caption: _captionCtrl.text.trim()));

  void _cancel() => Navigator.pop(context, null);

  @override
  Widget build(BuildContext context) {
    final isMulti = _images.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 26),
                    onPressed: _cancel,
                  ),
                  const Spacer(),
                  Text(
                    isMulti
                        ? 'Отправить ${_images.length} фото'
                        : 'Отправить фото',
                    style: AppTypography.titleSmall
                        .copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Main image
            Expanded(
              child: GestureDetector(
                onTap: () => _captionFocus.unfocus(),
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _images.length,
                  onPageChanged: (i) =>
                      setState(() => _currentIndex = i),
                  itemBuilder: (_, i) {
                    final bytes = _cache[_images[i].path];
                    if (bytes == null) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white));
                    }
                    return InteractiveViewer(
                      child: Center(
                          child: Image.memory(bytes,
                              fit: BoxFit.contain,
                              gaplessPlayback: true)),
                    );
                  },
                ),
              ),
            ),

            // Thumbnail strip (multi only)
            if (isMulti)
              Container(
                height: 72,
                color: Colors.black,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _images.length,
                  itemBuilder: (_, i) {
                    final bytes = _cache[_images[i].path];
                    final selected = i == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageCtrl.jumpToPage(i);
                        setState(() => _currentIndex = i);
                      },
                      child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: selected
                                  ? Border.all(
                                      color: AppColors.primary,
                                      width: 2)
                                  : Border.all(
                                      color: Colors.white24, width: 1),
                            ),
                            child: bytes == null
                                ? Container(
                                    color: Colors.white12,
                                    child: const Icon(Icons.image,
                                        color: Colors.white38, size: 20))
                                : ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    child: Image.memory(bytes,
                                        fit: BoxFit.cover),
                                  ),
                          ),
                          Positioned(
                            top: 0,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Caption bar
            _buildCaptionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionBar() {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _captionCtrl,
                focusNode: _captionFocus,
                style:
                    const TextStyle(color: Colors.black87, fontSize: 15),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Добавьте подпись...',
                  hintStyle:
                      TextStyle(color: Colors.black38, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
