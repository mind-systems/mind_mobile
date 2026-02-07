import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';
import 'package:rxdart/rxdart.dart';

class BreathSessionListService implements IBreathSessionListService {
  final BreathSessionNotifier provider;
  final BehaviorSubject<List<BreathSessionListItemDTO>> _subject;

  BreathSessionListService({required this.provider})
      : _subject = BehaviorSubject<List<BreathSessionListItemDTO>>() {
    _subject.add(_transformSessions(provider.currentState));

    provider.stream.listen((sessions) {
      _subject.add(_transformSessions(sessions));
    });
  }

  @override
  Stream<List<BreathSessionListItemDTO>> observeChanges() => _subject.stream;

  @override
  Future<void> fetchPage(int page, int pageSize) async {
    await provider.load(page, pageSize);
  }

  @override
  Future<void> syncSessions(int pageSize) async {
    await provider.load(0, pageSize);
  }

  List<BreathSessionListItemDTO> _transformSessions(List<BreathSession> sessions) {
    return sessions.map(_sessionToDTO).toList();
  }

  void dispose() {
    _subject.close();
  }

  BreathSessionListItemDTO _sessionToDTO(BreathSession session) {
    final patterns = session.exercises.map(_exerciseSetToPattern).toList();
    final totalDuration = _calculateTotalDuration(session.exercises);

    return BreathSessionListItemDTO(
      id: session.id,
      description: session.description,
      patterns: patterns,
      totalDurationSeconds: totalDuration,
    );
  }

  BreathPatternDTO _exerciseSetToPattern(ExerciseSet exerciseSet) {
    final shape = _mapShape(exerciseSet.shape);
    final durations = exerciseSet.steps.map((step) => step.duration).toList();

    return BreathPatternDTO(
      shape: shape,
      durations: durations,
      repeatCount: exerciseSet.repeatCount,
    );
  }

  BreathPatternShape _mapShape(SetShape? shape) {
    switch (shape) {
      case SetShape.circle:
        return BreathPatternShape.circle;
      case SetShape.square:
        return BreathPatternShape.square;
      case SetShape.triangleUp:
        return BreathPatternShape.triangleUp;
      case SetShape.triangleDown:
        return BreathPatternShape.triangleDown;
      case null:
        return BreathPatternShape.circle;
    }
  }

  int _calculateTotalDuration(List<ExerciseSet> exercises) {
    return exercises.fold(0, (total, exercise) => total + exercise.totalDuration);
  }
}
