import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_theme.dart';
import '../models/memo.dart';
import '../services/export_service.dart';
import '../services/memo_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/memo_detail_dialog.dart';
import '../widgets/memo_form_dialog.dart';
import '../widgets/memo_table.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final service = MemoService();
  List<Memo> memos = [];
  bool loading = true;
  String search = '', jenis = 'Semua';

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
      final data = await service.getAll();
      if (mounted) {
        setState(() {
          memos = data;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  List<Memo> get filtered => memos.where((m) {
        final q = search.trim().toLowerCase();
        final match = q.isEmpty ||
            [m.idPelanggan, m.nomorMemo, m.tanggalMemo, showDateStr(m.tanggalMemo)]
                .any((s) => s.toLowerCase().contains(q));
        return match && (jenis == 'Semua' || m.jenisMemo == jenis) && m.status == 'Belum Selesai';
      }).toList();

  Future<void> addOrEdit([Memo? old]) async {
    final result = await showDialog<Memo>(
      context: context,
      builder: (_) => MemoFormDialog(initial: old),
    );
    if (result == null) return;
    try {
      await service.save(result);
      await load();
      if (mounted) {
        showSuccess(context,
            old == null ? 'Memo berhasil ditambahkan' : 'Memo berhasil diperbarui');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> delete(Memo m) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus memo?',
      message: 'Memo ${m.nomorMemo} akan dihapus permanen.',
    );
    if (!ok) return;
    try {
      await service.delete(m.id);
      await load();
      if (mounted) showSuccess(context, 'Memo berhasil dihapus');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> deleteAll() async {
    final ids = memos.where((m) => m.status == 'Belum Selesai').map((m) => m.id).toList();
    if (ids.isEmpty) {
      showWarning(context, 'Tidak ada data memo untuk dihapus.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Hapus semua data?',
      message: '${ids.length} memo belum selesai di Dashboard akan dihapus permanen. '
          'Ringkasan yang sudah disimpan di Evaluasi tidak terpengaruh.',
      confirmLabel: 'Hapus Semua',
    );
    if (!ok) return;
    try {
      await service.deleteMany(ids);
      await load();
      if (mounted) showSuccess(context, '${ids.length} memo berhasil dihapus');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void detail(Memo m) => showDialog(context: context, builder: (_) => MemoDetailDialog(memo: m));

  Future<void> importDil() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (picked == null || picked.files.single.bytes == null) return;
      final fileName = picked.files.single.name;
      final bytes = picked.files.single.bytes!;
      if (!mounted) return;

      final result = await withLoading(context, 'Mengimport data DIL...', () async {
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) throw Exception('File Excel kosong');
        final rows = excel.tables.values.first.rows;
        if (rows.length < 2) throw Exception('File Excel tidak memiliki data');

        String norm(dynamic v) => (v?.value ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('_', '');
        final headers = rows.first.map((c) => norm(c)).toList();
        int idx(List<String> aliases) => headers.indexWhere((h) => aliases.contains(h));

        final idIdx = idx(['idpel', 'idpelanggan']);
        final tarifIdx = idx(['tarif']);
        final dayaIdx = idx(['daya']);
        final meterIdx = idx(['nometerbaru', 'nomormeter', 'nomormeterlama']);

        if (idIdx < 0) throw Exception('Kolom IDPEL tidak ditemukan.');

        final client = Supabase.instance.client;
        int imported = 0, skipped = 0, failed = 0;
        String? firstError;
        for (final row in rows.skip(1)) {
          String val(int i) => i >= 0 && i < row.length ? (row[i]?.value ?? '').toString().trim() : '';
          final id = val(idIdx);
          if (id.isEmpty) {
            skipped++;
            continue;
          }
          try {
            await client.from('pelanggan').upsert({
              'id_pel': id,
              'jenis_pelanggan': 'Pascabayar',
              'tarif': tarifIdx < 0 ? '' : val(tarifIdx),
              'daya': dayaIdx < 0 ? '' : val(dayaIdx),
              'nomor_meter_lama': meterIdx < 0 ? '' : val(meterIdx)
            }, onConflict: 'id_pel');
            imported++;
          } catch (e) {
            failed++;
            firstError ??= errorText(e);
          }
        }
        return (imported: imported, skipped: skipped, failed: failed, firstError: firstError);
      });

      MemoService.notifyChanged();
      if (mounted) {
        await showImportResultDialog(context,
            fileName: fileName,
            imported: result.imported,
            skipped: result.skipped,
            failed: result.failed,
            firstError: result.firstError);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> export() async {
    final data = filtered;
    if (data.isEmpty) {
      showWarning(context, 'Tidak ada data memo untuk diexport.');
      return;
    }
    try {
      final r = await withLoading(
          context, 'Membuat file Excel...', () => exportMemosToExcel(data, filePrefix: 'dashboard-memo'));
      if (mounted) await showFileSavedDialog(context, fileName: r.fileName, path: r.path, total: data.length);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mcbOpen = memos.where((m) => m.jenisMemo == 'MCB' && m.status == 'Belum Selesai').length;
    final meterOpen = memos.where((m) => m.jenisMemo == 'Meter' && m.status == 'Belum Selesai').length;
    final list = filtered;

    return PageScroll(
      onRefresh: load,
      children: [
        const PageTitle(title: 'Dashboard Memo', subtitle: 'Manajemen Memo Gangguan'),
        StatGrid(desktopColumns: 3, children: [
          StatCard(
              label: 'Total Memo',
              value: '${memos.length}',
              icon: Icons.assignment_outlined,
              color: AppTheme.primary,
              loading: loading),
          StatCard(
              label: 'MCB Belum Selesai',
              value: '$mcbOpen',
              icon: Icons.toggle_on_outlined,
              color: const Color(0xFFF59E0B),
              loading: loading),
          StatCard(
              label: 'Meter Belum Selesai',
              value: '$meterOpen',
              icon: Icons.electric_meter_outlined,
              color: const Color(0xFF8B5CF6),
              loading: loading),
        ]),
        const SizedBox(height: 20),
        ToolbarCard(
          search: PillSearch(
            hint: 'Cari ID Pelanggan, Nomor Memo dan Tanggal Memo',
            onChanged: (x) => setState(() => search = x),
          ),
          dropdown: PillDropdown(
            value: jenis,
            options: const ['Semua', 'Meter', 'MCB'],
            onChanged: (x) => setState(() => jenis = x),
          ),
          actions: [
            ExportButton(onPressed: loading ? null : export),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: importDil,
              icon: const Icon(Icons.upload_file_outlined, size: 20),
              label: const Text('Input Data DIL'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => addOrEdit(),
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Tambah Memo'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Daftar Memo',
          corner: CornerDeleteButton(onTap: deleteAll),
          subtitle: loading ? 'Memuat data memo...' : 'Total ${list.length} memo belum selesai',
          child: MemoTable(
            list: list,
            loading: loading,
            onDetail: detail,
            onEdit: addOrEdit,
            onDelete: delete,
            emptyText: 'Tidak ada memo yang sesuai.',
          ),
        ),
      ],
    );
  }
}
