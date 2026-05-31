enum MeditationSessionStatus { idle, active }

class MeditationSessionState {
  final MeditationSessionStatus status;
  const MeditationSessionState({required this.status});
  const MeditationSessionState.initial() : status = MeditationSessionStatus.idle;
  MeditationSessionState copyWith({MeditationSessionStatus? status}) =>
      MeditationSessionState(status: status ?? this.status);
}
