import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditation_module/meditation_module.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/MeditationModule/MeditationListCoordinator.dart';
import 'package:mind/MeditationModule/MeditationListService.dart';
import 'package:mind/MeditationModule/Core/MeditationModuleStateChannel.dart';

class MeditationModule {
  static Widget buildSessionList(BuildContext context) {
    final service = MeditationListService();
    final coordinator = MeditationListCoordinator(context);
    return ProviderScope(
      overrides: [
        meditationListViewModelProvider.overrideWith(
          () => MeditationListViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const MeditationListScreen(),
    );
  }

  static Widget buildSession(BuildContext context, {required String poseId}) {
    late final MeditationModuleStateChannel stateChannel;
    final refId = App.shared.meditationPoseUuids[poseId] ?? poseId;
    return ProviderScope(
      overrides: [
        meditationSessionViewModelProvider.overrideWith(() {
          final vm = MeditationSessionViewModel(poseId: poseId);
          stateChannel = MeditationModuleStateChannel(
            channel: App.shared.moduleStateChannel,
            stateStream: vm.stream,
            refId: refId,
          );
          return vm;
        }),
      ],
      child: MeditationSessionScreen(onDispose: () => stateChannel.dispose()),
    );
  }
}
