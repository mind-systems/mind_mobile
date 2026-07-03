import 'dart:async';

import 'package:mind/Logger.dart';

import 'package:mind/Core/Grpc/ModuleStateChannel.dart';

/// App-level sibling adapter — tied to the connection, not a screen.
///
/// Opens the root activity on first connect and every reconnect (the root
/// is idempotent per user server-side: same `root.id`, no duplicate root).
/// Exposes the registry-derived `root.id` for downstream consumers (bio
/// tagging). There is no end/stop/pause/resume path — the root never ends.
class RootStateChannel {
  final ModuleStateChannel _channel;

  late final StreamSubscription<void> _streamOpenedSub;

  RootStateChannel({required ModuleStateChannel channel}) : _channel = channel {
    _streamOpenedSub = _channel.sessionStreamOpened.listen((_) {
      logPrint('[RootStateChannel] opening root');
      _channel.startRoot();
    });
  }

  String? get rootId => _channel.rootId;
  Stream<String?> get rootIdChanges => _channel.rootIdChanges;

  void dispose() {
    _streamOpenedSub.cancel();
  }
}
