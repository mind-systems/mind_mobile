 class ActiveFieldKey {
  final String exerciseId;
  final String fieldName;

  const ActiveFieldKey({required this.exerciseId, required this.fieldName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveFieldKey &&
          exerciseId == other.exerciseId &&
          fieldName == other.fieldName;

  @override
  int get hashCode => Object.hash(exerciseId, fieldName);
}
