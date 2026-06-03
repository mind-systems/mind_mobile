enum MeditationSessionStatus { idle, active }

class MeditationSessionState {
  final MeditationSessionStatus status;
  final String poseId;
  const MeditationSessionState({required this.status, required this.poseId});
  const MeditationSessionState.initial({required String poseId})
      : status = MeditationSessionStatus.idle,
        poseId = poseId;
  MeditationSessionState copyWith({MeditationSessionStatus? status, String? poseId}) =>
      MeditationSessionState(
        status: status ?? this.status,
        poseId: poseId ?? this.poseId,
      );
}
