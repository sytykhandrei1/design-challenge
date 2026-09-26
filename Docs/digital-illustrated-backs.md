# Digital — иллюстрированные обороты, 26 сентября 2026

Пользователь выбрал ранее показанные иллюстрации. Amanecer — рассветный город;
Jacarandá — цветущий двор; Cenote — фантазийный сенот; Noche — ночной город.
Маленький аксолотль объединяет серию. Сцены вымышленные, не точные изображения
конкретных достопримечательностей; аксолотль в Cenote — сказочная деталь.

## Подключение

Target Plata, iOS 18+. Галерея: Card preview → Digital → тап по карте → поворот
на оборот. Debug demo: `--plata-metal-v1-demo --plata-digital-default`, кнопка Back.
PNG лежат в raw folder `Plata/PlataDigitalV1/Resources/plata_digital_v1`, который
копируется целиком Copy Bundle Resources. Регистрация добавлена в источник
генератора Scripts/create-project.py и соответствующими четырьмя строками
в project.pbxproj; генератор с побочными asset writers не запускался.

Исходные PNG из imagegen переименованы, скопированы побайтно. Нет JPEG/HEIC,
перерисовки, downscale или upscale. В PNG отсутствует ICC: при декодировании
цвета явно трактуются как sRGB; TextureResource semantic .color, compression .none.
Прозрачные presentation margins исключены только центрированными UV scale/offset
в стандартном PhysicallyBasedMaterial. Масштаб UV сохраняет пропорции рисунка,
offset=(1-scale)/2. Контур карты задаёт прежняя геометрия ID-1; детали на обороте
не зеркальны. Генеративная сцена плоско напечатана на поверхности, это не новый
трёхмерный город и не анимация внутри карты.

Front, лого, облако, Mastercard, edge и весь свет не менялись. Back сохраняет
metallic0, roughness0.55, specular0.16, clearcoat0.12/0.40, emission0.30.
Изображение применяется и к baseColor, и к существующему emissive каналу.
Геометрические нормали, без normal/height карт. Сохраняется cache трёх appearance
с очисткой при memory pressure и фоновым декодированием. При проблеме загрузки
ошибка указывает `plata_digital_v1/<skin>_back_illustration.png`.

| PNG | Native size | UV scale x/y | SHA-256 |
| --- | --- | --- | --- |
| amanecer_back_illustration.png | 1580×996 | 0.988376661 / 0.988733720 | `500f7149063f5991a1ce70fe27c39494ac064e2f342893e57f3f4c0d4877a790` |
| jacaranda_back_illustration.png | 1579×996 | 0.996733376 / 0.996462382 | `ea3b6ae0a14c23617e463f611b274800053bbb6c3b2eeee212a4eb84f80249f9` |
| cenote_back_illustration.png | 1579×996 | 0.946733376 / 0.946475976 | `87713230e80eef23c77bc9875b1a1e39ac4641ee12191054e2a5c50e377aabd0` |
| noche_back_illustration.png | 1579×996 | 0.890733376 / 0.890491201 | `9475c654c16481f86f0ee11d814eb848e18eae13d488b42e0f42589f5770959c` |

Общий размер добавленных PNG: 11,624,741 байт. Исходная детализация примерно
1.5K; при сильном увеличении её предел остаётся видимым, апскейл не применяется.

## Проверки

Debug build + UI test на iPhone16 Pro / iOS18.6 PASS: один существующий сценарий
`testFourSkinsWithoutPersonalData` проверяет все четыре скина, Front/Light/Back,
Studio/Soft/Night и отсутствие реквизитов. Просмотрены реальные кадры четырёх
оборотов: ориентация, контур и узнаваемые детали корректны. SHA-256 четырёх
файлов внутри собранного bundle совпадают с исходными PNG. Из прежних179
контрольных файлов176 неизменны; три намеренных изменения перечислены ниже.
Скриншоты: `/Users/a.sytykh/Documents/ChatGPT/TT/Artifacts/plata-digital-illustrated-review`.
Результат: `/tmp/plata-digital-illustrated-test01.xcresult`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'platform=iOS Simulator,id=15F004E6-333F-4583-915E-FA4AD5C593CE' \
  -derivedDataPath /tmp/plata-digital-illustrated-build \
  -resultBundlePath /tmp/plata-digital-illustrated-test01.xcresult \
  -only-testing:PlataUITests/PlataDigitalV1UITests/testFourSkinsWithoutPersonalData test
```

Pinch/max-zoom и физический телефон в этой итерации не проверялись; известные
ограничения gesture-тестов из предыдущей итерации не считаются исправленными.
После отдельного запроса пользователя «добавь на телефон» подписанная Release
собрана и установлена на iPhone And (UDID00008120-001A390E0A400032),
databaseSequence3580. Все4PNG внутри device Release совпадают с исходниками.
Подтверждение: `/tmp/plata-digital-illustrated-phone-install.json`;
сборка: `/tmp/plata-digital-illustrated-phone-build.log`.
Две попытки devicectl launch завершились timeout60/30с; автоматический запуск
не подтверждён. Приложение можно открыть вручную. Затем пользователь явно разрешил публикацию этой итерации сообщением «заливай на гит»; обычный push в main без переписывания истории.

## Явная ревизия checksum baseline

После проверки обновлены только три существующие записи и добавлены четыре PNG.
Остальные176 записей сохранены; это новая функциональная итерация ПОСЛЕ очистки
репозитория, не подмена доказательства идентичности при очистке. Исходный baseline
доступен в commit2d07662. Прежние значения изменённых записей:

```json
{
  "Plata.xcodeproj/project.pbxproj": {
    "bytes": 29038,
    "sha256": "f040b4f1951de351af22ae14dc2f0d26291d43a8f0d0c70b0a96815547ea1d6f"
  },
  "Plata/PlataDigitalV1/PlataDigitalArtwork.swift": {
    "bytes": 19732,
    "sha256": "ce8667f732350442cb603b3d92d28526142dafcd306634c287a91d8bdfa58647"
  },
  "Plata/PlataDigitalV1/PlataDigitalCardMaterial.swift": {
    "bytes": 13827,
    "sha256": "2fb7abac38785271a51c00e179fedde2a19d33dd20141fcec3aec46928b092ec"
  }
}
```
