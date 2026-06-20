# Fix Google Sign-In Silent Failure on Network Errors

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- `_gmsFlow()` converts `GoogleSignInException(canceled)` to `GoogleSignInCanceledException`, which `UserNotifier` silently swallows — so GMS technical failures (network unreachable) are indistinguishable from explicit user cancels and show no error.
- Plan B fix: remove the cancel catch from `_gmsFlow()` so all GMS failures bubble to the outer catch in `getServerAuthCode()` and fall through to `_browserFlow()`.
- Browser flow already handles both cases correctly: explicit cancel → `PlatformException(CANCELED)` → `GoogleSignInCanceledException` → silent; network error → regular exception → `UserNotifier._authErrorSubject` → snackbar.
- Trade-off: a user who explicitly cancels the GMS picker will see the browser OAuth flow open next. Acceptable — GMS picker is only shown on Android with Play Services.

## Details

### Affected files

- `lib/User/Infrastructure/GoogleAuthProvider.dart` — one file, ~3 lines removed from `_gmsFlow()`

### Current `_gmsFlow()` (problematic)

```dart
Future<({String code, String? redirectUri})> _gmsFlow() async {
  try {
    final serverAuth = await _google.authorizationClient.authorizeServer(['email']);
    if (serverAuth == null) throw Exception('Google Sign-In did not return a serverAuthCode.');
    return (code: serverAuth.serverAuthCode, redirectUri: null);
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw GoogleSignInCanceledException(); // ← conflates user cancel with technical failure
    }
    rethrow;
  }
}
```

### Fixed `_gmsFlow()`

```dart
Future<({String code, String? redirectUri})> _gmsFlow() async {
  final serverAuth = await _google.authorizationClient.authorizeServer(['email']);
  if (serverAuth == null) throw Exception('Google Sign-In did not return a serverAuthCode.');
  return (code: serverAuth.serverAuthCode, redirectUri: null);
}
```

All `GoogleSignInException` variants (including `canceled`) now bubble up to `getServerAuthCode()`'s outer `catch (e)` and route to `_browserFlow()`.

### Error propagation path after fix

```
GMS network failure
  → GoogleSignInException (any code) bubbles
  → getServerAuthCode() outer catch → _browserFlow()
  → browser also fails with SocketException
  → propagates as regular Exception
  → UserNotifier.loginWithGoogle() catch (e) line 78
  → _authErrorSubject.add('Failed to sign in with Google')
  → GlobalListeners._authErrorSubscription
  → _showSnackBar(SnackBarEvent.error('Ошибка входа: …'))
```

### Guards

- Do NOT modify `_browserFlow()` — it already handles `CANCELED` correctly.
- Do NOT modify `GoogleSignInCanceledException` — browser flow still uses it.
- Do NOT modify `UserNotifier` — swallowing `GoogleSignInCanceledException` is correct for the browser cancel path.
- `MissingPluginException` and other `PlatformException` from GMS already fell to `_browserFlow()` via the outer catch — behavior unchanged for those.

### Verification

1. Disable network on device, tap Google Sign-In → snackbar "Ошибка входа: Failed to sign in with Google" must appear.
2. Enable network, tap Google Sign-In, tap Cancel in GMS picker → browser OAuth opens → user can cancel or complete from there.
3. Enable network, complete sign-in via GMS → works as before.
