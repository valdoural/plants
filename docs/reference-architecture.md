# PictureThis 5.38.0 (Android): разбор архитектуры и план кроссплатформенного аналога

Источник: `PictureThis v5.38.0 b5096.apk` (пакет `cn.danatech.xingseus`, разработчик Glority), md5 `63f29c990fdebfa2cd1190d09ad16e9b`.
Метод: распаковка (apktool), декомпиляция (jadx), анализ манифеста, ресурсов, строк и сгенерированного API-клиента.
Часть методов защищена от декомпиляции (упаковщик + `libencrypt.so`/`libsigner.so`), эту защиту мы не вскрывали — для построения собственного продукта она не нужна.

> **Принцип клона.** Берём функциональность, структуру экранов и UX-паттерны. Не берём: код, графику, иконки, Rive/Lottie-анимации, тексты, базу растений, бренд и серверы Glority. Визуальный стиль — свой (App Store Guideline 4.1 «Copycats», политика Google Play об имперсонации, авторское право/trade dress).

---

## 1. Сводка

| Параметр | Значение |
|---|---|
| Платформа | Native Android, Kotlin, minSdk 28 (Android 9), targetSdk 36 |
| UI | Jetpack Compose (основное) + немного XML/Fragments; single-activity + `ContainerActivity` для фрагментов |
| Архитектура клиента | MVVM (ViewModel + UiState + Flow/LiveData), модульная (≈60 gradle-модулей `features/*`, `fwk-*`, `outsourcing/*`) |
| Распознавание | **Полностью на сервере.** Локальных ML-моделей в APK нет |
| Диагностика | Сервер, **потоковый ответ** (stream, мультимодальная — фото + анкета, похоже на LLM) |
| Хранилище | Room (SQLite) — локальный кэш; источник истины — сервер |
| Фоновые задачи | WorkManager, AlarmManager (напоминания), FCM push |
| Виджеты | Glance: 3 размера виджета напоминаний на домашний экран |
| Локализация | ~90 языков |
| Размер | 94 МБ, 10 DEX, ~18 900 классов |

---

## 2. Технологический стек (что внутри и чем заменить)

| Слой | В PictureThis | Аналог для кроссплатформы |
|---|---|---|
| UI | Jetpack Compose, Material 3 | Flutter (Material 3 / свой дизайн) или React/PWA |
| Анимации | Rive (`.riv`), Lottie (onboarding, paywall, тосты) | `rive` и `lottie` есть для Flutter и web — **свои** анимации |
| Камера | CameraX | `camera` (Flutter) / `getUserMedia` (web) |
| Сеть | OkHttp, собственный `ApiServer`: POST/GET/multipart + **streaming**; опциональное шифрование тела; резервный хост и multi-DNS | Dio/HTTP + SSE (или WebSocket) для стриминга |
| Изображения | Glide | `cached_network_image` / CDN с ресайзом |
| Загрузка фото | Прямая загрузка в облачное хранилище по выдаваемому сервером upload-токену (модуль `aws`, `GetUploadConfigMessage`) | Pre-signed URL в S3 / Supabase Storage / R2 |
| БД на устройстве | Room: `Plant`, `MyPlant`, `MyFolder`, `SnapHistory`, `DiagnoseHistory`, `BookInventory`; отдельная `CityDatabase` (офлайн-справочник городов `cities.db`) | Drift/Isar (Flutter) или IndexedDB (web) |
| Push | Firebase Cloud Messaging | FCM (Android/iOS), Web Push (PWA, iOS 16.4+) |
| Конфиг/эксперименты | Firebase Remote Config + собственный A/B-сервис (`abtesting`) | Firebase Remote Config / GrowthBook / PostHog |
| Аналитика | Firebase, Adjust (атрибуция), собственный трекинг `gw.…/tracking` | Firebase Analytics / Amplitude / PostHog + AppsFlyer/Adjust при платном трафике |
| Краши/перф | Crashlytics, Firebase Performance | Crashlytics / Sentry |
| Платежи | Google Play Billing (подписки, триал), restore, промокоды/gift cards | RevenueCat (единый слой для App Store / Play / Stripe-web) |
| Авторизация | Анонимный пользователь по устройству + email-код, Google Sign-In, удаление аккаунта | Firebase Auth / Supabase Auth (anonymous → email/Apple/Google) |
| Веб-вставки | WebView + JS-bridge (`AndroidJsBridge.js`) для статических страниц, справки, статей | Обычные web-страницы / `webview_flutter` |
| Markdown | commonmark (контент диагнозов и советов в Markdown) | `flutter_markdown` / `marked` |
| Виджеты | Glance AppWidget | `home_widget` (Flutter) — iOS WidgetKit, Android AppWidget; в PWA недоступно |

---

## 3. Модульная структура клиента

```
app (MyApplication, SplashActivity, MainActivity)
├── features/
│   ├── home          — главная лента: советы по сезону, погода, растения рядом, курсы, подборки
│   ├── identify      — камера → кроп → загрузка → результат распознавания
│   ├── diagnose      — диагностика болезней (пассивная/активная, мультимодальная анкета, стрим)
│   ├── myplants      — «Мой сад»: растения, коллекции (папки), заметки, настройки растения, wish list
│   ├── reminder      — напоминания по уходу (полив, удобрение, пересадка…), виджеты
│   ├── tools         — инструменты: люксметр, калькулятор полива, проверка пересадки, спил дерева, «спроси ботаника»
│   ├── books         — магазин/читалка электронных книг (внутренние покупки)
│   ├── premium       — экран премиум-сервиса, управление подпиской
│   ├── onboarding    — онбординг и повторный онбординг (ReOnboarding)
│   ├── settings      — настройки, аккаунт, единицы измерения, уведомления, помощь
│   └── more          — раздел «Ещё»
├── guide/memoXXXXX   — ~40 вариантов paywall (A/B), retain/detain — экраны удержания при отмене
├── modules/purchase  — restore, renew, after-buy онбординг
├── customerservicerobot — чат-бот поддержки
├── cmsui             — рендер CMS-контента (карточки растений, статьи) из layout-описаний с сервера
├── glance/widgets    — виджеты домашнего экрана
└── fwk-*             — сеть, трекинг, A/B, роутер, базовые UI-компоненты
```

**Важная деталь:** карточки растений и статьи собираются из серверного описания разметки (`CmsLayout`, `LayoutType`, `uimaker`) — это «server-driven UI». Для аналога рекомендуется тот же подход: контент меняется без релиза приложения.

---

## 4. Карта экранов и навигация

### 4.1 Нижняя навигация (по строкам ресурсов)
`Home` · `Diagnose` · **[Identify — центральная кнопка камеры]** · `My Garden` · `More`

### 4.2 Дерево экранов

```
Splash → (первый запуск) Onboarding (видео/анимации, опросник «что выращиваете») → Paywall (A/B) → Main
                                                                                        │
├─ HOME ────────────────────────────────────────────────────────────────────────────────┤
│   ├─ Лента: советы на месяц (персональные, по погоде и городу), «Растения рядом»,
│   │         популярные курсы, подборки (ядовитые, аллергенные, инвазивные, местные)
│   ├─ PlantIndexList / PlantIndexDetail  — каталог-подборки
│   ├─ TopicList / TopicDetail, TipsList, TrendingList
│   ├─ PlantKnowHowSearch / PlantKnowHowDetail — поиск по базе знаний
│   └─ HomeLocationGuide (bottom sheet) — запрос местоположения/города
│
├─ IDENTIFY (камера) ───────────────────────────────────────────────────────────────────┤
│   IdentifyCamera → IdentifyCrop → IdentifyLoading → IdentifyResult
│     ├─ режимы камеры: обычный, 360° (Full-Circle), аллергены, грибы/др. виды (OtherSpecies)
│     ├─ IdentifySample — «пример фото» для новых пользователей
│     ├─ IdentifyResult: топ-кандидаты + вероятность, похожие фото, «это не то растение» (CorrectPlantCmsName, голосование)
│     └─ → PlantDetail (карточка вида) → «Добавить в мой сад» / в коллекцию
│
├─ DIAGNOSE ────────────────────────────────────────────────────────────────────────────┤
│   DiagnoseCamera → MultimodalDiagnoseSurvey (уточняющие вопросы) → MultimodalDiagnoseLoading (стрим)
│     → MultimodalDiagnoseResult (статус здоровья, болезнь, лечение по шагам, ошибки ухода)
│     ├─ TreatmentTips (bottom sheet), CommonProblemsDetail
│     ├─ ProblemsByPlant / ProblemsByPlantPart — справочник проблем (лист, стебель, корень…)
│     └─ DiagnoseHistoryList / DiagnoseHistoryDetail
│
├─ MY GARDEN ───────────────────────────────────────────────────────────────────────────┤
│   ├─ Список растений / коллекции (FolderDetail, CreateFolder) / MyWishList / SnapHistory
│   ├─ MyGardenSearch, SearchPlants, AddFromMyGarden
│   ├─ MyPlantDetail (вкладки):
│   │     ├─ Care   — график ухода, напоминания
│   │     ├─ Notes  — заметки и фото-дневник (AddOrEditNote, NoteImageViewer)
│   │     └─ Info   — данные вида
│   ├─ PlantSettings: возраст, расположение (indoor/outdoor), свет, тип горшка, дренаж, размер горшка
│   ├─ PlantFinder (подбор растения по фильтрам: свет, место, безопасность, тип) → Result
│   └─ Reminders: ReminderList, Choose plant, Settings, Snooze, Complete
│
└─ MORE ────────────────────────────────────────────────────────────────────────────────┤
    ├─ Tools: LightMeter (люксметр), WaterCalculator (камера + анкета → объём воды),
    │         RepottingChecker (камера → нужна ли пересадка), TreeRingIdentify, SpeciesIdentify,
    │         AskForHelp (вопрос ботанику), ContactUs, CSR (чат-бот поддержки)
    ├─ Books: BookShelf, BookSell, BookReading
    ├─ PremiumService / ManageMembership
    └─ Settings: Account, единицы (метрика/имперские, °C/°F), уведомления, помощь, политика,
                 удаление аккаунта, VibrationTest, AppInfo
```

Глубокие ссылки: `picturethis://dl/...` и `https://www.picturethisai.com/...` (identify/camera, premiumservice, contactus, settings/help) — для аналога нужен такой же роутер по URL (удобно и для web).

---

## 5. Ключевые сценарии (data flow)

### 5.1 Распознавание
```
Камера → кроп/сжатие → запрос upload-конфига (токен) → загрузка фото напрямую в облачное хранилище
→ RecognizeIdentify(imageUrl, location?, identifyType)
→ IdentificationResult { кандидаты [вид, вероятность], похожие изображения (SIMILAR_IMAGE), engine info }
→ RecognizeGetIdentificationPlantCareInfo → карточка + уход
→ сохранение в SnapHistory (item) → по желанию AddToMyPlant
```
Ответ содержит несколько «движков» (`engine_result_map`): классификатор вида + поиск похожих картинок. Результаты бесплатного тарифа ограничены (история удаляется без Premium).

### 5.2 Диагностика (мультимодальная)
```
Фото больного растения → анкета (полив? пересадка? свет? как давно у вас?)
→ DiagnosisStreamDiagnoseV3 (стрим событий) → поэтапный показ: здоровье → проблема → лечение → ошибки ухода
→ сохранение в DiagnoseHistory и как заметку к растению
```
Структура ответа: `DiagnoseResult`, `Treatments` (шаги в Markdown), `CareMistake` (Water/Light/Temperature/Ventilation), `InsightWithHealthCard`. По всем признакам — LLM поверх vision-модели.

### 5.3 Сад и напоминания
```
AddToMyPlant → PlantSettings (место, свет, горшок…) → сервер рассчитывает авто-частоту ухода
(GetReminderAutoFrequencyMap, учитывает сезон и климат города)
→ Reminder {тип, частота, след. дата} → локальный AlarmManager + push → Done / Snooze → виджет
```
Есть «умное расписание»: частота меняется по сезону и погоде (`geo`: климат, погода по дням, сезоны).

### 5.4 Монетизация
Онбординг → paywall (вариант выбирается A/B-сервисом) → триал 7 дней с напоминанием за 48 ч до списания → after-buy онбординг. При попытке отмены — retain/detain экраны со скидкой. Ограничения Free: число распознаваний/диагнозов, хранение истории, книги, «спроси ботаника».

---

## 6. Доменная модель (сущности для вашего бэкенда)

Выведена из сгенерированного API-клиента (только названия и смысл, без копирования схем).

| Сущность | Основные поля (смысл) |
|---|---|
| **User** | id, анонимный/email/Google/Apple, язык, страна, город, единицы, VIP-статус, устройство(а) |
| **Species / CmsName** | id вида, латинское и локальные имена, таксономия, фото, теги (ядовитость, свет, полив, почва, pH, зоны), уход по месяцам, болезни, распространение |
| **Identification (Item/Snap)** | id, фото (оригинал + кроп), кандидаты с вероятностями, выбранный вид, геопозиция, дата, заметка, пользовательское имя |
| **MyPlant** | id, ссылка на вид, никнейм, фото-обложка, коллекция, настройки (возраст, место, свет, горшок, дренаж, размер) |
| **Folder (Collection)** | id, название, тип (indoor/outdoor/garden), порядок |
| **Reminder** | id, myPlantId, тип (полив, удобрение, пересадка, обрезка, опрыскивание…), частота, авто/ручной, след. дата, история выполнений, snooze |
| **Note** | id, myPlantId, тип (обычная / результат диагноза), текст, фото, дата |
| **Diagnosis** | id, фото, ответы анкеты, статус здоровья, болезни (с регионами на фото), лечение, ошибки ухода |
| **Disease** | id, категория, уровень, симптомы, причины, лечение, профилактика, фото |
| **WishPlant** | список желаемых растений |
| **Article / Tip / Course / Topic** | контент главной ленты |
| **Book** | каталог, цены, владение/разблокировка |
| **Subscription** | платформа, продукт, статус, триал, auto-renew, восстановление |
| **ChatSession / Message** | чат-бот/ботаник: сессия, сообщения (текст/изображение) |
| **City / Climate / Weather** | справочник городов, климат по месяцам, прогноз |

---

## 7. API вашего бэкенда (предлагаемая карта, REST)

Группировка зеркалит домены оригинала (`recognize`, `diagnosis`, `gardening`, `plant`, `note`, `cms`, `home`, `geo`, `chatbot`, `vip`, `user`, `abtesting`), но реализация и форматы — ваши.

```
POST /auth/anonymous | /auth/email/code | /auth/email/verify | /auth/oauth
GET  /me            PATCH /me          DELETE /me
POST /uploads/sign                     → pre-signed URL
POST /identify                          {imageUrl, lat?, lng?} → candidates[]
GET  /identifications  GET/PATCH/DELETE /identifications/{id}
POST /diagnose        (SSE stream)     {imageUrls[], answers{}} → events
GET  /diagnoses  GET /diagnoses/{id}
GET  /species/{id}   GET /species/{id}/care   GET /species/search?q=
GET  /diseases/{id}  GET /problems?part=leaf
CRUD /plants  /folders  /plants/{id}/notes  /plants/{id}/settings
CRUD /reminders  POST /reminders/{id}/done  POST /reminders/{id}/snooze
GET  /reminders/auto-frequency?plantId=
GET  /home/feed?city=   GET /geo/cities?q=   GET /geo/weather?city=
POST /tools/water-amount  POST /tools/repot-check
POST /chat/sessions  POST /chat/sessions/{id}/messages (SSE)
GET  /config   GET /experiments
POST /billing/webhook (RevenueCat)
```

---

## 8. Как заменить «мозги» (легально)

| Функция | Варианты |
|---|---|
| Распознавание вида | **Plant.id / Kindwise** (вид + здоровье, платно за запрос), **Pl@ntNet API** (бесплатный лимит, некоммерческие условия — проверить), собственная модель (EfficientNet/ViT, дообученная на iNaturalist / PlantCLEF) |
| Диагностика | Plant.id Health Assessment **или** vision-LLM (Claude) с анкетой и стримингом — повторяет «мультимодальную» схему оригинала |
| База растений | GBIF, Wikidata/Wikipedia (CC BY-SA — с атрибуцией), USDA Plants, Trefle; тексты ухода — генерация LLM + ревью ботаника |
| Уход/частота | Правила по тегам вида × настройки растения × климат (Open-Meteo — бесплатный API погоды) |
| Чат «спроси ботаника» | LLM-ассистент + эскалация к живому эксперту |
| Похожие фото | Векторный поиск (pgvector) по вашим/лицензированным изображениям |

---

## 9. Целевая архитектура аналога

### Рекомендация: **Flutter** (iOS + Android + Web из одного кода)
- Камера, виджеты, push, подписки App Store/Play — всё есть.
- Web-сборка даёт PWA для быстрого запуска на iPhone без App Store.

### Альтернатива для быстрого старта: **PWA** (React/Next.js)
- Работает на iPhone через Safari, «На экран Домой».
- Ограничения iOS: push только для установленной PWA (iOS 16.4+), **нет виджетов**, нет фоновых будильников (напоминания только через серверный push), нет in-app покупок App Store (оплата через Stripe — при этом Apple не берёт комиссию, но и в App Store вас нет).

### Схема
```
┌──────────── Клиент (Flutter: iOS / Android / Web-PWA) ────────────┐
│ UI (свой дизайн-кит) · state: Riverpod/Bloc · роутер go_router (deeplinks)│
│ локальный кэш (Drift) · камера · уведомления · RevenueCat SDK      │
└──────────────┬────────────────────────────────────────────────────┘
               │ HTTPS REST + SSE
┌──────────────▼──────────── Бэкенд ────────────────────────────────┐
│ API (Supabase/Postgres + Edge Functions  или  NestJS/FastAPI)      │
│ ├─ Auth · Storage (фото) · Postgres (+pgvector)                    │
│ ├─ Identify-сервис → Plant.id / своя модель                         │
│ ├─ Diagnose-сервис → vision-LLM, стриминг                           │
│ ├─ Care-engine (частоты, сезоны, погода Open-Meteo)                 │
│ ├─ Scheduler → FCM / APNs / Web Push                                │
│ ├─ CMS (Directus/Strapi/Sanity) — виды, болезни, статьи, лента      │
│ └─ Webhooks RevenueCat, A/B (GrowthBook), аналитика (PostHog)       │
└────────────────────────────────────────────────────────────────────┘
```

---

## 10. План работ (этапы)

| Этап | Содержание | Ориентир |
|---|---|---|
| 0. Дизайн | Свой бренд, дизайн-кит, макеты ~25 ключевых экранов по карте из п.4 | 3–4 нед |
| 1. MVP | Auth (аноним), камера → распознавание (Plant.id) → карточка вида → «Мой сад» → напоминания о поливе (push) | 6–8 нед |
| 2. Диагностика | Фото + анкета → LLM-диагноз со стримингом, история, заметки | 3–4 нед |
| 3. Монетизация | RevenueCat, paywall + триал, лимиты Free, A/B paywall | 2–3 нед |
| 4. Контент | CMS, главная лента, советы по сезону/погоде, подборки (ядовитые и т.д.) | 3–4 нед |
| 5. Инструменты | Люксметр (нативно, на web — ограниченно), калькулятор полива, проверка пересадки, виджеты | 3–4 нед |
| 6. Рост | Локализация, чат-бот, книги/курсы, ASO | по мере |

---

## 11. Что осталось за рамками разбора
- Тела защищённых методов (часть бизнес-логики главного экрана и сетевого слоя) — не вскрывались намеренно.
- Точные схемы ответов сервера, ключи и эндпоинты Glority — не нужны и не должны использоваться в аналоге.
- iOS-версия оригинала не анализировалась.
