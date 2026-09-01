import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'currency/app_currency.dart';
import 'localization/app_language.dart';
import 'security/biometric_gate.dart';
import 'security/biometric_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageController.instance.load();
  await AppCurrencyController.instance.load();
  await BiometricSecurityController.instance.load();
  runApp(const PersonalFinanceApp());
}

class PersonalFinanceApp extends StatelessWidget {
  const PersonalFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0B8D86);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liblo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7FAF9),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE7E9F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: seedColor,
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const BiometricGate(
        child: AppShell(),
      ),
    );
  }
}
