class SuggestionDTO {
  final String id;
  final String title;
  final String description;
  final String? iconUrl;

  SuggestionDTO({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
  });

  factory SuggestionDTO.fromJson(Map<String, dynamic> json) => SuggestionDTO(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    iconUrl: json['iconUrl'] as String?,
  );
}
