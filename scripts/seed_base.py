#!/usr/bin/env python3
"""
Seed "База знаний" content from Telegram export.
Usage:
    python scripts/seed_base.py --key YOUR_ADMIN_KEY
    # or set env var:
    ADMIN_KEY=xxx python scripts/seed_base.py
"""

import argparse
import json
import os
import ssl
import sys
import urllib.request
import urllib.error

# macOS Python often lacks root certs — allow unverified SSL for internal admin API
_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE

API_BASE = "https://donskih-cdn.ru/api/v1"

# ─────────────────────────────────────────────────────────────
# Quill Delta builder helpers
# ─────────────────────────────────────────────────────────────

def _op(text: str, **attrs) -> dict:
    op = {"insert": text}
    if attrs:
        op["attributes"] = {k: v for k, v in attrs.items() if v is not None}
        if not op["attributes"]:
            del op["attributes"]
    return op

def quill_delta(*parts) -> str:
    """
    Build Quill Delta JSON string.
    Parts can be:
      - str  → plain text insert
      - dict → raw op (use _op() helper)
    Always ends with a newline insert.
    """
    ops = []
    for p in parts:
        if isinstance(p, str):
            ops.append({"insert": p})
        else:
            ops.append(p)
    # Ensure document ends with newline
    if not ops or ops[-1].get("insert", "").endswith("\n"):
        pass
    else:
        ops.append({"insert": "\n"})
    return json.dumps(ops, ensure_ascii=False)


def bold(text: str) -> dict:
    return _op(text, bold=True)

def italic(text: str) -> dict:
    return _op(text, italic=True)

def link(text: str, url: str) -> dict:
    return _op(text, link=url)

def nl(n: int = 1) -> str:
    return "\n" * n


# ─────────────────────────────────────────────────────────────
# Content data
# ─────────────────────────────────────────────────────────────

LESSONS = [

    # ══════════════════════════════════════════════════════════
    # УРОК 1 — Clean Girl макияж
    # ══════════════════════════════════════════════════════════
    {
        "type": "video",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Макияж: Clean Girl с акцентом на сияющую здоровую кожу",
        "sort_order": 0,
        "sub_items": [
            {
                "title": "Уход",
                "sort_order": 0,
                "description": quill_delta(
                    italic("Название продуктов — это ссылки, они кликабельны"), nl(2),
                    "Тоник: ", link("CLARINS lotion tonique apaisante",
                        "https://goldapple.ru/19760334995-lotion-tonique-apaisante"), nl(),
                    "Сыворотка для лица: ", link("ART & FACT",
                        "https://goldapple.ru/19000039339-3d-hyaluronic-acid-2-provitamin-b5-moisturizing-biorevitalization-effect"), nl(),
                    "Крем для лица: ", link("ORIKO", "https://ozon.ru/t/baTZ97r"), nl(),
                    "Стик для лица: ", link("DERMA FACTORY",
                        "https://www.wildberries.ru/catalog/146474923/detail.aspx?size=246545503"), nl(),
                ),
            },
            {
                "title": "Нанесение тона и консилера",
                "sort_order": 1,
                "description": quill_delta(
                    "Фильтр флюид: ", link("CHARLOTTE TILBURY",
                        "https://www.charlottetilbury.com/us/product/hollywood-flawless-filter-shade-4-5-medium"), nl(),
                    italic("Бюджетная альтернатива:"), nl(),
                    "Фильтр флюид: ", link("CATRICE",
                        "https://goldapple.ru/19000263133-soft-glam-filter-fluid"), nl(2),
                    "Тон: ", link("BELOR DESIGN",
                        "https://goldapple.ru/19000187196-funhouse-skin-teen"), nl(2),
                    "Консилер: ", link("NATALYA SHIK",
                        "https://goldapple.ru/19000334042-concealer-blurring-effect"), nl(),
                ),
            },
            {
                "title": "Скульптурирование лица",
                "sort_order": 2,
                "description": quill_delta(
                    "Кремовые румяна: ", link("RARE BEAUTY",
                        "https://www.rarebeauty.com/"), " оттенок ", bold("hope"), nl(),
                    italic("Бюджетная альтернатива:"), nl(),
                    "Кремовые румяна: ", link("OK BEAUTY",
                        "https://goldapple.ru/15840800001-color-salute"), " оттенок ", bold("safari"), nl(2),
                    "Кремовый хайлайтер: ", link("CHARLOTTE TILBURY",
                        "https://www.charlottetilbury.com/us/product/hollywood-beauty-light-wand-highlighter"),
                    " оттенок ", bold("spotlight"), nl(2),
                    "Пудра: ", link("CHARLOTTE TILBURY",
                        "https://www.charlottetilbury.com/us/product/airbrush-flawless-finish-2-medium"), nl(),
                    italic("Бюджетная альтернатива:"), nl(),
                    "Пудра: ", link("RELOUIS pro icon look satin",
                        "https://goldapple.ru/19000041617-icon-look-satin-face-powder"), nl(2),
                    "Сухие румяна: ", link("STELLARY",
                        "https://goldapple.ru/19000374454-cashmere-blush"), nl(),
                ),
            },
            {
                "title": "Макияж бровей",
                "sort_order": 3,
                "description": quill_delta(
                    "Карандаш для бровей: ", link("VIVIENNE SABO",
                        "https://goldapple.ru/3226300001-brow-arcade-slim"), nl(2),
                    "Гель для бровей: ", link("LUXVISAGE",
                        "https://goldapple.ru/19000314269-brow-laminator-extreme-fix-24h"), nl(),
                ),
            },
            {
                "title": "Макияж глаз",
                "sort_order": 4,
                "description": quill_delta(
                    "Хайлайтер: ", link("STELLARY",
                        "https://goldapple.ru/19000374458-mousse-highlighter-rich-glow"), nl(2),
                    "Бронзер: ", link("CATRICE",
                        "https://goldapple.ru/69987500001-sun-lover-glow-bronzing-powder"), nl(2),
                    "Карандаш для глаз: ", link("SHIKSTUDIO",
                        "https://goldapple.ru/70062600002-kajal-liner"), " оттенок ", bold("02"), nl(2),
                    "Тени: ", link("ROMANOVAMAKEUP",
                        "https://goldapple.ru/19000174507-sexy-eyeshadow-palette"), nl(2),
                    "Тушь: ", link("ESSENCE",
                        "https://goldapple.ru/19000282960-lash-without-limits-brown-extreme-lengthening-volume"),
                    " коричневая", nl(),
                ),
            },
            {
                "title": "Макияж губ",
                "sort_order": 5,
                "description": quill_delta(
                    "Карандаш для губ: ", link("LOVE GENERATION",
                        "https://goldapple.ru/19000251663-lip-pencil"), " оттенок 09", nl(2),
                    "Карандаш для губ: ", link("VIVIENNE SABO",
                        "https://goldapple.ru/19760304887-le-grand-volume"), " оттенок 01", nl(2),
                    "Блеск: ", link("SHIKSTUDIO",
                        "https://goldapple.ru/19000058261-intense"), " оттенок 04", nl(),
                ),
            },
            {
                "title": "Итог: вот такой макияж получился ♥️",
                "sort_order": 6,
                "description": quill_delta(
                    "Обратите внимание как он смотрится в помещении и при уличном солнечном свете ✨", nl(),
                ),
            },
        ],
    },

    # ══════════════════════════════════════════════════════════
    # УРОК 2 — Кисти
    # ══════════════════════════════════════════════════════════
    {
        "type": "video",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Какие кисти должны быть в косметичке",
        "sort_order": 1,
        "subtitle": quill_delta(
            bold("Кисти которые использовала в макияже «Clean Girl»"), nl(2),
            "1. Кисть для тона и кремовых румян, скульптора, бронзера, румян\n",
            link("NATALYA SHIK brush 03 foundation & sculptor",
                "https://goldapple.ru/19000386766-brush-03-foundation-sculptor"), nl(2),
            "2. Кисть для пудры, сухих: румян, скульптора, бронзера, хайлайтера\n",
            link("NATALYA SHIK brush 01 powder",
                "https://goldapple.ru/19000386764-brush-01-powder"), nl(2),
            "3. Кисть для теней\n",
            link("NATALYA SHIK brush 05 blending eyeshadow",
                "https://goldapple.ru/19000386768-brush-05-blending-eyeshadow"), nl(2),
            "4. Детальная кисть для теней и растушевки стрелочки\n",
            link("MANLY PRO к53",
                "https://goldapple.ru/19000323328-round-pencil-brush-for-shadows-and-eyeliner"), nl(2),
            "5. Детальная кисть для теней и растушевки стрелочки\n",
            link("PIMINOVA VALERY gs3",
                "https://goldapple.ru/19000065740-gs3"), nl(2),
            "6. Подчищающая кисть, кисть для графичных стрел\n",
            link("ROMANOVAMAKEUP sexy makeup brush s7",
                "https://goldapple.ru/19760331864-sexy-makeup-brush-s7"), nl(2),
            "7. Спонж\n",
            link("MUL MUL celaeno",
                "https://goldapple.ru/99000038771-celaeno"), nl(),
        ),
        "sub_items": [
            {
                "title": "Кисти для тона и кремовых: скульптора, бронзера, румян, хайлайтера",
                "sort_order": 0,
            },
            {
                "title": "Кисти для сухих продуктов: пудры, румян, хайлайтера, бронзера, скульптора",
                "sort_order": 1,
            },
            {
                "title": "Кисти для теней и растушевки карандаша",
                "sort_order": 2,
            },
            {
                "title": "Кисть для подчищений в макияже и графичных стрел",
                "sort_order": 3,
            },
            {
                "title": "Спонж",
                "sort_order": 4,
            },
            {
                "title": "Точилки",
                "sort_order": 5,
            },
        ],
    },

    # ══════════════════════════════════════════════════════════
    # УРОК 3 — Уход за кистями
    # ══════════════════════════════════════════════════════════
    {
        "type": "video",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Как ухаживать за кистями",
        "sort_order": 2,
        "subtitle": quill_delta(
            bold("🧼 Памятка по уходу за кистями и спонжами"), nl(2),
            bold("✨ Как часто мыть кисти?"), nl(),
            "• Кисти для тона и консилера — после каждого использования или хотя бы 2–3 раза в неделю\n",
            "• Кисти для сухих текстур (пудра, румяна, тени) — 1 раз в неделю\n", nl(),
            bold("✨ Как часто мыть спонжи?"), nl(),
            "• После каждого использования (спонж впитывает продукт и влагу — там быстрее всего размножаются бактерии)\n", nl(),
            bold("💦 Как сушить кисти?"), nl(),
            "• Сразу после мытья промокнуть полотенцем, придать форму ворсу\n",
            "• Сушить только в горизонтальном положении или ворсом вниз, чтобы вода не попадала в основание\n",
            "• Никогда не сушить на батарее или феном на высокой температуре — клей в основании расплавляется, ворс пересыхает\n",
        ),
        "sub_items": [
            {
                "title": "Урок: как ухаживать за кистями",
                "sort_order": 0,
            },
        ],
    },

    # ══════════════════════════════════════════════════════════
    # УРОК 4 — Контуринг
    # ══════════════════════════════════════════════════════════
    {
        "type": "video",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Создание контуринга",
        "sort_order": 3,
        "subtitle": quill_delta(
            bold("Продукты из урока:"), nl(2),
            "🔸 Кремовый бронзер ", link("CATRICE melted sun liquid bronzer",
                "https://goldapple.ru/19000381735-melted-sun-liquid-bronzer"), nl(),
            "оттенок 15 (тёплый) — в уроке / оттенок 05 (прохладнее)\n", nl(),
            "🔸 Сухой бронзер ", link("CATRICE sun lover glow",
                "https://goldapple.ru/69987500001-sun-lover-glow-bronzing-powder"),
            " оттенок 010\n", nl(),
            "🔸 Хайлайтер ", link("ROMANOVAMAKEUP sexy powder highlighter",
                "https://goldapple.ru/25253600001-sexy-powder-highlighter"), nl(),
        ),
        "sub_items": [
            {
                "title": "Техника с кремовыми и сухими продуктами",
                "sort_order": 0,
                "description": quill_delta(
                    "С одной стороны показываю технику с ", bold("кремовыми продуктами"),
                    ", а с другой — с ", bold("сухими"), ".\n\n",
                    "🖐🏾 Тёплая коричневая тень на лице — это ", bold("бронзер"), "\n",
                    "🖐🏾 Холодная коричневая тень — это ", bold("скульптор"), "\n",
                ),
            },
            {
                "title": "Контуринг: разбор по зонам",
                "sort_order": 1,
            },
            {
                "title": "Итог контуринга",
                "sort_order": 2,
            },
        ],
    },

    # ══════════════════════════════════════════════════════════
    # УРОК 5 — Типы кожи и нанесение тона
    # ══════════════════════════════════════════════════════════
    {
        "type": "video",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Особенности подготовки кожи и нанесения тона на разных типах кожи",
        "sort_order": 4,
        "sub_items": [
            {
                "title": "Наталья — кожа склонна к жирности ✨",
                "sort_order": 0,
                "description": quill_delta(
                    "Показываю сбалансированную подготовку кожи и нанесение тона без лишнего блеска\n\n",
                    bold("Подготовка кожи:"), nl(),
                    "Увлажняющий тоник ", link("DERMEDIC",
                        "https://goldapple.ru/19000023137-hydrain3-hialuro"), nl(),
                    "Сыворотка ", link("ART & FACT",
                        "https://goldapple.ru/19000039299-3d-hyaluronic-acid-2-provitamin-b5-anti-age-moistening"), nl(),
                    "Маска для губ ", link("KLAVUU",
                        "https://goldapple.ru/19000111154-nourishing-care-lip-sleeping-pack-vanilla/"), nl(),
                    "Крем для глаз ", link("CENTELLIAN24",
                        "https://goldapple.ru/99000082952-lifting-peptide/"), nl(),
                    "Сыворотка-мист ", link("VT Cosmetics",
                        "https://cream.shop/catalog/kosmetika-dlya-litsa/syvorotki/pdrn_glow_ampoule/"), nl(2),
                    bold("Нанесение тона:"), nl(),
                    "Тональный крем ", link("LIC",
                        "https://goldapple.ru/19000063388-soft-velvet/"), nl(),
                    "Консилер ", link("DIOR",
                        "https://goldapple.ru/19000155712-forever-skin-correct/"), nl(),
                    "Фиксатор макияжа ", link("CLARINS",
                        "https://goldapple.ru/19000298298-fix-make-up/"), nl(),
                    "Пудра ", link("SHIKSTUDIO",
                        "https://goldapple.ru/19000000796-glow-perfect-powder/"), nl(2),
                    bold("Кисти:"), nl(),
                    link("ROMANOVAMAKEUP sexy makeup brush s2",
                        "https://goldapple.ru/19760331859-sexy-makeup-brush-s2"), " — кисть для тона\n",
                    link("PIMINOVA VALERY t7",
                        "https://goldapple.ru/19000039048-t7"), " — кисть для консилера\n",
                    link("MUL MUL celaeno",
                        "https://goldapple.ru/99000038771-celaeno"), " — спонж\n",
                    link("NATALYA SHIK brush 01 powder",
                        "https://goldapple.ru/19000386764-brush-01-powder"), " — кисть для пудры\n",
                ),
            },
            {"title": "Наталья — нанесение тона (часть 2)", "sort_order": 1},
            {"title": "Наталья — нанесение тона (часть 3)", "sort_order": 2},
            {"title": "Наталья — нанесение тона (часть 4)", "sort_order": 3},
            {"title": "Наталья — финальный результат", "sort_order": 4},
            {
                "title": "Ирина — кожа склонна к сухости ✨",
                "sort_order": 5,
                "description": quill_delta(
                    "Делаю акцент на увлажнение и показываю, как наносить тон без подчёркнутых шелушений\n\n",
                    bold("Подготовка кожи:"), nl(),
                    "Увлажняющий тоник ", link("CLARINS",
                        "https://goldapple.ru/19760334995-lotion-tonique-apaisante/"), nl(),
                    "Вода красоты ", link("CAUDALIE",
                        "https://goldapple.ru/19000035763-beauty-elixir-travel-sive/"), nl(),
                    "Эссенция с PDRN ", link("VT Cosmetics",
                        "https://cream.shop/catalog/kosmetika-dlya-litsa/essentsii/pdrn_essence_100/"), nl(),
                    "Стик-эссенция с PDRN ", link("VT Cosmetics",
                        "https://cream.shop/catalog/kosmetika-dlya-litsa/uvlazhnenie_i_pitanie/stik/balzam_essentsiya_s_pdrn_dlya_siyaniya_kozhi/"), nl(),
                    "Сыворотка для губ ", link("BOBBI BROWN",
                        "https://goldapple.ru/19000284166-extra-plump-lip-serum/"), nl(2),
                    bold("Нанесение тона:"), nl(),
                    "Консилер ", link("LUNA",
                        "https://goldapple.ru/19000163543-longlasting-tip-cover-fit/"), nl(),
                    "Тональный крем ", link("SHISEIDO",
                        "https://goldapple.ru/19000265710-revitalessence-skin-glow/"), nl(),
                    "Пудра ", link("CHARLOTTE TILBURY",
                        "https://www.charlottetilbury.com/us/product/airbrush-flawless-finish-2-medium"), nl(2),
                    bold("Кисти:"), nl(),
                    link("MUL MUL celaeno",
                        "https://goldapple.ru/99000038771-celaeno"), " — спонж\n",
                    link("NATALYA SHIK brush 02 full face",
                        "https://goldapple.ru/19000386765-brush-02-full-face"), " — кисть для пудры\n",
                ),
            },
            {"title": "Ирина — нанесение тона (часть 2)", "sort_order": 6},
            {"title": "Ирина — нанесение тона (часть 3)", "sort_order": 7},
            {"title": "Ирина — нанесение тона (часть 4)", "sort_order": 8},
            {"title": "Ирина — финальный результат", "sort_order": 9},
        ],
    },

    # ══════════════════════════════════════════════════════════
    # ЧЕКЛИСТЫ
    # ══════════════════════════════════════════════════════════
    {
        "type": "checklist",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Чек-лист по кистям",
        "sort_order": 5,
        "sub_items": [],
    },
    {
        "type": "checklist",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Чек-лист: Косметичка новичка",
        "sort_order": 6,
        "sub_items": [],
    },
    {
        "type": "checklist",
        "section": "base",
        "display_date": "2026-02-21",
        "title": "Чек-лист: Тональные крема",
        "sort_order": 7,
        "sub_items": [],
    },
]


# ─────────────────────────────────────────────────────────────
# API helpers
# ─────────────────────────────────────────────────────────────

def api_post(path: str, body: dict, admin_key: str) -> dict:
    url = f"{API_BASE}{path}"
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "X-Admin-Key": admin_key,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30, context=_SSL_CTX) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body_txt = e.read().decode("utf-8")
        print(f"  ✗ HTTP {e.code}: {body_txt}", file=sys.stderr)
        raise


def api_get(path: str, admin_key: str) -> list:
    url = f"{API_BASE}{path}"
    req = urllib.request.Request(
        url,
        headers={"X-Admin-Key": admin_key},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=30, context=_SSL_CTX) as resp:
        return json.loads(resp.read().decode("utf-8"))


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Seed База знаний content")
    parser.add_argument("--key", default=os.environ.get("ADMIN_KEY", ""), help="Admin secret key")
    parser.add_argument("--dry-run", action="store_true", help="Print payload without sending")
    args = parser.parse_args()

    if not args.key:
        print("Error: provide --key or set ADMIN_KEY env var", file=sys.stderr)
        sys.exit(1)

    # Check existing content to avoid duplicates
    print("Checking existing content in section=base...")
    try:
        existing = api_get("/admin/content?section=base", args.key)
        existing_titles = {item["title"] for item in existing}
        print(f"Found {len(existing)} existing items: {existing_titles or 'none'}")
    except Exception as e:
        print(f"Warning: could not fetch existing content: {e}")
        existing_titles = set()

    created = 0
    skipped = 0

    for lesson in LESSONS:
        title = lesson["title"]

        if title in existing_titles:
            print(f"  ⟳ SKIP (already exists): {title}")
            skipped += 1
            continue

        # Build payload
        payload = {
            "type": lesson["type"],
            "section": lesson["section"],
            "display_date": lesson["display_date"],
            "title": title,
            "subtitle": lesson.get("subtitle"),
            "sort_order": lesson.get("sort_order", 0),
            "url": lesson.get("url"),
            "sub_items": [
                {
                    "title": s["title"],
                    "description": s.get("description"),
                    "url": s.get("url"),
                    "sort_order": s.get("sort_order", i),
                }
                for i, s in enumerate(lesson.get("sub_items", []))
            ],
        }

        if args.dry_run:
            print(f"\n{'='*60}")
            print(f"DRY RUN — {title}")
            print(json.dumps(payload, ensure_ascii=False, indent=2))
            continue

        print(f"  → Creating: {title}  ({len(payload['sub_items'])} sub-items)...")
        try:
            result = api_post("/admin/content", payload, args.key)
            print(f"  ✓ Created: {result['id']}")
            created += 1
        except Exception as e:
            print(f"  ✗ Failed: {e}")

    print(f"\nDone. Created: {created}, Skipped: {skipped}")
    if skipped:
        print("Re-run to update existing items manually via admin UI.")


if __name__ == "__main__":
    main()
