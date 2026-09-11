# MotoTalk — отчёт: duck/resume музыки + уменьшение APK

Дата: 2026-09-11

## 8.1. Подтверждение диагноза

**Подтверждено** на актуальном коде до правок:

1. `AudioService` держал мёртвый `just_audio.AudioPlayer`; `setMusicSource` /
   `pauseMusic` / `startPlaying` **нигде не вызывались** из UI — только из
   самого `audio_service.dart`.
2. `startRecording`/`stopRecording` паузили только этот внутренний плеер →
   внешняя музыка (Spotify / Яндекс / Telegram) **не управлялась**.
3. Единственный реальный эффект на внешние плееры — `audio_session` с
   `AndroidAudioFocusGainType.gain` на весь звонок (`prepareForCall` →
   `endCall`), без связи с `isTransmitting` / `partnerTalking`.
4. Мёртвые зависимости: `audioplayers`, `just_audio`, `cupertino_icons`,
   `crypto`, `uuid`, `shimmer` — нулевые импорты в `app/lib/` (кроме
   `just_audio` внутри мёртвого плеера).
5. `MainActivity.setCommunicationMode()` безусловно ставил
   `isSpeakerphoneOn = true`, конфликтуя с BT SCO.

## 8.2. Изменённые / удалённые файлы

| Файл | Суть |
|---|---|
| `app/lib/services/music_ducking_controller.dart` | **новый** — автомат duck + 5 с grace + `forceResumeNow` |
| `app/lib/services/audio_service.dart` | VAF через native focus; убран `just_audio`; interruption → stop TX |
| `app/lib/services/webrtc_service.dart` | `voiceActivity` → duck; GSM interruption; cleanup → immediate resume |
| `app/android/.../MainActivity.kt` | `requestDuckFocus` / `abandonDuckFocus`; BT-aware speakerphone |
| `app/android/app/proguard-rules.pro` | **новый** — keep `org.webrtc.**` / `com.cloudwebrtc.**` |
| `app/android/app/build.gradle` | `minifyEnabled` + `shrinkResources` |
| `app/android/.../AndroidManifest.xml` | убран `requestLegacyExternalStorage` |
| `app/pubspec.yaml` | очистка зависимостей + `fake_async` для тестов |
| `app/test/music_ducking_controller_test.dart` | **новый** — 5 unit-тестов автомата |
| `scripts/build-apk.sh` | release → `--split-per-abi` (arm/arm64) |
| `docs/IDEAL_SPEC.md` | уточнено требование про duck при TX/RX |

### Удалённые зависимости

| Пакет | Почему |
|---|---|
| `just_audio` | Вариант А — мёртвый внутренний плеер, не в UI |
| `audioplayers` | Нуль вхождений, дубль аудио-стека |
| `cupertino_icons` | Нуль вхождений (только Material) |
| `crypto` | Нуль вхождений в Flutter-клиенте |
| `uuid` | Нуль вхождений |
| `shimmer` | Нуль вхождений |

## 8.3. Архитектурное решение по `just_audio`

**Вариант А** — полный отказ от внутреннего плеера.

Причина: фича не подключена ни к одному экрану; удаление снижает вес APK
(ExoPlayer-стек) и убирает ложную «паузу музыки» без реальной пользы.
Дакинг внешних приложений — только через Android AudioFocus
`AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` (локально на каждом устройстве).

## 8.4. Результаты unit-тестов

```
flutter test test/music_ducking_controller_test.dart
00:00 +5: All tests passed!
```

Покрыто (п. 6.1):
1. active → duck ×1  
2. silence 3 с → снова active → resume не вызван, duck не повторён  
3. silence 5.0 с → resume ×1  
4. `forceResumeNow` отменяет таймер, resume ×1  
5. 20 быстрых переключений → duck ×1, resume после 5 с тишины  

## 8.5. Результаты ручного тестирования

На этой машине **нет двух подключённых Android-устройств** (`adb devices`
пуст / недоступен в момент сборки). Код и unit-тесты готовы; прогон
матрицы 6.2 нужно выполнить на двух телефонах после установки:

```bash
adb install -r app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# или app-armeabi-v7a-release.apk для 32-bit
```

| # | Сценарий | Статус |
|---|---|---|
| 1 | A+B без музыки/наушников | **ожидает устройств** |
| 2 | Яндекс Музыка + PTT → duck → resume 5 с | **ожидает** |
| 3 | BT earbuds + SCO + music resume на BT | **ожидает** |
| 4 | Duck только от `partnerTalking` (без своего PTT) | **ожидает** (заложено в коде) |
| 5 | Независимый duck на A и B | **ожидает** (локальный AudioFocus) |
| 6 | Пауза 4 с — музыка не резюмится | **ожидает** (unit OK) |
| 7 | Пауза 6 с — резюм сам | **ожидает** (unit OK) |
| 8 | Обрыв Wi-Fi → резюм ≤5 с / сразу через cleanup | **ожидает** |
| 9 | «Выйти из комнаты» → немедленный резюм | **ожидает** (`forceResumeNow`) |
| 10 | GSM-звонок → stop TX; после — снова PTT вручную | **ожидает** |
| 11 | Release minify = поведение debug (нет R8-креша WebRTC) | **сборка OK**; рантайм — **ожидает** |

Ожидаемое поведение GSM (п. 10): при interruption `pause`/`unknown`
вызывается `stopTransmitting()`; после GSM пользователь **снова удерживает
PTT** (авто-возврат TX намеренно не делается).

## 8.6. Размер APK до / после

| Артефакт | Размер |
|---|---|
| **До** `app-release.apk` (fat, без minify) | **40 MB** |
| **После** `app-armeabi-v7a-release.apk` | **22.1 MB** (−45%) |
| **После** `app-arm64-v8a-release.apk` | **29.5 MB** (−26% vs fat) |

Вклад в уменьшение (по убыванию):
1. **ABI-split** — убраны лишние `.so` (главный выигрыш vs fat 40 MB)
2. Удаление `just_audio` + `audioplayers` (нативные медиа-стеки)
3. `minifyEnabled` + `shrinkResources` + icon tree-shake
4. Удаление мелких Dart-пакетов (`shimmer`, `uuid`, …)

Пути:
- `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `app/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`

## 8.7. Известные ограничения

1. **Android не даёт API «понизь громкость приложения X на 70%».**
   `TRANSIENT_MAY_DUCK` — единственный официальный механизм. Хорошие
   MediaSession-плееры (Spotify, YouTube Music) **приглушают**; часть
   мессенджеров/старых плееров **полностью встают на паузу** — это их
   выбор, не баг MotoTalk.
2. Если стороннее приложение **не** возобновляет playback после
   `AUDIOFOCUS_GAIN` — это ограничение того приложения.
3. Убийство процесса системой снимает AudioFocus само (системная гарантия);
   отдельный код не нужен.
4. Reconnect / peer left / выход из комнаты вызывают **немедленный**
   `forceResumeNow()` (не ждут 5 с) — намеренно, чтобы не оставлять
   «мёртвую тишину» после обрыва.
5. Ручной чек-лист 6.2 на двух телефонах ещё не прогнан в этой сессии —
   требуется установка собранных APK.
