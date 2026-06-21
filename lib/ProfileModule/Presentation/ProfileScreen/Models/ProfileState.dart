class ProfileState {
  final String? userName;
  final String? appVersion;
  final String theme;
  final String language;
  final bool isAuthenticated;

  const ProfileState({
    this.userName,
    this.appVersion,
    this.theme = 'system',
    this.language = 'en',
    this.isAuthenticated = false,
  });

  factory ProfileState.initial() => const ProfileState();

  ProfileState copyWith({
    String? userName,
    String? appVersion,
    String? theme,
    String? language,
    bool? isAuthenticated,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      appVersion: appVersion ?? this.appVersion,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
