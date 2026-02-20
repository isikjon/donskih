import 'package:flutter/material.dart';
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

  final List<Widget> _tabs = const [
    ContentTab(),
    BaseTab(),
    ChatTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 44,
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 0,
            right: 0,
            child: const _DynamicIsland(),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _DynamicIsland extends StatelessWidget {
  const _DynamicIsland();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF26061), Color(0xFFE84855)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30F26061),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 18, height: 18),
            const SizedBox(width: 8),
            Text(
              'Donskih',
              style: AppTypography.titleSmall.copyWith(
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
