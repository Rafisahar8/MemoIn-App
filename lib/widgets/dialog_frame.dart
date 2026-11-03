import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/responsive.dart';

/// Header dialog yang seragam: judul (+ keterangan), aksesori opsional, tombol tutup.
class DialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;

  /// false = tombol tutup dinonaktifkan (mis. saat sedang menyimpan).
  final bool closable;

  /// true = pita biru dengan teks putih (dipakai dialog memo); false = putih bergaris tipis.
  final bool filled;
  const DialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.closable = true,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 12, 14),
        decoration: BoxDecoration(
          color: filled ? AppTheme.sidebar : null,
          border: filled ? null : const Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: filled ? Colors.white : AppTheme.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: filled ? AppTheme.sidebarText : AppTheme.muted)),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!, const SizedBox(width: 4)],
          IconButton(
            tooltip: 'Tutup',
            onPressed: closable ? (onClose ?? () => Navigator.maybePop(context)) : null,
            style: IconButton.styleFrom(
              foregroundColor: filled ? Colors.white : AppTheme.muted,
              disabledForegroundColor: filled ? AppTheme.sidebarMuted : AppTheme.faint,
            ),
            icon: const Icon(Icons.close, size: 22),
          ),
        ]),
      );
}

/// Footer dialog: garis tipis di atas, tombol rata kanan.
class DialogFooter extends StatelessWidget {
  final List<Widget> children;
  const DialogFooter({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: children),
      );
}

/// Kerangka dialog generik: header, isi yang bisa di-scroll, dan footer aksi.
/// Otomatis hampir selebar layar pada ponsel.
class DialogFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;
  final Widget? headerTrailing;

  const DialogFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 560,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < Responsive.mobileMax;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 24, vertical: mobile ? 16 : 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: size.height * 0.92),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DialogHeader(title: title, subtitle: subtitle, trailing: headerTrailing),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(mobile ? 16 : 24, 16, mobile ? 16 : 24, 16),
              child: body,
            ),
          ),
          if (actions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 24, vertical: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
              child: Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
            ),
        ]),
      ),
    );
  }
}

/// Grid yang membagi lebar tersedia menjadi 1-3 kolom sesuai ukuran dialog.
class FormGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const FormGrid({super.key, required this.children, this.gap = 16});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final cols = w >= 720 ? 3 : (w >= 440 ? 2 : 1);
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: itemW, child: c)],
        );
      });
}

/// Seksi dengan judul kecil + [FormGrid].
class FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const FormSection({super.key, required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink)),
            const SizedBox(width: 10),
            const Expanded(child: Divider(height: 1)),
          ]),
          const SizedBox(height: 12),
          FormGrid(children: children),
        ]),
      );
}

/// Panel seksi bergaris tipis: pita judul biru muda + ikon, lalu isi.
/// Dipakai di form dan detail memo.
class SectionPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;
  const SectionPanel({super.key, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: AppTheme.accentSoft,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(children: [
              Icon(icon, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(18), child: body),
        ]),
      );
}

/// Label di atas, nilai di bawah. [locked] = kotak abu-abu dengan ikon gembok (baca-saja).
class InfoField extends StatelessWidget {
  final String label, value;
  final bool locked;
  const InfoField(this.label, this.value, {super.key, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(value.trim().isEmpty ? '-' : value, style: const TextStyle(fontSize: 14, color: AppTheme.ink));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
      const SizedBox(height: 6),
      locked
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.fieldLocked,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline, size: 16, color: AppTheme.muted),
                const SizedBox(width: 10),
                Expanded(child: text),
              ]),
            )
          : Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: text),
    ]);
  }
}

/// Sub-judul di dalam seksi (mis. "Data Memo").
class SubHeading extends StatelessWidget {
  final String text;
  const SubHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.muted)),
      );
}
