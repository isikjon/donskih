import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';
import 'admin_chat_moderation_screen.dart';
import 'admin_content_list_screen.dart';
import 'admin_login_screen.dart';
import 'admin_users_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});
  static const routeName = '/admin/main';

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  String? _adminKey;
  final _api = AdminApiService();

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _api.getAdminKey();
    if (mounted) setState(() => _adminKey = key);
  }

  Future<void> _logout() async {
    await _api.clearAdminKey();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AdminLoginScreen.routeName);
  }

  static const _navItems = [
    _NavItem(Icons.library_books_outlined, Icons.library_books_rounded, 'Контент'),
    _NavItem(Icons.school_outlined, Icons.school_rounded, 'База'),
    _NavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Пользователи'),
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Чат'),
  ];

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: isNarrow ? null : 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Donskih Admin', style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
            const Spacer(),
            if (!isNarrow) _buildDesktopNav(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Выйти',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
        bottom: isNarrow
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildMobileNav(),
              )
            : null,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          AdminContentListBody(adminKey: _adminKey, section: 'main'),
          AdminContentListBody(adminKey: _adminKey, section: 'base'),
          AdminUsersScreen(adminKey: _adminKey),
          AdminChatModerationScreen(adminKey: _adminKey),
        ],
      ),
    );
  }

  Widget _buildDesktopNav() {
    return Row(
      children: List.generate(_navItems.length, (i) {
        final item = _navItems[i];
        final selected = _selectedIndex == i;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton.icon(
            onPressed: () => setState(() => _selectedIndex = i),
            icon: Icon(
              selected ? item.activeIcon : item.icon,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            label: Text(
              item.label,
              style: AppTypography.labelSmall.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: selected ? AppColors.primaryLight : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMobileNav() {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final selected = _selectedIndex == i;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 20,
                      color: selected ? AppColors.primary : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: selected ? AppColors.primary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
