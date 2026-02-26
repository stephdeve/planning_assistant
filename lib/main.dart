// ============================================================
// POINT D'ENTRÉE DE L'APPLICATION
// Configure Riverpod, le thème Material 3, les locales FR,
// initialise le Workmanager et charge le fichier .env.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/background_task_service.dart';
import 'services/permission_service.dart';
import 'presentation/pages/home_page.dart';

/// Point d'entrée principal de l'application.
/// L'ordre d'initialisation est important :
/// 1. Flutter binding (requis avant tout appel natif)
/// 2. Variables d'environnement (.env)
/// 3. Localisation française pour les dates
/// 4. Workmanager (background tasks)
Future<void> main() async {
  // Indispensable avant tout appel à une API native Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Charger les variables d'environnement depuis le fichier .env
  // Le fichier .env doit être à la racine du projet et
  // déclaré dans pubspec.yaml > assets
  await dotenv.load(fileName: '.env');

  // Initialiser les données de localisation pour le français
  // (nécessaire pour DateFormat avec 'fr_FR')
  await initializeDateFormatting('fr_FR', null);

  // Initialiser le Workmanager pour les tâches en arrière-plan
  // Le dispatcher est enregistré ici, une seule fois au démarrage
  await BackgroundTaskService.initialize();
  await BackgroundTaskService.registerPeriodicCheck();

  runApp(
    // ProviderScope est le container Riverpod global.
    // TOUT le tree de widgets a accès aux providers grâce à lui.
    const ProviderScope(
      child: VocalPlanningApp(),
    ),
  );
}

/// Widget racine de l'application.
/// Configure le thème Material 3 et les localisations.
class VocalPlanningApp extends ConsumerStatefulWidget {
  const VocalPlanningApp({super.key});

  @override
  ConsumerState<VocalPlanningApp> createState() =>
      _VocalPlanningAppState();
}

class _VocalPlanningAppState extends ConsumerState<VocalPlanningApp> {
  @override
  void initState() {
    super.initState();
    // Demander les permissions dès le premier lancement.
    // On ne bloque pas le démarrage en cas de refus : l'application
    // reste fonctionnelle, seules les features impactées sont désactivées.
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Laisser l'UI se construire avant de demander les permissions
    await Future.delayed(const Duration(milliseconds: 500));
    await PermissionService().requestAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocal Planning Assistant',
      debugShowCheckedModeBanner: false,

      // ─── Thème Material 3 ─────────────────────────────────
      // Material 3 offre des composants modernes (NavigationBar,
      // FilledButton, etc.) et un système de couleurs cohérent.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Violet Material 3
          brightness: Brightness.light,
        ),
        // Style global des cartes
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Style global des champs de texte
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Style global des AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
      ),

      // Thème sombre (cohérent avec le thème clair)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Respecter les préférences système (clair/sombre)
      themeMode: ThemeMode.system,

      // ─── Localisation française ───────────────────────────
      // Obligatoire pour les widgets natifs Flutter en français
      // (DatePicker, TimePicker, etc.)
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'), // Fallback anglais
      ],
      locale: const Locale('fr', 'FR'),

      home: const HomePage(),
    );
  }
}
