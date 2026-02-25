import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../video/video_player_screen.dart';

// ═══════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════

class _Product {
  final String name;
  final String url;
  final String? note;
  const _Product(this.name, this.url, {this.note});
}

class _ProductGroup {
  final String? label;
  final List<_Product> products;
  const _ProductGroup({this.label, required this.products});
}

class _Section {
  final String title;
  final String? description;
  final List<_ProductGroup> productGroups;
  final bool hasVideo;
  final String? videoUrl;
  const _Section({
    required this.title,
    this.description,
    this.productGroups = const [],
    this.hasVideo = true,
    this.videoUrl,
  });
}

class _TextMemo {
  final String title;
  final List<_MemoBlock> blocks;
  const _TextMemo({required this.title, required this.blocks});
}

class _MemoBlock {
  final String heading;
  final List<String> points;
  const _MemoBlock({required this.heading, required this.points});
}

class _Lesson {
  final int number;
  final String title;
  final String? introText;
  final List<_Section> sections;
  final List<_TextMemo> memos;
  final List<String> photos;
  final String? resultNote;
  const _Lesson({
    required this.number,
    required this.title,
    this.introText,
    this.sections = const [],
    this.memos = const [],
    this.photos = const [],
    this.resultNote,
  });
}

// ═══════════════════════════════════════════════════════════════
// LESSON DATA — точное соответствие Telegram-каналу «База»
// ═══════════════════════════════════════════════════════════════

const _lessons = <_Lesson>[
  // ─── УРОК 1 ───────────────────────────────────────────────
  _Lesson(
    number: 1,
    title: 'Макияж: Clean Girl с акцентом на сияющую здоровую кожу',
    sections: [
      _Section(
        title: 'Уход',
        videoUrl: 'https://donskih-cdn.ru/hls/lesson1/uhod/index.m3u8',
        description:
            'Название продуктов (синим цветом) — это ссылки, они кликабельны',
        productGroups: [
          _ProductGroup(products: [
            _Product('Тоник: CLARINS lotion tonique apaisante',
                'https://goldapple.ru/19760334995-lotion-tonique-apaisante'),
            _Product('Сыворотка для лица: ART & FACT',
                'https://goldapple.ru/19000039339-3d-hyaluronic-acid-2-provitamin-b5-moisturizing-biorevitalization-effect'),
            _Product('Крем для лица: ORIKO', 'https://ozon.ru/t/baTZ97r'),
            _Product('Стик для лица: DERMA FACTORY',
                'https://www.wildberries.ru/catalog/146474923/detail.aspx?size=246545503'),
          ]),
        ],
      ),
      _Section(
        title: 'Нанесение тона и консилера',
        videoUrl: 'https://donskih-cdn.ru/hls/lesson1/ton/index.m3u8',
        productGroups: [
          _ProductGroup(products: [
            _Product('Фильтр флюид: CHARLOTTE TILBURY',
                'https://www.charlottetilbury.com/us/product/hollywood-flawless-filter-shade-4-5-medium'),
          ]),
          _ProductGroup(label: 'Бюджетная альтернатива', products: [
            _Product('Фильтр флюид: CATRICE',
                'https://goldapple.ru/19000263133-soft-glam-filter-fluid'),
          ]),
          _ProductGroup(products: [
            _Product('Тон: BELOR DESIGN',
                'https://goldapple.ru/19000187196-funhouse-skin-teen'),
            _Product('Консилер: NATALYA SHIK',
                'https://goldapple.ru/19000334042-concealer-blurring-effect'),
          ]),
        ],
      ),
      _Section(
        title: 'Скульптурирование лица',
        videoUrl: 'https://donskih-cdn.ru/hls/lesson1/skulptur/index.m3u8',
        productGroups: [
          _ProductGroup(products: [
            _Product('Кремовые румяна: RARE BEAUTY',
                'https://www.rarebeauty.com/?srsltid=AfmBOooPMJHnLXcBupTDWBxNwFthUHCw7kfjucNyfEqSrhCcYLvYEPE2',
                note: 'оттенок hope'),
          ]),
          _ProductGroup(label: 'Бюджетная альтернатива', products: [
            _Product('Кремовые румяна: OK BEAUTY',
                'https://goldapple.ru/15840800001-color-salute',
                note: 'оттенок safari'),
          ]),
          _ProductGroup(products: [
            _Product('Кремовый хайлайтер: CHARLOTTE TILBURY',
                'https://www.charlottetilbury.com/us/product/hollywood-beauty-light-wand-highlighter',
                note: 'оттенок spotlight'),
            _Product('Пудра: CHARLOTTE TILBURY',
                'https://www.charlottetilbury.com/us/product/airbrush-flawless-finish-2-medium'),
          ]),
          _ProductGroup(label: 'Бюджетная альтернатива', products: [
            _Product('Пудра: RELOUIS pro icon look satin',
                'https://goldapple.ru/19000041617-icon-look-satin-face-powder'),
          ]),
          _ProductGroup(products: [
            _Product('Сухие румяна: STELLARY',
                'https://goldapple.ru/19000374454-cashmere-blush'),
          ]),
        ],
      ),
      _Section(
        title: 'Макияж бровей',
        videoUrl: 'https://donskih-cdn.ru/hls/lesson1/brovi/index.m3u8',
        productGroups: [
          _ProductGroup(products: [
            _Product('Карандаш для бровей: VIVIENNE SABO',
                'https://goldapple.ru/3226300001-brow-arcade-slim'),
            _Product('Гель для бровей: LUXVISAGE',
                'https://goldapple.ru/19000314269-brow-laminator-extreme-fix-24h'),
          ]),
        ],
      ),
      _Section(
        title: 'Макияж глаз',
        videoUrl: 'https://donskih-cdn.ru/hls/lesson1/glaza/index.m3u8',
        productGroups: [
          _ProductGroup(products: [
            _Product('Хайлайтер: STELLARY',
                'https://goldapple.ru/19000374458-mousse-highlighter-rich-glow'),
            _Product('Бронзер: CATRICE',
                'https://goldapple.ru/69987500001-sun-lover-glow-bronzing-powder'),
            _Product('Карандаш для глаз: SHIKSTUDIO',
                'https://goldapple.ru/70062600002-kajal-liner',
                note: 'оттенок 02'),
            _Product('Тени: ROMANOVAMAKEUP',
                'https://goldapple.ru/19000174507-sexy-eyeshadow-palette'),
            _Product('Тушь: ESSENCE',
                'https://goldapple.ru/19000282960-lash-without-limits-brown-extreme-lengthening-volume',
                note: 'коричневая'),
          ]),
        ],
      ),
      _Section(
        title: 'Макияж губ',
        videoUrl: 'https://donskih-cdn.ru/hls/lesson1/guby/index.m3u8',
        productGroups: [
          _ProductGroup(products: [
            _Product('Карандаш для губ: LOVE GENERATION',
                'https://goldapple.ru/19000251663-lip-pencil',
                note: 'оттенок 09'),
            _Product('Карандаш для губ: VIVIENNE SABO',
                'https://goldapple.ru/19760304887-le-grand-volume',
                note: 'оттенок 01'),
            _Product(
                'Блеск: SHIKSTUDIO', 'https://goldapple.ru/19000058261-intense',
                note: 'оттенок 04'),
          ]),
        ],
      ),
    ],
    resultNote:
        'Вот такой макияж получился ♥️\nОбратите внимание как он смотрится в помещении и при уличном солнечном свете ✨',
    photos: [
      'assets/images/telegram_photos/lesson1_photo1.jpg',
      'assets/images/telegram_photos/lesson1_photo2.jpg',
      'assets/images/telegram_photos/lesson1_photo3.jpg',
      'assets/images/telegram_photos/lesson1_photo4.jpg',
      'assets/images/telegram_photos/lesson1_photo5.jpg',
      'assets/images/telegram_photos/lesson1_photo6.jpg',
    ],
  ),

  // ─── УРОК 2 ───────────────────────────────────────────────
  _Lesson(
    number: 2,
    title: 'Какие кисти должны быть в косметичке',
    sections: [
      _Section(
          title:
              'Кисти для тона и кремовых: скульптора, бронзера, румян, хайлайтера'),
      _Section(
          title:
              'Кисти для сухих продуктов: пудры, румян, хайлайтера, бронзера, скульптора'),
      _Section(title: 'Кисти для теней и растушевки карандаша'),
      _Section(
          title: 'Кисть для подчищений в макияже и графичных стрел',
          videoUrl: 'https://donskih-cdn.ru/hls/lesson2/podchistka/index.m3u8'),
      _Section(
          title: 'Спонж',
          videoUrl: 'https://donskih-cdn.ru/hls/lesson2/sponzh/index.m3u8'),
      _Section(
          title: 'Точилки',
          videoUrl: 'https://donskih-cdn.ru/hls/lesson2/tochilki/index.m3u8'),
      _Section(
        title: 'Кисти которые я использовала в макияже «Clean Girl»',
        hasVideo: false,
        productGroups: [
          _ProductGroup(products: [
            _Product(
                '1. Кисть для тона и кремовых румян, скульптора, бронзера, румян — NATALYA SHIK brush 03 foundation & sculptor',
                'https://goldapple.ru/19000386766-brush-03-foundation-sculptor'),
            _Product(
                '2. Кисть для пудры, сухих: румян, скульптора, бронзера, хайлайтера — NATALYA SHIK brush 01 powder',
                'https://goldapple.ru/19000386764-brush-01-powder'),
            _Product(
                '3. Кисть для теней — NATALYA SHIK brush 05 blending eyeshadow',
                'https://goldapple.ru/19000386768-brush-05-blending-eyeshadow'),
            _Product(
                '4. Детальная кисть для теней и растушевки стрелочки — MANLY PRO к53',
                'https://goldapple.ru/19000323328-round-pencil-brush-for-shadows-and-eyeliner'),
            _Product(
                '5. Детальная кисть для теней и растушевки стрелочки — PIMINOVA VALERY gs3',
                'https://goldapple.ru/19000065740-gs3'),
            _Product(
                '6. Подчищающая кисть, кисть для графичных стрел — ROMANOVAMAKEUP sexy makeup brush s7',
                'https://goldapple.ru/19760331864-sexy-makeup-brush-s7'),
            _Product('7. Спонж — MUL MUL celaeno',
                'https://goldapple.ru/99000038771-celaeno'),
          ]),
        ],
      ),
    ],
    photos: [
      'assets/images/telegram_photos/lesson2_brushes.jpg',
    ],
  ),

  // ─── УРОК 3 ───────────────────────────────────────────────
  _Lesson(
    number: 3,
    title: 'Как ухаживать за кистями',
    sections: [
      _Section(title: 'Видеоурок по уходу за кистями'),
    ],
    memos: [
      _TextMemo(
        title: '🧼 Памятка по уходу за кистями и спонжами',
        blocks: [
          _MemoBlock(
            heading: '✨ Как часто мыть кисти?',
            points: [
              'Кисти для тона и консилера — после каждого использования или хотя бы 2–3 раза в неделю',
              'Кисти для сухих текстур (пудра, румяна, тени) — 1 раз в неделю',
            ],
          ),
          _MemoBlock(
            heading: '✨ Как часто мыть спонжи?',
            points: [
              'После каждого использования (спонж впитывает продукт и влагу — там быстрее всего размножаются бактерии)',
            ],
          ),
          _MemoBlock(
            heading: '💦 Как сушить кисти?',
            points: [
              'Сразу после мытья промокнуть полотенцем, придать форму ворсу',
              'Сушить только в горизонтальном положении или ворсом вниз, чтобы вода не попадала в основание',
              'Никогда не сушить на батарее или феном на высокой температуре (клей в основании расплавляется и разрушается, ворс пересыхает и портится, форма кисти деформируется)',
            ],
          ),
        ],
      ),
    ],
  ),

  // ─── УРОК 4 ───────────────────────────────────────────────
  _Lesson(
    number: 4,
    title: 'Создание контуринга',
    introText:
        'С одной стороны показываю технику с кремовыми продуктами, а с другой — с сухими.\n\n🖐🏾 Тёплая коричневая тень на лице — это бронзер\n🖐🏾 Холодная коричневая тень — это скульптор',
    sections: [
      _Section(
        title: 'Техника контуринга: кремовые и сухие продукты',
        productGroups: [],
      ),
      _Section(
        title: 'Продукты, которые использовала в видео-уроке',
        hasVideo: false,
        productGroups: [
          _ProductGroup(products: [
            _Product('Кремовый бронзер: CATRICE melted sun liquid bronzer',
                'https://goldapple.ru/19000381735-melted-sun-liquid-bronzer',
                note: 'оттенок 15 (тёплый) — в уроке, оттенок 05 (прохладнее)'),
            _Product('Сухой бронзер: CATRICE sun lover glow',
                'https://goldapple.ru/69987500001-sun-lover-glow-bronzing-powder',
                note: 'оттенок 010'),
            _Product('Хайлайтер: ROMANOVAMAKEUP sexy powder highlighter',
                'https://goldapple.ru/25253600001-sexy-powder-highlighter'),
          ]),
        ],
      ),
    ],
    photos: [
      'assets/images/telegram_photos/lesson4_photo1.jpg',
      'assets/images/telegram_photos/lesson4_photo2.jpg',
      'assets/images/telegram_photos/lesson4_photo3.jpg',
      'assets/images/telegram_photos/lesson4_photo4.jpg',
    ],
  ),

  // ─── УРОК 5 ───────────────────────────────────────────────
  _Lesson(
    number: 5,
    title: 'Особенности подготовки кожи и нанесения тона на разных типах кожи',
    introText:
        'Сегодня поговорим про особенности подготовки кожи и нанесения тона на разных типах кожи ✨\n\nЯ пригласила двух девушек с разными типами кожи, чтобы наглядно показать, как подбирать и наносить тон так, чтобы он выглядел без маски на лице, но при этом скрывал всё, что хочется скрыть!\n\nВ уроках вы увидите, как отличается подготовка кожи и нанесение тона при склонности к жирности и при сухости',
    sections: [
      _Section(
        title: 'Наталья — кожа склонна к жирности ✨',
        description:
            'Показываю сбалансированную подготовку кожи и нанесение тона без лишнего блеска',
        productGroups: [
          _ProductGroup(label: 'Подготовка кожи', products: [
            _Product('Увлажняющий тоник: DERMEDIC',
                'https://goldapple.ru/19000023137-hydrain3-hialuro'),
            _Product('Сыворотка: ART & FACT',
                'https://goldapple.ru/19000039299-3d-hyaluronic-acid-2-provitamin-b5-anti-age-moistening'),
            _Product('Маска для губ: KLAVUU',
                'https://goldapple.ru/19000111154-nourishing-care-lip-sleeping-pack-vanilla/'),
            _Product('Крем для глаз: CENTELLIAN24',
                'https://goldapple.ru/99000082952-lifting-peptide/'),
            _Product('Сыворотка-мист: VT Cosmetics',
                'https://cream.shop/catalog/kosmetika-dlya-litsa/syvorotki/pdrn_glow_ampoule/'),
          ]),
          _ProductGroup(label: 'Нанесение тона', products: [
            _Product('Тональный крем: LIC',
                'https://goldapple.ru/19000063388-soft-velvet/'),
            _Product('Консилер: DIOR',
                'https://goldapple.ru/19000155712-forever-skin-correct/'),
            _Product('Фиксатор макияжа: CLARINS',
                'https://goldapple.ru/19000298298-fix-make-up/'),
            _Product('Пудра: SHIKSTUDIO',
                'https://goldapple.ru/19000000796-glow-perfect-powder/'),
          ]),
          _ProductGroup(label: 'Кисти которые использовала', products: [
            _Product('Кисть для тона: ROMANOVAMAKEUP sexy makeup brush s2',
                'https://goldapple.ru/19760331859-sexy-makeup-brush-s2'),
            _Product('Кисть для консилера: PIMINOVA VALERY t7',
                'https://goldapple.ru/19000039048-t7'),
            _Product(
                'Спонж: MUL MUL', 'https://goldapple.ru/99000038771-celaeno'),
            _Product('Кисть для пудры: NATALYA SHIK brush 01 powder',
                'https://goldapple.ru/19000386764-brush-01-powder'),
          ]),
        ],
      ),
      _Section(
        title: 'Ирина — кожа склонна к сухости ✨',
        description:
            'Делаю акцент на увлажнение и показываю, как наносить тон без подчеркнутых шелушений',
        productGroups: [
          _ProductGroup(label: 'Подготовка кожи', products: [
            _Product('Увлажняющий тоник: CLARINS',
                'https://goldapple.ru/19760334995-lotion-tonique-apaisante/'),
            _Product('Вода красоты: CAUDALIE',
                'https://goldapple.ru/19000035763-beauty-elixir-travel-sive/'),
            _Product('Эссенция с PDRN: VT Cosmetics',
                'https://cream.shop/catalog/kosmetika-dlya-litsa/essentsii/pdrn_essence_100/'),
            _Product('Стик эссенция с PDRN: VT Cosmetics',
                'https://cream.shop/catalog/kosmetika-dlya-litsa/uvlazhnenie_i_pitanie/stik/balzam_essentsiya_s_pdrn_dlya_siyaniya_kozhi/'),
            _Product('Сыворотка для губ: BOBBI BROWN',
                'https://goldapple.ru/19000284166-extra-plump-lip-serum/'),
          ]),
          _ProductGroup(label: 'Нанесение тона', products: [
            _Product('Консилер: LUNA',
                'https://goldapple.ru/19000163543-longlasting-tip-cover-fit/'),
            _Product('Тональный крем: SHISEIDO',
                'https://goldapple.ru/19000265710-revitalessence-skin-glow/'),
            _Product('Пудра: CHARLOTTE TILBURY',
                'https://www.charlottetilbury.com/us/product/airbrush-flawless-finish-2-medium'),
          ]),
          _ProductGroup(label: 'Кисти которые использовала', products: [
            _Product(
                'Спонж: MUL MUL', 'https://goldapple.ru/99000038771-celaeno'),
            _Product('Кисть для пудры: NATALYA SHIK brush 02 full face',
                'https://goldapple.ru/19000386765-brush-02-full-face'),
          ]),
        ],
      ),
    ],
  ),
];

const _checklistTitles = [
  'Чек-лист по кистям',
  'Чек-лист «Косметичка новичка»',
  'Чек-лист «Тональные кремá»',
];

// ═══════════════════════════════════════════════════════════════
// MAIN TAB
// ═══════════════════════════════════════════════════════════════

class BaseTab extends StatelessWidget {
  const BaseTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text('База Знаний', style: AppTypography.headlineSmall),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _lessons.length + 1 + 1,
            itemBuilder: (context, index) {
              if (index < _lessons.length) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LessonCard(lesson: _lessons[index]),
                );
              }
              if (index == _lessons.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text('Чек-листы', style: AppTypography.headlineSmall),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: _checklistTitles
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChecklistCard(title: t),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LESSON CARD (expandable)
// ═══════════════════════════════════════════════════════════════

class _LessonCard extends StatefulWidget {
  final _Lesson lesson;
  const _LessonCard({required this.lesson});

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primarySoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${l.number}',
                      style: AppTypography.titleLarge
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Урок ${l.number}',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(l.title,
                          style: AppTypography.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textTertiary, size: 24),
                ),
              ],
            ),
          ),
        ),

        // ── Content ──
        SizeTransition(
          sizeFactor: _anim,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (l.introText != null) ...[
                    _IntroTextWidget(text: l.introText!),
                    const SizedBox(height: 16),
                  ],
                  ...l.sections.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SectionWidget(section: s),
                      )),
                  ...l.memos.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _MemoWidget(memo: m),
                      )),
                  if (l.resultNote != null) ...[
                    _ResultNoteWidget(text: l.resultNote!),
                    const SizedBox(height: 12),
                  ],
                  if (l.photos.isNotEmpty) _PhotoGallery(photos: l.photos),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION — видео-раздел внутри урока с продуктами
// ═══════════════════════════════════════════════════════════════

class _SectionWidget extends StatelessWidget {
  final _Section section;
  const _SectionWidget({required this.section});

  void _openVideo(BuildContext context) {
    if (section.videoUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: section.videoUrl!,
          title: section.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPlay = section.hasVideo && section.videoUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPlay)
          GestureDetector(
            onTap: () => _openVideo(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/telegram_thumbs/lesson_vid_thumb.jpg',
                          width: 96,
                          height: 132,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 132,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            section.title,
                            style: AppTypography.titleSmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Видеоурок',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Нажмите, чтобы открыть',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            section.title,
            style: AppTypography.titleSmall,
          ),
        if (section.description != null) ...[
          const SizedBox(height: 6),
          Text(
            section.description!,
            style:
                AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        if (section.productGroups.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...section.productGroups.map((g) => _ProductGroupWidget(group: g)),
        ],
        const SizedBox(height: 4),
        const Divider(height: 1, color: AppColors.borderLight),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRODUCT GROUP + LINK
// ═══════════════════════════════════════════════════════════════

class _ProductGroupWidget extends StatelessWidget {
  final _ProductGroup group;
  const _ProductGroupWidget({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                group.label!,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ...group.products.map((p) => _ProductLinkWidget(product: p)),
        ],
      ),
    );
  }
}

class _ProductLinkWidget extends StatelessWidget {
  final _Product product;
  const _ProductLinkWidget({required this.product});

  Future<void> _open() async {
    final uri = Uri.parse(product.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        onTap: _open,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  if (product.note != null)
                    Text(
                      product.note!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
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

// ═══════════════════════════════════════════════════════════════
// TEXT WIDGETS
// ═══════════════════════════════════════════════════════════════

class _IntroTextWidget extends StatelessWidget {
  final String text;
  const _IntroTextWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(text, style: AppTypography.bodyMedium),
    );
  }
}

class _ResultNoteWidget extends StatelessWidget {
  final String text;
  const _ResultNoteWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MEMO — текстовая памятка
// ═══════════════════════════════════════════════════════════════

class _MemoWidget extends StatelessWidget {
  final _TextMemo memo;
  const _MemoWidget({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            memo.title,
            style: AppTypography.titleSmall.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...memo.blocks.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.heading, style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    ...b.points.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(fontSize: 14, height: 1.5)),
                              Expanded(
                                child: Text(p, style: AppTypography.bodyMedium),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PHOTO GALLERY — горизонтальная галерея фото
// ═══════════════════════════════════════════════════════════════

class _PhotoGallery extends StatelessWidget {
  final List<String> photos;
  const _PhotoGallery({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Фото',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openFullScreen(context, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Image.asset(
                  photos[i],
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 140,
                    height: 200,
                    color: AppColors.surfaceSecondary,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenGallery(photos: photos, initialIndex: initialIndex),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _FullScreenGallery({required this.photos, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.asset(widget.photos[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHECKLIST CARD
// ═══════════════════════════════════════════════════════════════

class _ChecklistCard extends StatelessWidget {
  final String title;
  const _ChecklistCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text('PDF', style: AppTypography.labelSmall),
              ],
            ),
          ),
          const Icon(Icons.file_download_outlined,
              color: AppColors.textTertiary, size: 22),
        ],
      ),
    );
  }
}
