import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';

/// DTO для передачи данных между модулем конструктора и приложением.
/// Описывает намерение пользователя без привязки к хранению, ID и метаданным.
class BreathSessionConstructorDTO {
  final String description;
  final bool shared;
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionConstructorDTO({
    required this.description,
    required this.shared,
    required this.exercises,
  });

  /// Пустой DTO для создания новой сессии
  factory BreathSessionConstructorDTO.empty() {
    return const BreathSessionConstructorDTO(
      description: '',
      shared: false,
      exercises: [],
    );
  }

  BreathSessionConstructorDTO copyWith({
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionConstructorDTO(
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
    );
  }
}
