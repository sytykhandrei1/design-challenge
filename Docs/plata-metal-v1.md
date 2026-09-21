# PLATA Metal / Plata v1 — RealityKit demo

> Latest data revision: both finishes now use the requested **ALEX SMITH** engraving via four derived front PBR maps; original PNGs remain unchanged. See [plata-card-personalization.md](plata-card-personalization.md). This supersedes the original front-map inventory below.

> Обновление: витрина теперь включает Plata и Obsidiana, открывается через Account → Transfer и поддерживает pinch zoom. Актуальный этап описан в [plata-metal-obsidiana.md](plata-metal-obsidiana.md). Ниже сохранён отчёт первой интеграции Plata v1.

Изолированная интеграция пакета `plata_metal_v1_codex_bundle.zip`. Дизайн-ревью ещё не пройдено; коммитов и пушей нет. Существующая SceneKit-карта и продуктовый flow не заменены.

## Проект и вход

- Основной iOS target и схема: `Plata`; deployment target: iOS 18.0, Swift 5 mode.
- Проект: `Plata.xcodeproj`. Tuist, XcodeGen и Swift Package не используются. Источник конфигурации — собственный `Scripts/create-project.py`; его список Sources/Resources синхронизирован с точечными добавлениями в `.pbxproj`. Полный генератор в рабочем репозитории не запускался, чтобы сохранить формат и параллельные изменения.
- Переиспользуемый компонент: `PlataMetalCardView()`.
- Открыть `Plata/PlataMetalV1/PlataMetalCardDemoView.swift`, Preview **PLATA Metal / Plata v1**.
- Альтернатива: Debug-сборка с launch argument `--plata-metal-v1-demo`. В обычном запуске и Release остаётся исходный `BankRootView`. DEBUG-вставку в `PlataApp.swift` внёс владелец файла из соседней задачи по согласованию.
- Кнопки Front / Light / Back / Edge выставляют контрольные положения; один палец вращает X/Y. Повторное нажатие положения сбрасывает жест. Камера вписывает сферу, содержащую карту, с запасом 10%, с учётом размера viewport.

## Геометрия и материалы

```
PLATA Metal — Plata
├── Metal body and edge
├── Front surface
├── Back surface
└── Inserted chip
    └── physical insert edge
```

Контур 85.60 × 53.98 мм, толщина корпуса 0.76 мм, радиус углов 3.18 мм. Торец — экструзия скруглённого контура; front/back замыкают его в один объект при z ±0.38 мм. Так радиус углов не ограничивается толщиной, как при обычном скруглённом боксе. Чип имеет собственную поверхность и торец 0.040 мм; выступает всего на 0.004 мм, остальное внутри корпуса. Положение и масштаб чипа взяты из manifest: x130/y390, 338×240 на исходном поле 2048×1292.

Front, back, chip используют отдельные `PhysicallyBasedMaterial` с baseColor, roughness, metallic, normal; торец — отдельный стандартный PBR. Оборот повёрнут вокруг Y на π вместе с UV и касательным базисом; отрицательного масштаба и отдельного зеркалирования текстуры нет. Гравировка целиком определяется исходными картами материала. Никаких текстовых слоёв поверх карты, CustomMaterial, `.metal`, внешних зависимостей или height maps.

`ARView(cameraMode: .nonAR, automaticallyConfigureSession: false)`. ARSession не запускается, разрешение камеры и ARKit capability не добавлены.

## Ресурсы

Все файлы без переименования и без изменения исходных байтов лежат в `Plata/PlataMetalV1/Resources/plata_metal_v1`. Это **folder reference** с Target Membership в `Plata` и записью в **Copy Bundle Resources**, не Image Sets. В собранном `.app` остаётся отдельный `plata_metal_v1/`; загрузка идёт по URL относительно переданного `resourceBundle` (по умолчанию `.main`). Имена RealityKit-кэша также имеют namespace `plata_metal_v1/`.

| Сторона | baseColor | roughness | metallic | normal |
| --- | --- | --- | --- | --- |
| Front | `front_basecolor.png` | `front_roughness_rgb.png` | `front_metalness_rgb.png` | `front_normal_opengl.png` |
| Back | `back_basecolor.png` | `back_roughness_rgb.png` | `back_metalness_rgb.png` | `back_normal_opengl.png` |
| Chip | `chip_basecolor_rgba.png` | `chip_roughness_rgb.png` | `chip_metalness_rgb.png` | `chip_normal_opengl.png` |

Тринадцатый файл — `plata_studio.hdr`: исходный Radiance HDR декодируется ImageIO с float-компонентами и передаётся в `EnvironmentResource(equirectangular:)`. Это источник environment lighting/reflections, дополненный двумя DirectionalLight. Интенсивности адаптированы для RealityKit: environment exponent −0.7, key 300, fill 80, чтобы избежать пересвета исходного примера.

BaseColor имеет semantic `.color`, roughness/metalness — `.raw`, normal — `.normal`; compression `.none`. Семантика raw сохраняет значения каналов без цветового преобразования ([Apple](https://developer.apple.com/documentation/realitykit/textureresource/semantic-swift.enum/raw)); normal предназначена для tangent-space нормалей ([Apple](https://developer.apple.com/documentation/realitykit/textureresource/semantic-swift.enum/normal)). Front/back: 2048×1292; chip: 1024×727. Ни один исходник не уменьшен и не конвертирован. Обычная генерация mip-уровней движком не меняет исходное разрешение и файлы.

Используется **OpenGL +Y одновременно для трёх сторон**. DirectX, Reference и документы из архива в bundle не включены. Если визуальное ревью покажет инверсию рельефа, нужно заменить сразу три normal-файла на исходные Alternates/NormalsDirectX и изменить одну константу `normalConvention` в `PlataMetalV1Resources`; не править изображения вручную.

Ошибки валидации, загрузки PNG или HDR отображаются на экране и пишутся в Logger category `PlataMetalV1` с точным `plata_metal_v1/<filename>`. Критические ошибки не подавляются `try?`. Асинхронная загрузка отменяется при закрытии компонента.

## Файлы интеграции

Добавлены:

- `Plata/PlataMetalV1/PlataMetalCardView.swift` — SwiftUI/RealityKit, загрузка PBR/HDR, жесты, fit camera.
- `Plata/PlataMetalV1/PlataMetalCardGeometry.swift` — контур, торец, UV/касательный базис.
- `Plata/PlataMetalV1/PlataMetalCardDemoView.swift` — DEBUG demo и Preview.
- 13 файлов в `Plata/PlataMetalV1/Resources/plata_metal_v1/`, перечисленных выше.
- `PlataUITests/PlataMetalV1UITests.swift` — загрузка, контрольные кадры, независимое вращение X/Y и reset.
- `Docs/plata-metal-v1.md` — этот отчёт.

Точечно дополнены `Scripts/create-project.py`, `Plata.xcodeproj/project.pbxproj`. Согласованная DEBUG-вставка в `Plata/PlataApp.swift` сделана соседним агентом. Его остальные изменения не относятся к этой интеграции.

## Проверки

Команда сборки из корня проекта:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'platform=iOS Simulator,id=15F004E6-333F-4583-915E-FA4AD5C593CE' \
  -derivedDataPath /tmp/plata-metal-v1-build build
```

Сборка: **BUILD SUCCEEDED**, iPhone 16 Pro, iOS 18.6. Вся папка из 13 файлов в собранном приложении сверена с ZIP по SHA-256, совпадение 13/13. Временный запуск генератора вне репозитория подтвердил, что membership Sources/Resources всех targets совпадает с рабочим `.pbxproj`, без дубликатов.

UI-проверка запускается той же командой с `test -only-testing:PlataUITests/PlataMetalV1UITests -parallel-testing-enabled NO` и отдельным `-resultBundlePath`.

Финальный UI-тест проверяет готовность всей сцены, 4 положения, независимый X/Y drag и повторный reset. Отдельно проверена временная копия `.app` без `front_normal_opengl.png`: экран и Logger показывают точный путь отсутствующего файла, приложение не падает. После проверки полноценная сборка восстановлена. В `Info.plist` нет camera permission и ARKit required capability.

Визуально исправлены перевёрнутые по Y UV из входного примера и несовпадение чипа с посадкой. Roughness/metallic явно используют scale=1, чтобы texture maps управляли полным диапазоном материала. Контрольные изображения сохранены вне репозитория, в `/Users/a.sytykh/Documents/ChatGPT/TT/Artifacts/plata-metal-v1-review`.

Остаётся дизайн-ревью пользователя, в том числе характер блика, чтение углублённой гравировки и интенсивность микрошлифовки на физическом устройстве. На симуляторе установлена работоспособность renderer/ресурсов/жестов и ориентации сторон. Проверка на реальном iPhone не выполнялась. OpenGL оставлен; текстуры не оптимизировались, другие варианты линейки не подключались.

## Контрольные суммы runtime-файлов

SHA-256 исходного ZIP совпадает с файлами репозитория и собранного app bundle:

| Файл | SHA-256 |
| --- | --- |
| `back_basecolor.png` | `505577b8136887384c89f6d430d1faa2a10d007315717ad910876f8d2bdbaaf3` |
| `back_metalness_rgb.png` | `730130139dd50f48e13cc29d7c6a898c9f00e892f3e71c0879262a0cf62d3c75` |
| `back_normal_opengl.png` | `951110e23c421df149efb2beb82eada1a174264ce8fd05846721300c4e2a9c3f` |
| `back_roughness_rgb.png` | `209aeda9c8d6183d96b086f8921e7377f9685192df69d19572fa39d6f4c90229` |
| `chip_basecolor_rgba.png` | `630089a7a81eea539a7361f757635ceb259dcd1bdd95d99d570098d17e4d9665` |
| `chip_metalness_rgb.png` | `ac7e7f28c058d25431baff8a910ec9160a1a1fa1bd60589f716ab00b1e4ba3c0` |
| `chip_normal_opengl.png` | `72d0cff41f9106484477ac0b76a771e900d92840fb4ef972c2a4c16f08971179` |
| `chip_roughness_rgb.png` | `705c719c5174a32c1a593e27ad79f507e1fabb7ca08bc106bbc4d76d39252030` |
| `front_basecolor.png` | `e28edfddc4e6aebf1baaf28445ea2eb009c3bf48aae0f5befd2c20ae5665ca1b` |
| `front_metalness_rgb.png` | `47b4e47e8f1644f1bc240a1fe989c741c56db7bdadc64a3a2932d68f4170fc29` |
| `front_normal_opengl.png` | `e4278682cc7a72761cc513d56e5ba33ac66172331636ef1d84fabf6bd2434ed7` |
| `front_roughness_rgb.png` | `cd52440863e2261e88704920171b39ee68a74e52ca96400c2166cb7b3c51d022` |
| `plata_studio.hdr` | `875e54c6030ea507b12794bd062b895af4d0ac5b75d9cf161ee1de2e0909a76a` |

Итоговая проверка 19.09.2026: `BUILD SUCCEEDED`, `TEST SUCCEEDED` (1 feature UI-test, 0 failures; `/tmp/plata-metal-v1-tests-04.xcresult`). Последняя отдельная команда `build` также прошла. `git diff --check` и отдельная проверка whitespace новых файлов прошли. Журнал и таблица SHA-256 сохранены рядом со скриншотами. Полный `git diff --stat` содержит также изменения соседней задачи; `feature-diff-stat.txt` в папке ревью показывает только эту интеграцию, включая новые файлы, без staging и без изменения Git index.
