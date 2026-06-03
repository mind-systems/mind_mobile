import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import 'MeditationListViewModel.dart';
import '../Models/MeditationPoses.dart';
import 'Views/MeditationListCell.dart';
import 'Views/MeditationListSectionHeader.dart';

class MeditationListScreen extends ConsumerWidget {
  const MeditationListScreen({super.key});

  static String name = 'meditation_list';
  static String path = '/$name';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meditationListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final pixel = 1.0 / MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: state.poses.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return MeditationListSectionHeader(
                title: l10n.meditationPoseSectionTitle,
              );
            }

            final poseIndex = index - 1;
            final pose = state.poses[poseIndex];
            final showDivider = poseIndex < state.poses.length - 1;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MeditationListCell(
                  poseId: pose.id,
                  title: meditationPoseTitle(l10n, pose.id),
                  onTap: () => ref
                      .read(meditationListViewModelProvider.notifier)
                      .onPoseTap(pose.id),
                ),
                if (showDivider)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: pixel,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
