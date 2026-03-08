# 🚀 Настройка окружений (dev/prod)

## Быстрый старт

### 1. Создайте Environment.dart

```bash
cp lib/Core/Environment.example.dart lib/Core/Environment.dart
```

Отредактируйте `lib/Core/Environment.dart` и укажите:
- API URLs (dev / prod)
- Google OAuth client IDs (`googleIosClientId`, `googleAndroidClientId`, `googleServerClientId`)

Client IDs берутся из [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.

### 2. Создание Keystores

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

SHA-отпечатки нужно добавить в Google Cloud Console → OAuth 2.0 Client IDs → Android client.

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

### 3. iOS Setup (когда будет нужен)

В Xcode создайте два schemes:
- **Dev** → bundle ID `io.mind.dev`
- **Prod** → bundle ID `io.mind`

URL scheme для Google Sign-In (reversed client ID) уже прописан в `Info.plist`.

### 4. Запуск приложения

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
- ✅ `lib/Core/Environment.dart` (API URLs, Google client IDs)
- ✅ `*.keystore`, `*.jks` (Android signing keys)
- ✅ `android/keystore.properties` (keystore passwords)

---

## 📦 Окружения

| Параметр             | Dev                   | Prod              |
| -------------------- | --------------------- | ----------------- |
| **API Base URL**     | Ваш dev сервер        | Ваш prod API      |
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
            final String googleIosClientId;
            final String googleAndroidClientId;
            final String googleServerClientId;

            Environment._({
              required this.name,
              required this.apiBaseUrl,
              required this.isProduction,
              required this.googleIosClientId,
              required this.googleAndroidClientId,
              required this.googleServerClientId,
            });
            static late Environment _instance;
            static Environment get instance => _instance;

            static void initDev() {
              _instance = Environment._(
                name: 'Development',
                apiBaseUrl: '${{ secrets.DEV_API_URL }}',
                isProduction: false,
                googleIosClientId: '${{ secrets.GOOGLE_IOS_CLIENT_ID_DEV }}',
                googleAndroidClientId: '${{ secrets.GOOGLE_ANDROID_CLIENT_ID_DEV }}',
                googleServerClientId: '${{ secrets.GOOGLE_SERVER_CLIENT_ID_DEV }}',
              );
            }

            static void initProd() {
              _instance = Environment._(
                name: 'Production',
                apiBaseUrl: '${{ secrets.PROD_API_URL }}',
                isProduction: true,
                googleIosClientId: '${{ secrets.GOOGLE_IOS_CLIENT_ID_PROD }}',
                googleAndroidClientId: '${{ secrets.GOOGLE_ANDROID_CLIENT_ID_PROD }}',
                googleServerClientId: '${{ secrets.GOOGLE_SERVER_CLIENT_ID_PROD }}',
              );
            }
          }
          EOF

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

# Google OAuth Client IDs
GOOGLE_IOS_CLIENT_ID_DEV=...
GOOGLE_ANDROID_CLIENT_ID_DEV=...
GOOGLE_SERVER_CLIENT_ID_DEV=...
GOOGLE_IOS_CLIENT_ID_PROD=...
GOOGLE_ANDROID_CLIENT_ID_PROD=...
GOOGLE_SERVER_CLIENT_ID_PROD=...

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
- [ ] Добавить Fastlane для автоматической публикации
