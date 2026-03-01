import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:mind/Views/AlertModule/AppAlert.dart';
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
        AppAlert.show(context, title: 'Ошибка', description: error);
      };

      viewModel.onSuccessEvent = () {
        context.go(ref.read(loginViewModelProvider).returnPath);
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginViewModelProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.secondaryContainer;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: loginState.isLoading || loginState.isLoginInProgress,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2/4 — картинка
                Expanded(
                  flex: 2,
                  child: Image.asset('assets/images/home.png', fit: BoxFit.contain),
                ),
                // 1/4 — текст
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Hello',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome to your mind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.6),
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 1/4 — кнопки
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'login_btn',
                          child: GestureDetector(
                            onTap: () {
                              context.push(LoginScreen.path, extra: loginState.returnPath);
                            },
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                              child: Image.asset('assets/images/email.png', width: 50, height: 50),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                        GestureDetector(
                          onTap: () {
                            ref.read(loginViewModelProvider.notifier).loginWithGoogle();
                          },
                          child: Image.asset('assets/images/google.png', width: 50, height: 50),
                        ),
                      ],
                    ),
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
