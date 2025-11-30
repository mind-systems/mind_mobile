import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_overlay/loading_overlay.dart';

import 'package:mind/Views/CustomButton.dart';
import 'package:mind/Views/CustomTextField.dart';
import 'package:mind/Views/ScreenTitle.dart';
import 'package:mind/Views/TopScreenImage.dart';
import 'package:mind/Views/constants.dart';
import 'package:mind/Views/ShowAlert.dart';
import 'LoginViewModel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  static String name = 'login_screen';
  static String path = '/$name';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = ref.read(loginViewModelProvider.notifier);

      viewModel.onErrorEvent = (error) {
        showAlert(
          context: context,
          onPressed: () {},
          title: 'Ошибка',
          desc: error,
          btnText: 'OK',
        ).show();
      };

      viewModel.onSuccessEvent = () {
        showAlert(
          context: context,
          onPressed: () {},
          title: 'Check your email',
          desc: 'We sent you a one-time sign-in link. Please check your email.',
          btnText: 'OK',
        ).show();
      };

      viewModel.onAuthenticatedEvent = () {
        context.go(ref.read(loginViewModelProvider).returnPath);
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: LoadingOverlay(
        isLoading: loginState.isLoading,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const TopScreenImage(screenImageName: 'welcome.png'),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const ScreenTitle(title: 'Login'),
                      CustomTextField(
                        textField: TextField(
                          onChanged: (value) {
                            ref.read(loginViewModelProvider.notifier).updateEmail(value);
                          },
                          style: const TextStyle(fontSize: 20),
                          decoration: kTextInputDecoration.copyWith(
                            hintText: 'Email',
                          ),
                        ),
                      ),
                      Hero(
                        tag: 'login_btn',
                        child: CustomButton(
                          buttonText: 'Login',
                          width: 150,
                          onPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            await ref
                                .read(loginViewModelProvider.notifier)
                                .sendPasswordlessSignInLink();
                          },
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
