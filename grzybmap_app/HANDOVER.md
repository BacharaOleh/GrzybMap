# 🍄 GrzybMap — Handover & Continuation Guide

## 📌 Status projektu
В проекте реализована масштабная модернизация пользовательского интерфейса (Anti-AI-Slop Comprehensive UI Modernization) с устранением избыточных вложенных рамок («box-in-a-box»), переходом на нейтральные полупрозрачные границы и концентрические скругления.

### ✅ Полностью завершенные этапы (M1 – M4):
1. **M1 (Базовые токены темы)** — `lib/core/theme/app_theme.dart`:
   - Заменены навязчивые зеленые рамки (`AppColors.border`) на нейтральные субпиксельные полупрозрачные линии (`Colors.white` 8–10% alpha).
   - Внедрена математическая система концентрических скруглений `AppRadii`.
   - Настроена плавающая тема снекбаров `snackBarTheme` (r=12).
2. **M2 (Оверлеи карты)** — `lib/features/map/presentation/map_screen.dart`, `map_top_bar.dart`:
   - Контекстное меню долгого тапа по карте переведено в единый аккуратный `Grouped Action Sheet` с векторными иконками вместо эмодзи (`Icons.bookmark_add_rounded`, `Icons.directions_car_filled_rounded`).
   - Легенда осадков стала компактной градиентной шкалой миллиметров (12 мм, 22 мм, 35+ мм).
3. **M3 (Шторка характеристик участка)** — `lib/features/map/presentation/widgets/parcel_bottom_sheet.dart`:
   - Объединены характеристики биотопа, 14-дневных осадков, температуры почвы и влажности подстилки в **единый монолитный блок** без многослойных рамок.
   - Адаптивная верстка проверена на экранах от 320px до 450px без переполнений текста (`Flexible` + `ellipsis`).
4. **M4 (Дневник находок и формы)** — `lib/features/foraging_journal/presentation/`:
   - `foraging_journal_screen.dart`: моноширинные табулярные цифры статистики находок (`FontFeature.tabularFigures()`), фильтры-пилюли с неоновыми индикаторами активности, концентрические карточки мест с фото-миниатюрами.
   - `save_spot_dialog.dart`: поля ввода с нейтральными контурами, визуальный интерактивный пикер видов с живым поиском и фото.
   - `spot_details_sheet.dart`: концентрическая геометрия, табулярные координаты и даты.
   - `test/foraging_journal_widget_test.dart`: 9 новых целевых виджет-тестов.

---

### ⏳ Оставшиеся этапы для продолжения (M5 – M7):
- **M5 (Досье видов грибов и поиск)**:
  - Файлы: `lib/features/map/presentation/widgets/mushroom_detail_sheet.dart`, `widgets/mushroom_search_sheet.dart`.
  - Задачи: замена эмодзи характеристик (`🗓️ 💧 🌲`) на векторные иконки (`Icons.calendar_today_rounded`, `Icons.water_drop_rounded`, `Icons.park_rounded`), выделенная ботаническая карточка безопасности для ядовитых двойников, стилизованные пилюли микоризных связей.
- **M6 (Офлайн-менеджер)**:
  - Файлы: `lib/features/offline_mode/presentation/widgets/offline_areas_sheet.dart`, `download_area_dialog.dart`.
  - Задачи: векторные иконки статуса офлайна, группированный контейнер списка пакетов, полоса использования памяти.
- **M7 (Релизная сборка и верификация)**:
  - `flutter analyze` (должен быть 0 ошибок).
  - `flutter test` (все тесты зеленые).
  - `flutter build web --release` и запуск сервера на порту 8088 (`node server.cjs`).

---

### 🚀 Как проверить и запустить на любом компьютере:

```bash
# 1. Проверка анализатора:
flutter analyze

# 2. Проверка тестов:
flutter test

# 3. Сборка веб-версии:
flutter build web --release

# 4. Запуск локального сервера (порт 8088):
node server.cjs
```
Локальный доступ: `http://localhost:8088`
