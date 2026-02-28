class ProfileState {
  final String? userName;
  final String? appVersion;

  const ProfileState({this.userName, this.appVersion});

  factory ProfileState.initial() => const ProfileState();
}
