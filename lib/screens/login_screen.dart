import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

/// Halaman login: hanya username + password (diverifikasi lewat fungsi `app_login`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false, _hide = true;
  String _message = '';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = 'Username dan password wajib diisi');
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      await AuthService.instance.login(_username.text, _password.text);
      // Navigasi otomatis: main.dart mendengarkan AuthService.user.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (e) {
      if (mounted) setState(() => _message = 'Login gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          if (wide) {
            return Row(children: [
              const Expanded(flex: 11, child: _BrandPanel()),
              Expanded(
                flex: 10,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: _form(compact: false)),
                  ),
                ),
              ),
            ]);
          }
          // Mobile / tablet sempit: satu kolom polos.
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: box.maxWidth < 480 ? 24 : 32, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Row(children: [
                      BrandMark(size: 48),
                      SizedBox(width: 12),
                      Text('MemoIn',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                    ]),
                    const SizedBox(height: 36),
                    _form(compact: true),
                  ]),
                ),
              ),
            ),
          );
        }),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
      );

  Widget _form({required bool compact}) => AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              const Text('Selamat datang',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppTheme.ink, letterSpacing: -.4)),
              const SizedBox(height: 6),
              const Text('Masuk dengan username dan password Anda untuk melanjutkan.',
                  style: TextStyle(color: AppTheme.muted, height: 1.45)),
              const SizedBox(height: 32),
            ] else ...[
              const Text('Masuk',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.ink, letterSpacing: -.3)),
              const SizedBox(height: 6),
              const Text('Gunakan username dan password Anda.', style: TextStyle(color: AppTheme.muted, height: 1.45)),
              const SizedBox(height: 24),
            ],
            _label('Username'),
            TextField(
              controller: _username,
              autofocus: true,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: const InputDecoration(hintText: 'Masukkan username'),
            ),
            const SizedBox(height: 18),
            _label('Password'),
            TextField(
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !_loading,
              obscureText: _hide,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                hintText: 'Masukkan password',
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Tampilkan password' : 'Sembunyikan password',
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: _message.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: .25)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.error_outline, size: 20, color: AppTheme.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_message,
                              style: const TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                        ),
                      ]),
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Masuk', style: TextStyle(fontSize: 14.5)),
              ),
            ),
          ],
        ),
      );
}

/// Panel branding di sisi kiri untuk layar lebar: satu bidang biru logo, tanpa dekorasi.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => Container(
        color: AppTheme.sidebar,
        padding: const EdgeInsets.all(56),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            BrandMark(size: 48, onDark: true),
            SizedBox(width: 12),
            Text('MemoIn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          const Spacer(),
          const Text('Kelola memo gangguan\nlebih cepat dan rapi.',
              style: TextStyle(
                  fontSize: 34, height: 1.2, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -.6)),
          const SizedBox(height: 16),
          const Text(
            'Pantau memo meter & MCB, stok meter, dan evaluasi pemasangan dalam satu aplikasi.',
            style: TextStyle(fontSize: 15, height: 1.55, color: Color(0xFFC9DBF8)),
          ),
          const SizedBox(height: 40),
          const _Feature('01', 'Dashboard memo & status otomatis'),
          const _Feature('02', 'Stok nomor meter terkelola'),
          const _Feature('03', 'Evaluasi gangguan, merk, dan tahun meter'),
        ]),
      );
}

class _Feature extends StatelessWidget {
  final String no, text;
  const _Feature(this.no, this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x33FFFFFF)))),
        child: Row(children: [
          SizedBox(width: 36, child: Text(no, style: const TextStyle(color: AppTheme.sidebarMuted, fontSize: 13))),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5))),
        ]),
      );
}
