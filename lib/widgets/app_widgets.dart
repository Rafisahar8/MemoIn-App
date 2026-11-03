import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_theme.dart';
import '../core/responsive.dart';

// ---------------------------------------------------------------------------
// Merek
// ---------------------------------------------------------------------------

/// Logo MemoIn dari `assets/Logo.svg`. [onDark] menambah cincin tipis agar tepinya tetap
/// terlihat di atas latar biru (sidebar, panel login).
class BrandMark extends StatelessWidget {
  final double size;
  final bool onDark;
  const BrandMark({super.key, this.size = 36, this.onDark = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .16)),
        foregroundDecoration: onDark
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(size * .16),
                border: Border.all(color: Colors.white.withValues(alpha: .35)),
              )
            : null,
        child: SvgPicture.asset('assets/Logo.svg', width: size, height: size, fit: BoxFit.contain),
      );
}

// ---------------------------------------------------------------------------
// Pesan & dialog
// ---------------------------------------------------------------------------

/// Mengambil teks yang enak dibaca dari sebuah error (termasuk pesan `raise exception` Postgres).
String errorText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is Exception) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
  return e.toString();
}

// ---- Popup status (berhasil / gagal / peringatan / info) ----

enum _Kind { success, error, warning, info }

Color _kindColor(_Kind k) => switch (k) {
      _Kind.success => AppTheme.success,
      _Kind.error => AppTheme.danger,
      _Kind.warning => AppTheme.warning,
      _Kind.info => AppTheme.accent,
    };

IconData _kindIcon(_Kind k) => switch (k) {
      _Kind.success => Icons.check_circle_outline,
      _Kind.error => Icons.error_outline,
      _Kind.warning => Icons.warning_amber_outlined,
      _Kind.info => Icons.info_outline,
    };

/// Popup di tengah layar. Jika [autoCloseMs] diisi, tertutup otomatis (tetap bisa ditutup dengan tombol OK).
class _StatusDialog extends StatefulWidget {
  final _Kind kind;
  final String title, message;
  final Widget? extra;
  final int? autoCloseMs;
  const _StatusDialog(
      {required this.kind, required this.title, required this.message, this.extra, this.autoCloseMs});

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final ms = widget.autoCloseMs;
    if (ms != null) {
      _timer = Timer(Duration(milliseconds: ms), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(widget.kind);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      title: Row(children: [
        Icon(_kindIcon(widget.kind), color: color, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.title)),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.message, style: const TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.45)),
            if (widget.extra != null) ...[const SizedBox(height: 14), widget.extra!],
          ]),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

Future<void> _popup(BuildContext context, _Kind kind, String title, String message,
        {Widget? extra, int? autoCloseMs}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _StatusDialog(
          kind: kind, title: title, message: message, extra: extra, autoCloseMs: autoCloseMs),
    );

/// Popup gagal (tetap tampil sampai ditutup).
void showError(BuildContext context, Object e) => _popup(context, _Kind.error, 'Terjadi Kesalahan', errorText(e));

/// Popup berhasil (menutup sendiri setelah ±2 detik).
void showSuccess(BuildContext context, String text) =>
    _popup(context, _Kind.success, 'Berhasil', text, autoCloseMs: 2200);

/// Popup peringatan, mis. data kosong.
void showWarning(BuildContext context, String text) => _popup(context, _Kind.warning, 'Perhatian', text);

/// Menampilkan dialog loading selama [task] berjalan, lalu menutupnya (juga saat error).
Future<T> withLoading<T>(BuildContext context, String text, Future<T> Function() task) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 22, 28, 22),
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
          const SizedBox(width: 16),
          Flexible(child: Text(text, style: const TextStyle(color: AppTheme.ink, fontSize: 14))),
        ]),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    nav.pop();
  }
}

Widget _detailRow(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted))),
        Expanded(
            child: SelectableText(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppTheme.ink))),
      ]),
    );

Widget _detailBox(List<Widget> rows) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.fieldLocked,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );

/// Pemberitahuan bahwa file hasil export sudah tersimpan di folder Download.
Future<void> showFileSavedDialog(BuildContext context,
        {required String fileName, required String path, int? total}) =>
    _popup(
      context,
      _Kind.success,
      'Export Berhasil',
      'File Excel sudah tersimpan di folder Download.',
      extra: _detailBox([
        _detailRow('Nama file', fileName),
        if (total != null) _detailRow('Jumlah data', '$total memo'),
        if (path.isNotEmpty) _detailRow('Lokasi', path),
      ]),
    );

/// Ringkasan hasil import data DIL.
Future<void> showImportResultDialog(BuildContext context,
    {required String fileName, required int imported, required int skipped, required int failed, String? firstError}) {
  final allFailed = imported == 0;
  return _popup(
    context,
    allFailed ? _Kind.error : (failed > 0 ? _Kind.warning : _Kind.success),
    allFailed ? 'Import Gagal' : 'Import Selesai',
    allFailed ? 'Tidak ada data pelanggan yang berhasil diimport.' : 'Data DIL berhasil dimasukkan ke database.',
    extra: _detailBox([
      _detailRow('File', fileName),
      _detailRow('Berhasil', '$imported pelanggan', color: AppTheme.success),
      if (skipped > 0) _detailRow('Dilewati', '$skipped baris (ID kosong)'),
      if (failed > 0) _detailRow('Gagal', '$failed baris', color: AppTheme.danger),
      if (firstError != null) _detailRow('Penyebab', firstError),
    ]),
  );
}

/// Dialog konfirmasi (mis. hapus). Mengembalikan true jika dikonfirmasi.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(message, style: const TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.45)),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: danger ? AppTheme.danger : AppTheme.primary),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------------------
// Judul halaman
// ---------------------------------------------------------------------------

class PageTitle extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageTitle({super.key, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: LayoutBuilder(builder: (context, box) {
          final narrow = box.maxWidth < 620;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: narrow ? 21 : 26,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                      letterSpacing: -.4,
                      height: 1.2)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.4)),
            ],
          );
          if (action == null) return text;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 14), action!],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: text), const SizedBox(width: 16), action!],
          );
        }),
      );
}

// ---------------------------------------------------------------------------
// Kartu statistik
// ---------------------------------------------------------------------------

/// Kartu angka ringkas: label dan angka besar di kiri, ikon berwarna dalam petak lembut di kanan.
class StatCard extends StatelessWidget {
  final String label, value, caption;
  final IconData icon;
  final Color color;

  /// Warna angka (default: ink).
  final Color? valueColor;

  /// Tampilkan placeholder abu-abu saat data masih dimuat.
  final bool loading;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption = '',
    this.valueColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // Layar sempit: petak ikon dan angka dikecilkan supaya label tidak terjepit.
        final small = box.maxWidth < 220;
        return Container(
          padding: EdgeInsets.fromLTRB(small ? 14 : 20, 18, small ? 12 : 18, 18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: small ? 12.5 : 13.5, color: AppTheme.muted, height: 1.25)),
                  const SizedBox(height: 10),
                  if (loading)
                    const SkeletonBar(width: 48, height: 32, radius: 8)
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: small ? 26 : 32,
                              fontWeight: FontWeight.w600,
                              color: valueColor ?? AppTheme.ink,
                              letterSpacing: -.5,
                              height: 1.1)),
                    ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(caption, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ],
                ],
              ),
            ),
            SizedBox(width: small ? 8 : 12),
            Container(
              width: small ? 38 : 48,
              height: small ? 38 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(small ? AppTheme.radiusControl : AppTheme.radius),
              ),
              child: Icon(icon, size: small ? 21 : 26, color: color),
            ),
          ]),
        );
      });
}

/// Grid statistik yang menyesuaikan jumlah kolom dengan lebar yang tersedia.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  const StatGrid({super.key, required this.children, this.desktopColumns = 4});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (children.isEmpty) return const SizedBox.shrink();
        const gap = 16.0;
        final w = box.maxWidth;
        int cols;
        if (w >= 860) {
          cols = desktopColumns;
        } else if (w >= 300) {
          cols = 2;
        } else {
          cols = 1;
        }
        cols = cols.clamp(1, children.length).toInt();
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: itemW, child: c)],
        );
      });
}

// ---------------------------------------------------------------------------
// Kartu seksi
// ---------------------------------------------------------------------------

class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// Aksi kecil di ujung kanan judul kartu (mis. tombol hapus semua).
  final Widget? corner;
  const SectionCard(
      {super.key, required this.title, this.subtitle, this.trailing, this.corner, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (context, box) {
                final wide = box.maxWidth >= 640;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
                    ],
                  ],
                );
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: heading),
                    if (trailing != null && wide) ...[const SizedBox(width: 12), trailing!],
                    if (corner != null) ...[const SizedBox(width: 8), corner!],
                  ]),
                  if (trailing != null && !wide) ...[const SizedBox(height: 12), trailing!],
                ]);
              }),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

/// Tombol ikon "hapus semua data" untuk ujung kanan judul tabel. Memerah saat disorot.
class CornerDeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  final String tooltip;
  const CornerDeleteButton({super.key, required this.onTap, this.tooltip = 'Hapus semua data'});
  @override
  State<CornerDeleteButton> createState() => _CornerDeleteButtonState();
}

class _CornerDeleteButtonState extends State<CornerDeleteButton> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hover = true),
          onExit: (_) => setState(() => hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hover ? AppTheme.danger.withValues(alpha: .08) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(Icons.delete_sweep_outlined, size: 22, color: hover ? AppTheme.danger : AppTheme.muted),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Chip status
// ---------------------------------------------------------------------------

class StatusChip extends StatelessWidget {
  final String text;
  final Color? color;
  const StatusChip(this.text, {super.key, this.color});

  Color get _color {
    if (color != null) return color!;
    switch (text) {
      case 'Selesai':
        return AppTheme.success;
      case 'Belum Selesai':
        return AppTheme.warning;
      case 'MCB':
        return AppTheme.violet;
      case 'Meter':
        return AppTheme.accent;
      case 'Prabayar':
        return AppTheme.warning;
      case 'Pascabayar':
        return AppTheme.info;
      default:
        return AppTheme.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .11), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c, height: 1.3)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Keadaan kosong
// ---------------------------------------------------------------------------

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppTheme.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: AppTheme.accent),
            ),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, fontSize: 13.5)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Bar filter (pencarian + dropdown)
// ---------------------------------------------------------------------------

class FilterBar extends StatelessWidget {
  final String hint, filterLabel, filterValue;
  final List<String> options;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;
  const FilterBar({
    super.key,
    required this.hint,
    required this.onSearch,
    required this.filterLabel,
    required this.filterValue,
    required this.options,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final search = TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: hint),
          onChanged: onSearch,
        );
        final dropdown = DropdownButtonFormField<String>(
          value: filterValue,
          isExpanded: true,
          decoration: InputDecoration(labelText: filterLabel),
          items: options.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (x) => onFilter(x ?? options.first),
        );
        if (box.maxWidth < 560) {
          return Column(children: [search, const SizedBox(height: 10), dropdown]);
        }
        return Row(children: [
          Expanded(child: search),
          const SizedBox(width: 12),
          SizedBox(width: 200, child: dropdown),
        ]);
      });
}

// ---------------------------------------------------------------------------
// Tombol ikon kecil untuk aksi baris
// ---------------------------------------------------------------------------

/// Tombol ikon polos: abu-abu saat diam, berwarna ([color]) saat disorot.
class IconAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const IconAction({super.key, required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  State<IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<IconAction> {
  bool hover = false;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hover = true),
          onExit: (_) => setState(() => hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: hover ? widget.color.withValues(alpha: .09) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(widget.icon, size: 21, color: hover ? widget.color : AppTheme.muted),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Tabel responsif: DataTable di layar lebar, daftar kartu di layar sempit
// ---------------------------------------------------------------------------

class ResponsiveTable extends StatefulWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final Widget Function(int index) cardBuilder;
  final double breakpoint;
  const ResponsiveTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.cardBuilder,
    this.breakpoint = 700,
  });

  @override
  State<ResponsiveTable> createState() => _ResponsiveTableState();
}

class _ResponsiveTableState extends State<ResponsiveTable> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < widget.breakpoint) {
          return Column(children: [
            for (var i = 0; i < widget.rows.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: widget.cardBuilder(i)),
          ]);
        }
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth - 2),
                child: DataTable(
                  columns: [for (final c in widget.columns) DataColumn(label: Text(c))],
                  rows: [
                    for (final r in widget.rows) DataRow(cells: [for (final w in r) DataCell(w)]),
                  ],
                ),
              ),
            ),
          ),
        );
      });
}

/// Kartu satu record untuk tampilan mobile.
class RecordCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final Map<String, String> fields;
  final List<Widget> actions;
  const RecordCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.fields = const {},
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.isEmpty ? '-' : title,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                ],
              ]),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(width: 8),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: badges),
            ],
          ]),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final e in fields.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 104,
                    child: Text(e.key, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                  ),
                  Expanded(
                    child: Text(e.value.isEmpty ? '-' : e.value,
                        style: const TextStyle(fontSize: 13, color: AppTheme.ink)),
                  ),
                ]),
              ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ]),
      );
}

// ---------------------------------------------------------------------------
// Kerangka halaman: padding responsif, lebar konten maksimum, tarik-untuk-muat-ulang
// ---------------------------------------------------------------------------

class PageScroll extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  const PageScroll({super.key, required this.onRefresh, required this.children});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(builder: (context, box) {
          final pad = Responsive.pagePadding(box.maxWidth);
          const maxContent = 1400.0;
          final extra = box.maxWidth > maxContent ? (box.maxWidth - maxContent) / 2 : 0.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad + extra, pad + 4, pad + extra, pad + 16),
            children: children,
          );
        }),
      );
}

// ---------------------------------------------------------------------------
// Tanggal: tampilan dd/mm/yyyy, penyimpanan yyyy-mm-dd
// ---------------------------------------------------------------------------

String fmtDate(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

DateTime? parseDate(String s) => s.trim().isEmpty ? null : DateTime.tryParse(s.trim());

/// Tanggal tersimpan (yyyy-mm-dd) -> dd/mm/yyyy. Jika gagal diparse, dikembalikan apa adanya.
String showDateStr(String iso) {
  final d = parseDate(iso);
  return d == null ? iso : fmtDate(d);
}

/// [minDate]: tanggal sebelum ini tidak bisa dipilih (dipakai untuk kolom tanggal "sesudah").
Future<DateTime?> pickDate(BuildContext context, DateTime? initial, {DateTime? minDate}) {
  final first = minDate == null ? DateTime(2000) : DateTime(minDate.year, minDate.month, minDate.day);
  var init = initial ?? DateTime.now();
  if (init.isBefore(first)) init = first;
  return showDatePicker(context: context, initialDate: init, firstDate: first, lastDate: DateTime(2100));
}

/// Kotak tanggal bergaya input: placeholder `dd/mm/yyyy` + ikon kalender di kanan.
class DateBox extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const DateBox({super.key, required this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        onTap: onTap,
        child: Container(
          height: AppTheme.controlHeight,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AppTheme.borderStrong),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value == null ? 'dd/mm/yyyy' : fmtDate(value),
                style: TextStyle(fontSize: 14, color: value == null ? AppTheme.faint : AppTheme.ink),
              ),
            ),
            if (onClear != null && value != null)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: AppTheme.muted),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.calendar_month_outlined, size: 21, color: AppTheme.muted),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Placeholder memuat data (skeleton)
// ---------------------------------------------------------------------------

class SkeletonBar extends StatelessWidget {
  final double? width;
  final double height, radius;
  const SkeletonBar({super.key, this.width, this.height = 14, this.radius = 20});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE9EEF5), borderRadius: BorderRadius.circular(radius)),
      );
}

/// Tabel kerangka (header kolom + baris abu-abu) selama data dimuat.
class TableSkeleton extends StatelessWidget {
  final List<String> columns;
  final int rows;
  const TableSkeleton({super.key, required this.columns, this.rows = 6});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: AppTheme.surfaceMuted,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final c in columns)
                Expanded(
                  child: Text(c,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.body)),
                ),
            ]),
          ),
          for (int i = 0; i < rows; i++)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
              child: Row(children: [
                for (int j = 0; j < columns.length; j++)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SkeletonBar(width: j == 0 ? 20 : (j % 3 == 0 ? 44 : 90), height: j == 0 ? 16 : 12),
                    ),
                  ),
              ]),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Toolbar: pencarian + dropdown + tombol aksi (langsung di atas latar halaman)
// ---------------------------------------------------------------------------

/// Kolom pencarian. Bentuk dan warna mengikuti tema input (sama dengan semua input lain).
class PillSearch extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const PillSearch({super.key, required this.hint, this.controller, this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppTheme.controlHeight,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 22),
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      );
}

/// Dropdown filter. Nilai 'Semua' ditampilkan sebagai "Semua Jenis".
class PillDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const PillDropdown({super.key, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppTheme.controlHeight,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.muted),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.filter_alt_outlined, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 14),
          ),
          items: [
            for (final x in options)
              DropdownMenuItem(value: x, child: Text(x == 'Semua' ? 'Semua Jenis' : x)),
          ],
          onChanged: (x) => onChanged(x ?? options.first),
        ),
      );
}

/// Tombol hijau "Export Excel".
class ExportButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const ExportButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
        onPressed: onPressed,
        icon: const Icon(Icons.file_download_outlined, size: 20),
        label: const Text('Export Excel'),
      );
}

/// Baris toolbar. Lebar: [search] melebar, lalu [dropdown], [middle], [actions] sebaris.
/// Sempit: [search] dan [dropdown] satu baris/kolom sendiri, sisanya membungkus ke bawah.
class ToolbarCard extends StatelessWidget {
  final Widget search;
  final Widget? dropdown;
  final List<Widget> middle;
  final List<Widget> actions;
  final double singleRowMin;
  const ToolbarCard({
    super.key,
    required this.search,
    this.dropdown,
    this.middle = const [],
    this.actions = const [],
    this.singleRowMin = 900,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final rest = [...middle, ...actions];
        if (box.maxWidth >= singleRowMin) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: search),
            if (dropdown != null) ...[const SizedBox(width: 12), SizedBox(width: 190, child: dropdown)],
            for (final w in rest) ...[const SizedBox(width: 12), w],
          ]);
        }
        final narrow = box.maxWidth < 560;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (dropdown == null || narrow) ...[
            search,
            if (dropdown != null) ...[const SizedBox(height: 10), dropdown!],
          ] else
            Row(children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 190, child: dropdown),
            ]),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: rest),
          ],
        ]);
      });
}
