import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Center(
                  child: Text(
                    _isLogin ? 'Вход' : 'Регистрация',
                    style: AppTypography.displaySmall,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _isLogin ? 'Рады видеть вас снова' : 'Создайте аккаунт',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите email';
                    if (!v.contains('@')) return 'Некорректный email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password
                AppTextField(
                  controller: _passwordController,
                  label: 'Пароль',
                  hint: '••••••••',
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < 6) return 'Минимум 6 символов';
                    return null;
                  },
                ),

                if (_isLogin) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Забыли пароль?',
                        style: AppTypography.buttonSmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit
                AppButton(
                  text: _isLogin ? 'Войти' : 'Создать аккаунт',
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('или', style: AppTypography.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                // Social
                AppButton(
                  text: 'Продолжить с Google',
                  onPressed: () {},
                  type: AppButtonType.outline,
                  icon: Icons.g_mobiledata,
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Продолжить с Apple',
                  onPressed: () {},
                  type: AppButtonType.secondary,
                  icon: Icons.apple,
                ),

                const SizedBox(height: 40),

                // Toggle
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        children: [
                          TextSpan(text: _isLogin ? 'Нет аккаунта? ' : 'Уже есть аккаунт? '),
                          TextSpan(
                            text: _isLogin ? 'Регистрация' : 'Войти',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
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
