import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';
import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/StepType.dart';
import 'package:mind/Core/Api/Models/SaveBreathSessionRequest.dart';
import 'package:mind/Core/Api/Models/StarSessionRequest.dart';
import 'package:mind/Core/Grpc/generated/breath_sessions.pb.dart' as proto;
import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart' show BreathSessionServiceClient;

class BreathSessionApi implements IBreathSessionApi {
  final BreathSessionServiceClient _service;

  BreathSessionApi(this._service);

  @override
  Future<BreathSession> create(SaveBreathSessionRequest request) async {
    final response = await _service.createSession(proto.CreateSessionRequest(
      description: request.description,
      exercises: _mapExercisesToProto(request.exercises),
      shared: request.shared,
    ));
    return _mapSession(response);
  }

  @override
  Future<BreathSession> update(String id, SaveBreathSessionRequest request) async {
    final response = await _service.replaceSession(proto.ReplaceSessionRequest(
      id: id,
      description: request.description,
      exercises: _mapExercisesToProto(request.exercises),
      shared: request.shared,
    ));
    return _mapSession(response);
  }

  @override
  Future<void> delete(String sessionId) async {
    await _service.deleteSession(proto.DeleteSessionRequest(id: sessionId));
  }

  @override
  Future<BreathSession> fetchById(String id) async {
    final response = await _service.getSession(proto.GetSessionRequest(id: id));
    return _mapSessionWithStarred(response);
  }

  @override
  Future<BreathSessionsListResponse> fetchPage(String? cursor, int pageSize) async {
    final request = cursor != null
        ? proto.ListSessionsRequest(cursor: cursor, pageSize: pageSize)
        : proto.ListSessionsRequest(pageSize: pageSize);
    final response = await _service.listSessions(request);
    final entries = response.items.map((item) => BreathSessionListEntry(
      session: _mapSessionWithStarred(item.session),
      section: _mapSection(item.section),
    )).toList();
    return BreathSessionsListResponse(
      entries: entries,
      nextCursor: response.hasNextCursor() ? response.nextCursor : null,
    );
  }

  @override
  Future<void> starSession(StarSessionRequest request) async {
    await _service.updateSessionSettings(proto.UpdateSessionSettingsRequest(id: request.id, starred: request.starred));
  }

  BreathListSection _mapSection(proto.SessionSection section) {
    switch (section) {
      case proto.SessionSection.STARRED:
        return BreathListSection.starred;
      case proto.SessionSection.MINE:
        return BreathListSection.mine;
      case proto.SessionSection.SHARED:
        return BreathListSection.shared;
      default:
        return BreathListSection.shared;
    }
  }

  BreathSession _mapSession(proto.BreathSessionDto dto, {bool isStarred = false}) {
    return BreathSession(
      id: dto.id,
      userId: dto.userId,
      description: dto.description,
      shared: dto.shared,
      isStarred: isStarred,
      complexity: dto.complexity,
      createdAt: DateTime.parse(dto.createdAt),
      exercises: dto.exercises.map(_mapExercise).toList(),
    );
  }

  BreathSession _mapSessionWithStarred(proto.BreathSessionWithStarredDto dto) {
    return _mapSession(dto.session, isStarred: dto.isStarred);
  }

  ExerciseSet _mapExercise(proto.ExerciseDto dto) {
    return ExerciseSet(
      steps: dto.steps.map(_mapStep).toList(),
      restDuration: dto.restDuration.round(),
      repeatCount: dto.repeatCount,
    );
  }

  ExerciseStep _mapStep(proto.StepDto dto) {
    return ExerciseStep(
      type: _mapStepType(dto.type),
      duration: dto.duration.round(),
    );
  }

  StepType _mapStepType(proto.StepType type) {
    if (type == proto.StepType.EXHALE) return StepType.exhale;
    if (type == proto.StepType.HOLD) return StepType.hold;
    return StepType.inhale;
  }

  proto.StepType _mapStepTypeToProto(StepType type) => switch (type) {
    StepType.inhale => proto.StepType.INHALE,
    StepType.exhale => proto.StepType.EXHALE,
    StepType.hold => proto.StepType.HOLD,
  };

  List<proto.ExerciseDto> _mapExercisesToProto(List<ExerciseSet> exercises) {
    return exercises.map((exercise) => proto.ExerciseDto(
      steps: exercise.steps.map((step) => proto.StepDto(
        type: _mapStepTypeToProto(step.type),
        duration: step.duration.toDouble(),
      )).toList(),
      restDuration: exercise.restDuration.toDouble(),
      repeatCount: exercise.repeatCount,
    )).toList();
  }
}
