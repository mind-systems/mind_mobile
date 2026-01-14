import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/TickSource.dart';

/// DTO для передачи данных между модулем конструктора и приложением.
/// Описывает намерение пользователя без привязки к хранению, ID и метаданным.
class BreathSessionDTO {
  final String description;
  final bool shared;
  final TickSource tickSource;
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionDTO({
    required this.description,
    required this.shared,
    required this.tickSource,
    required this.exercises,
  });

  /// Пустой DTO для создания новой сессии
  factory BreathSessionDTO.empty() {
    return const BreathSessionDTO(
      description: '',
      shared: false,
      tickSource: TickSource.timer,
      exercises: [],
    );
  }

  BreathSessionDTO copyWith({
    String? description,
    bool? shared,
    TickSource? tickSource,
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionDTO(
      description: description ?? this.description,
      shared: shared ?? this.shared,
      tickSource: tickSource ?? this.tickSource,
      exercises: exercises ?? this.exercises,
    );
  }
}
