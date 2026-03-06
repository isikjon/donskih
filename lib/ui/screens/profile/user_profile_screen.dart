import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';
import '../media_viewer/media_viewer_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final User user;
  final String heroTag;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.heroTag,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late User _user;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final fresh = await UserService().fetchUserById(_user.id);
    if (fresh != null && mounted) {
      setState(() => _user = fresh);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _joinedText() {
    final joined = _user.joinedAt;
    if (joined == null) return '—';
    final df = DateFormat('d MMMM y', 'ru');
    return 'В приложении с ${df.format(joined)}';
  }

  String _statusText() {
    if (_user.isOnline == true) return 'в сети';
    if (_user.lastSeenAt != null) {
      final df = DateFormat('d MMMM y', 'ru');
      return 'был(а) ${df.format(_user.lastSeenAt!)}';
    }
    return '—';
  }

  void _openAvatar() {
    final url = _user.avatarUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerScreen(
          imageUrls: [url],
          initialIndex: 0,
          caption: null,
          heroTag: widget.heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Профиль', style: AppTypography.titleSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _openAvatar,
                    child: Hero(
                      tag: widget.heroTag,
                      child: AppAvatar(
                        name: _user.name,
                        size: AvatarSize.xlarge,
                        imageUrl: _user.avatarUrl,
                      ),
                    ),
                  ),
                  if (_loading)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(_user.name, style: AppTypography.headlineSmall),
            ),
            if (_user.username != null && _user.username!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '@${_user.username!}',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Center(
              child: Text(
                _statusText(),
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
              ),
            ),
            if (_user.bio != null && _user.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _user.bio!,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary, height: 1.35),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _InfoRow(
                    title: 'Username',
                    value: (_user.username != null && _user.username!.isNotEmpty)
                        ? '@${_user.username!}'
                        : '—',
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    title: 'Дата регистрации',
                    value: _joinedText(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

