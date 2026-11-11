import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'core/api.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'state/auth_state.dart';
import 'state/duty_state.dart';
import 'theme.dart';
import 'tracking/tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final auth = AuthState();
  final duty = DutyState();

  // keep recording a duty that was running when the app was closed, even before the network answers
  await Tracker.instance.resumeFromDisk();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: duty),
      ChangeNotifierProvider.value(value: Tracker.instance),
    ],
    child: const SkirlFieldApp(),
  ));

  try {
    await auth.init();
  } catch (_) {
    // shown by Root as a retry screen
  }
}

class SkirlFieldApp extends StatelessWidget {
  const SkirlFieldApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: Config.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Root(),
      );
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    switch (auth.status) {
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.needsPassword:
        return const ChangePasswordScreen(forced: true);
      case AuthStatus.signedIn:
        if (auth.me?.isPlatform == true) return const _PlatformUser();
        return const Shell();
      case AuthStatus.loading:
        return const _Splash();
    }
  }
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  Future<void> _retry() async {
    setState(() => _slow = false);
    try {
      await context.read<AuthState>().loadMe();
    } on ApiException {
      if (mounted) setState(() => _slow = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.my_location, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(Config.appName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 24),
            if (!_slow)
              const CircularProgressIndicator()
            else ...[
              const Text('Cannot reach the server.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              TextButton(onPressed: _retry, child: const Text('Try again')),
            ],
          ]),
        ),
      );
}

class _PlatformUser extends StatelessWidget {
  const _PlatformUser();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This app is for field staff.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Super Admin uses the SkirlField web app.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: () => context.read<AuthState>().logout(), child: const Text('Sign out')),
            ]),
          ),
        ),
      );
}
