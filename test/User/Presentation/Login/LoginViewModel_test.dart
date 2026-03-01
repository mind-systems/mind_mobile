import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
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

  Completer<void>? _loginWithGoogleCompleter;
  Completer<void>? _sendLinkCompleter;

  @override
  Stream<AuthState> observeAuthState() => _authStateController.stream;

  @override
  Stream<bool> observeAuthInProgress() => _authInProgressController.stream;

  @override
  Future<void> loginWithGoogle() async {
    _loginWithGoogleCompleter = Completer<void>();
    return _loginWithGoogleCompleter!.future;
  }

  @override
  Future<void> sendPasswordlessSignInLink(String email) async {
    _sendLinkCompleter = Completer<void>();
    return _sendLinkCompleter!.future;
  }

  void completeGoogleLogin() => _loginWithGoogleCompleter?.complete();
  void failGoogleLogin(Object error) =>
      _loginWithGoogleCompleter?.completeError(error);
  void completeSendLink() => _sendLinkCompleter?.complete();
  void failSendLink(Object error) =>
      _sendLinkCompleter?.completeError(error);
  void emitAuthInProgress(bool value) => _authInProgressController.add(value);

  void dispose() {
    _authStateController.close();
    _authInProgressController.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeLoginService fakeService;
  late LoginViewModel viewModel;

  setUp(() {
    fakeService = FakeLoginService();
    viewModel = LoginViewModel(service: fakeService, returnPath: '/');
  });

  tearDown(() {
    viewModel.dispose();
    fakeService.dispose();
  });

  group('loginWithGoogle', () {
    test('does NOT set isLoading = true', () async {
      final states = <bool>[];
      viewModel.addListener((state) {
        states.add(state.isLoading);
      });

      final future = viewModel.loginWithGoogle();
      fakeService.completeGoogleLogin();
      await future;

      expect(states, everyElement(false),
          reason: 'isLoading should never become true during Google login');
    });

    test('calls onSuccessEvent on success', () async {
      var successCalled = false;
      viewModel.onSuccessEvent = () => successCalled = true;

      final future = viewModel.loginWithGoogle();
      fakeService.completeGoogleLogin();
      await future;

      expect(successCalled, isTrue);
    });

    test('cancellation does not set error state', () async {
      String? capturedError;
      viewModel.onErrorEvent = (error) => capturedError = error;

      final future = viewModel.loginWithGoogle();
      fakeService.failGoogleLogin(GoogleSignInCanceledException());
      await future;

      expect(capturedError, isNull,
          reason: 'Cancellation should not trigger onErrorEvent');
    });

    test('error calls onErrorEvent', () async {
      String? capturedError;
      viewModel.onErrorEvent = (error) => capturedError = error;

      final future = viewModel.loginWithGoogle();
      fakeService.failGoogleLogin(Exception('network error'));
      await future;

      expect(capturedError, isNotNull);
      expect(capturedError, contains('Google'));
    });
  });

  group('sendPasswordlessSignInLink', () {
    test('toggles isLoading correctly', () async {
      final loadingStates = <bool>[];
      viewModel.addListener((state) {
        loadingStates.add(state.isLoading);
      });

      viewModel.updateEmail('test@example.com');
      final future = viewModel.sendPasswordlessSignInLink();
      // isLoading should be true at this point
      expect(viewModel.state.isLoading, isTrue);

      fakeService.completeSendLink();
      await future;

      expect(viewModel.state.isLoading, isFalse);
    });
  });

  group('isLoginInProgress (from domain stream)', () {
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
