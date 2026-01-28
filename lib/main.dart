import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
//import 'package:firebase_core/firebase_core.dart';

import 'core/config/app_config.dart';
import 'core/deep_link/deep_link_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize storage service
  await StorageService.init();
  
  // Initialize Firebase (for push notifications)
  try {
    //await Firebase.initializeApp();
    //await NotificationService.init();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const ProviderScope(child: FacultyPediaApp()));
}

// class FacultyPediaApp extends ConsumerWidget {
//   const FacultyPediaApp({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final router = ref.watch(appRouterProvider);
//     final themeMode = ref.watch(themeModeProvider);
//
//     return MaterialApp.router(
//       title: AppConfig.appName,
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.lightTheme,
//       darkTheme: AppTheme.darkTheme,
//       themeMode: themeMode,
//       routerConfig: router,
//     );
//   }
// }
class FacultyPediaApp extends ConsumerStatefulWidget {
  const FacultyPediaApp({super.key});

  @override
  ConsumerState<FacultyPediaApp> createState() => _FacultyPediaAppState();
}

class _FacultyPediaAppState extends ConsumerState<FacultyPediaApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    _deepLinkService.init(
      onLink: (uri) {
        final router = ref.read(appRouterProvider);

        String path = uri.path;
        if (uri.host.isNotEmpty) {
          path = "/${uri.host}${uri.path}";
        }

        if (path.isEmpty || path == "/") return;

        // ✅ Directly go to deep link
        router.go(path);
      },
    );


  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

