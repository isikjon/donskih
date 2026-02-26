import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_bottom_nav.dart';
import '../content/content_tab.dart';
import '../home/base_tab.dart';
import '../chat/chat_tab.dart';
import '../profile/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _avatarUrl;
  bool _isBlocked = false;

  // Unread tracking
  bool _showHomeDot = false;
  bool _showChatDot = false;
  int _lastSeenChatCount = 0;
  StreamSubscription<dynamic>? _chatSub;

  final List<Widget> _tabs = const [
    ContentTab(),
    BaseTab(),
    ChatTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    // Subscribe to chat stream to detect new messages
    _chatSub = ChatService().stream.listen(_onChatUpdate);
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  void _onChatUpdate(List<dynamic> messages) {
    if (!mounted) return;
    // Only show dot if user is NOT currently on the chat tab
    if (_currentIndex != 2 && messages.length > _lastSeenChatCount) {
      setState(() => _showChatDot = true);
    }
  }

  void _onTabTap(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) _showHomeDot = false;
      if (index == 2) {
        _showChatDot = false;
        _lastSeenChatCount = ChatService().messages.length;
      }
    });
  }

  Future<void> _loadAvatar() async {
    final auth = AuthService();

    // Check blocked flag from previous session first (instant feedback)
    if (await auth.isBlocked && mounted) {
      setState(() => _isBlocked = true);
      return;
    }

    var user = await auth.fetchProfile();
    if (!mounted) return;

    // fetchProfile sets isBlocked flag if server returned 403
    if (await auth.isBlocked) {
      setState(() => _isBlocked = true);
      return;
    }

    user ??= await auth.getUser();
    if (user != null && mounted) {
      final tg = user['telegram_account'] as Map<String, dynamic>?;
      setState(() {
        _avatarUrl = tg?['photo_url'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked) return const _BlockedScreen();

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        avatarUrl: _avatarUrl,
        showHomeDot: _showHomeDot,
        showChatDot: _showChatDot,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen();

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('https://t.me/DonskihCom');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 44,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Аккаунт заблокирован',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ваш аккаунт был заблокирован администратором.\nЕсли вы считаете это ошибкой — напишите в поддержку.',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openSupport,
                    icon: const Icon(Icons.telegram, size: 20),
                    label: const Text('Написать в поддержку'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _logout(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Выйти из аккаунта'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
