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
  String get sessionExpired => 'Сессия истекла';

  @override
  String get sessionAbandoned => 'Сессия неожиданно завершилась';

  @override
  String get sessionMovedToAnotherDevice =>
      'Сессия перенесена на другое устройство';

  @override
  String get sessionStartFailed => 'Не удалось начать сессию';

  @override
  String get heartTickNoSourceTitle => 'Датчик пульса';

  @override
  String get heartTickNoSourceDescription =>
      'Чтобы дышать в ритм с сердцем, подключите датчик пульса.';

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
  String get logIn => 'Войти';

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
  String get loginTooManyAttemptsError =>
      'Слишком много попыток. Запросите новый код и попробуйте через несколько минут.';

  @override
  String get loginSendCodeCooldownError =>
      'Подождите немного перед повторным запросом кода.';

  @override
  String get loginNoConnectionError => 'Нет подключения к интернету';

  @override
  String get loginGoogleSignInError => 'Не удалось войти через Google';

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
  String get homeTabMeditation => 'Медитация';

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

  @override
  String get bciPairingTitle => 'Подключить нейрогарнитуру';

  @override
  String get bciPairingNearbyDevices => 'Устройства рядом';

  @override
  String get bciPairingSignalQuality => 'Качество сигнала';

  @override
  String get bciPairingAdjustHeadband =>
      'Поправьте гарнитуру для хорошего контакта на всех каналах.';

  @override
  String get bciPairingCalibration => 'Калибровка';

  @override
  String get bciPairingCalibrationInstruction =>
      'Во время калибровки нужно будет закрывать и открывать глаза, ориентируясь на звук.';

  @override
  String get bciPairingStartCalibration => 'Начать калибровку';

  @override
  String get bciPairingRetryCalibration => 'Повторить';

  @override
  String get bciPairingCalibrationFailedArtifacts =>
      'Калибровка не удалась: слишком много помех в сигнале. Сядьте спокойно, расслабьтесь и попробуйте снова.';

  @override
  String get bciPairingCalibrationFailedPeak =>
      'Калибровка не удалась: не удалось надёжно определить ваш индивидуальный ритм. Попробуйте ещё раз.';

  @override
  String get bciPairingCalibrationFailed =>
      'Калибровка не удалась. Попробуйте ещё раз.';

  @override
  String get bciPairingCloseEyes => 'Закройте глаза и расслабьтесь.';

  @override
  String get bciPairingOpenEyes => 'Откройте глаза и смотрите прямо.';

  @override
  String get bciPairingCalibrationComplete => 'Калибровка завершена';

  @override
  String get bciPairingDisconnect => 'Отключить';

  @override
  String get bciPairingDisconnectConfirm => 'Отключить устройство?';

  @override
  String get bciBluetoothPermissionTitle => 'Нужен доступ к Bluetooth';

  @override
  String get bciBluetoothPermissionMessage =>
      'Mind использует Bluetooth для подключения к гарнитуре Neiry. Разрешите доступ в Настройках.';

  @override
  String get bciOpenSettings => 'Открыть настройки';

  @override
  String get bciFocus => 'Фокус';

  @override
  String get bciCognitiveLoad => 'Нагрузка';

  @override
  String get bciRelaxation => 'Расслабление';

  @override
  String get bciCognitiveControl => 'Контроль';

  @override
  String get bciSelfControl => 'Самоконтроль';

  @override
  String get bciHeartRate => 'Пульс';

  @override
  String get bciBpm => 'уд/мин';

  @override
  String get bciEegBands => 'ЭЭГ полосы';

  @override
  String get bciEmotionalStates => 'Состояния';

  @override
  String get bciNotConnectedMessage => 'Устройство не подключено';

  @override
  String get bciConnectButton => 'Подключить';

  @override
  String get meditationPoseSectionTitle => 'Позы';

  @override
  String get meditationPoseEasy => 'Поза по-турецки';

  @override
  String get meditationPoseLotus => 'Лотос';

  @override
  String get meditationPoseHalfLotus => 'Полулотос';

  @override
  String get meditationPoseSeiza => 'На коленях (сэйдза)';

  @override
  String get meditationPoseChair => 'Сидя на стуле';

  @override
  String get meditationPoseSavasana => 'Лёжа (шавасана)';

  @override
  String get meditationNotePrompt =>
      'Запишите что чувствовали на протяжении сессии — что в начале, и как это изменилось к концу. Это поможет нейросети лучше понимать ваше тело.';

  @override
  String get keepAliveNotificationTitle => 'Сессия активна';

  @override
  String get keepAliveNotificationBody => 'Mind удерживает вашу сессию';
}
