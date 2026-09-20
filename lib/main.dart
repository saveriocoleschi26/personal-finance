import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'cloud_sync/icloud_sync_service.dart';
import 'currency/app_currency.dart';
import 'database/database_service.dart';
import 'localization/app_language.dart';
import 'security/biometric_gate.dart';
import 'security/biometric_security.dart';
import 'theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageController.instance.load();
  await AppCurrencyController.instance.load();
  await BiometricSecurityController.instance.load();
  await AppThemeController.instance.load();
  // Se su iCloud c'è una copia del database più recente di quella locale
  // (es. aggiunta da un altro dispositivo), la scarichiamo PRIMA di aprire
  // il database. In caso di problemi con iCloud l'app parte comunque
  // normalmente con i dati locali.
  final dbPath = await DatabaseService.instance.getDatabaseFilePath();
  final versionPath = await DatabaseService.instance.getDataVersionFilePath();
  await ICloudSyncService.downloadIfNewer(dbPath, versionPath);
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
    AppThemeController.instance.addListener(_themeChanged);
    // Serve a far ricostruire l'app quando cambia la lingua, così la
    // direzione del testo (necessaria per l'arabo, RTL) si aggiorna subito
    // senza dover riavviare l'app.
    AppLanguageController.instance.addListener(_languageChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppThemeController.instance.removeListener(_themeChanged);
    AppLanguageController.instance.removeListener(_languageChanged);
    super.dispose();
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rete di sicurezza aggiuntiva: il caricamento "vero" avviene subito
    // dopo ogni scrittura (vedi DatabaseService), mentre l'app è ancora
    // in primo piano. Usiamo solo "paused" (app davvero in background) e
    // non "inactive": quest'ultimo scatta anche solo per il gesto rapido
    // di cambio app, e avviare un caricamento proprio in quel momento
    // rischiava di intralciare la lettura dei dati se l'utente tornava
    // subito indietro nell'app.
    if (state == AppLifecycleState.paused) {
      Future(() async {
        final path = await DatabaseService.instance.getDatabaseFilePath();
        final versionPath =
            await DatabaseService.instance.getDataVersionFilePath();
        await ICloudSyncService.uploadDatabase(path, versionPath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0B8D86);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liblo',
      themeMode: AppThemeController.instance.themeMode,
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
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1917),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E1917),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16221F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF223532)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1FBF95),
              width: 1.5,
            ),
          ),
        ),
      ),
      home: Directionality(
        textDirection: AppLanguageController.instance.isRTL
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: const BiometricGate(
          child: AppShell(),
        ),
      ),
    );
  }
}
