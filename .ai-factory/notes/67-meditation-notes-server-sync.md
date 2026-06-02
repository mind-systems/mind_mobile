# Meditation Notes — Server Sync

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `MeditationModuleStateChannel` never subscribed to `channel.state`, so `moduleSessionId` (returned by the server when the session starts) was silently discarded. Adding `_channelSub` mirrors the existing pattern in `BreathModuleStateChannel` (lines 35–39).
- The `moduleSessionId` is NOT nulled on session re-arm — it must survive until after the note screen is dismissed, because the coordinator reads it after `active → idle` fires.
- `getSessionId: () => stateChannel.moduleSessionId` is a lazy closure capturing the `late final stateChannel` — the same pattern as the existing `onDispose: () => stateChannel.dispose()` in `MeditationModule.buildSession()`.

## Details

### Step 1 — Copy proto and regenerate stubs

Copy `mind_api/proto/meditation_notes.proto` into `mind_mobile/proto/`. Run:
```bash
./scripts/gen_proto.sh
```
Verify `MeditationNotesServiceClient` appears in `lib/Core/Grpc/generated/`. No application code changes in this step.

**Proto contract (from `meditation_notes.proto`):**
```proto
message CreateNoteRequest {
  string session_id = 1;
  string pose_name  = 2;
  string note_text  = 3;
}

service MeditationNotesService {
  rpc CreateNote(CreateNoteRequest) returns (MeditationNote);
  rpc UpdateNote(UpdateNoteRequest) returns (MeditationNote);  // future — not wired
  rpc ListNotes(ListNotesRequest)   returns (ListNotesResponse);
}
```
Timestamps in `MeditationNote` are ISO-8601 strings (`string created_at / updated_at`). `user_id` absent from response. `ALREADY_EXISTS` returned if `CreateNote` called twice for the same `session_id` — treat as non-fatal in `.catchError`.

---

### Step 2 — Capture `moduleSessionId` in `MeditationModuleStateChannel`

**File:** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`

Add `_channelSub` and `_moduleSessionId`, mirroring `BreathModuleStateChannel`:

```dart
import 'package:mind/Core/Grpc/ModuleState.dart';

class MeditationModuleStateChannel {
  final ModuleStateChannel _channel;
  final String _poseId;
  bool _started = false;
  bool _ended = false;
  MeditationSessionStatus? _previousStatus;
  String? _moduleSessionId;                    // NEW
  late final StreamSubscription<MeditationSessionState> _stateSub;
  late final StreamSubscription<ModuleState> _channelSub;  // NEW

  MeditationModuleStateChannel({
    required ModuleStateChannel channel,
    required Stream<MeditationSessionState> stateStream,
    required String poseId,
  })  : _channel = channel,
        _poseId = poseId {
    _stateSub = stateStream.listen(_onState);
    _channelSub = channel.state.listen((moduleState) {   // NEW
      _moduleSessionId = moduleState.moduleSessionId;
    });
  }

  String? get moduleSessionId => _moduleSessionId;        // NEW

  void _onState(MeditationSessionState state) {
    final status = state.status;
    if (status == _previousStatus) return;

    if (status == MeditationSessionStatus.active && !_started) {
      _channel.start(type: ActivityType.meditation, refId: _poseId);
      _started = true;
    } else if (status == MeditationSessionStatus.idle && _started && !_ended) {
      _channel.end();
      // Re-arm for next session. Do NOT null _moduleSessionId here —
      // the coordinator reads it after this transition, before the next session starts.
      _started = false;
      _ended = false;
    }
    _previousStatus = status;
  }

  void dispose() {
    if (_started && !_ended) _channel.stop();
    _stateSub.cancel();
    _channelSub.cancel();   // NEW
  }
}
```

---

### Step 3 — `MeditationNotesGrpcApi`

**File:** `lib/MeditationModule/MeditationNotesGrpcApi.dart`

```dart
class MeditationNotesGrpcApi {
  final MeditationNotesServiceClient _client;

  MeditationNotesGrpcApi(this._client);

  Future<void> createNote({
    required String sessionId,
    required String poseName,
    required String noteText,
  }) =>
      _client.createNote(
        CreateNoteRequest(
          sessionId: sessionId,
          poseName: poseName,
          noteText: noteText,
        ),
      );
}
```

The generated `MeditationNotesServiceClient` is accessed via `App.shared.grpcClient.meditationNotesService` (exact getter name comes from the regenerated stubs — match whatever name `gen_proto.sh` produces for this service).

---

### Step 4 — Update `IMeditationNoteService` and `MeditationNoteService`

**File:** `lib/MeditationModule/IMeditationNoteService.dart`

Add optional `sessionId` param:
```dart
abstract class IMeditationNoteService {
  Future<void> saveNote(String text, {String? sessionId});
}
```

**File:** `lib/MeditationModule/MeditationNoteService.dart`

```dart
class MeditationNoteService implements IMeditationNoteService {
  final String _poseName;
  final MeditationNoteRepository _repository;
  final MeditationNotesGrpcApi _api;

  MeditationNoteService(this._poseName, this._repository, this._api);

  @override
  Future<void> saveNote(String text, {String? sessionId}) async {
    await _repository.save(_poseName, text, serverSessionId: sessionId);
    if (sessionId != null) {
      unawaited(
        _api
            .createNote(
              sessionId: sessionId,
              poseName: _poseName,
              noteText: text,
            )
            .catchError(
              (e) => dev.log('MeditationNoteService: server sync failed: $e',
                  name: 'MeditationNote'),
            ),
      );
    }
  }
}
```

Local save always happens first. gRPC call is fire-and-forget and only when `sessionId` is non-null (if the session never registered with the server, only the local row is saved).

---

### Step 5 — Update `MeditationSessionCoordinator`

**File:** `lib/MeditationModule/MeditationSessionCoordinator.dart`

Add `getSessionId` callback:

```dart
class MeditationSessionCoordinator implements IMeditationSessionCoordinator {
  final BuildContext context;
  final IMeditationNoteService noteService;
  final String? Function() getSessionId;

  MeditationSessionCoordinator({
    required this.context,
    required this.noteService,
    required this.getSessionId,
  });

  @override
  Future<void> onSessionStopped() async {
    final text = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const MeditationNoteScreen()),
    );
    if (text != null && text.trim().isNotEmpty) {
      unawaited(noteService.saveNote(text.trim(), sessionId: getSessionId()));
    }
  }
}
```

---

### Step 6 — Update `MeditationModule.buildSession()`

**File:** `lib/MeditationModule/MeditationModule.dart`

```dart
static Widget buildSession(BuildContext context, {required String poseId}) {
  final noteService = MeditationNoteService(
    poseId,
    App.shared.meditationNoteRepository,
    App.shared.meditationNotesGrpcApi,
  );

  late final MeditationModuleStateChannel stateChannel;

  // Lazy closure — stateChannel is a late final assigned inside overrideWith.
  // By the time getSessionId() is called (after session stops), it is initialized.
  // Same pattern as `onDispose: () => stateChannel.dispose()` below.
  final coordinator = MeditationSessionCoordinator(
    context: context,
    noteService: noteService,
    getSessionId: () => stateChannel.moduleSessionId,
  );

  return ProviderScope(
    overrides: [
      meditationSessionViewModelProvider.overrideWith((_) {
        final vm = MeditationSessionViewModel().._poseId = poseId;
        stateChannel = MeditationModuleStateChannel(
          channel: App.shared.moduleStateChannel,
          stateStream: vm.stream,
          poseId: poseId,
        );
        return vm;
      }),
      meditationSessionCoordinatorProvider.overrideWithValue(coordinator),
    ],
    child: MeditationSessionScreen(
      onDispose: () => stateChannel.dispose(),
    ),
  );
}
```

---

### Step 7 — `App.dart`

Add field and initialize after the gRPC client is ready:

```dart
late final MeditationNotesGrpcApi meditationNotesGrpcApi;

// In initialize(), after grpcClient is constructed:
meditationNotesGrpcApi = MeditationNotesGrpcApi(
  grpcClient.meditationNotesService, // exact name from generated stubs
);
```

---

### Verify

1. Start a meditation session — check `channel.state` listener fires and `stateChannel.moduleSessionId` is non-null after the server responds.
2. Stop the session → note screen appears → type text → OK.
3. Local Drift row: `serverSessionId` matches the `moduleSessionId`.
4. Server: `GET /meditation-notes` (or gRPC `ListNotes`) shows the saved note.
5. Repeat: Cancel → no row inserted, no gRPC call.
6. Network off → note saved locally with `sessionId`; gRPC call fails silently (logged).
