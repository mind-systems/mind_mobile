import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/Views/CustomButton.dart';
import 'package:mind/Views/ScreenTitle.dart';
import 'package:mind/Views/ShowAlert.dart';
import 'package:mind/Views/TopScreenImage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'LoginScreen.dart';
import 'LoginViewModel.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  static String name = 'onboarding_screen';
  static String path = '/$name';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
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
        context.go(ref.read(loginViewModelProvider).returnPath);
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TopScreenImage(screenImageName: 'home.png'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 15.0, left: 15, bottom: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const ScreenTitle(title: 'Hello'),
                      const Text(
                        'Welcome to your mind',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 20),
                      ),
                      const SizedBox(height: 15),
                      Hero(
                        tag: 'login_btn',
                        child: CustomButton(
                          buttonText: 'Login',
                          onPressed: () {
                            context.push(LoginScreen.path, extra: loginState.returnPath,);
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              ref.read(loginViewModelProvider.notifier).loginWithGoogle();
                            },
                            icon: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.transparent,
                              child: Image.asset('assets/images/google.png'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
