import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_button.dart';

/// Подписка Donskih
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Подписка')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Center(
            child: Image.asset('assets/images/logo.png', width: 100, height: 100),
          ),
          const SizedBox(height: 20),
          Text('Donskih Premium', style: AppTypography.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Получите полный доступ ко всем материалам',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Features
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _Feature(icon: Icons.play_circle_outline, title: 'Все видеоматериалы'),
                _Feature(icon: Icons.article_outlined, title: 'База знаний'),
                _Feature(icon: Icons.chat_bubble_outline, title: 'Закрытый чат'),
                _Feature(icon: Icons.download_outlined, title: 'Скачивание материалов'),
                _Feature(icon: Icons.calendar_today_outlined, title: 'Эксклюзивные мероприятия'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Plans
          Text('Выберите план', style: AppTypography.titleLarge),
          const SizedBox(height: 14),
          _PlanCard(
            title: 'Месячная',
            price: '990 ₽',
            period: '/месяц',
            isSelected: _selected == 0,
            onTap: () => setState(() => _selected = 0),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Годовая',
            price: '7 990 ₽',
            period: '/год',
            badge: 'Экономия 33%',
            isSelected: _selected == 1,
            onTap: () => setState(() => _selected = 1),
          ),
          const SizedBox(height: 28),

          // Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Text('Подписка активна', style: AppTypography.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow('Тариф', 'Годовая подписка'),
                _InfoRow('Списание', '15 марта 2026'),
                _InfoRow('Сумма', '7 990 ₽'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('Отменить подписку', style: AppTypography.buttonSmall.copyWith(color: AppColors.textTertiary)),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: AppButton(text: 'Продолжить', onPressed: () {}),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _Feature({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: AppTypography.bodyMedium)),
          const Icon(Icons.check_outlined, color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? Colors.white : AppColors.border, width: 2),
                ),
                child: isSelected
                    ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleSmall.copyWith(color: isSelected ? Colors.white : null)),
                    if (badge != null)
                      Text(badge!, style: AppTypography.labelSmall.copyWith(color: isSelected ? Colors.white70 : AppColors.success)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price, style: AppTypography.titleMedium.copyWith(color: isSelected ? Colors.white : null)),
                  Text(period, style: AppTypography.bodySmall.copyWith(color: isSelected ? Colors.white70 : null)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(value, style: AppTypography.titleSmall),
        ],
      ),
    );
  }
}
