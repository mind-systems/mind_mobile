import 'package:mind/Core/Grpc/generated/meditation_poses.pbgrpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';

class MeditationPosesGrpcApi {
  final MeditationPosesServiceClient _client;

  MeditationPosesGrpcApi(this._client);

  Future<List<({String id, String slug, int displayOrder})>> listPoses() async {
    final response = await _client.listPoses(Empty());
    return response.poses.map((p) => (id: p.id, slug: p.slug, displayOrder: p.displayOrder)).toList();
  }
}
