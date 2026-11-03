import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/memo_options.dart';
import '../models/meter_stok.dart';
import '../services/memo_service.dart';
import '../services/meter_stok_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/dialog_frame.dart';

class StokMeterScreen extends StatefulWidget {
  const StokMeterScreen({super.key});
  @override
  State<StokMeterScreen> createState() => _StokMeterScreenState();
}

class _StokMeterScreenState extends State<StokMeterScreen> {
  final service = MeterStokService();
  List<MeterStok> items = [];
  bool loading = true;
  String search = '', filter = 'Semua';

  void _reload() => load();

  @override
  void initState() {
    super.initState();
    MemoService.changes.addListener(_reload);
    load();
  }

  @override
  void dispose() {
    MemoService.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await service.getAvailable();
      if (mounted) setState(() => items = d);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<MeterStok> get filtered => items
      .where((m) =>
          (filter == 'Semua' || m.jenisPelanggan == filter) &&
          (search.isEmpty || m.nomorMeter.toLowerCase().contains(search.toLowerCase())))
      .toList();

  Future<void> edit([MeterStok? old]) async {
    final result = await showDialog<MeterStok>(context: context, builder: (_) => _StokDialog(old: old));
    if (result == null) return;
    try {
      await service.save(result);
      await load();
      if (mounted) showSuccess(context, old == null ? 'Stok meter ditambahkan' : 'Stok meter diperbarui');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> delete(MeterStok item) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus stok meter?',
      message: 'Nomor ${item.nomorMeter} akan dihapus dari stok.',
    );
    if (!ok) return;
    try {
      await service.delete(item.id);
      await load();
      if (mounted) showSuccess(context, 'Nomor meter dihapus');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String _date(MeterStok x) => x.createdAt.isEmpty ? '-' : x.createdAt.split('T').first;

  List<Widget> _actions(MeterStok x) => [
        IconAction(icon: Icons.edit_outlined, color: AppTheme.accent, tooltip: 'Edit', onTap: () => edit(x)),
        IconAction(icon: Icons.delete_outline, color: AppTheme.danger, tooltip: 'Hapus', onTap: () => delete(x)),
      ];

  static const _cols = ['No', 'Nomor Meter', 'Jenis Pelanggan', 'Ditambahkan', 'Aksi'];

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    final pasca = items.where((x) => x.jenisPelanggan == 'Pascabayar').length;
    final pra = items.where((x) => x.jenisPelanggan == 'Prabayar').length;
    return PageScroll(
      onRefresh: load,
      children: [
        const PageTitle(title: 'Stok Meter', subtitle: 'Nomor meter baru yang tersedia'),
        StatGrid(desktopColumns: 3, children: [
          StatCard(
              label: 'Total Tersedia',
              value: '${items.length}',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.primary,
              loading: loading),
          StatCard(
              label: 'Sisa Pascabayar',
              value: '$pasca',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.success,
              valueColor: AppTheme.success,
              loading: loading),
          StatCard(
              label: 'Sisa Prabayar',
              value: '$pra',
              icon: Icons.bolt_outlined,
              color: const Color(0xFFF59E0B),
              valueColor: const Color(0xFFD97706),
              loading: loading),
        ]),
        const SizedBox(height: 20),
        ToolbarCard(
          search: PillSearch(hint: 'Cari nomor meter...', onChanged: (x) => setState(() => search = x)),
          dropdown: PillDropdown(
            value: filter,
            options: const ['Semua', 'Pascabayar', 'Prabayar'],
            onChanged: (x) => setState(() => filter = x),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => edit(),
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Tambah No Meter'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Daftar Nomor Meter Tersedia',
          subtitle: 'Total ${list.length} nomor meter',
          child: loading
              ? const TableSkeleton(columns: _cols)
              : list.isEmpty
                  ? const EmptyState('Belum ada nomor meter. Tambahkan nomor meter melalui tombol di atas.')
                  : ResponsiveTable(
                      breakpoint: 560,
                      columns: _cols,
                      rows: [
                        for (int i = 0; i < list.length; i++)
                          [
                            Text('${i + 1}'),
                            Text(list[i].nomorMeter, style: const TextStyle(fontWeight: FontWeight.w600)),
                            StatusChip(list[i].jenisPelanggan),
                            Text(_date(list[i])),
                            Row(mainAxisSize: MainAxisSize.min, children: _actions(list[i])),
                          ],
                      ],
                      cardBuilder: (i) => RecordCard(
                        title: list[i].nomorMeter,
                        subtitle: 'Ditambahkan ${_date(list[i])}',
                        badges: [StatusChip(list[i].jenisPelanggan)],
                        actions: _actions(list[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Dialog tambah / edit nomor meter.
class _StokDialog extends StatefulWidget {
  final MeterStok? old;
  const _StokDialog({this.old});
  @override
  State<_StokDialog> createState() => _StokDialogState();
}

class _StokDialogState extends State<_StokDialog> {
  late final TextEditingController no = TextEditingController(text: widget.old?.nomorMeter ?? '');
  late String? type = widget.old?.jenisPelanggan;
  final key = GlobalKey<FormState>();

  @override
  void dispose() {
    no.dispose();
    super.dispose();
  }

  void _submit() {
    if (key.currentState!.validate()) {
      Navigator.pop(context, MeterStok(id: widget.old?.id ?? '', nomorMeter: no.text.trim(), jenisPelanggan: type!));
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
      );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.old == null;
    final options = [...MemoOptions.jenisStok];
    if (type != null && !options.contains(type)) options.insert(0, type!);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DialogHeader(
            title: isNew ? 'Tambah Nomor Meter' : 'Edit Nomor Meter',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Form(
                key: key,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Nomor Meter *'),
                  TextFormField(
                    controller: no,
                    autofocus: true,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nomor meter wajib diisi' : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Jenis Pelanggan *'),
                  DropdownButtonFormField<String>(
                    value: type,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.muted),
                    hint: const Text('Pilih Jenis Pelanggan', style: TextStyle(color: AppTheme.faint, fontSize: 14)),
                    items: options.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (x) => setState(() => type = x),
                    validator: (v) => v == null ? 'Jenis pelanggan wajib dipilih' : null,
                  ),
                ]),
              ),
            ),
          ),
          DialogFooter(children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _submit, child: Text(isNew ? 'Tambah ke Stok' : 'Simpan')),
          ]),
        ]),
      ),
    );
  }
}
