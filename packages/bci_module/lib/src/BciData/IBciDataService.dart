import 'Models/BciDataState.dart';

sealed class BciDataEvent {
  const BciDataEvent();
}

final class BciDataStateUpdated extends BciDataEvent {
  final BciDataState state;

  const BciDataStateUpdated(this.state);
}

abstract class IBciDataService {
  Stream<BciDataEvent> get events;
}
