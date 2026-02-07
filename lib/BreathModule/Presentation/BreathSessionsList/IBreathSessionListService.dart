import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';

/// Сервис адаптации доменных моделей BreathSession в презентационные DTO
/// для списка сессий. Не знает про UI, не формирует строки, только структурные данные.
///
/// Все методы асинхронные и завершаются после выполнения запроса.
/// Данные приходят через поток observeChanges(), а не через return.
abstract class IBreathSessionListService {
  /// Подписка на изменения данных.
  /// Возвращает поток DTO, который обновляется при любых изменениях в источнике данных.
  /// При подписке сразу эмитит текущее состояние (если данные есть).
  Stream<List<BreathSessionListItemDTO>> observeChanges();

  /// Загружает страницу сессий.
  ///
  /// [page] - номер страницы (начиная с 0)
  /// [pageSize] - количество элементов на странице
  Future<void> fetchPage(int page, int pageSize);

  /// Полная синхронизация сессий (для pull-to-refresh).
  /// Метод завершается после выполнения запроса.
  /// Данные придут через observeChanges().
  ///
  /// [pageSize] - количество элементов на странице
  Future<void> syncSessions(int pageSize);
}
