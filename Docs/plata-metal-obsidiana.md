# Metal — Plata & Obsidiana

Второй Metal-вариант добавлен по `plata-cards-spec.md`, предоставленному пользователем. Текущий этап — дизайн-ревью двух Metal-карт. Остальные Digital/Plastic из документа не входят в работу; основная продуктовая галерея будет изменена только после одобрения дизайна. Коммитов и пушей нет.

## Где смотреть

`Account → Transfer` открывает `PlataMetalCardDemoView`. Этот вход реализован соседним агентом по прямому запросу пользователя и доступен в обычной навигации. В Debug также сохраняется `--plata-metal-v1-demo`; Preview называется `PLATA Metal — Plata & Obsidiana`.

- Заголовок витрины: **Metal**.
- **Plata—polished silver, catches the light**.
- **Obsidiana—matte PVD, dark to the edge**.
- Segmented selector переключает покрытие без перезагрузки сцены и ресурсов, с сохранением ракурса и увеличения.
- Один палец вращает X/Y. Pinch приближает от 1× до 3×; увеличение сохраняется после отпускания пальцев. Двойной тап возвращает 1×. Кнопки Front/Light/Back/Edge устанавливают контрольный ракурс и масштаб 1×.

## Как устроена Obsidiana

Это второй независимый набор параметров **стандартного PhysicallyBasedMaterial**, использующий общую геометрию ID-1 и неизменённые PBR-карты композиции Plata v1. PNG/HDR не создавались заново, не перекрашивались, не уменьшались и не дублировались. Исходные 13 ресурсов по-прежнему находятся в `plata_metal_v1/` и побайтно совпадают с входным ZIP.

Тёмное PVD-покрытие представлено tint поверхности и торца и более высокой roughness; это прототип отделки для визуального ревью, не новая рисованная иллюстрация и не отдельный готовый пакет текстур Obsidiana.

| Параметр | Plata | Obsidiana |
| --- | --- | --- |
| Surface tint | white | neutral 0.42 |
| Roughness texture multiplier | 1.0 | 2.1 |
| Edge tint | RGB 0.53 / 0.54 / 0.55 | neutral 0.28 |
| Edge roughness | 0.24 | 0.62 |
| Chip | отдельная серебристая вставка | та же серебристая вставка |

Front/back сохраняют baseColor, roughness, metallic, normal maps; геометрия чипа и его PBR независимы от покрытия. Normal convention — **OpenGL +Y**. Для гравировки не добавлены текст или overlay. Обе карты отражают `plata_studio.hdr` в одной non-AR сцене. CustomMaterial, `.metal`, внешних зависимостей и разрешения камеры нет.

Увеличение перемещает камеру, физический размер карты 85.60 × 53.98 × 0.76 мм сохраняется. Камера ограничена перед сферой, содержащей объект, чтобы при наклоне не пересекать поверхность. В режиме 1× весь объект помещается в viewport; при намеренном увеличении края могут выйти за экран.

API для будущей интеграции после дизайн-ревью:

```swift
PlataMetalCardView(finish: .plata)
PlataMetalCardView(finish: .obsidiana)
```

`PlataMetalFinish` содержит стабильные IDs `plata`, `obsidiana`, имена и английские подзаголовки. Текущие `CardCatalog`, `CardOrderingView`, SceneKit-жесты и процесс заказа этой задачей не менялись.

## Изменения этой итерации

Target: `Plata`; UI-тесты: `PlataUITests`.

- `Plata/PlataMetalV1/PlataMetalCardView.swift`: два покрытия, переключение material-параметров, pinch/double-tap, камера и диагностическое состояние.
- `Plata/PlataMetalV1/PlataMetalCardDemoView.swift`: selector, заголовок Metal, подзаголовки спецификации, инструкция жестов. Сохранены согласованные изменения соседнего агента для Release/Transfer.
- `PlataUITests/PlataMetalV1UITests.swift`: проверки двух покрытий, сохранения ракурса/zoom, отсутствия случайного вращения при pinch, double-tap reset и drag после pinch.
- `Docs/plata-metal-obsidiana.md`: этот отчёт.
- `Docs/plata-metal-v1.md`: ссылка на текущую итерацию, с сохранением исходного отчёта.

Новых ресурсов или записей генератора/.pbxproj не требуется.

## Проверки

Команда тестирования (из корня проекта):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'platform=iOS Simulator,id=15F004E6-333F-4583-915E-FA4AD5C593CE' \
  -derivedDataPath /tmp/plata-metal-v1-build \
  -resultBundlePath /tmp/plata-metal-second-tests-01.xcresult \
  -only-testing:PlataUITests/PlataMetalV1UITests \
  -parallel-testing-enabled NO test
```

Первый полный прогон: **TEST SUCCEEDED**, 2 теста, 0 failures. После корректировки яркости только покрытия Obsidiana отдельно прошёл `testObsidianaFinishAndPinchZoom` с контрольными кадрами: **TEST SUCCEEDED**, 1 test, 0 failures (`/tmp/plata-metal-second-tests-02.xcresult`). PNG сохраняются в `/Users/a.sytykh/Documents/ChatGPT/TT/Artifacts/plata-metal-obsidiana-review`.

Подтверждена неизменность SHA-256 всех 13 исходных ресурсов. Коммитов и пушей нет. Добавление обеих карт в основную галерею отложено до отдельного подтверждения дизайн-ревью; доступ через Transfer служит витриной для этого ревью.

Подписанная сборка для физического iPhone: **BUILD SUCCEEDED**.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/plata-metal-second-phone-build build
```

Артефакт: `/tmp/plata-metal-second-phone-build/Build/Products/Debug-iphoneos/Plata.app`.

19 сентября 2026: финальная общая Debug-сборка успешно установлена на **iPhone And (iPhone 15)** и запущена с `--plata-metal-v1-demo`. Установка и запуск подтверждены `devicectl`. На телефоне открыт viewer; сверху нужно выбрать Obsidiana. При обычном запуске приложения вход — Account → Transfer.

`git diff --check` прошёл. Общий `git diff --stat` содержит и работу соседнего агента, и предыдущую интеграцию; отдельная сводка этой итерации сохранена в `Artifacts/plata-metal-obsidiana-review/iteration-diff-stat.txt` рабочего пространства.
