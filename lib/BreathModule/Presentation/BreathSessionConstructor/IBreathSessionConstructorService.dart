import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorDTO.dart';

/// Интерфейс сервиса для работы с конструктором сессий.
/// Модуль конструктора не знает о деталях хранения, userId, sessionId.
/// Сервис инкапсулирует всю бизнес-логику приложения.
abstract class IBreathSessionConstructorService {
  /// Получить начальное состояние для конструктора.
  /// Возвращает пустой DTO для создания новой сессии
  /// или заполненный DTO для редактирования существующей.
  ///
  /// Метод синхронный — данные должны быть готовы до показа UI.
  BreathSessionConstructorDTO getInitialState();

  /// Получить начальный режим конструктора.
  /// Возвращает режим создания или редактирования
  /// в зависимости от пришедшего юзер айди в сессии
  ConstructorMode getInitialConstructorMode();

  /// Сохранить собранную сессию.
  /// Сервис самостоятельно решает:
  /// - создать новую запись или обновить существующую
  /// - сгенерировать ID при необходимости
  /// - привязать к текущему userId
  /// - выполнить валидацию на уровне приложения
  /// - синхронизировать с сервером (если нужно)
  Future<void> save(BreathSessionConstructorDTO dto);

  /// Удалить текущую сессию.
  /// Вызывается только в режиме редактирования.
  /// Если сессии нет (режим создания) — метод ничего не делает.
  Future<void> delete();
}
