import 'User.dart';

sealed class AuthState {
  final User user;
  const AuthState(this.user);
}

class GuestState extends AuthState {
  const GuestState(super.user);
}

class AuthenticatedState extends AuthState {
  const AuthenticatedState(super.user);
}

