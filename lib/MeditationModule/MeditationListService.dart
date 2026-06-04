import 'package:flutter/foundation.dart';
import 'package:meditation_module/meditation_module.dart';
import 'package:mind/Core/App.dart';

class MeditationListService implements IMeditationListService {
  @override
  List<MeditationPoseDTO> poses() => kMeditationPoses;

  @override
  Future<void> refresh() async {
    try {
      final poses = await App.shared.meditationPosesApi.listPoses();
      await App.shared.db.meditationPosesDao.saveAll(
        poses.map((p) => (id: p.id, slug: p.slug, displayOrder: p.displayOrder)).toList(),
      );
      App.shared.meditationPoseUuids = {
        for (final p in poses) p.slug: p.id,
      };
    } catch (e) {
      debugPrint('MeditationListService.refresh failed: $e');
    }
  }
}
