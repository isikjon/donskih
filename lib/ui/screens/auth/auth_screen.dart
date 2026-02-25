import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  _AuthStep _step = _AuthStep.phone;
  bool _isLoading = false;
  String? _error;
  String _sessionId = '';
  bool _botOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExistingSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _step == _AuthStep.linkTelegram &&
        _botOpened) {
      _checkLinkAndProceed();
    }
  }

  Future<void> _checkExistingSession() async {
    final loggedIn = await AuthService().isLoggedIn;
    if (loggedIn && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }

    final formatted = phone.startsWith('+') ? phone : '+$phone';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('$apiBase/auth/telegram/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': formatted}),
      );

      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        setState(() {
          _sessionId = data['session_id'];
          _step = _AuthStep.code;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['detail'] ?? 'Ошибка отправки кода';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка соединения с сервером';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите код');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('$apiBase/auth/telegram/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': _sessionId, 'code': code}),
      );

      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200 && data['access_token'] != null) {
        final auth = AuthService();
        await auth.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );

        setState(() {
          _step = _AuthStep.linkTelegram;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['detail'] ?? 'Неверный код';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка соединения с сервером';
        _isLoading = false;
      });
    }
  }

  Future<void> _openBot() async {
    final uri = Uri.parse('https://t.me/donskih_authorization_bot');
    if (await canLaunchUrl(uri)) {
      _botOpened = true;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _checkLinkAndProceed() async {
    setState(() => _isLoading = true);

    final auth = AuthService();
    await auth.fetchProfile();
    final user = await auth.getUser();

    if (mounted) {
      if (user != null && user['telegram_account'] != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Telegram ещё не привязан. Нажмите Start в боте и поделитесь контактом.';
        });
      }
    }
  }

  void _goHome() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 32),

                Text(_title, style: AppTypography.displaySmall),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                if (_step == _AuthStep.phone) _buildPhoneStep(),
                if (_step == _AuthStep.code) _buildCodeStep(),
                if (_step == _AuthStep.linkTelegram) _buildLinkStep(),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Text(
                      _error!,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title {
    switch (_step) {
      case _AuthStep.phone:
        return 'Вход';
      case _AuthStep.code:
        return 'Код подтверждения';
      case _AuthStep.linkTelegram:
        return 'Привяжите Telegram';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _AuthStep.phone:
        return 'Введите номер телефона для входа';
      case _AuthStep.code:
        return 'Код отправлен в Telegram\nна номер ${_phoneController.text}';
      case _AuthStep.linkTelegram:
        return 'Откройте бот, нажмите Start\nи поделитесь контактом';
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        AppTextField(
          controller: _phoneController,
          label: 'Номер телефона',
          hint: '+7 999 123 45 67',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]')),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(
          text: 'Получить код в Telegram',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _sendCode,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        AppTextField(
          controller: _codeController,
          label: 'Код из Telegram',
          hint: '000000',
          prefixIcon: Icons.lock_outline,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofocus: true,
          onSubmitted: (_) => _verifyCode(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(
          text: 'Подтвердить',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyCode,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _step = _AuthStep.phone;
              _codeController.clear();
              _error = null;
            });
          },
          child: Text('Изменить номер', style: AppTypography.buttonSmall),
        ),
      ],
    );
  }

  Widget _buildLinkStep() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF0088CC).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.telegram, size: 36, color: Color(0xFF0088CC)),
        ),
        const SizedBox(height: 24),
        AppButton(
          text: 'Открыть бот в Telegram',
          onPressed: _openBot,
          icon: Icons.open_in_new_rounded,
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('Проверяю привязку...'),
              ],
            ),
          ),
        if (!_isLoading)
          AppButton(
            text: 'Я привязал — продолжить',
            type: AppButtonType.secondary,
            onPressed: _checkLinkAndProceed,
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _goHome,
          child: Text(
            'Пропустить',
            style: AppTypography.buttonSmall.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

enum _AuthStep { phone, code, linkTelegram }
