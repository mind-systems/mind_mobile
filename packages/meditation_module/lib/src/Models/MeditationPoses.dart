import 'package:flutter/foundation.dart';
import 'package:mind_l10n/mind_l10n.dart';

@immutable
class MeditationPoseDTO {
  final String id;

  const MeditationPoseDTO({required this.id});
}

const List<MeditationPoseDTO> kMeditationPoses = [
  MeditationPoseDTO(id: 'easy'),
  MeditationPoseDTO(id: 'lotus'),
  MeditationPoseDTO(id: 'half_lotus'),
  MeditationPoseDTO(id: 'seiza'),
  MeditationPoseDTO(id: 'chair'),
  MeditationPoseDTO(id: 'savasana'),
];

String meditationPoseTitle(AppLocalizations l10n, String id) {
  switch (id) {
    case 'easy':
      return l10n.meditationPoseEasy;
    case 'lotus':
      return l10n.meditationPoseLotus;
    case 'half_lotus':
      return l10n.meditationPoseHalfLotus;
    case 'seiza':
      return l10n.meditationPoseSeiza;
    case 'chair':
      return l10n.meditationPoseChair;
    case 'savasana':
      return l10n.meditationPoseSavasana;
    default:
      return id;
  }
}
