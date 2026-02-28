import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:mind/Views/AlertModule/AppAlert.dart';
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
        AppAlert.show(context, title: 'Ошибка', description: error);
      };

      viewModel.onSuccessEvent = () {
        AppAlert.show(
          context,
          title: 'Check your email',
          description: 'We sent you a one-time sign-in link. Click the link on the same device.',
        );
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
      body: LoadingOverlay(
        isLoading: loginState.isLoading,
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
                        'Login',
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
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Email',
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
                              child: const Center(
                                child: Text(
                                  'Login',
                                  style: TextStyle(
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
