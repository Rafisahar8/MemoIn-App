import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'widgets/app_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const MemoInApp(configurationMissing: true));
    return;
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MemoInApp());
}

class MemoInApp extends StatelessWidget {
  final bool configurationMissing;
  const MemoInApp({super.key, this.configurationMissing = false});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MemoIn',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Semua teks di aplikasi bisa diseleksi & disalin.
        builder: (context, child) => SelectionArea(child: child ?? const SizedBox.shrink()),
        home: configurationMissing
            ? const _ConfigurationScreen()
            : ValueListenableBuilder<AppUser?>(
                valueListenable: AuthService.instance.user,
                builder: (context, user, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: user == null
                      ? const LoginScreen(key: ValueKey('login'))
                      : const MainShell(key: ValueKey('shell')),
                ),
              ),
      );
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(size: 40),
                      const SizedBox(height: 20),
                      const Text('Konfigurasi Supabase belum diisi',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                      const SizedBox(height: 8),
                      const Text(
                        'Jalankan aplikasi dengan --dart-define=SUPABASE_URL=... dan '
                        '--dart-define=SUPABASE_ANON_KEY=... . Petunjuk lengkap ada di README.md.',
                        style: TextStyle(color: AppTheme.muted, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
