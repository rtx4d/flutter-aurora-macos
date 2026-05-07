# flutter-aurora for macOS

`flutter-aurora` собирает Flutter-проект в подписанный Aurora OS RPM на macOS через Docker.

Базовый сценарий:

```bash
cd /path/to/flutter_project
flutter-aurora build --arch arm
```

## Подключение CLI

```bash
export PATH="$PWD/bin:$PATH"
```

Постоянно можно добавить абсолютный путь к `flutter-aurora-macos/bin` в `~/.zshrc`:

```bash
export PATH="/path/to/flutter-aurora-macos/bin:$PATH"
```

Проверка:

```bash
flutter-aurora --help
```

## Docker image

Собрать или пересобрать image:

```bash
flutter-aurora image
```

По умолчанию используется:

- image: `auroraos-flutter:3.35.7`;
- Flutter Aurora: `3.35.7`;
- Aurora PSDK: `5.2.1.70`;
- buildx builder: `aurora-builder`.

Проверить окружение для текущего проекта:

```bash
cd /path/to/flutter_project
flutter-aurora doctor
```

Для сборки важны Flutter/Aurora toolchain и PSDK targets:

```text
AuroraOS-5.2.1.70-base-armv7hl
AuroraOS-5.2.1.70-base-aarch64
AuroraOS-5.2.1.70-base-x86_64
```

Warnings про IDE, подключенные устройства или network resources не блокируют локальную RPM-сборку.

## Подготовка проекта

Перейти в Flutter-проект:

```bash
cd /path/to/flutter_project
```

Если в проекте ещё нет `aurora/`, добавить Aurora platform files:

```bash
flutter-aurora init
```

Проверить `pubspec.yaml`. Для текущего Flutter Aurora нужен Dart, совместимый с `3.9.2`:

```yaml
name: my_app
description: "My app."
organization: ru.example
license: "Proprietary"
version: 1.0.0+1

environment:
  sdk: '>=3.9.0 <4.0.0'
```

`organization` должен совпадать с именами файлов в `aurora/rpm/` и `aurora/desktop/`.

Пример:

```text
organization: ru.example
aurora/rpm/ru.example.my_app.spec
aurora/desktop/ru.example.my_app.desktop
```

## Сборка RPM

Для устройств с `arm` userspace:

```bash
flutter-aurora build --arch arm
```

Результат:

```text
build/aurora/psdk_5.2.1.70/aurora-arm/release/RPMS/*.armv7hl.rpm
```

Для `aarch64` userspace:

```bash
flutter-aurora build --arch arm64
```

Результат:

```text
build/aurora/psdk_5.2.1.70/aurora-arm64/release/RPMS/*.aarch64.rpm
```

Добавить `aurora/` и сразу собрать:

```bash
flutter-aurora build --init-aurora --arch arm
```

Собрать без подписи:

```bash
flutter-aurora build --arch arm --no-sign
```

## Подпись

По умолчанию используются:

```text
.auroraos-regular-keys/regular_key.pem
.auroraos-regular-keys/regular_cert.pem
```

Подписать готовый RPM или директорию с RPM:

```bash
flutter-aurora sign build/aurora/psdk_5.2.1.70/aurora-arm/release/RPMS
```

Проверить подпись:

```bash
flutter-aurora verify build/aurora/psdk_5.2.1.70/aurora-arm/release/RPMS
```

Использовать другие ключи:

```bash
flutter-aurora build --arch arm --keys /path/to/keys
```

или:

```bash
AURORA_KEYS_DIR=/path/to/keys flutter-aurora build --arch arm
```

Если private key зашифрован:

```bash
KEY_PASSPHRASE='...' flutter-aurora build --arch arm
```

Важно: Aurora external signature проверяется через `rpmsign-external verify/dump`. Обычный `rpm -Kv` после такой подписи может показывать `Payload digest: BAD`; это не является корректной проверкой Aurora external signature.

## Что делает build

`flutter-aurora build`:

- запускает Flutter Aurora внутри Docker;
- получает Flutter bundle;
- копирует `aurora/` в `build/aurora/.../release`;
- применяет Docker/chroot-патчи только к копии внутри `build/`;
- запускает `mb2` в правильном chroot path;
- подписывает RPM через `rpmsign-external`, если подпись включена.

Исходники проекта не патчатся ради Docker-обходов. Исключение - `flutter-aurora init`, который создаёт платформенный каталог `aurora/`.

## Частые проблемы

### `No spec or yaml file found in '/home/mer/rpm/'`

Это известная проблема штатного `flutter build aurora` внутри Docker/chroot. `flutter-aurora build` обходит её на следующей стадии. Если после этого RPM появился, сообщение можно игнорировать.

### `The current Dart SDK version is 3.9.2`

Проект требует более новый Dart, чем есть в Flutter Aurora. Исправить constraint:

```yaml
environment:
  sdk: '>=3.9.0 <4.0.0'
```

Также нужно убрать syntax, которого нет в Dart `3.9`.

### `Mismatch between organization name`

Проверить `organization` в `pubspec.yaml` и имена файлов:

```text
aurora/rpm/<organization>.<app>.spec
aurora/desktop/<organization>.<app>.desktop
```

Лишние файлы с другим prefix нужно удалить.

### `wrong architecture: aarch64`

Проверить архитектуру userspace на устройстве:

```bash
rpm --eval "%{_arch}"
getconf LONG_BIT
```

Если RPM arch на устройстве `arm`, собирать так:

```bash
flutter-aurora build --arch arm
```

Если RPM arch `aarch64`, собирать так:

```bash
flutter-aurora build --arch arm64
```
