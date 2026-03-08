import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/Presentation/Login/ILoginService.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';

// ---------------------------------------------------------------------------
// Fake ILoginService
// ---------------------------------------------------------------------------

class FakeLoginService implements ILoginService {
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<bool> _authInProgressController =
      StreamController<bool>.broadcast();

  Object? googleLoginError;
  Object? sendLinkError;
  Object? verifyCodeError;

  @override
  Stream<AuthState> observeAuthState() => _authStateController.stream;

  @override
  Stream<bool> observeAuthInProgress() => _authInProgressController.stream;

  @override
  Future<void> loginWithGoogle() async {
    if (googleLoginError != null) throw googleLoginError!;
  }

  @override
  Future<void> sendPasswordlessSignInLink(String email) async {
    if (sendLinkError != null) throw sendLinkError!;
  }

  @override
  Future<void> completePasswordlessSignIn(String code) async {
    if (verifyCodeError != null) throw verifyCodeError!;
  }

  void emitAuthState(AuthState state) => _authStateController.add(state);
  void emitAuthInProgress(bool value) => _authInProgressController.add(value);

  void dispose() {
    _authStateController.close();
    _authInProgressController.close();
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _authenticatedUser = User(
  id: 'user-123',
  email: 'test@example.com',
  name: 'Test User',
  isGuest: false,
);

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

LoginViewModel _makeViewModel({FakeLoginService? service}) {
  return LoginViewModel(service: service ?? FakeLoginService());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeLoginService fakeService;
  late LoginViewModel viewModel;

  setUp(() {
    fakeService = FakeLoginService();
    viewModel = _makeViewModel(service: fakeService);
  });

  tearDown(() {
    viewModel.dispose();
    fakeService.dispose();
  });

  group('onAuthenticatedEvent', () {
    test('fires when AuthenticatedState is emitted', () async {
      bool called = false;
      viewModel.onAuthenticatedEvent = () => called = true;

      fakeService.emitAuthState(AuthenticatedState(_authenticatedUser));
      await Future.delayed(Duration.zero);

      expect(called, isTrue);
    });

    test('does not fire for GuestState', () async {
      bool called = false;
      viewModel.onAuthenticatedEvent = () => called = true;

      fakeService.emitAuthState(GuestState(User.guest()));
      await Future.delayed(Duration.zero);

      expect(called, isFalse);
    });
  });

  group('loginWithGoogle', () {
    test('cancellation does not call onErrorEvent', () async {
      fakeService.googleLoginError = GoogleSignInCanceledException();
      String? capturedError;
      viewModel.onErrorEvent = (error) => capturedError = error;

      await viewModel.loginWithGoogle();

      expect(capturedError, isNull);
    });

    test('error calls onErrorEvent', () async {
      fakeService.googleLoginError = Exception('network error');
      String? capturedError;
      viewModel.onErrorEvent = (error) => capturedError = error;

      await viewModel.loginWithGoogle();

      expect(capturedError, isNotNull);
      expect(capturedError, contains('Google'));
    });
  });

  group('sendPasswordlessSignInLink', () {
    test('sets isLoading = true during call, false after success', () async {
      viewModel.updateEmail('test@example.com');

      final future = viewModel.sendPasswordlessSignInLink();
      expect(viewModel.state.isLoading, isTrue);

      await future;
      expect(viewModel.state.isLoading, isFalse);
    });

    test('calls onSuccessEvent on success', () async {
      bool called = false;
      viewModel.onSuccessEvent = () => called = true;
      viewModel.updateEmail('test@example.com');

      await viewModel.sendPasswordlessSignInLink();

      expect(called, isTrue);
    });

    test('calls onErrorEvent and clears isLoading on failure', () async {
      fakeService.sendLinkError = Exception('network error');
      String? capturedError;
      viewModel.onErrorEvent = (error) => capturedError = error;
      viewModel.updateEmail('test@example.com');

      await viewModel.sendPasswordlessSignInLink();

      expect(viewModel.state.isLoading, isFalse);
      expect(capturedError, isNotNull);
    });
  });

  group('verifyCode', () {
    test('sets isLoading = true during call, false after success', () async {
      final future = viewModel.verifyCode('123456');
      expect(viewModel.state.isLoading, isTrue);

      await future;
      expect(viewModel.state.isLoading, isFalse);
    });

    test('calls onErrorEvent and clears isLoading on failure', () async {
      fakeService.verifyCodeError = Exception('invalid code');
      String? capturedError;
      viewModel.onErrorEvent = (error) => capturedError = error;

      await viewModel.verifyCode('bad-code');

      expect(viewModel.state.isLoading, isFalse);
      expect(capturedError, contains('invalid or expired'));
    });
  });

  group('isLoginInProgress', () {
    test('updates state when authInProgress stream emits', () async {
      fakeService.emitAuthInProgress(true);
      await Future.delayed(Duration.zero);
      expect(viewModel.state.isLoginInProgress, isTrue);

      fakeService.emitAuthInProgress(false);
      await Future.delayed(Duration.zero);
      expect(viewModel.state.isLoginInProgress, isFalse);
    });
  });
}
