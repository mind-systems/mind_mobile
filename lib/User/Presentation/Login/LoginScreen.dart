import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:mind/Views/AlertModule/AppAlert.dart';
import 'package:mind/l10n/app_localizations.dart';
import 'Models/AuthResult.dart';
import 'Models/LoginState.dart';
import 'LoginViewModel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  static String name = 'login_screen';
  static String path = '/$name';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isAlertOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = ref.read(loginViewModelProvider.notifier);

      viewModel.onErrorEvent = (error) {
        final l10n = AppLocalizations.of(context)!;
        final message = switch (error) {
          LoginError.sendCodeFailed => l10n.loginSendCodeError,
          LoginError.codeInvalidOrExpired => l10n.loginCodeInvalidError,
        };
        AppAlert.show(context, title: l10n.error, description: message);
      };

      viewModel.onSuccessEvent = () async {
        final l10n = AppLocalizations.of(context)!;
        _isAlertOpen = true;
        final result = await AppAlert.showWithInput(
          context,
          title: l10n.loginCheckEmailTitle,
          description: l10n.loginCheckEmailDescription,
          inputHint: l10n.loginCodeHint,
        );
        _isAlertOpen = false;
        if (result.confirmed && result.text != null && result.text!.isNotEmpty) {
          await viewModel.verifyCode(result.text!.trim());
        }
      };

      viewModel.onAuthenticatedEvent = () {
        context.pop(AuthResult.success);
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginViewModelProvider);
    final l10n = AppLocalizations.of(context)!; // used in build tree below

    if (loginState.isLoginInProgress && _isAlertOpen) {
      _isAlertOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context, rootNavigator: true).pop();
      });
    }

    return Scaffold(
      body: LoadingOverlay(
        isLoading: loginState.isLoading || loginState.isLoginInProgress,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: Image.asset('assets/images/welcome.png', fit: BoxFit.contain),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        l10n.login,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(width: 2.5, color: Theme.of(context).colorScheme.secondaryContainer),
                        ),
                        child: TextField(
                          onChanged: (value) {
                            ref.read(loginViewModelProvider.notifier).updateEmail(value);
                          },
                          style: const TextStyle(fontSize: 20),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: l10n.email,
                          ),
                        ),
                      ),
                      Hero(
                        tag: 'login_btn',
                        child: GestureDetector(
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            await ref
                                .read(loginViewModelProvider.notifier)
                                .sendPasswordlessSignInLink();
                          },
                          child: Material(
                            borderRadius: BorderRadius.circular(30),
                            elevation: 4,
                            child: Container(
                              width: 150,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                border: Border.all(color: Theme.of(context).colorScheme.secondaryContainer, width: 2.5),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Center(
                                child: Text(
                                  l10n.login,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
