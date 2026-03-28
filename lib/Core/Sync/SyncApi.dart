import 'package:fixnum/fixnum.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/StepType.dart';
import 'package:mind/Core/Api/ISyncApi.dart';
import 'package:mind/Core/Api/Models/BatchSessionsResponse.dart';
import 'package:mind/Core/Api/Models/ChangeEvent.dart';
import 'package:mind/Core/Api/Models/SyncResponse.dart';
import 'package:mind/Core/Grpc/generated/breath_sessions.pb.dart' as bsProto;
import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart' show BreathSessionServiceClient;
import 'package:mind/Core/Grpc/generated/sync.pb.dart' as syncProto;
import 'package:mind/Core/Grpc/generated/sync.pbgrpc.dart' show SyncServiceClient;

class SyncApi implements ISyncApi {
  final SyncServiceClient _syncService;
  final BreathSessionServiceClient _breathSessionService;

  SyncApi(this._syncService, this._breathSessionService);

  @override
  Future<SyncResponse> fetchChanges(int lastEventId) async {
    final response = await _syncService.getChanges(syncProto.GetChangesRequest(after: Int64(lastEventId)));
    switch (response.whichResult()) {
      case syncProto.GetChangesResponse_Result.fullResync:
        return SyncResponse(events: [], fullResync: true);
      case syncProto.GetChangesResponse_Result.payload:
        final events = response.payload.events.map(_mapEvent).toList();
        return SyncResponse(events: events, fullResync: false);
      case syncProto.GetChangesResponse_Result.notSet:
        return SyncResponse(events: [], fullResync: false);
    }
  }

  @override
  Future<BatchSessionsResponse> fetchSessionsBatch(List<String> ids) async {
    final response = await _breathSessionService.batchGetSessions(bsProto.BatchGetSessionsRequest(ids: ids));
    return BatchSessionsResponse(data: response.sessions.map(_mapSessionWithStarred).toList());
  }

  ChangeEvent _mapEvent(syncProto.SyncEventDto dto) {
    return ChangeEvent(
      id: dto.id.toInt(),
      entity: dto.entity,
      refId: dto.refId,
      action: dto.action,
    );
  }

  BreathSession _mapSession(bsProto.BreathSessionDto dto, {bool isStarred = false}) {
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

  BreathSession _mapSessionWithStarred(bsProto.BreathSessionWithStarredDto dto) {
    return _mapSession(dto.session, isStarred: dto.isStarred);
  }

  ExerciseSet _mapExercise(bsProto.ExerciseDto dto) {
    return ExerciseSet(
      steps: dto.steps.map(_mapStep).toList(),
      restDuration: dto.restDuration.round(),
      repeatCount: dto.repeatCount,
    );
  }

  ExerciseStep _mapStep(bsProto.StepDto dto) {
    return ExerciseStep(
      type: _mapStepType(dto.type),
      duration: dto.duration.round(),
    );
  }

  StepType _mapStepType(bsProto.StepType type) {
    if (type == bsProto.StepType.EXHALE) return StepType.exhale;
    if (type == bsProto.StepType.HOLD) return StepType.hold;
    return StepType.inhale;
  }
}
