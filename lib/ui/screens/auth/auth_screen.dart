import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';

// ---------------------------------------------------------------------------
// Country config
// ---------------------------------------------------------------------------

class _Country {
  final String flag; // emoji character
  final String name;
  final String prefix;
  final String mask; // # = digit placeholder
  final String hint;

  const _Country({
    required this.flag,
    required this.name,
    required this.prefix,
    required this.mask,
    required this.hint,
  });
}

const _countries = [
  _Country(
    flag: '🇷🇺',
    name: 'Россия',
    prefix: '+7',
    mask: '+7 (###) ###-##-##',
    hint: '+7 (999) 123-45-67',
  ),
  _Country(
    flag: '🇰🇿',
    name: 'Казахстан',
    prefix: '+7',
    mask: '+7 (###) ###-##-##',
    hint: '+7 (701) 123-45-67',
  ),
  _Country(
    flag: '🇺🇿',
    name: 'Узбекистан',
    prefix: '+998',
    mask: '+998 ## ###-##-##',
    hint: '+998 90 123-45-67',
  ),
  _Country(
    flag: '🇧🇾',
    name: 'Беларусь',
    prefix: '+375',
    mask: '+375 ## ###-##-##',
    hint: '+375 29 123-45-67',
  ),
  _Country(
    flag: '🇺🇦',
    name: 'Украина',
    prefix: '+380',
    mask: '+380 ## ###-##-##',
    hint: '+380 50 123-45-67',
  ),
  _Country(
    flag: '🇰🇬',
    name: 'Кыргызстан',
    prefix: '+996',
    mask: '+996 ### ###-###',
    hint: '+996 555 123-456',
  ),
  _Country(
    flag: '🇹🇯',
    name: 'Таджикистан',
    prefix: '+992',
    mask: '+992 ## ###-##-##',
    hint: '+992 90 123-45-67',
  ),
  _Country(
    flag: '🇹🇲',
    name: 'Туркменистан',
    prefix: '+993',
    mask: '+993 ## ##-##-##',
    hint: '+993 65 12-34-56',
  ),
  _Country(
    flag: '🇬🇪',
    name: 'Грузия',
    prefix: '+995',
    mask: '+995 ### ##-##-##',
    hint: '+995 555 12-34-56',
  ),
  _Country(
    flag: '🇦🇲',
    name: 'Армения',
    prefix: '+374',
    mask: '+374 ## ###-###',
    hint: '+374 91 123-456',
  ),
  _Country(
    flag: '🇦🇿',
    name: 'Азербайджан',
    prefix: '+994',
    mask: '+994 ## ###-##-##',
    hint: '+994 50 123-45-67',
  ),
  _Country(
    flag: '🇲🇩',
    name: 'Молдова',
    prefix: '+373',
    mask: '+373 ## ###-###',
    hint: '+373 69 123-456',
  ),
  _Country(
    flag: '🇹🇷',
    name: 'Турция',
    prefix: '+90',
    mask: '+90 ### ### ## ##',
    hint: '+90 555 123 45 67',
  ),
  _Country(
    flag: '🇮🇱',
    name: 'Израиль',
    prefix: '+972',
    mask: '+972 ## ###-##-##',
    hint: '+972 50 123-45-67',
  ),
  _Country(
    flag: '🇦🇪',
    name: 'ОАЭ',
    prefix: '+971',
    mask: '+971 ## ###-####',
    hint: '+971 50 123-4567',
  ),
  _Country(
    flag: '🇩🇪',
    name: 'Германия',
    prefix: '+49',
    mask: '+49 ### ########',
    hint: '+49 170 12345678',
  ),
  _Country(
    flag: '🇺🇸',
    name: 'США',
    prefix: '+1',
    mask: '+1 (###) ###-####',
    hint: '+1 (555) 123-4567',
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
    final prefixDigits =
        mask.substring(0, mask.indexOf('#')).replaceAll(RegExp(r'\D'), '');

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
      PushNotificationService().registerCurrentToken();
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
      PushNotificationService().registerCurrentToken();
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
      PushNotificationService().registerCurrentToken();
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _isLoading = false;
        _error =
            'Telegram ещё не привязан.\nНажмите Start в боте и поделитесь контактом.';
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
                      BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 20,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/logo.png',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 32),
                Text(_title, style: AppTypography.displaySmall),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
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
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Text(
                      _error!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.error),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Выберите страну', style: AppTypography.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: countries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final c = countries[i];
                  final isSelected =
                      c.prefix == selected.prefix && c.name == selected.name;
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                    title: Text(c.name, style: AppTypography.bodyMedium),
                    trailing: Text(c.prefix,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                    selected: isSelected,
                    selectedTileColor:
                        AppColors.primary.withValues(alpha: 0.06),
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(c);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
