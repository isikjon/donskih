import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/user.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';
import '../media_viewer/media_viewer_screen.dart';
import '../profile/user_profile_screen.dart';

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
  ChatMessage? _replyingToMessage;
  bool _isUploading = false;
  bool _showScrollToBottom = false;

  /// Tracks local file paths for optimistic image messages (tempId → filePath)
  final Map<String, String> _localImagePaths = {};
  /// Tracks upload progress for optimistic messages (tempId → 0.0..1.0)
  final Map<String, double> _uploadProgressMap = {};

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
      if (msg.isDeleted) {
        i++;
        continue;
      }
      final gid = msg.groupId;
      if (gid != null && msg.imageUrl != null) {
        final group = <ChatMessage>[];
        while (i < msgs.length && msgs[i].groupId == gid) {
          if (!msgs[i].isDeleted) group.add(msgs[i]);
          i++;
        }
        if (group.isEmpty) continue;
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
    final replyId = _replyingToMessage?.id;
    _inputController.clear();
    _cancelReply();
    await _chat.sendTextMessage(text, replyToMessageId: replyId);
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

      // Create optimistic placeholders so user sees images immediately
      final tempIds = <String>[];
      for (int i = 0; i < result.images.length; i++) {
        final tempId = 'upload_${DateTime.now().millisecondsSinceEpoch}_$i';
        tempIds.add(tempId);

        final isLast = i == result.images.length - 1;
        final cap = (isLast && result.caption.isNotEmpty)
            ? result.caption
            : null;

        _localImagePaths[tempId] = result.images[i].path;
        _uploadProgressMap[tempId] = 0.0;

        final placeholder = ChatMessage(
          id: tempId,
          userId: _chat.currentUserId ?? '',
          senderName: '',
          text: cap,
          imageUrl: 'file://${result.images[i].path}',
          groupId: groupId,
          isDeleted: false,
          isEdited: false,
          createdAt: DateTime.now(),
          status: MessageStatus.sending,
          uploadProgress: 0.0,
        );
        _chat.addOptimistic(placeholder);
      }
      _scrollToBottom();

      // Upload one by one
      for (int i = 0; i < result.images.length; i++) {
        final tempId = tempIds[i];
        final url = await _chat.uploadImage(
          result.images[i],
          onProgress: (p) {
            _uploadProgressMap[tempId] = p;
            _chat.updateOptimisticProgress(tempId, p);
          },
        );

        // Remove optimistic placeholder
        _localImagePaths.remove(tempId);
        _uploadProgressMap.remove(tempId);
        _chat.removeOptimistic(tempId);

        if (url != null && mounted) {
          final isLast = i == result.images.length - 1;
          final cap = (isLast && result.caption.isNotEmpty)
              ? result.caption
              : null;
          final replyId = _replyingToMessage?.id;
          if (i == 0) _cancelReply();
          await _chat.sendImageMessage(url, caption: cap, groupId: groupId, replyToMessageId: replyId);
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
        onReply: () {
          setState(() {
            _replyingToMessage = msg;
            _editingMessage = null;
          });
          _inputFocus.requestFocus();
        },
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

  void _cancelReply() {
    setState(() => _replyingToMessage = null);
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _replyingToMessage = null;
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

  void _openMediaViewer(
    BuildContext context, {
    required List<String> imageUrls,
    required int initialIndex,
    String? caption,
    String? heroTag,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          caption: caption,
          heroTag: heroTag,
        ),
      ),
    );
  }

  void _openUserProfile(
    BuildContext context, {
    required User user,
    required String heroTag,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          user: user,
          heroTag: heroTag,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final navPad = MediaQuery.of(context).padding.bottom + 10.0;
    // max() eliminates the "teleport" on iOS interactive dismiss:
    // input tracks the keyboard down but never drops below navPad position.
    final bottomPad = kb > navPad ? kb : navPad;

    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(
          child: GestureDetector(
            onTap: () => _inputFocus.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                StreamBuilder<List<ChatMessage>>(
                  stream: _chat.stream,
                  initialData: _chat.messages,
                  builder: (context, snapshot) {
                    final msgs = snapshot.data ?? [];
                    if (msgs.isEmpty) return _buildEmpty();

                    final items = _buildDisplayItems(msgs);
                    final replyToMap = {for (final m in msgs) m.id: m};

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scrollController.hasClients) return;
                      if (_scrollController.position.pixels < 140) {
                        _scrollController.jumpTo(0);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: items.length,
                      itemBuilder: (context, revIdx) {
                        final origIdx = items.length - 1 - revIdx;
                        final item = items[origIdx];

                        final DateTime thisDate = _itemDate(item);

                        final olderItem =
                            origIdx > 0 ? items[origIdx - 1] : null;
                        final showDateDivider = olderItem == null ||
                            !_sameDay(_itemDate(olderItem), thisDate);

                        Widget child;
                        if (item is _SingleItem) {
                          final msg = item.message;
                          final isMe = _chat.isMyMessage(msg);

                          final newerItem = origIdx < items.length - 1
                              ? items[origIdx + 1]
                              : null;
                          final showAvatar = !isMe &&
                              (newerItem == null ||
                                  _itemUserId(newerItem) != msg.userId);
                          final isTail = showAvatar;

                          child = _MessageBubble(
                            message: msg,
                            replyToMessage: msg.replyToMessageId != null
                                ? replyToMap[msg.replyToMessageId]
                                : null,
                            onReplyBlockTap: _scrollToMessageId,
                            isMe: isMe,
                            showAvatar: showAvatar,
                            isTail: isTail,
                            onLongPress: () => _showMessageMenu(msg),
                            onAvatarTap: showAvatar
                                ? () => _openUserProfile(
                                      context,
                                      user: User(
                                        id: msg.userId,
                                        name: msg.senderName,
                                        avatarUrl: msg.senderPhotoUrl,
                                      ),
                                      heroTag: 'chat_avatar_${msg.id}',
                                    )
                                : null,
                            avatarHeroTag:
                                showAvatar ? 'chat_avatar_${msg.id}' : null,
                            onImageTap: msg.imageUrl != null &&
                                    msg.status != MessageStatus.sending
                                ? () => _openMediaViewer(
                                      context,
                                      imageUrls: [msg.imageUrl!],
                                      initialIndex: 0,
                                      caption: msg.text,
                                      heroTag: 'media_${msg.id}',
                                    )
                                : null,
                            imageHeroTag: msg.imageUrl != null
                                ? 'media_${msg.id}'
                                : null,
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
                          final groupImageMessages = g.messages
                              .where((m) => m.imageUrl != null)
                              .toList();
                          final groupUrls = groupImageMessages
                              .map((m) => m.imageUrl!)
                              .toList();

                          child = _MediaGroupBubble(
                            group: g,
                            replyToMessage: g.messages.first.replyToMessageId != null
                                ? replyToMap[g.messages.first.replyToMessageId]
                                : null,
                            onReplyBlockTap: _scrollToMessageId,
                            isMe: isMe,
                            showAvatar: showAvatar,
                            onLongPress: (msg) => _showMessageMenu(msg),
                            onAvatarTap: showAvatar
                                ? () => _openUserProfile(
                                      context,
                                      user: User(
                                        id: g.messages.first.userId,
                                        name: g.messages.first.senderName,
                                        avatarUrl:
                                            g.messages.first.senderPhotoUrl,
                                      ),
                                      heroTag: 'chat_avatar_${g.messages.first.id}',
                                    )
                                : null,
                            avatarHeroTag: showAvatar
                                ? 'chat_avatar_${g.messages.first.id}'
                                : null,
                            onImageTap: groupUrls.isNotEmpty
                                ? (int index) => _openMediaViewer(
                                      context,
                                      imageUrls: groupUrls,
                                      initialIndex: index,
                                      caption: g.caption,
                                      heroTag: 'media_${groupImageMessages[index].id}',
                                    )
                                : null,
                          );
                        }

                        final replyTarget = item is _SingleItem
                            ? (item as _SingleItem).message
                            : (item as _GroupItem).messages.first;
                        final wrappedChild = _SwipeToReplyWrapper(
                          message: replyTarget,
                          onReply: (m) {
                            setState(() {
                              _replyingToMessage = m;
                              _editingMessage = null;
                            });
                            _inputFocus.requestFocus();
                          },
                          child: child,
                        );

                        return Column(
                          children: [
                            if (showDateDivider)
                              _DateDivider(date: thisDate),
                            wrappedChild,
                          ],
                        );
                      },
                    );
                  },
                ),

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
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _replyingToMessage != null
              ? _ReplyPreview(
                  message: _replyingToMessage!,
                  onClose: _cancelReply,
                )
              : const SizedBox.shrink(),
        ),
        _buildInput(bottomPad),
      ],
    );
  }

  void _scrollToMessageId(String messageId) {
    final msgs = _chat.messages;
    final items = _buildDisplayItems(msgs);
    int? origIdx;
    for (int i = 0; i < items.length; i++) {
      if (_itemContainsMessageId(items[i], messageId)) {
        origIdx = i;
        break;
      }
    }
    if (origIdx == null) return;
    final revIdx = items.length - 1 - origIdx;
    const estimatedItemHeight = 100.0;
    final offset = revIdx * estimatedItemHeight;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _itemContainsMessageId(_DisplayItem item, String messageId) {
    return switch (item) {
      _SingleItem s => s.message.id == messageId,
      _GroupItem g => g.messages.any((m) => m.id == messageId),
    };
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
    return Container(
      padding:
          EdgeInsets.only(left: 8, right: 8, top: 8, bottom: bottomPad),
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

// ---------------------------------------------------------------------------
// Swipe-to-reply wrapper (Telegram-style)
// ---------------------------------------------------------------------------

const double _kSwipeReplyThreshold = 72.0;
const double _kSwipeReplyMax = 100.0;

class _SwipeToReplyWrapper extends StatefulWidget {
  final ChatMessage message;
  final void Function(ChatMessage) onReply;
  final Widget child;

  const _SwipeToReplyWrapper({
    required this.message,
    required this.onReply,
    required this.child,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> {
  double _offset = 0;

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.message.isDeleted) return;
    // Prefer horizontal drag so list scroll still works for vertical swipes
    if (d.delta.dx.abs() >= d.delta.dy.abs()) {
      setState(() {
        _offset = (_offset + d.delta.dx).clamp(0.0, _kSwipeReplyMax);
      });
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_offset >= _kSwipeReplyThreshold) {
      widget.onReply(widget.message);
    }
    setState(() => _offset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      children: [
        if (_offset > 4)
          Positioned(
            left: 14,
            child: Opacity(
              opacity: (_offset / _kSwipeReplyThreshold).clamp(0.0, 1.0),
              child: Icon(
                Icons.reply_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reply preview bar (above input)
// ---------------------------------------------------------------------------

class _ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onClose;

  const _ReplyPreview({required this.message, required this.onClose});

  static String _previewText(ChatMessage m) {
    if (m.text != null && m.text!.trim().isNotEmpty) return m.text!.trim();
    if (m.imageUrl != null) return '📷 Фото';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTertiary,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                    decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                      color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _previewText(message),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
              onPressed: onClose,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
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
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageMenuSheet({
    required this.message,
    required this.isMe,
    this.onReply,
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
            if (onReply != null)
              _MenuItem(
                icon: Icons.reply_rounded,
                label: 'Ответить',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  onReply!();
                },
              ),
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
  final ChatMessage? replyToMessage;
  final void Function(String messageId)? onReplyBlockTap;
  final bool isMe;
  final bool showAvatar;
  final void Function(ChatMessage) onLongPress;
  final void Function(int index)? onImageTap;
  final VoidCallback? onAvatarTap;
  final String? avatarHeroTag;

  static const double _maxWidth = 260;
  static const double _gap = 2;

  const _MediaGroupBubble({
    required this.group,
    this.replyToMessage,
    this.onReplyBlockTap,
    required this.isMe,
    required this.showAvatar,
    required this.onLongPress,
    this.onImageTap,
    this.onAvatarTap,
    this.avatarHeroTag,
  });

  Widget _buildReplyBlock() {
    final reply = replyToMessage;
    if (reply == null || onReplyBlockTap == null) return const SizedBox.shrink();
    String preview = reply.text != null && reply.text!.trim().isNotEmpty
        ? reply.text!.trim()
        : (reply.imageUrl != null ? '📷 Фото' : '—');
    final lineColor = isMe ? AppColors.textOnPrimary.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.85);
    final nameColor = isMe ? AppColors.textOnPrimary.withValues(alpha: 0.85) : AppColors.primary.withValues(alpha: 0.9);
    final textColor = isMe ? AppColors.textOnPrimary.withValues(alpha: 0.65) : AppColors.textSecondary.withValues(alpha: 0.9);
    return GestureDetector(
      onTap: () => onReplyBlockTap!(reply.id),
      child: Opacity(
        opacity: 0.92,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: lineColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reply.senderName,
                style: AppTypography.labelSmall.copyWith(
                  color: nameColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                preview,
                style: AppTypography.bodySmall.copyWith(
                  color: textColor,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  _buildUnifiedBubble(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedBubble() {
    final hasCaption = group.caption != null && group.caption!.isNotEmpty;
    final lastMsg = group.messages.last;

    return Container(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      decoration: BoxDecoration(
        color: isMe ? AppColors.myMessage : AppColors.otherMessage,
        borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadow,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
                ],
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
                children: [
            if (replyToMessage != null) _buildReplyBlock(),
            _buildGrid(),
            if (hasCaption)
                    Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.caption!,
                      style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary, height: 1.35),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lastMsg.timeFormatted,
                          style: AppTypography.labelSmall.copyWith(
                              fontSize: 10, color: AppColors.textTertiary),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          _statusIconFor(lastMsg, color: AppColors.textTertiary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusIconFor(ChatMessage msg, {Color? color}) {
    final c = color ?? AppColors.textTertiary;
    switch (msg.status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: 12, color: c);
      case MessageStatus.sent:
        return Icon(Icons.check, size: 12, color: c);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 12, color: c);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 12, color: color ?? AppColors.primary);
    }
  }

  List<ChatMessage> get _messagesWithImages =>
      group.messages.where((m) => m.imageUrl != null).toList();

  Widget _buildAvatar(ChatMessage msg) {
    Widget child;
    if (msg.senderPhotoUrl != null) {
      child = ClipOval(
        child: CachedNetworkImage(
          imageUrl: msg.senderPhotoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              AppAvatar(name: msg.senderName, size: AvatarSize.small),
        ),
      );
    } else {
      child = AppAvatar(name: msg.senderName, size: AvatarSize.small);
    }

    if (avatarHeroTag != null) {
      child = Hero(tag: avatarHeroTag!, child: child);
    }
    if (onAvatarTap != null) {
      child = GestureDetector(onTap: onAvatarTap, child: child);
    }
    return child;
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
      return _gridPhoto(urls[0], _maxWidth, 200, index: 0,
          showTime: !hasCaption, time: time);
    }
    if (n == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gridPhoto(urls[0], (_maxWidth - _gap) / 2, 180, index: 0),
          const SizedBox(width: _gap),
          _gridPhoto(urls[1], (_maxWidth - _gap) / 2, 180, index: 1,
              showTime: !hasCaption, time: time),
        ],
      );
    }
    if (n == 3) {
      final half = (_maxWidth - _gap) / 2;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _gridPhoto(urls[0], half, 180 + _gap + 130, index: 0),
          const SizedBox(width: _gap),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _gridPhoto(urls[1], half, 180, index: 1),
              const SizedBox(height: _gap),
              _gridPhoto(urls[2], half, 130, index: 2,
                  showTime: !hasCaption, time: time),
            ],
          ),
        ],
      );
    }
    final showCount = n > 4 ? n - 4 : 0;
    final displayUrls = urls.take(4).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gridPhoto(displayUrls[0], (_maxWidth - _gap) / 2, 130, index: 0),
            const SizedBox(width: _gap),
            _gridPhoto(displayUrls[1], (_maxWidth - _gap) / 2, 130, index: 1),
          ],
        ),
        const SizedBox(height: _gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gridPhoto(displayUrls[2], (_maxWidth - _gap) / 2, 130, index: 2),
            const SizedBox(width: _gap),
            _gridPhotoWithOverlay(
              displayUrls[3],
              (_maxWidth - _gap) / 2,
              130,
              index: 3,
              showTime: !hasCaption,
              time: time,
              overlapCount: showCount,
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridImage(String url) {
    if (url.startsWith('file://')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        fit: BoxFit.cover,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.surfaceTertiary),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surfaceTertiary,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textTertiary),
      ),
    );
  }

  Widget _gridPhoto(
    String url,
    double w,
    double h, {
    int? index,
    bool showTime = false,
    String? time,
  }) {
    Widget content = _gridImage(url);
    if (index != null &&
        onImageTap != null &&
        index < _messagesWithImages.length &&
        _messagesWithImages[index].status != MessageStatus.sending) {
      final heroTag = 'media_${_messagesWithImages[index].id}';
      content = Hero(
        tag: heroTag,
        child: GestureDetector(
          onTap: () => onImageTap!(index),
          child: content,
        ),
      );
    }
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (group.messages.any((m) => m.imageUrl == url && m.status == MessageStatus.sending))
            _uploadOverlayFor(group.messages.firstWhere((m) => m.imageUrl == url)),
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

  Widget _uploadOverlayFor(ChatMessage msg) {
    final p = msg.uploadProgress ?? 0.0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: p > 0 ? p : null,
                  strokeWidth: 2.5,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                    ),
                  Text(
                  '${(p * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridPhotoWithOverlay(
    String url,
    double w,
    double h, {
    int? index,
    bool showTime = false,
    String? time,
    int overlapCount = 0,
  }) {
    Widget content = _gridImage(url);
    if (index != null &&
        onImageTap != null &&
        index < _messagesWithImages.length &&
        _messagesWithImages[index].status != MessageStatus.sending) {
      final heroTag = 'media_${_messagesWithImages[index].id}';
      content = Hero(
        tag: heroTag,
        child: GestureDetector(
          onTap: () => onImageTap!(index),
          child: content,
        ),
      );
    }
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time,
              style: const TextStyle(fontSize: 10, color: Colors.white)),
          if (isMe) ...[
            const SizedBox(width: 3),
            _statusIconFor(group.messages.last, color: Colors.white),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatMessage? replyToMessage;
  final void Function(String messageId)? onReplyBlockTap;
  final bool isMe;
  final bool showAvatar;
  final bool isTail;
  final VoidCallback onLongPress;
  final VoidCallback? onImageTap;
  final String? imageHeroTag;
  final VoidCallback? onAvatarTap;
  final String? avatarHeroTag;

  const _MessageBubble({
    required this.message,
    this.replyToMessage,
    this.onReplyBlockTap,
    required this.isMe,
    required this.showAvatar,
    required this.isTail,
    required this.onLongPress,
    this.onImageTap,
    this.imageHeroTag,
    this.onAvatarTap,
    this.avatarHeroTag,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return const SizedBox.shrink();

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
    Widget child;
    if (message.senderPhotoUrl != null) {
      child = ClipOval(
        child: CachedNetworkImage(
          imageUrl: message.senderPhotoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              AppAvatar(name: message.senderName, size: AvatarSize.small),
        ),
      );
    } else {
      child = AppAvatar(name: message.senderName, size: AvatarSize.small);
    }

    if (avatarHeroTag != null) {
      child = Hero(tag: avatarHeroTag!, child: child);
    }
    if (onAvatarTap != null) {
      child = GestureDetector(onTap: onAvatarTap, child: child);
    }
    return child;
  }

  Widget _buildBubble() {
    final hasImage = message.imageUrl != null;
    final hasText = message.text != null && message.text!.isNotEmpty;

    if (hasImage && !hasText) return _buildImageOnlyBubble();
    if (hasImage && hasText) return _buildImageCaptionBubble();
    return _buildTextBubble();
  }

  Widget _buildReplyBlock() {
    final reply = replyToMessage;
    if (reply == null || onReplyBlockTap == null) return const SizedBox.shrink();
    String preview = reply.text != null && reply.text!.trim().isNotEmpty
        ? reply.text!.trim()
        : (reply.imageUrl != null ? '📷 Фото' : '—');
    final lineColor = isMe ? AppColors.textOnPrimary.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.85);
    final nameColor = isMe ? AppColors.textOnPrimary.withValues(alpha: 0.85) : AppColors.primary.withValues(alpha: 0.9);
    final textColor = isMe ? AppColors.textOnPrimary.withValues(alpha: 0.65) : AppColors.textSecondary.withValues(alpha: 0.9);
    return GestureDetector(
      onTap: () => onReplyBlockTap!(reply.id),
      child: Opacity(
        opacity: 0.92,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: lineColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reply.senderName,
                style: AppTypography.labelSmall.copyWith(
                  color: nameColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                preview,
                style: AppTypography.bodySmall.copyWith(
                  color: textColor,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
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
              _buildReplyBlock(),
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

  bool get _isLocalFile => message.imageUrl?.startsWith('file://') ?? false;

  Widget _imageWidget({double? width, double? height}) {
    final url = message.imageUrl!;
    if (_isLocalFile) {
      final path = url.replaceFirst('file://', '');
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: width,
        height: height,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: width,
      placeholder: (_, __) => Container(
        width: width ?? 260,
        height: height ?? 180,
        color: AppColors.surfaceTertiary,
        child: const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary)),
      ),
      errorWidget: (_, __, ___) => Container(
        width: width ?? 260,
        height: height ?? 80,
        color: AppColors.surfaceTertiary,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textTertiary),
      ),
    );
  }

  Widget _uploadOverlay() {
    if (message.status != MessageStatus.sending || message.uploadProgress == null) {
      return const SizedBox.shrink();
    }
    final p = message.uploadProgress!;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: p > 0 ? p : null,
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
                Text(
                  '${(p * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrappedImage({required double width}) {
    Widget child = _imageWidget(width: width);
    if (imageHeroTag != null) {
      child = Hero(tag: imageHeroTag!, child: child);
    }
    if (onImageTap != null) {
      child = GestureDetector(onTap: onImageTap, child: child);
    }
    return child;
  }

  Widget _buildImageOnlyBubble() {
    final hasReply = replyToMessage != null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: _bubbleDecoration(noPadding: true),
      child: ClipRRect(
        borderRadius: _bubbleBorderRadius(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasReply)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _buildReplyBlock(),
              ),
            Stack(
              children: [
                _wrappedImage(width: 260),
                _uploadOverlay(),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: _overlaidTime(),
                ),
              ],
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
            if (replyToMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _buildReplyBlock(),
              ),
            Stack(
              children: [
                _wrappedImage(width: 260),
                _uploadOverlay(),
              ],
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

  Widget _statusIcon({Color? color}) {
    if (!isMe) return const SizedBox.shrink();
    final c = color ?? AppColors.textTertiary;
    switch (message.status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: 12, color: c);
      case MessageStatus.sent:
        return Icon(Icons.check, size: 12, color: c);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 12, color: c);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 12, color: color ?? AppColors.primary);
    }
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
        if (isMe) ...[
          const SizedBox(width: 3),
          _statusIcon(),
        ],
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
          if (isMe) ...[
            const SizedBox(width: 3),
            _statusIcon(color: Colors.white),
          ],
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
      resizeToAvoidBottomInset: false,
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
                onTap: () => _captionFocus.requestFocus(),
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
