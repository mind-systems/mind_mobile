class ProfileState {
  final String? userName;
  final String? appVersion;

  const ProfileState({this.userName, this.appVersion});

  factory ProfileState.initial() => const ProfileState();

  ProfileState copyWith({String? userName, String? appVersion}) {
    return ProfileState(
      userName: userName ?? this.userName,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}
