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

// ---------------------------------------------------------------------------
// Country config
// ---------------------------------------------------------------------------

class _Country {
  final String flagUrl; // Apple emoji PNG from CDN
  final String name;
  final String prefix;
  final String mask;    // # = digit placeholder
  final String hint;

  const _Country({
    required this.flagUrl,
    required this.name,
    required this.prefix,
    required this.mask,
    required this.hint,
  });
}

// Apple emoji CDN (jsdelivr)
const _appleEmojiBase =
    'https://cdn.jsdelivr.net/npm/emoji-datasource-apple/img/apple/64';

const _countries = [
  _Country(
    // 🇷🇺 = 1f1f7-1f1fa
    flagUrl: '$_appleEmojiBase/1f1f7-1f1fa.png',
    name: 'Россия',
    prefix: '+7',
    mask: '+7 (###) ###-##-##',
    hint: '+7 (999) 123-45-67',
  ),
  _Country(
    // 🇺🇿 = 1f1fa-1f1ff
    flagUrl: '$_appleEmojiBase/1f1fa-1f1ff.png',
    name: 'Узбекистан',
    prefix: '+998',
    mask: '+998 ## ###-##-##',
    hint: '+998 90 123-45-67',
  ),
];

// ---------------------------------------------------------------------------
// Phone mask formatter
// ---------------------------------------------------------------------------

class _PhoneMaskFormatter extends TextInputFormatter {
  final String mask; // e.g. "+7 (###) ###-##-##"

  _PhoneMaskFormatter(this.mask);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract only digits from the new input
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Count digits in the prefix (non-# chars before first #)
    final prefixDigits = mask
        .substring(0, mask.indexOf('#'))
        .replaceAll(RegExp(r'\D'), '');

    // The digits the user typed (without prefix digits)
    final userDigits = digits.startsWith(prefixDigits)
        ? digits.substring(prefixDigits.length)
        : digits;

    final buf = StringBuffer();
    int digitIdx = 0;

    for (int i = 0; i < mask.length; i++) {
      final ch = mask[i];
      if (ch == '#') {
        if (digitIdx < userDigits.length) {
          buf.write(userDigits[digitIdx++]);
        } else {
          break;
        }
      } else {
        // Only write separator if we've already written at least one user digit
        // or it's part of the prefix
        if (digitIdx > 0 || i < mask.indexOf('#')) {
          buf.write(ch);
        }
      }
    }

    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

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
  _Country _selectedCountry = _countries[0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExistingSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Timer? _pollTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _step == _AuthStep.linkTelegram &&
        _botOpened) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _checkLinkStatus();
    // Keep polling every 3s while user is on this screen
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_step != _AuthStep.linkTelegram || !mounted) {
        _pollTimer?.cancel();
        return;
      }
      _checkLinkStatus();
    });
  }

  Future<void> _checkLinkStatus() async {
    final auth = AuthService();
    final user = await auth.fetchProfile();
    if (!mounted) return;

    if (user != null && user['telegram_account'] != null) {
      _pollTimer?.cancel();
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _checkExistingSession() async {
    final auth = AuthService();
    final loggedIn = await auth.isLoggedIn;
    if (!loggedIn || !mounted) return;

    // Fetch fresh profile to confirm Telegram link
    final user = await auth.fetchProfile();
    if (!mounted) return;

    if (user != null && user['telegram_account'] != null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (user != null) {
      // Logged in but Telegram not linked — force link step
      setState(() => _step = _AuthStep.linkTelegram);
    }
  }

  Future<void> _sendCode() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }

    // Strip everything except digits and leading +
    final formatted = '+${raw.replaceAll(RegExp(r'\D'), '')}';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = AuthService();
    final user = await auth.fetchProfile();

    if (!mounted) return;

    if (user != null && user['telegram_account'] != null) {
      _pollTimer?.cancel();
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Telegram ещё не привязан.\nНажмите Start в боте и поделитесь контактом.';
      });
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

  void _onCountryChanged(_Country country) {
    setState(() {
      _selectedCountry = country;
      _phoneController.clear();
    });
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Номер телефона', style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Country selector
              _CountrySelector(
                selected: _selectedCountry,
                countries: _countries,
                onChanged: _onCountryChanged,
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              // Phone input
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendCode(),
                  style: AppTypography.bodyLarge,
                  inputFormatters: [
                    _PhoneMaskFormatter(_selectedCountry.mask),
                  ],
                  decoration: InputDecoration(
                    hintText: _selectedCountry.hint,
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
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
        const SizedBox(height: 16),
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
            text: 'Я привязал — проверить',
            type: AppButtonType.secondary,
            onPressed: _checkLinkAndProceed,
          ),
      ],
    );
  }
}

enum _AuthStep { phone, code, linkTelegram }

// ---------------------------------------------------------------------------

class _CountrySelector extends StatelessWidget {
  final _Country selected;
  final List<_Country> countries;
  final ValueChanged<_Country> onChanged;

  const _CountrySelector({
    required this.selected,
    required this.countries,
    required this.onChanged,
  });

  Widget _flag(String url) => Image.network(
        url,
        width: 28,
        height: 28,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.flag_outlined, size: 24),
      );

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Country>(
      onSelected: onChanged,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 52),
      itemBuilder: (_) => countries
          .map(
            (c) => PopupMenuItem<_Country>(
              value: c,
              child: Row(
                children: [
                  _flag(c.flagUrl),
                  const SizedBox(width: 10),
                  Text(c.name, style: AppTypography.bodyMedium),
                  const SizedBox(width: 6),
                  Text(
                    c.prefix,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _flag(selected.flagUrl),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
