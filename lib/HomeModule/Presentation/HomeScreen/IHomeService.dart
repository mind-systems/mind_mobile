import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';

abstract class IHomeService {
  bool get isGuest;
  Future<List<SuggestionItemDTO>> fetchSuggestions();
  Future<StatsDTO?> fetchStats();
  Stream<HomeEvent> observeChanges();
}
