import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import 'MeditationListViewModel.dart';
import '../Models/MeditationPoses.dart';
import 'Views/MeditationListCell.dart';

class MeditationListScreen extends ConsumerWidget {
  const MeditationListScreen({super.key});

  static String name = 'meditation_list';
  static String path = '/$name';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meditationListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: state.poses.length,
          itemBuilder: (context, index) {
            final pose = state.poses[index];
            return MeditationListCell(
              poseId: pose.id,
              title: meditationPoseTitle(l10n, pose.id),
              onTap: () =>
                  ref.read(meditationListViewModelProvider.notifier).onPoseTap(pose.id),
            );
          },
        ),
      ),
    );
  }
}
