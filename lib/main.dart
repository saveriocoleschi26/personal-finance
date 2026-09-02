import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'cloud_sync/icloud_sync_service.dart';
import 'currency/app_currency.dart';
import 'localization/app_language.dart';
import 'security/biometric_gate.dart';
import 'security/biometric_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageController.instance.load();
  await AppCurrencyController.instance.load();
  await BiometricSecurityController.instance.load();
  // Se su iCloud c'è una copia del database più recente di quella locale
  // (es. aggiunta da un altro dispositivo), la scarichiamo PRIMA di aprire
  // il database. In caso di problemi con iCloud l'app parte comunque
  // normalmente con i dati locali.
  await ICloudSyncService.downloadIfNewer();
  runApp(const PersonalFinanceApp());
}

class PersonalFinanceApp extends StatefulWidget {
  const PersonalFinanceApp({super.key});

  @override
  State<PersonalFinanceApp> createState() => _PersonalFinanceAppState();
}

class _PersonalFinanceAppState extends State<PersonalFinanceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando l'utente esce dall'app (per chiuderla o passare a un'altra
    // app) carichiamo la copia aggiornata del database su iCloud, così
    // sarà disponibile sugli altri dispositivi alla prossima apertura.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ICloudSyncService.uploadDatabase();
    }
  }

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
