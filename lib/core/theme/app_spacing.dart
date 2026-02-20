import 'package:flutter/material.dart';

/// Система отступов
/// 8-point grid system для консистентности
class AppSpacing {
  AppSpacing._();

  // ═══════════════════════════════════════════════════════════════
  // БАЗОВЫЕ ОТСТУПЫ (8-point grid)
  // ═══════════════════════════════════════════════════════════════

  /// 4px — микро отступ
  static const double xs = 4;

  /// 8px — малый отступ
  static const double sm = 8;

  /// 12px — средне-малый отступ
  static const double md = 12;

  /// 16px — средний отступ
  static const double lg = 16;

  /// 20px — средне-большой отступ
  static const double xl = 20;

  /// 24px — большой отступ
  static const double xxl = 24;

  /// 32px — очень большой отступ
  static const double xxxl = 32;

  /// 40px — огромный отступ
  static const double huge = 40;

  /// 48px — гигантский отступ
  static const double giant = 48;

  /// 64px — максимальный отступ
  static const double max = 64;

  // ═══════════════════════════════════════════════════════════════
  // ОТСТУПЫ КОНТЕНТА
  // ═══════════════════════════════════════════════════════════════

  /// Горизонтальный паддинг экрана
  static const double screenHorizontal = 20;

  /// Вертикальный паддинг экрана
  static const double screenVertical = 16;

  /// Паддинг карточки
  static const double cardPadding = 16;

  /// Паддинг списка
  static const double listPadding = 16;

  /// Расстояние между элементами списка
  static const double listItemSpacing = 12;

  /// Расстояние между секциями
  static const double sectionSpacing = 32;

  // ═══════════════════════════════════════════════════════════════
  // РАДИУСЫ СКРУГЛЕНИЯ
  // ═══════════════════════════════════════════════════════════════

  /// Малый радиус (чипы, бейджи)
  static const double radiusSmall = 8;

  /// Средний радиус (кнопки, инпуты)
  static const double radiusMedium = 12;

  /// Большой радиус (карточки)
  static const double radiusLarge = 16;

  /// Очень большой радиус (модальные окна)
  static const double radiusXLarge = 24;

  /// Полное скругление
  static const double radiusFull = 100;

  // ═══════════════════════════════════════════════════════════════
  // EDGE INSETS
  // ═══════════════════════════════════════════════════════════════

  /// Паддинг экрана
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );

  /// Горизонтальный паддинг экрана
  static const EdgeInsets screenHorizontalPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );

  /// Паддинг карточки
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);

  /// Паддинг кнопки
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 16,
  );

  /// Паддинг малой кнопки
  static const EdgeInsets buttonSmallPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );

  /// Паддинг инпута
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  // ═══════════════════════════════════════════════════════════════
  // РАЗМЕРЫ ЭЛЕМЕНТОВ
  // ═══════════════════════════════════════════════════════════════

  /// Высота кнопки
  static const double buttonHeight = 52;

  /// Высота малой кнопки
  static const double buttonSmallHeight = 40;

  /// Высота инпута
  static const double inputHeight = 52;

  /// Высота навбара
  static const double navBarHeight = 56;

  /// Высота таббара
  static const double tabBarHeight = 48;

  /// Размер аватара маленький
  static const double avatarSmall = 32;

  /// Размер аватара средний
  static const double avatarMedium = 44;

  /// Размер аватара большой
  static const double avatarLarge = 64;

  /// Размер иконки маленький
  static const double iconSmall = 18;

  /// Размер иконки средний
  static const double iconMedium = 24;

  /// Размер иконки большой
  static const double iconLarge = 28;
}
