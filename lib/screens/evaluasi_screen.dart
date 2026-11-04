import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../models/memo.dart';
import '../services/memo_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/dialog_frame.dart';

/// Satu baris memo pada evaluasi yang disimpan (snapshot saat disimpan).
class _EvalItem {
  final String idPelanggan, noMeterLama, noMeterBaru, gangguan;
  const _EvalItem({
    required this.idPelanggan,
    required this.noMeterLama,
    required this.noMeterBaru,
    required this.gangguan,
  });

  Map<String, dynamic> toJson() =>
      {'id': idPelanggan, 'lama': noMeterLama, 'baru': noMeterBaru, 'gangguan': gangguan};

  factory _EvalItem.fromJson(Map<String, dynamic> j) => _EvalItem(
        idPelanggan: '${j['id'] ?? ''}',
        noMeterLama: '${j['lama'] ?? ''}',
        noMeterBaru: '${j['baru'] ?? ''}',
        gangguan: '${j['gangguan'] ?? ''}',
      );
}

/// Evaluasi yang disimpan ke riwayat (snapshot saat disimpan, tersimpan di perangkat ini).
class _SavedEval {
  final String id, nama, start, end, dibuat;
  final int jumlah;
  /// ID memo yang ikut dievaluasi (dipakai untuk mencegah menyimpan data yang sama dua kali).
  final List<String> memoIds;
  /// Jenis gangguan dominan (bisa lebih dari satu bila jumlahnya sama) dan jumlah kasus masing-masing.
  final List<String> dominanGangguan;
  final int dominanJumlah;
  /// Rincian memo saat disimpan (ID pelanggan, no meter, gangguan).
  final List<_EvalItem> items;
  const _SavedEval({
    required this.id,
    required this.nama,
    required this.start,
    required this.end,
    required this.dibuat,
    required this.jumlah,
    required this.memoIds,
    required this.dominanGangguan,
    required this.dominanJumlah,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'nama': nama, 'start': start, 'end': end, 'dibuat': dibuat, 'jumlah': jumlah, 'memoIds': memoIds,
        'dominanGangguan': dominanGangguan, 'dominanJumlah': dominanJumlah,
        'items': items.map((e) => e.toJson()).toList(),
      };

  /// Format lama: dominan berupa satu teks, atau hanya ada distribusi `gangguan`.
  static List<String> _dom(Map<String, dynamic> j) {
    final d = j['dominanGangguan'];
    if (d is List) return d.map((e) => '$e').toList();
    if (d is String && d.isNotEmpty && d != '-') return [d];
    final m = j['gangguan'];
    if (m is Map && m.isNotEmpty) {
      final top = m.values.fold<num>(0, (a, v) => (v as num) > a ? v : a);
      return m.entries.where((e) => e.value == top).map((e) => '${e.key}').toList();
    }
    return const [];
  }

  static int _domCount(Map<String, dynamic> j) {
    if (j['dominanJumlah'] is num) return (j['dominanJumlah'] as num).toInt();
    final m = j['gangguan'];
    if (m is Map && m.isNotEmpty) return m.values.fold<num>(0, (a, v) => (v as num) > a ? v : a).toInt();
    return 0;
  }

  factory _SavedEval.fromJson(Map<String, dynamic> j) => _SavedEval(
        id: '${j['id']}',
        nama: '${j['nama']}',
        start: '${j['start']}',
        end: '${j['end']}',
        dibuat: '${j['dibuat'] ?? ''}',
        jumlah: (j['jumlah'] as num? ?? 0).toInt(),
        memoIds: ((j['memoIds'] as List?) ?? const []).map((e) => '$e').toList(),
        dominanGangguan: _dom(j),
        dominanJumlah: _domCount(j),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => _EvalItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

enum _Trend { up, down, same }

class EvaluasiScreen extends StatefulWidget {
  const EvaluasiScreen({super.key});
  @override
  State<EvaluasiScreen> createState() => _EvaluasiScreenState();
}

class _EvaluasiScreenState extends State<EvaluasiScreen> {
  static const _prefsKey = 'evaluasi_tersimpan';
  /// Grafik satu rumpun biru: jenis gangguan dominan biru tua, sisanya biru muda.
  static const _barDominant = Color(0xFF003D99);
  static const _barOther = Color(0x590066CC);

  final service = MemoService();
  List<Memo> all = []; // hanya memo berstatus Selesai
  bool loading = true;

  // Periode bawaan = bulan berjalan.
  static DateTime get _defStart {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  static DateTime get _defEnd {
    final n = DateTime.now();
    return DateTime(n.year, n.month + 1, 0);
  }

  // Periode yang sedang diterapkan, dan isian tanggal yang belum diterapkan.
  late DateTime start = _defStart, end = _defEnd;
  late DateTime pStart = _defStart, pEnd = _defEnd;

  final name = TextEditingController();
  List<_SavedEval> saved = [];
  String? compareA, compareB;
  bool showComparison = false;

  void _reload() => load();

  @override
  void initState() {
    super.initState();
    MemoService.changes.addListener(_reload);
    load();
    _loadSaved();
  }

  @override
  void dispose() {
    MemoService.changes.removeListener(_reload);
    name.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await service.getAll();
      if (mounted) setState(() => all = d.where((m) => m.status == 'Selesai').toList());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------------------------------------------------------------- riwayat tersimpan

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => _SavedEval.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) setState(() => saved = list);
    } catch (_) {
      // Data tersimpan rusak / tidak terbaca: abaikan, mulai dari daftar kosong.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(saved.map((e) => e.toJson()).toList()));
  }

  // ---------------------------------------------------------------- data & analisis

  String iso(DateTime d) => d.toIso8601String().substring(0, 10);
  String fmt(String isoDate) => isoDate.isEmpty ? '-' : showDateStr(isoDate.substring(0, 10));

  List<Memo> get filtered => all.where((m) {
        final dt = parseDate(m.tanggalMemo);
        if (dt == null) return false;
        final day = DateTime(dt.year, dt.month, dt.day);
        return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(DateTime(end.year, end.month, end.day));
      }).toList();

  Map<String, int> freq(Iterable<String> values) {
    final r = <String, int>{};
    for (final v in values) {
      if (v.isNotEmpty && v != 'null') r[v] = (r[v] ?? 0) + 1;
    }
    return r;
  }

  List<MapEntry<String, int>> byCount(Map<String, int> m) =>
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  String mode(Iterable<String> values) {
    final s = byCount(freq(values));
    return s.isEmpty ? '-' : s.first.key;
  }

  /// Jenis gangguan yang jumlahnya tertinggi (bisa lebih dari satu bila sama).
  List<String> dominantsOf(List<MapEntry<String, int>> data) =>
      data.isEmpty ? [] : data.where((e) => e.value == data.first.value).map((e) => e.key).toList();

  /// Jenis gangguan tanpa "Sambung Langsung" (itu Kondisi, bukan Jenis Gangguan).
  List<MapEntry<String, int>> gangguanOf(List<Memo> list) =>
      byCount(freq(list.map((m) => m.jenisGangguan).where((x) => x != 'Sambung Langsung')));

  // ---------------------------------------------------------------- aksi

  Future<void> pick(bool isStart) async {
    final d = await pickDate(context, isStart ? pStart : pEnd, minDate: isStart ? null : pStart);
    if (d == null) return;
    setState(() {
      if (isStart) {
        pStart = d;
        if (pEnd.isBefore(d)) pEnd = d;
      } else {
        pEnd = d;
      }
    });
  }

  void applyPeriod() {
    if (pStart.isAfter(pEnd)) {
      showWarning(context, 'Tanggal Mulai tidak boleh setelah Tanggal Selesai.');
      return;
    }
    setState(() {
      start = pStart;
      end = pEnd;
    });
    load();
  }

  void resetPeriod() => setState(() {
        start = pStart = _defStart;
        end = pEnd = _defEnd;
      });

  /// Evaluasi tersimpan yang berisi kumpulan memo persis sama. Evaluasi lama tanpa daftar ID
  /// dianggap sama bila periode dan jumlah memonya sama.
  _SavedEval? _findDuplicate(List<String> ids) {
    for (final e in saved) {
      if (e.memoIds.isNotEmpty) {
        if (e.memoIds.length == ids.length) {
          final a = [...e.memoIds]..sort();
          var same = true;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != ids[i]) {
              same = false;
              break;
            }
          }
          if (same) return e;
        }
      } else if (e.start == iso(start) && e.end == iso(end) && e.jumlah == ids.length) {
        return e;
      }
    }
    return null;
  }

  Future<void> saveEvaluation(List<Memo> list) async {
    if (name.text.trim().isEmpty) {
      showError(context, 'Nama evaluasi tidak boleh kosong');
      return;
    }
    if (list.isEmpty) {
      showWarning(context, 'Tidak ada data pada periode ini, tidak ada yang bisa disimpan.');
      return;
    }
    final ids = (list.map((m) => m.id).toList()..sort());
    final dup = _findDuplicate(ids);
    if (dup != null) {
      showWarning(context,
          'Data ini sudah disimpan pada evaluasi "${dup.nama}". Data yang sama tidak bisa disimpan lagi, '
          'walaupun dengan nama berbeda. Ubah periode jika ingin menyimpan data yang berbeda.');
      return;
    }
    final now = DateTime.now();
    final item = _SavedEval(
      id: now.microsecondsSinceEpoch.toString(),
      nama: name.text.trim(),
      start: iso(start),
      end: iso(end),
      dibuat: iso(now),
      jumlah: list.length,
      memoIds: ids,
      dominanGangguan: dominantsOf(gangguanOf(list)),
      dominanJumlah: gangguanOf(list).isEmpty ? 0 : gangguanOf(list).first.value,
      items: [
        for (final m in list)
          _EvalItem(
            idPelanggan: m.idPelanggan,
            noMeterLama: m.nomorMeterLama,
            noMeterBaru: m.nomorMeterBaru,
            gangguan: m.jenisGangguan,
          ),
      ],
    );
    try {
      setState(() => saved.insert(0, item));
      await _persist();
      name.clear();
      if (mounted) showSuccess(context, 'Evaluasi "${item.nama}" berhasil disimpan');
    } catch (e) {
      if (mounted) {
        setState(() => saved.remove(item));
        showError(context, e);
      }
    }
  }

  Future<void> deleteSaved(_SavedEval e) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus evaluasi?',
      message: 'Evaluasi "${e.nama}" akan dihapus.',
    );
    if (!ok) return;
    try {
      setState(() {
        saved.remove(e);
        if (compareA == e.id) compareA = null;
        if (compareB == e.id) compareB = null;
        showComparison = false;
      });
      await _persist();
      if (mounted) showSuccess(context, 'Evaluasi dihapus');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  /// Ikon mata: tampilkan rincian (ID pelanggan, no meter, gangguan) sesuai yang disimpan.
  void viewSaved(_SavedEval e) {
    // Evaluasi lama tanpa rincian: coba ambil dari memo yang masih ada.
    var items = e.items;
    if (items.isEmpty && e.memoIds.isNotEmpty) {
      final ids = e.memoIds.toSet();
      items = [
        for (final m in all.where((m) => ids.contains(m.id)))
          _EvalItem(
            idPelanggan: m.idPelanggan,
            noMeterLama: m.nomorMeterLama,
            noMeterBaru: m.nomorMeterBaru,
            gangguan: m.jenisGangguan,
          ),
      ];
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DialogHeader(
              title: e.nama,
              subtitle: '${fmt(e.start)} — ${fmt(e.end)}  •  ${e.jumlah} memo',
              onClose: () => Navigator.pop(ctx),
            ),
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Rincian tidak tersedia untuk evaluasi ini (disimpan sebelum rincian dicatat).',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('No')),
                            DataColumn(label: Text('ID Pelanggan')),
                            DataColumn(label: Text('No Meter Lama')),
                            DataColumn(label: Text('No Meter Baru')),
                            DataColumn(label: Text('Jenis Gangguan')),
                          ],
                          rows: [
                            for (int i = 0; i < items.length; i++)
                              DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(items[i].idPelanggan,
                                    style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(items[i].noMeterLama.isEmpty ? '-' : items[i].noMeterLama)),
                                DataCell(Text(items[i].noMeterBaru.isEmpty ? '-' : items[i].noMeterBaru)),
                                DataCell(Text(items[i].gangguan.isEmpty ? '-' : items[i].gangguan)),
                              ]),
                          ],
                        ),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  void compare() {
    if (compareA == null || compareB == null) {
      showError(context, 'Pilih dua evaluasi untuk dibandingkan');
      return;
    }
    if (compareA == compareB) {
      showError(context, 'Pilih evaluasi yang berbeda untuk dibandingkan');
      return;
    }
    setState(() => showComparison = true);
  }

  _SavedEval? _byId(String? id) {
    for (final e in saved) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ---------------------------------------------------------------- UI kecil

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
          const SizedBox(height: 6),
          child,
        ],
      );

  Widget _readonly(String text) => Container(
        height: AppTheme.controlHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.fieldLocked,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.ink)),
      );

  Widget _cardHeader(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
        ]),
      );

  Widget _infoPill(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Menampilkan data: '),
                TextSpan(text: '$count', style: const TextStyle(fontWeight: FontWeight.w600)),
                const TextSpan(text: ' memo selesai dalam periode ini'),
              ]),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ),
        ]),
      );

  /// Badge jenis gangguan dominan. Diletakkan di bawah subjudul (lebar penuh) supaya teks panjang tidak terpotong-potong.
  Widget _dominanBadge(List<String> names) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.emoji_events_outlined, size: 18, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Dominan: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: names.join(', ')),
              ]),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35, color: Color(0xFFB45309)),
            ),
          ),
        ]),
      );

  // ---------------------------------------------------------------- filter periode

  Widget _filterCard(int count) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(builder: (context, box) {
            final from = _labeled('Tanggal Mulai', DateBox(value: pStart, onTap: () => pick(true)));
            final to = _labeled('Tanggal Selesai', DateBox(value: pEnd, onTap: () => pick(false)));
            final apply = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: applyPeriod,
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Terapkan'),
            );
            final reset = OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: resetPeriod,
              child: const Text('Reset'),
            );
            if (box.maxWidth < 1120) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
                  SizedBox(width: 190, child: from),
                  SizedBox(width: 190, child: to),
                  apply,
                  reset,
                ]),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: _infoPill(count)),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              SizedBox(width: 200, child: from),
              const SizedBox(width: 12),
              SizedBox(width: 200, child: to),
              const SizedBox(width: 12),
              apply,
              const SizedBox(width: 10),
              reset,
              const SizedBox(width: 16),
              Expanded(child: Align(alignment: Alignment.centerRight, child: _infoPill(count))),
            ]);
          }),
        ),
      );

  // ---------------------------------------------------------------- grafik gangguan

  Widget _gangguanChart(List<MapEntry<String, int>> data, int total) {
    final maxVal = data.fold<int>(0, (a, e) => e.value > a ? e.value : a);
    final step = maxVal <= 5 ? 1.0 : (maxVal / 5).ceilToDouble();
    int pct(int v) => total > 0 ? (v * 100 / total).round() : 0;
    return LayoutBuilder(builder: (context, box) {
      // Lebar mengikuti jumlah batang supaya grafik selalu mulai dari kiri.
      final chartW = data.length * 96.0;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartW,
          height: 300,
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: BarChart(
              BarChartData(
                maxY: (maxVal + step).toDouble(),
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: step,
                      getTitlesWidget: (v, m) => v == m.max
                          ? const SizedBox.shrink()
                          : Text(v.toInt().toString(), style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox.shrink();
                        final label = data[i].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 84,
                            child: Text(
                              label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Persentase selalu tampil di atas batang (seperti label di desain acuan).
                barTouchData: BarTouchData(
                  enabled: false,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 4,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      '${pct(data[group.x].value)}%',
                      const TextStyle(
                          fontFamily: AppTheme.font,
                          fontFamilyFallback: AppTheme.fontFallback,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted),
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      showingTooltipIndicators: const [0],
                      barRods: [
                        BarChartRodData(
                          toY: data[i].value.toDouble(),
                          width: 32,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          color: data[i].value == maxVal ? _barDominant : _barOther,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _gangguanCard(List<MapEntry<String, int>> data, int total, int memoCount) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Distribusi Jenis Gangguan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink)),
            const SizedBox(height: 3),
            const Text(
              'Jumlah kasus per jenis gangguan — Sambung Langsung dikategorikan sebagai Kondisi, bukan Jenis Gangguan',
              style: TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
            if (data.isNotEmpty) ...[
              const SizedBox(height: 12),
              _dominanBadge(dominantsOf(data)),
            ],
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
            else if (memoCount == 0 || data.isEmpty)
              const SizedBox(
                height: 260,
                child: Center(
                  child: Text('Tidak ada data untuk periode ini', style: TextStyle(color: AppTheme.muted)),
                ),
              )
            else
              _gangguanChart(data, total),
          ]),
        ),
      );

  // ---------------------------------------------------------------- top 5

  Widget _rankBadge(int rank) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: rank == 1 ? const Color(0xFFFEF3C7) : AppTheme.fieldLocked,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$rank',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: rank == 1 ? const Color(0xFFB45309) : AppTheme.muted)),
      );

  Widget _top5Card(List<MapEntry<String, int>> data, int total) {
    // Peringkat kompetisi: jumlah sama = rank sama (1, 1, 3, ...). Semua yang berperingkat <= 5 ditampilkan.
    int rankOf(MapEntry<String, int> e) => 1 + data.where((x) => x.value > e.value).length;
    final top = data.where((e) => rankOf(e) <= 5).toList();
    final maxVal = top.isEmpty ? 1 : top.first.value;
    const head = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.muted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader('Top 5 Jenis Gangguan', 'Ranking berdasarkan jumlah kasus'),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Tidak ada data', style: TextStyle(color: AppTheme.muted))),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(children: [
                SizedBox(width: 48, child: Text('Rank', style: head)),
                Expanded(child: Text('Jenis Gangguan', style: head)),
                SizedBox(width: 120, child: Text('Jumlah', style: head, textAlign: TextAlign.right)),
                SizedBox(width: 56, child: Text('%', style: head, textAlign: TextAlign.right)),
              ]),
            ),
            const Divider(height: 1),
            for (int i = 0; i < top.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                child: Row(children: [
                  SizedBox(width: 48, child: Align(alignment: Alignment.centerLeft, child: _rankBadge(rankOf(top[i])))),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: top[i].key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (rankOf(top[i]) == 1)
                        const TextSpan(
                            text: '  (Dominan)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                    ])),
                  ),
                  SizedBox(
                    width: 120,
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: top[i].value / maxVal,
                            minHeight: 6,
                            color: rankOf(top[i]) == 1 ? AppTheme.primary : AppTheme.muted.withValues(alpha: .5),
                            backgroundColor: AppTheme.fieldLocked,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text('${top[i].value}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
                      ),
                    ]),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text('${total > 0 ? (top[i].value * 100 / total).round() : 0}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                ]),
              ),
              if (i < top.length - 1) const Divider(height: 1),
            ],
          ],
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- simpan evaluasi

  Widget _saveCard(List<Memo> list) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardHeader('Simpan Evaluasi', 'Simpan hasil evaluasi ini ke riwayat untuk perbandingan'),
            LayoutBuilder(builder: (context, box) {
              final nameField = _labeled(
                'Nama Evaluasi *',
                TextField(
                  controller: name,
                  onSubmitted: (_) => saveEvaluation(list),
                  decoration: const InputDecoration(hintText: 'Contoh: Evaluasi Minggu 3 Juni 2026'),
                ),
              );
              final created = _labeled('Tanggal Dibuat', _readonly(fmtDate(DateTime.now())));
              final periode = _labeled('Periode', _readonly('${fmtDate(start)} — ${fmtDate(end)}'));
              if (box.maxWidth < 760) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  nameField,
                  const SizedBox(height: 14),
                  created,
                  const SizedBox(height: 14),
                  periode,
                ]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: nameField),
                const SizedBox(width: 16),
                Expanded(child: created),
                const SizedBox(width: 16),
                Expanded(child: periode),
              ]);
            }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => saveEvaluation(list),
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text('Simpan Evaluasi'),
            ),
          ]),
        ),
      );

  // ---------------------------------------------------------------- riwayat

  List<Widget> _historyActions(_SavedEval e) => [
        IconAction(icon: Icons.visibility_outlined, color: AppTheme.accent, tooltip: 'Lihat Detail Evaluasi', onTap: () => viewSaved(e)),
        IconAction(icon: Icons.delete_outline, color: AppTheme.danger, tooltip: 'Hapus Evaluasi', onTap: () => deleteSaved(e)),
      ];

  static const _historyCols = ['No', 'Nama Evaluasi', 'Tanggal Dibuat', 'Periode', 'Total Memo', 'Aksi'];

  Widget _historyCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardHeader('Riwayat Evaluasi', '${saved.length} evaluasi tersimpan'),
            if (saved.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history, size: 40, color: AppTheme.borderStrong),
                    SizedBox(height: 10),
                    Text('Belum ada evaluasi tersimpan',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.body)),
                    SizedBox(height: 4),
                    Text('Simpan evaluasi di atas untuk melihat riwayat di sini.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                  ]),
                ),
              )
            else
              ResponsiveTable(
                breakpoint: 640,
                columns: _historyCols,
                rows: [
                  for (int i = 0; i < saved.length; i++)
                    [
                      Text('${i + 1}'),
                      Text(saved[i].nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(fmt(saved[i].dibuat)),
                      Text('${fmt(saved[i].start)} — ${fmt(saved[i].end)}'),
                      Text('${saved[i].jumlah}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      Row(mainAxisSize: MainAxisSize.min, children: _historyActions(saved[i])),
                    ],
                ],
                cardBuilder: (i) => RecordCard(
                  title: saved[i].nama,
                  subtitle: 'Dibuat ${fmt(saved[i].dibuat)}',
                  fields: {
                    'Periode': '${fmt(saved[i].start)} — ${fmt(saved[i].end)}',
                    'Total Memo': '${saved[i].jumlah}',
                  },
                  actions: _historyActions(saved[i]),
                ),
              ),
          ]),
        ),
      );

  // ---------------------------------------------------------------- bandingkan

  _Trend _numTrend(int a, int b) => b > a ? _Trend.up : (b < a ? _Trend.down : _Trend.same);

  Widget _trendBadge(_Trend t) {
    final (text, color) = switch (t) {
      _Trend.up => ('↑ Naik', const Color(0xFF15803D)),
      _Trend.down => ('↓ Turun', const Color(0xFFDC2626)),
      _Trend.same => ('→ Sama', const Color(0xFF9CA3AF)),
    };
    return Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color));
  }

  Widget _compareDropdown(String label, String? value, ValueChanged<String?> onChanged) => _labeled(
        label,
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          hint: Text('-- Pilih Evaluasi ${label.split(' ').last} --', style: const TextStyle(color: AppTheme.faint)),
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.muted),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
          items: [for (final e in saved) DropdownMenuItem(value: e.id, child: Text(e.nama, overflow: TextOverflow.ellipsis))],
          onChanged: onChanged,
        ),
      );

  Widget _periodBox(String label, _SavedEval e, Color bg, Color border, Color labelColor) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusControl), border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: labelColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: labelColor)),
          ]),
          const SizedBox(height: 10),
          Text(e.nama, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
          const SizedBox(height: 4),
          Text('${fmt(e.start)} — ${fmt(e.end)}', style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
          Text('${e.jumlah} memo selesai', style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
        ]),
      );

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
      );

  Widget _tintBox(Color bg, Color border, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusControl), border: Border.all(color: border)),
        child: child,
      );

  String _conclusion(_SavedEval a, _SavedEval b) {
    final diff = b.jumlah - a.jumlah;
    final pct = a.jumlah > 0 ? (diff / a.jumlah * 100).round().abs() : 0;
    var t = 'Berdasarkan perbandingan antara "${a.nama}" (periode ${fmt(a.start)}–${fmt(a.end)}, ${a.jumlah} memo) '
        'dan "${b.nama}" (periode ${fmt(b.start)}–${fmt(b.end)}, ${b.jumlah} memo), ';
    if (diff > 0) {
      t += 'terjadi peningkatan volume memo sebesar $pct% yang memerlukan perhatian manajemen. ';
    } else if (diff < 0) {
      t += 'terjadi penurunan volume memo sebesar $pct%, mengindikasikan perbaikan dalam kegiatan pemeliharaan. ';
    } else {
      t += 'volume memo tidak mengalami perubahan signifikan. ';
    }
    final dom = b.dominanGangguan.isEmpty ? '-' : b.dominanGangguan.map((x) => '"$x"').join(' dan ');
    t += 'Gangguan dominan pada periode terbaru adalah ${b.dominanGangguan.isEmpty ? '"-"' : dom}.';
    return t;
  }

  Widget _kpiTable(_SavedEval a, _SavedEval b) {
    final rows = <(String, String, String, _Trend)>[
      ('Total Memo', '${a.jumlah}', '${b.jumlah}', _numTrend(a.jumlah, b.jumlah)),
    ];
    // Tren gangguan dominan hanya tampil bila gangguan dominannya sama dan periodenya berbeda.
    final sameDom = a.dominanGangguan.isNotEmpty &&
        a.dominanGangguan.length == b.dominanGangguan.length &&
        a.dominanGangguan.toSet().containsAll(b.dominanGangguan);
    final diffPeriod = a.start != b.start || a.end != b.end;
    if (sameDom && diffPeriod) {
      rows.add((
        'Jenis Gangguan Dominan',
        a.dominanGangguan.join(', '),
        b.dominanGangguan.join(', '),
        (a.dominanJumlah > 0 && b.dominanJumlah > 0) ? _numTrend(a.dominanJumlah, b.dominanJumlah) : _Trend.same,
      ));
    }
    const hs = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white);
    const cell = TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.ink);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        child: Column(children: [
          Container(
            color: AppTheme.sidebar,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('Indikator', style: hs)),
              Expanded(flex: 3, child: Text('Periode A', style: hs)),
              Expanded(flex: 3, child: Text('Periode B', style: hs)),
              Expanded(flex: 2, child: Text('Tren', style: hs, textAlign: TextAlign.center)),
            ]),
          ),
          for (int i = 0; i < rows.length; i++)
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 3, child: Text(rows[i].$1, style: const TextStyle(fontSize: 13.5, color: AppTheme.body))),
                Expanded(flex: 3, child: Text(rows[i].$2, style: cell)),
                Expanded(flex: 3, child: Text(rows[i].$3, style: cell)),
                Expanded(flex: 2, child: Center(child: _trendBadge(rows[i].$4))),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _comparisonResult(_SavedEval a, _SavedEval b) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, box) {
          final boxA = _periodBox('Periode A', a, const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), const Color(0xFF1D4ED8));
          final boxB = _periodBox('Periode B', b, const Color(0xFFF0FDF4), const Color(0xFFBBF7D0), const Color(0xFF15803D));
          if (box.maxWidth < 560) {
            return Column(children: [boxA, const SizedBox(height: 12), boxB]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: boxA),
            const SizedBox(width: 12),
            Expanded(child: boxB),
          ]);
        }),
        const SizedBox(height: 18),
        _sectionLabel('Tabel Perbandingan KPI'),
        _kpiTable(a, b),
        const SizedBox(height: 18),
        _sectionLabel('Kesimpulan Rapat'),
        _tintBox(const Color(0xFFF0FDF4), const Color(0xFFBBF7D0),
            Text(_conclusion(a, b), style: const TextStyle(fontSize: 13.5, height: 1.6, color: AppTheme.body))),
        const SizedBox(height: 14),
        _tintBox(
          const Color(0xFFEFF6FF),
          const Color(0xFFBFDBFE),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 20, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Catatan: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: 'Indikator '),
                  TextSpan(text: '↑ Naik', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' pada Total Memo menunjukkan peningkatan kasus — perlu perhatian lebih. Indikator '),
                  TextSpan(text: '→ Sama', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' pada gangguan dominan menunjukkan pola berulang yang memerlukan tindakan sistematis.'),
                ]),
                style: TextStyle(fontSize: 12.5, height: 1.55, color: Color(0xFF1D4ED8)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _compareCard() {
    final a = _byId(compareA), b = _byId(compareB);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader('Bandingkan Evaluasi', 'Bandingkan dua evaluasi tersimpan untuk melihat perubahan KPI'),
          LayoutBuilder(builder: (context, box) {
            final dropA = _compareDropdown('Periode A', compareA, (v) => setState(() {
                  compareA = v;
                  showComparison = false;
                }));
            final dropB = _compareDropdown('Periode B', compareB, (v) => setState(() {
                  compareB = v;
                  showComparison = false;
                }));
            final btn = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: compare,
              icon: const Icon(Icons.compare_arrows, size: 22),
              label: const Text('Bandingkan'),
            );
            const vs = Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.muted)),
            );
            if (box.maxWidth < 760) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                dropA,
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: vs)),
                dropB,
                const SizedBox(height: 12),
                btn,
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: dropA),
              Padding(padding: const EdgeInsets.only(bottom: 14), child: vs),
              Expanded(child: dropB),
              const SizedBox(width: 12),
              btn,
            ]);
          }),
          if (showComparison && a != null && b != null) _comparisonResult(a, b),
          if (saved.length < 2) ...[
            const SizedBox(height: 14),
            _tintBox(
              const Color(0xFFFFFBEB),
              const Color(0xFFFDE68A),
              const Row(children: [
                Icon(Icons.warning_amber_outlined, size: 20, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Simpan minimal 2 evaluasi untuk dapat membandingkan data antar periode.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFFB45309))),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    final gangguan = gangguanOf(list);
    return PageScroll(
      onRefresh: load,
      children: [
        const PageTitle(title: 'Evaluasi Memo', subtitle: 'Analisis data memo selesai'),
        _filterCard(list.length),
        const SizedBox(height: 20),
        _gangguanCard(gangguan, list.length, list.length),
        const SizedBox(height: 20),
        _top5Card(gangguan, list.length),
        const SizedBox(height: 20),
        _saveCard(list),
        const SizedBox(height: 20),
        _historyCard(),
        const SizedBox(height: 20),
        _compareCard(),
      ],
    );
  }
}
