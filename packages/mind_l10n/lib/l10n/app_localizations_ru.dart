// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get ok => 'ОК';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get error => 'Ошибка';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get account => 'Аккаунт';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get session => 'Сессия';

  @override
  String get name => 'Имя';

  @override
  String get language => 'Язык';

  @override
  String get theme => 'Тема';

  @override
  String get profile => 'Профиль';

  @override
  String get email => 'Email';

  @override
  String get login => 'Войти';

  @override
  String get logOut => 'Выйти';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeSystem => 'Системная';

  @override
  String get onboardingHello => 'Привет';

  @override
  String get onboardingWelcome => 'Добро пожаловать в Mind';

  @override
  String get loginCheckEmailTitle => 'Проверьте почту';

  @override
  String get loginCheckEmailDescription =>
      'Мы отправили вам одноразовую ссылку для входа. Откройте её на этом устройстве.';

  @override
  String get loginCodeHint => 'Или вставьте код здесь';

  @override
  String get loginSendCodeError => 'Не удалось отправить код';

  @override
  String get loginCodeInvalidError => 'Код недействителен или истёк';

  @override
  String get logOutDescription => 'Возвращайтесь скорее';

  @override
  String get breathPhaseInhale => 'Вдох';

  @override
  String get breathPhaseHold => 'Задержка';

  @override
  String get breathPhaseExhale => 'Выдох';

  @override
  String get breathPhaseRest => 'Отдых';

  @override
  String get breathSessionListLoadFailed => 'Не удалось загрузить сессии';

  @override
  String get breathSessionListPagingFailed => 'Не удалось загрузить ещё';

  @override
  String get breathSessionListSyncFailed =>
      'Не удалось синхронизировать сессии';

  @override
  String get breathSessionListMySessions => 'Мои сессии';

  @override
  String get breathSessionListStarredSessions => '★ Избранное';

  @override
  String get breathSessionListSharedSessions => 'Общие сессии';

  @override
  String get breathConstructorDeletedSuccess => 'Сессия удалена';

  @override
  String breathConstructorDeleteError(String error) {
    return 'Ошибка удаления: $error';
  }

  @override
  String get breathConstructorValidationError =>
      'Добавьте хотя бы одно упражнение';

  @override
  String get breathConstructorSavedSuccess => 'Сессия сохранена';

  @override
  String breathConstructorSaveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get breathConstructorDeleteConfirmTitle => 'Удалить сессию';

  @override
  String get breathConstructorDeleteConfirmDescription =>
      'Это действие нельзя отменить.';

  @override
  String get breathConstructorAddExercise => 'Добавить упражнение';

  @override
  String get breathConstructorTotal => 'Итого';

  @override
  String get breathConstructorRepeat => 'Повтор';

  @override
  String get homeTabBreath => 'Дыхание';

  @override
  String get homeTabMind => 'Mind';

  @override
  String get homeSuggestionsTitle => 'Рекомендации для вас';

  @override
  String get homeSuggestionsError => 'Не удалось загрузить рекомендации';

  @override
  String get homeSuggestionsMorning1 => 'Доброе утро';

  @override
  String get homeSuggestionsMorning2 => 'Утренняя энергия';

  @override
  String get homeSuggestionsMorning3 => 'Начните день правильно';

  @override
  String get homeSuggestionsMorning4 => 'Мягкое пробуждение';

  @override
  String get homeSuggestionsMidday1 => 'Перезарядка в середине дня';

  @override
  String get homeSuggestionsMidday2 => 'Восстановите концентрацию';

  @override
  String get homeSuggestionsMidday3 => 'Сделайте вдох';

  @override
  String get homeSuggestionsMidday4 => 'Момент для себя';

  @override
  String get homeSuggestionsEvening1 => 'Расслабьтесь';

  @override
  String get homeSuggestionsEvening2 => 'Вечерний покой';

  @override
  String get homeSuggestionsEvening3 => 'Подготовьтесь ко сну';

  @override
  String get homeSuggestionsEvening4 => 'Завершите день хорошо';

  @override
  String get level => 'Уровень';

  @override
  String get homeStatsTotalSessions => 'Всего сессий';

  @override
  String get homeStatsDuration => 'Время практики';

  @override
  String homeStatsDurationHours(String h, String m) {
    return '$h ч $m мин';
  }

  @override
  String homeStatsDurationMinutes(String m) {
    return '$m мин';
  }

  @override
  String get homeStatsCurrentStreak => 'Стрик';

  @override
  String get homeStatsBestStreak => 'Рекорд';

  @override
  String get homeStatsLastSession => 'Последняя сессия';

  @override
  String get mcpTitle => 'MCP';

  @override
  String get mcpIntegrations => 'Интеграции';

  @override
  String get mcpDescription =>
      'Токены доступа позволяют Claude Desktop работать с вашими упражнениями.';

  @override
  String get mcpCreateToken => 'Создать токен';

  @override
  String get mcpRevealTitle => 'Скопируйте токен';

  @override
  String get mcpRevealWarning =>
      'Он показывается один раз. Передайте его своему ИИ.';

  @override
  String get mcpCopy => 'Копировать';

  @override
  String get mcpDone => 'Готово';

  @override
  String get mcpRevokeConfirmTitle => 'Отозвать токен';

  @override
  String get mcpRevokeConfirmDescription =>
      'Этот токен перестанет работать немедленно.';

  @override
  String get mcpTokenName => 'Название';

  @override
  String get mcpNewToken => 'Новый токен';

  @override
  String mcpCreatedAt(String date) {
    return 'Создан $date';
  }
}
