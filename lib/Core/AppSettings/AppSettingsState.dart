class AppSettingsState {
  final String theme;
  final String language;

  const AppSettingsState({required this.theme, required this.language});

  AppSettingsState copyWith({String? theme, String? language}) {
    return AppSettingsState(
      theme: theme ?? this.theme,
      language: language ?? this.language,
    );
  }
}
