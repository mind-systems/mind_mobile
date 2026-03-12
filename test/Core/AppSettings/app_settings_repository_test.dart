import 'package:flutter_test/flutter_test.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/IAppSettingsStorage.dart';

// ---------------------------------------------------------------------------
// Fake storage
// ---------------------------------------------------------------------------

class FakeAppSettingsStorage implements IAppSettingsStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppSettingsRepository _repo(FakeAppSettingsStorage storage) =>
    AppSettingsRepository(storage);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AppSettingsRepository.init()', () {
    test('detects and saves locale when no language stored', () async {
      final storage = FakeAppSettingsStorage();
      final repo = _repo(storage);

      // Simulate Platform.localeName = 'ru_RU' by pre-seeding — actually we
      // call init() and the real Platform.localeName will be used in CI.
      // Instead, test the side-effect: after init, a language is always stored.
      await repo.init();

      final stored = await storage.getString('app_language');
      expect(stored, isNotNull);
      expect(AppSettingsRepository.supportedLocales, contains(stored));
    });

    test('does NOT overwrite existing language preference', () async {
      final storage = FakeAppSettingsStorage();
      await storage.setString('app_language', 'ru');
      final repo = _repo(storage);

      await repo.init();

      expect(await storage.getString('app_language'), equals('ru'));
    });
  });

  group('AppSettingsRepository.getTheme()', () {
    test('defaults to "system" when nothing stored', () async {
      final repo = _repo(FakeAppSettingsStorage());
      expect(await repo.getTheme(), 'system');
    });

    test('returns "dark" when "dark" stored', () async {
      final storage = FakeAppSettingsStorage();
      await storage.setString('app_theme', 'dark');
      expect(await _repo(storage).getTheme(), 'dark');
    });

    test('returns "light" when "light" stored', () async {
      final storage = FakeAppSettingsStorage();
      await storage.setString('app_theme', 'light');
      expect(await _repo(storage).getTheme(), 'light');
    });

    test('returns stored value for unknown key', () async {
      final storage = FakeAppSettingsStorage();
      await storage.setString('app_theme', 'unknown');
      expect(await _repo(storage).getTheme(), 'unknown');
    });
  });

  group('AppSettingsRepository.setTheme()', () {
    test('persists "light"', () async {
      final storage = FakeAppSettingsStorage();
      await _repo(storage).setTheme('light');
      expect(await storage.getString('app_theme'), 'light');
    });

    test('persists "dark"', () async {
      final storage = FakeAppSettingsStorage();
      await _repo(storage).setTheme('dark');
      expect(await storage.getString('app_theme'), 'dark');
    });

    test('persists "system"', () async {
      final storage = FakeAppSettingsStorage();
      await _repo(storage).setTheme('system');
      expect(await storage.getString('app_theme'), 'system');
    });
  });

  group('AppSettingsRepository.getLanguage()', () {
    test('defaults to "en" when nothing stored', () async {
      expect(await _repo(FakeAppSettingsStorage()).getLanguage(), 'en');
    });

    test('returns stored value', () async {
      final storage = FakeAppSettingsStorage();
      await storage.setString('app_language', 'ru');
      expect(await _repo(storage).getLanguage(), 'ru');
    });
  });

  group('AppSettingsRepository.setLanguage()', () {
    test('persists value', () async {
      final storage = FakeAppSettingsStorage();
      await _repo(storage).setLanguage('ru');
      expect(await storage.getString('app_language'), 'ru');
    });
  });

  group('AppSettingsRepository.resolveLocale()', () {
    late AppSettingsRepository repo;

    setUp(() => repo = _repo(FakeAppSettingsStorage()));

    test('exact match "en"', () => expect(repo.resolveLocale('en'), 'en'));
    test('exact match "ru"', () => expect(repo.resolveLocale('ru'), 'ru'));

    test('prefix match "ru-RU"', () => expect(repo.resolveLocale('ru-RU'), 'ru'));
    test('prefix match "ru_RU" (underscore separator)', () => expect(repo.resolveLocale('ru_RU'), 'ru'));
    test('prefix match "en-US"', () => expect(repo.resolveLocale('en-US'), 'en'));

    test('falls back to "en" for unsupported locale', () =>
        expect(repo.resolveLocale('fr-FR'), 'en'));
    test('falls back to "en" for empty string', () =>
        expect(repo.resolveLocale(''), 'en'));
  });
}
