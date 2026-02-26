import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';
import 'admin_main_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  static const routeName = '/admin';

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _keyController = TextEditingController();
  final _api = AdminApiService();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _tryStoredKey();
  }

  Future<void> _tryStoredKey() async {
    final key = await _api.getAdminKey();
    if (key == null || key.isEmpty) return;
    setState(() => _loading = true);
    final list = await _api.fetchContentList(key);
    if (!mounted) return;
    setState(() => _loading = false);
    if (list != null) {
      Navigator.of(context).pushReplacementNamed(AdminMainScreen.routeName);
    }
  }

  Future<void> _submit() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Введите ключ');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final list = await _api.fetchContentList(key);
    if (!mounted) return;
    setState(() => _loading = false);
    if (list == null) {
      setState(() => _error = 'Неверный ключ или ошибка сети');
      return;
    }
    await _api.setAdminKey(key);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AdminMainScreen.routeName);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Админка контента',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Введите ключ администратора',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'X-Admin-Key',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                          )
                        : const Text('Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
