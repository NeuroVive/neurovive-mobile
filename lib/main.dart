import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:neurovive/screens/auth_screen.dart';
import 'package:neurovive/screens/land_screen.dart';
import 'package:neurovive/screens/pen_screen.dart';
import 'package:neurovive/screens/result_screen.dart';
import 'package:neurovive/screens/send_voice_screen.dart';
import 'package:neurovive/screens/landing/landing_screen.dart';
import 'package:neurovive/screens/settings_screen.dart';
import 'package:neurovive/themes/main_themes.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './screens/handwriting_screen.dart';
import './screens/record_screen2.dart';
import './utils.dart';
import 'icons/neurovive_icons.dart';
import 'l10n/app_localizations.dart';
import 'notifiers/voice_upload_notifier.dart';

//router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final bool firstOpen = prefs.getBool('first_open') ?? true;
      
      if (firstOpen && state.uri.path != '/landing') {
        return '/landing';
      }
      return null;
    },

    routes: [
      GoRoute(
        path: '/landing',
        name: 'Landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'Login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'Settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final l10n = AppLocalizations.of(context)!;
          String routeName = state.topRoute?.path ?? '';
          final String currentPath = state.uri.path.split('?').first;
          final String pageName = switch (currentPath) {
            '/landing' => l10n.landingPage,
            '/login' => l10n.loginPage,
            '/' => l10n.chooseMethod,
            '/voice' => l10n.voiceRecord,
            '/handwriting' => l10n.handwritingTestPage,
            '/pen' => l10n.penPage,
            '/sendvoice' => '',
            '/results' => l10n.medicalReport,
            '/settings' => l10n.settings,
            _ => l10n.noNameError,
          };

          ThemeData theme = switch (routeName) {
            '/voice' => Mainthemes.blueBackgroundTheme,
            '/handwriting' => Mainthemes.blueBackgroundTheme,
            _ => Mainthemes.whiteBackgroundTheme,
          };

          ref.listen<AsyncValue<bool>>(showHelpOnceProvider(currentPath), (
            _,
            next,
          ) {
            next.whenOrNull(
              data: (shouldShow) {
                if (!shouldShow) return;

                showCurrentInstructions(context, currentPath);
              },
            );
          });

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didpop, _) async {
              if (!didpop) {
                await handleBack(context);
              }
            },
            child: Theme(
              data: theme,
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,

                    appBar: AppBar(
                      elevation: 0,
                      backgroundColor: const Color(0xFF1F3E6C),
                      leading:
                          currentPath == '/'
                          ? IconButton(
                              onPressed: () {
                                context.push('/settings');
                              },
                              icon: const Icon(Icons.settings),
                              color: Colors.white,
                            )
                          : !(currentPath == '/sendvoice')
                          ? IconButton(
                              onPressed: () {
                                handleBack(context);
                              },
                              icon: Transform(
                                transform: Matrix4.identity()
                                  ..scale(
                                    Directionality.of(context) == TextDirection.rtl
                                        ? -1.0
                                        : 1.0,
                                    1.0,
                                    1.0,
                                  ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Neurovive.arrow_left,
                                  color: Colors.white,
                                ),
                              ),
                              color: Colors.white,
                            )
                          : const SizedBox.shrink(),

                      title: Text(
                        pageName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      centerTitle: true,
                      actions: [
                        if (currentPath == '/voice' || currentPath == '/handwriting')
                          IconButton(
                            icon: Icon(
                              Neurovive.info,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () {
                              showCurrentInstructions(context, currentPath);
                            },
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),

                    body: child,
                  );
                },
              ),
            ),
          );
        },

        routes: [
          GoRoute(
            path: '/',
            name: 'Choose the method\nof detection',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LandScreen(),
              transitionDuration: const Duration(milliseconds: 10),
              reverseTransitionDuration: const Duration(milliseconds: 10),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: Tween<double>(
                        begin: 1,
                        end: 0,
                      ).animate(secondaryAnimation),
                      child: child,
                    );
                  },
            ),
          ),
          GoRoute(
            path: '/voice',
            name: 'Voice Record',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const RecordScreen2(),
                transitionDuration: const Duration(milliseconds: 10),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              );
            },
          ),
          GoRoute(
            path: '/handwriting',
            name: 'Handwriting Test',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const LiveShapeDetectionScreen(),
                transitionDuration: const Duration(milliseconds: 10),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              );
            },
          ),
          GoRoute(
            path: '/pen',
            name: 'Pen',
            builder: (context, state) => const BluetoothConnectionPage(),
          ),
          GoRoute(
            path: '/sendvoice',
            name: '#',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is! (String, FileType)) {
                throw Exception(
                  'Expected a (String, FileType) tuple in state.extra',
                );
              }
              final (filePath, type) = extra;
              return SendVoiceScreen(filePath: filePath, type: type);
            },
          ),
          GoRoute(
            path: '/results',
            name: 'Medical Report',
            builder: (context, state) {
              final results = state.extra as Response;
              return ResultScreen(result: results);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Placeholder(),
  );
});

//language provider
final localProvider = StateProvider<Locale>((ref) {
  return const Locale('en');
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  UniversalBle.setLogLevel(BleLogLevel.verbose);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localProvider);
    return MaterialApp.router(
      theme: ThemeData(
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
