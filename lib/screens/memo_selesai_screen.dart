import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/memo.dart';
import '../services/export_service.dart';
import '../services/memo_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/memo_detail_dialog.dart';
import '../widgets/memo_form_dialog.dart';
import '../widgets/memo_table.dart';

class MemoSelesaiScreen extends StatefulWidget {
  const MemoSelesaiScreen({super.key});
  @override
  State<MemoSelesaiScreen> createState() => _MemoSelesaiScreenState();
}

class _MemoSelesaiScreenState extends State<MemoSelesaiScreen> {
  final service = MemoService();
  final searchCtrl = TextEditingController();
  List<Memo> memos = [];
  bool loading = true;

  // Filter yang sedang diterapkan (berubah saat tombol Cari ditekan).
  String search = '', jenis = 'Semua';
  DateTime? from, to;

  // Isian tanggal yang belum diterapkan.
  DateTime? pFrom, pTo;

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
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await service.getAll();
      if (mounted) setState(() => memos = d.where((m) => m.status == 'Selesai').toList());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void apply() => setState(() {
        search = searchCtrl.text.trim();
        from = pFrom;
        to = pTo;
      });

  void reset() {
    searchCtrl.clear();
    setState(() {
      search = '';
      jenis = 'Semua';
      from = to = pFrom = pTo = null;
    });
  }

  List<Memo> get filtered {
    final q = search.toLowerCase();
    return memos.where((m) {
      if (jenis != 'Semua' && m.jenisMemo != jenis) return false;
      if (q.isNotEmpty &&
          ![m.idPelanggan, m.namaPelanggan, m.nomorMemo, m.tanggalMemo, showDateStr(m.tanggalMemo)]
              .any((s) => s.toLowerCase().contains(q))) {
        return false;
      }
      if (from != null || to != null) {
        final d = parseDate(m.tanggalMemo);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (from != null && day.isBefore(DateTime(from!.year, from!.month, from!.day))) return false;
        if (to != null && day.isAfter(DateTime(to!.year, to!.month, to!.day))) return false;
      }
      return true;
    }).toList();
  }

  Future<void> edit(Memo m) async {
    final result = await showDialog<Memo>(context: context, builder: (_) => MemoFormDialog(initial: m));
    if (result == null) return;
    try {
      await service.save(result);
      await load();
      if (mounted) showSuccess(context, 'Memo diperbarui');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> deleteAll() async {
    if (memos.isEmpty) {
      showWarning(context, 'Tidak ada data memo untuk dihapus.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Hapus semua data?',
      message: '${memos.length} memo selesai akan dihapus permanen. '
          'Ringkasan yang sudah disimpan di Evaluasi tidak terpengaruh.',
      confirmLabel: 'Hapus Semua',
    );
    if (!ok) return;
    try {
      final n = memos.length;
      await service.deleteMany(memos.map((m) => m.id).toList());
      await load();
      if (mounted) showSuccess(context, '$n memo berhasil dihapus');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void detail(Memo m) => showDialog(context: context, builder: (_) => MemoDetailDialog(memo: m));

  Future<void> export() async {
    final data = filtered;
    if (data.isEmpty) {
      showWarning(context, 'Tidak ada data memo untuk diexport.');
      return;
    }
    try {
      final r = await withLoading(
          context, 'Membuat file Excel...', () => exportMemosToExcel(data, filePrefix: 'memo-selesai'));
      if (mounted) await showFileSavedDialog(context, fileName: r.fileName, path: r.path, total: data.length);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pick(bool isFrom) async {
    final d = await pickDate(context, isFrom ? pFrom : pTo, minDate: isFrom ? null : pFrom);
    if (d == null) return;
    setState(() {
      if (isFrom) {
        pFrom = d;
        if (pTo != null && pTo!.isBefore(d)) pTo = d;
      } else {
        pTo = d;
      }
    });
  }

  Widget _dateRange() => Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 10),
        SizedBox(width: 160, child: DateBox(value: pFrom, onTap: () => _pick(true))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('s/d', style: TextStyle(color: AppTheme.muted)),
        ),
        SizedBox(width: 160, child: DateBox(value: pTo, onTap: () => _pick(false))),
      ]);

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return PageScroll(
      onRefresh: load,
      children: [
        const PageTitle(title: 'Memo Selesai', subtitle: 'Arsip memo dengan status selesai'),
        ToolbarCard(
          singleRowMin: 1280,
          search: PillSearch(
            controller: searchCtrl,
            hint: 'Cari ID Pelanggan, Nama, Nomor Memo...',
            onSubmitted: (_) => apply(),
          ),
          dropdown: PillDropdown(
            value: jenis,
            options: const ['Semua', 'Meter', 'MCB'],
            onChanged: (x) => setState(() => jenis = x),
          ),
          middle: [_dateRange()],
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: apply,
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Cari'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: reset,
              icon: const Icon(Icons.restart_alt, size: 20),
              label: const Text('Reset'),
            ),
            ExportButton(onPressed: loading ? null : export),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Daftar Memo Selesai',
          corner: CornerDeleteButton(onTap: deleteAll),
          subtitle: loading ? 'Memuat data memo...' : 'Total ${list.length} memo selesai',
          trailing: const Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 8),
          ]),
          child: MemoTable(
            list: list,
            loading: loading,
            onDetail: detail,
            onEdit: edit,
            emptyText: 'Belum ada memo selesai.',
            emptyIcon: Icons.assignment_turned_in_outlined,
          ),
        ),
      ],
    );
  }
}
