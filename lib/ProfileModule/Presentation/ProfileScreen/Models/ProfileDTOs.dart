class UserDTO {
  final String name;
  const UserDTO({required this.name});
}

sealed class ProfileEvent {}

class ProfileLoaded extends ProfileEvent {
  final UserDTO user;
  ProfileLoaded({required this.user});
}
