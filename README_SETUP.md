# 🚀 Настройка окружений (dev/prod)

## Быстрый старт

### 1. Создайте Environment.dart

```bash
cp lib/Core/Environment.example.dart lib/Core/Environment.dart
```

Отредактируйте `lib/Core/Environment.dart` и укажите ваши API URLs:
- Dev: ваш dev API URL
- Prod: ваш production API URL

### 2. Настройка Firebase конфигов

У вас должны быть два Firebase проекта:
- `mind-mobile-dev` - для разработки
- `mind-mobile` - для production

Эти файлы нужно создать локально. Они **не коммитятся в git** (защищены .gitignore):

```
lib/firebase_options_dev.dart
lib/firebase_options_prod.dart
android/app/google-services-dev.json
android/app/google-services-prod.json
ios/Runner/GoogleService-Info-dev.plist
ios/Runner/GoogleService-Info-prod.plist
```

#### Обновление конфигов через FlutterFire CLI

Когда создадите реальные Firebase проекты, обновите конфиги:

```bash
# Dev окружение
flutterfire config \
  --project=mind-mobile-dev \
  --out=lib/firebase_options_dev.dart \
  --ios-bundle-id=io.mind.dev \
  --android-app-id=io.mind.dev

# Prod окружение
flutterfire config \
  --project=mind-mobile \
  --out=lib/firebase_options_prod.dart \
  --ios-bundle-id=io.mind \
  --android-app-id=io.mind
```

### 3. Создание Keystores и настройка Firebase SHA

#### Создание keystores

```bash
cd android

# Dev keystore
keytool -genkey -v -keystore dev.keystore -alias dev -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass devpassword123 -keypass devpassword123 \
  -dname "CN=Mind Dev, OU=Development, O=Mind"

# Release keystore (используйте надёжный пароль!)
keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass YOUR_SECURE_PASSWORD -keypass YOUR_SECURE_PASSWORD \
  -dname "CN=Mind, OU=Production, O=Mind"
```

#### Получение SHA-1 и SHA-256

```bash
# Dev keystore
keytool -list -v -keystore dev.keystore -alias dev -storepass devpassword123 | grep SHA

# Release keystore
keytool -list -v -keystore release.keystore -alias release -storepass YOUR_PASSWORD | grep SHA
```

#### Добавление SHA в Firebase Console

1. Откройте [Firebase Console](https://console.firebase.google.com/)
2. Выберите проект `mind-mobile-dev`
3. Project Settings → Your apps → Android app (`io.mind.dev`)
4. Раздел **"SHA certificate fingerprints"** → **"Add fingerprint"**
5. Добавьте **SHA-1** и **SHA-256** из dev.keystore
6. Скачайте обновлённый `google-services.json` → переименуйте в `google-services-dev.json`

Повторите для проекта `mind-mobile` (prod) с SHA из release.keystore.

#### Создание keystore.properties

```bash
cd android
cat > keystore.properties << 'EOF'
# Dev keystore
devStoreFile=dev.keystore
devStorePassword=devpassword123
devKeyAlias=dev
devKeyPassword=devpassword123

# Prod/Release keystore
releaseStoreFile=release.keystore
releaseStorePassword=YOUR_SECURE_PASSWORD
releaseKeyAlias=release
releaseKeyPassword=YOUR_SECURE_PASSWORD
EOF
```

⚠️ Замените `YOUR_SECURE_PASSWORD` на реальный пароль!

### 4. iOS Setup (когда будет нужен)

В Xcode создайте два schemes:
- **Dev** → bundle ID `io.mind.dev`, использует `GoogleService-Info-dev.plist`
- **Prod** → bundle ID `io.mind`, использует `GoogleService-Info-prod.plist`

### 5. Запуск приложения

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart

# Release builds
flutter build apk --flavor dev -t lib/main_dev.dart --release
flutter build apk --flavor prod -t lib/main_prod.dart --release
```

---

## 🔐 Безопасность

Все секреты и конфиги **НЕ коммитятся** в репозиторий благодаря `.gitignore`.

Файлы защищены:
- ✅ `lib/Core/Environment.dart` (API URLs)
- ✅ `lib/firebase_options_*.dart` (Firebase Dart configs)
- ✅ `android/app/google-services.json` (автогенерируемый)
- ✅ `android/app/google-services-*.json` (Firebase Android configs)
- ✅ `ios/Runner/GoogleService-Info.plist` (автогенерируемый)
- ✅ `ios/Runner/GoogleService-Info-*.plist` (Firebase iOS configs)
- ✅ `*.keystore`, `*.jks` (Android signing keys)
- ✅ `android/keystore.properties` (keystore passwords)

---

## 📦 Окружения

| Параметр             | Dev                   | Prod              |
| -------------------- | --------------------- | ----------------- |
| **API Base URL**     | Ваш dev сервер        | Ваш prod API      |
| **Firebase Project** | mind-mobile-dev       | mind-mobile       |
| **Application ID**   | io.mind.dev           | io.mind           |
| **Bundle ID**        | io.mind.dev           | io.mind           |
| **App Name**         | Mind Dev              | Mind              |
| **Keystore**         | dev.keystore          | release.keystore  |

---

## 🤖 CI/CD Setup

### GitHub Actions пример

```yaml
name: Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Create Environment.dart
        run: |
          cat > lib/Core/Environment.dart << 'EOF'
          class Environment {
            final String name;
            final String apiBaseUrl;
            final bool isProduction;

            Environment._({required this.name, required this.apiBaseUrl, required this.isProduction});
            static late Environment _instance;
            static Environment get instance => _instance;

            static void initDev() {
              _instance = Environment._(
                name: 'Development',
                apiBaseUrl: '${{ secrets.DEV_API_URL }}',
                isProduction: false,
              );
            }

            static void initProd() {
              _instance = Environment._(
                name: 'Production',
                apiBaseUrl: '${{ secrets.PROD_API_URL }}',
                isProduction: true,
              );
            }
          }
          EOF

      - name: Decode Firebase configs
        run: |
          echo '${{ secrets.FIREBASE_OPTIONS_DEV }}' > lib/firebase_options_dev.dart
          echo '${{ secrets.FIREBASE_OPTIONS_PROD }}' > lib/firebase_options_prod.dart
          echo '${{ secrets.GOOGLE_SERVICES_DEV_BASE64 }}' | base64 -d > android/app/google-services-dev.json
          echo '${{ secrets.GOOGLE_SERVICES_PROD_BASE64 }}' | base64 -d > android/app/google-services-prod.json

      - name: Decode keystores
        run: |
          echo '${{ secrets.DEV_KEYSTORE_BASE64 }}' | base64 -d > android/dev.keystore
          echo '${{ secrets.RELEASE_KEYSTORE_BASE64 }}' | base64 -d > android/release.keystore

      - name: Create keystore.properties
        run: |
          cat > android/keystore.properties << EOF
          devStoreFile=dev.keystore
          devStorePassword=${{ secrets.DEV_KEYSTORE_PASSWORD }}
          devKeyAlias=dev
          devKeyPassword=${{ secrets.DEV_KEYSTORE_PASSWORD }}
          releaseStoreFile=release.keystore
          releaseStorePassword=${{ secrets.RELEASE_KEYSTORE_PASSWORD }}
          releaseKeyAlias=release
          releaseKeyPassword=${{ secrets.RELEASE_KEYSTORE_PASSWORD }}
          EOF

      - name: Build Dev APK
        run: flutter build apk --flavor dev -t lib/main_dev.dart --release

      - name: Build Prod APK
        run: flutter build apk --flavor prod -t lib/main_prod.dart --release
```

### Секреты для CI

Добавьте в GitHub Secrets:

```bash
# API URLs
DEV_API_URL=http://dev.yourdomain.com
PROD_API_URL=https://api.yourdomain.com

# Firebase configs (base64)
FIREBASE_OPTIONS_DEV=$(cat lib/firebase_options_dev.dart | base64)
FIREBASE_OPTIONS_PROD=$(cat lib/firebase_options_prod.dart | base64)
GOOGLE_SERVICES_DEV_BASE64=$(base64 -i android/app/google-services-dev.json)
GOOGLE_SERVICES_PROD_BASE64=$(base64 -i android/app/google-services-prod.json)

# Keystores (base64)
DEV_KEYSTORE_BASE64=$(base64 -i android/dev.keystore)
RELEASE_KEYSTORE_BASE64=$(base64 -i android/release.keystore)

# Пароли
DEV_KEYSTORE_PASSWORD=devpassword123
RELEASE_KEYSTORE_PASSWORD=your_secure_password
```

---

## 📝 TODO

- [ ] Настроить iOS schemes (Dev/Prod)
- [ ] Добавить разные иконки для dev/prod
- [ ] Настроить iOS GoogleService-Info.plist автокопирование
- [ ] Добавить Fastlane для автоматической публикации
