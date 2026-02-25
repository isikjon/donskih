import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
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
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final auth = AuthService();
    var user = await auth.getUser();
    user ??= await auth.fetchProfile();
    if (user != null && mounted) {
      final tg = user['telegram_account'] as Map<String, dynamic>?;
      setState(() {
        _avatarUrl = tg?['photo_url'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onTap: (index) => setState(() => _currentIndex = index),
        avatarUrl: _avatarUrl,
      ),
    );
  }
}
