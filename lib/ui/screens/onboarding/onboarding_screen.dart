import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      image: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=800&q=80',
      title: 'Добро пожаловать\nв Donskih',
      subtitle: 'Эксклюзивный доступ к знаниям и сообществу профессионалов',
    ),
    _OnboardingData(
      image: 'https://images.unsplash.com/photo-1487412947147-5cebf100ffc2?w=800&q=80',
      title: 'База знаний\nот экспертов',
      subtitle: 'Видео, статьи, гайды и чек-листы от лучших специалистов',
    ),
    _OnboardingData(
      image: 'https://images.unsplash.com/photo-1556761175-b413da4baf72?w=800&q=80',
      title: 'Живое общение\nи нетворкинг',
      subtitle: 'Чат с единомышленниками и Q&A сессии с экспертами',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 40, height: 40),
                  const SizedBox(width: 10),
                  Text('Donskih', style: AppTypography.titleLarge.copyWith(color: AppColors.primary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/auth'),
                    child: Text(
                      'Пропустить',
                      style: AppTypography.buttonSmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Image
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: page.image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => Container(color: AppColors.surfaceSecondary),
                              errorWidget: (_, __, ___) => Container(color: AppColors.surfaceSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Text
                        Text(
                          page.title,
                          style: AppTypography.displayMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Button
                  AppButton(
                    text: _currentPage == _pages.length - 1 ? 'Начать' : 'Далее',
                    onPressed: _next,
                    trailingIcon: Icons.arrow_forward_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String image;
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
