import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/responsive.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'dashboard_screen.dart';
import 'evaluasi_screen.dart';
import 'memo_selesai_screen.dart';
import 'stok_meter_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;

  static const titles = ['Dashboard', 'Memo Selesai', 'Stok Meter', 'Evaluasi'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.assignment_turned_in_outlined,
    Icons.inventory_2_outlined,
    Icons.analytics_outlined,
  ];
  static const iconsActive = [
    Icons.dashboard,
    Icons.assignment_turned_in,
    Icons.inventory_2,
    Icons.analytics,
  ];
  final pages = const [DashboardScreen(), MemoSelesaiScreen(), StokMeterScreen(), EvaluasiScreen()];

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Keluar dari akun?',
      message: 'Anda perlu login kembali untuk mengakses MemoIn.',
      confirmLabel: 'Keluar',
      danger: false,
    );
    if (ok) AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < Responsive.mobileMax;
    final desktop = width >= Responsive.desktopMin;

    return Scaffold(
      body: Row(children: [
        if (!mobile) _sidebar(compact: !desktop),
        Expanded(
          child: Column(children: [
            if (mobile) _topBar(),
            Expanded(child: IndexedStack(index: selected, children: pages)),
          ]),
        ),
      ]),
      bottomNavigationBar: mobile
          ? DecoratedBox(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
              child: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: [
                  for (int i = 0; i < titles.length; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      selectedIcon: Icon(iconsActive[i]),
                      label: titles[i],
                    ),
                ],
              ),
            )
          : null,
    );
  }

  // ------------------------------------------------------------------ top bar (mobile)

  Widget _topBar() {
    final user = AuthService.instance.user.value;
    final name = user?.name ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        const BrandMark(size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titles[selected],
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppTheme.ink),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Akun',
          offset: const Offset(0, 44),
          onSelected: (v) {
            if (v == 'logout') _logout();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Masuk sebagai', style: TextStyle(fontSize: 11.5, color: AppTheme.muted)),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
              ]),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, size: 20, color: AppTheme.danger),
                SizedBox(width: 10),
                Text('Keluar', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          child: _Avatar(initial: initial, size: 36),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------ sidebar

  Widget _sidebar({required bool compact}) => Container(
        width: compact ? 80 : 252,
        color: AppTheme.sidebar,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 0 : 20, 22, compact ? 0 : 16, 22),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const BrandMark(size: 44, onDark: true),
                  if (!compact) ...const [
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('MemoIn',
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
                        SizedBox(height: 1),
                        Text('Monitoring Memo Gangguan',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.sidebarText, fontSize: 11.5)),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: .12)),
            const SizedBox(height: 16),
            if (!compact)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 0, 8),
                child: Text('Menu', style: TextStyle(color: AppTheme.sidebarMuted, fontSize: 12)),
              ),
            for (int i = 0; i < titles.length; i++) _navItem(i, compact),
            const Spacer(),
            Divider(height: 1, color: Colors.white.withValues(alpha: .12)),
            _userBlock(compact),
          ]),
        ),
      );

  Widget _userBlock(bool compact) {
    final name = AuthService.instance.user.value?.name ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: IconButton(
          tooltip: 'Logout${name.isEmpty ? '' : ' ($name)'}',
          onPressed: _logout,
          style: IconButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.logout, size: 24),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _Avatar(initial: initial, size: 38, onDark: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Masuk sebagai', style: TextStyle(color: Color(0xFF9DB9E8), fontSize: 11.5)),
              Text(name.isEmpty ? '-' : name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          hoverColor: Colors.white.withValues(alpha: .08),
          onTap: _logout,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              Icon(Icons.logout, size: 21, color: Colors.white),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _navItem(int i, bool compact) {
    final active = selected == i;
    final fg = active ? Colors.white : AppTheme.sidebarText;
    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 46,
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
      decoration: BoxDecoration(
        color: active ? AppTheme.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Row(
        mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(active ? iconsActive[i] : icons[i], size: 23, color: fg),
          if (!compact) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Text(titles[i],
                  style: TextStyle(color: fg, fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ),
            if (active)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppTheme.yellow, shape: BoxShape.circle),
              ),
          ],
        ],
      ),
    );
    final tile = InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      hoverColor: Colors.white.withValues(alpha: .08),
      onTap: () => setState(() => selected = i),
      child: item,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: compact ? Tooltip(message: titles[i], child: tile) : tile,
    );
  }
}

/// Avatar inisial. [onDark] = lingkaran putih transparan untuk sidebar biru.
class _Avatar extends StatelessWidget {
  final String initial;
  final double size;
  final bool onDark;
  const _Avatar({required this.initial, required this.size, this.onDark = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: .16) : AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: Text(initial,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * .4)),
      );
}
