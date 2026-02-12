import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';

/// DTO для передачи данных между модулем конструктора и приложением.
/// Описывает намерение пользователя без привязки к хранению, ID и метаданным.
class BreathSessionDTO {
  final String description;
  final bool shared;
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionDTO({
    required this.description,
    required this.shared,
    required this.exercises,
  });

  /// Пустой DTO для создания новой сессии
  factory BreathSessionDTO.empty() {
    return const BreathSessionDTO(
      description: '',
      shared: false,
      exercises: [],
    );
  }

  BreathSessionDTO copyWith({
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionDTO(
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
    );
  }
}
