class ProfileState {
  final String? userName;
  final String? appVersion;
  final String themeLabel;
  final String languageLabel;

  const ProfileState({
    this.userName,
    this.appVersion,
    this.themeLabel = 'System',
    this.languageLabel = 'English',
  });

  factory ProfileState.initial() => const ProfileState();

  ProfileState copyWith({
    String? userName,
    String? appVersion,
    String? themeLabel,
    String? languageLabel,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      appVersion: appVersion ?? this.appVersion,
      themeLabel: themeLabel ?? this.themeLabel,
      languageLabel: languageLabel ?? this.languageLabel,
    );
  }
}
