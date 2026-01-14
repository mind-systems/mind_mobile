import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorScreen.dart';
import 'package:mind/BreathSessionMocks.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Mind"),
      ),
      body: Center(
        child: const Text('Нажми + чтобы открыть Login'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Выбери нужную тестовую сессию:
          // final session = BreathSessionMocks.quickTestSession;       // Быстрая
          // final session = BreathSessionMocks.triangleOnlySession;    // Только треугольники
          // final session = BreathSessionMocks.boxOnlySession;         // Только квадраты
          // final session = BreathSessionMocks.mixedShapesSession;     // Микс форм
          final session = BreathSessionMocks.fullTestSession;        // Полная тестовая
          // final session = BreathSessionMocks.longSession;            // Длинная сессия

          // context.push(OnboardingScreen.path);
          // context.push(BreathSessionScreen.path);
          context.push(BreathSessionConstructorScreen.path, extra: session);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
