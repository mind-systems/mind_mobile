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
