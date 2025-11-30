import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
          context.push(OnboardingScreen.path);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
