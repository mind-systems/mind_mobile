import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/OtpLockedException.dart';
import 'package:mind/User/Presentation/Login/ILoginService.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';
import 'package:mind/User/Presentation/Login/Models/LoginState.dart';

// ---------------------------------------------------------------------------
// Fake ILoginService
// ---------------------------------------------------------------------------

class _FakeLoginService implements ILoginService {
  String? lastVerifiedCode;
  Exception? exceptionToThrow;

  @override
  Stream<AuthState> observeAuthState() => const Stream.empty();

  @override
  Stream<bool> observeAuthInProgress() => const Stream.empty();

  @override
  Future<void> completePasswordlessSignIn(String code) async {
    lastVerifiedCode = code;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> sendPasswordlessSignInLink(String email) async {}

  @override
  Future<void> loginWithGoogle() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

typedef _Setup = ({
  ProviderContainer container,
  LoginViewModel vm,
  _FakeLoginService service,
  List<LoginError> capturedErrors,
});

_Setup _makeSetup() {
  final service = _FakeLoginService();
  final capturedErrors = <LoginError>[];
  final vm = LoginViewModel(service: service);
  final container = ProviderContainer(
    overrides: [loginViewModelProvider.overrideWith(() => vm)],
  );
  // Trigger build() by reading the notifier.
  container.read(loginViewModelProvider.notifier);
  vm.onErrorEvent = capturedErrors.add;
  return (
    container: container,
    vm: vm,
    service: service,
    capturedErrors: capturedErrors,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late ProviderContainer container;

  tearDown(() {
    container.dispose();
  });

  group('verifyCode error paths', () {
    test(
        'should set isLoading=false and emit LoginError.tooManyAttempts when verifyCode throws OtpLockedException',
        () async {
      final s = _makeSetup();
      container = s.container;
      s.service.exceptionToThrow = const OtpLockedException();

      await s.vm.verifyCode('123456');

      expect(container.read(loginViewModelProvider).isLoading, isFalse);
      expect(s.capturedErrors, equals([LoginError.tooManyAttempts]));
    });

    test(
        'should set isLoading=false and emit LoginError.codeInvalidOrExpired when verifyCode throws a generic Exception',
        () async {
      final s = _makeSetup();
      container = s.container;
      s.service.exceptionToThrow = Exception('boom');

      await s.vm.verifyCode('123456');

      expect(container.read(loginViewModelProvider).isLoading, isFalse);
      expect(s.capturedErrors, equals([LoginError.codeInvalidOrExpired]));
    });

    test(
        'should set isLoading=false and emit no error when verifyCode succeeds',
        () async {
      final s = _makeSetup();
      container = s.container;
      // No exception — service completes normally.

      await s.vm.verifyCode('123456');

      expect(container.read(loginViewModelProvider).isLoading, isFalse);
      expect(s.capturedErrors, isEmpty);
    });
  });
}
