import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import '../models/memo.dart';

/// Hasil export: nama file dan lokasi penyimpanan (bisa kosong di platform yang tidak mengembalikan path).
class ExportResult {
  final String fileName, path;
  const ExportResult(this.fileName, this.path);
}

// ------------------------------------------------------------------ gaya Excel

const _brand = '#003D99'; // biru header, sama dengan versi web
const _line = '#CBD5E1'; // garis tepi sel
const _zebra = '#F1F5F9'; // warna baris selang-seling

/// Gaya satu sel: warna, perataan, wrap, dan garis tepi tipis.
CellStyle _cell({
  String bg = '#FFFFFF',
  String fg = '#1E293B',
  bool bold = false,
  HorizontalAlign h = HorizontalAlign.Left,
  bool wrap = false,
  int size = 10,
}) {
  final edge = Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(_line));
  return CellStyle(
    fontColorHex: ExcelColor.fromHexString(fg),
    backgroundColorHex: ExcelColor.fromHexString(bg),
    bold: bold,
    fontSize: size,
    horizontalAlign: h,
    verticalAlign: VerticalAlign.Center,
    textWrapping: wrap ? TextWrapping.WrapText : null,
    leftBorder: edge,
    rightBorder: edge,
    topBorder: edge,
    bottomBorder: edge,
  );
}

void _put(Sheet sh, int col, int row, CellValue value, CellStyle style) {
  final c = sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
  c.value = value;
  c.cellStyle = style;
}

/// yyyy-mm-dd -> dd/mm/yyyy (sama seperti tampilan di aplikasi). Jika gagal diparse, dikembalikan apa adanya.
String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso.trim());
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ------------------------------------------------------------------ sheet memo

/// Definisi satu kolom sheet memo (kolom "No" ditangani terpisah di depan).
class _MemoCol {
  final String title;
  final double width; // satuan lebar karakter Excel
  final String Function(Memo m) text;
  final HorizontalAlign align;
  final bool wrap;
  final bool asInt; // tulis sebagai angka bila isinya angka murni
  const _MemoCol(this.title, this.width, this.text,
      {this.align = HorizontalAlign.Left, this.wrap = false, this.asInt = false});
}

final List<_MemoCol> _memoCols = [
  _MemoCol('Tanggal Memo', 14, (m) => _fmtDate(m.tanggalMemo), align: HorizontalAlign.Center),
  _MemoCol('Nomor Memo', 16, (m) => m.nomorMemo),
  _MemoCol('ID Pelanggan', 16, (m) => m.idPelanggan),
  _MemoCol('Nama Pelanggan', 24, (m) => m.namaPelanggan, wrap: true),
  _MemoCol('Jenis Pelanggan', 16, (m) => m.jenisPelanggan),
  _MemoCol('Tarif', 12, (m) => m.tarif, align: HorizontalAlign.Center),
  _MemoCol('Daya', 10, (m) => m.daya, align: HorizontalAlign.Center, asInt: true),
  _MemoCol('Nomor Meter Lama', 16, (m) => m.nomorMeterLama),
  _MemoCol('Jenis Gangguan', 28, (m) => m.jenisGangguan, wrap: true),
  _MemoCol('Kondisi', 16, (m) => m.kondisi, wrap: true),
  _MemoCol('Sisa Token / Stand Meter', 20, (m) => m.sisaToken, wrap: true),
  _MemoCol('Token Belum Di-entry', 20, (m) => '${m.tokenBelumDiEntry} ${m.tokenBelumDiEntry2}'.trim(), wrap: true),
  _MemoCol('Petugas', 18, (m) => m.petugas, wrap: true),
  _MemoCol('Nomor Telepon Pelanggan', 20, (m) => m.nomorTelepon),
  _MemoCol('Nomor Agenda', 16, (m) => m.nomorAgenda),
  _MemoCol('No Meter Baru', 16, (m) => m.nomorMeterBaru),
  _MemoCol('Petugas Pemasangan', 18, (m) => m.petugasPemasangan, wrap: true),
  _MemoCol('Tanggal Pemasangan', 16, (m) => _fmtDate(m.tanggalPasang), align: HorizontalAlign.Center),
  _MemoCol('Status Memo', 14, (m) => m.status, align: HorizontalAlign.Center),
];

/// ID pelanggan / nomor meter tetap teks supaya angka nol di depan tidak hilang; hanya kolom [asInt] yang jadi angka.
CellValue _memoValue(_MemoCol c, Memo m) {
  final s = c.text(m);
  if (c.asInt) {
    final n = int.tryParse(s.trim());
    if (n != null) return IntCellValue(n);
  }
  return TextCellValue(s);
}

/// Tinggi baris menyesuaikan teks yang di-wrap (perkiraan jumlah baris x tinggi huruf).
double _memoRowHeight(Memo m) {
  var lines = 1;
  for (final c in _memoCols) {
    if (!c.wrap) continue;
    final n = (c.text(m).length / (c.width - 2)).ceil();
    if (n > lines) lines = n;
  }
  return lines == 1 ? 22.0 : lines * 15.0 + 8;
}

void _writeMemoSheet(Sheet sh, List<Memo> rows) {
  final head = _cell(bg: _brand, fg: '#FFFFFF', bold: true, h: HorizontalAlign.Center, wrap: true);
  _put(sh, 0, 0, TextCellValue('No'), head);
  sh.setColumnWidth(0, 5);
  for (var c = 0; c < _memoCols.length; c++) {
    _put(sh, c + 1, 0, TextCellValue(_memoCols[c].title), head);
    sh.setColumnWidth(c + 1, _memoCols[c].width);
  }
  sh.setRowHeight(0, 34);

  if (rows.isEmpty) {
    sh.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: _memoCols.length, rowIndex: 1),
      customValue: TextCellValue('Tidak ada data'),
    );
    sh.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle =
        _cell(fg: '#64748B', h: HorizontalAlign.Center);
    sh.setRowHeight(1, 28);
    return;
  }

  // Gaya disiapkan sekali: [0] baris biasa, [1] baris selang-seling.
  final noStyle = [_cell(h: HorizontalAlign.Center), _cell(bg: _zebra, h: HorizontalAlign.Center)];
  final colStyle = [
    for (final c in _memoCols)
      [_cell(h: c.align, wrap: c.wrap), _cell(bg: _zebra, h: c.align, wrap: c.wrap)],
  ];
  final selesai = _cell(bg: '#D1FAE5', fg: '#047857', bold: true, h: HorizontalAlign.Center);
  final belum = _cell(bg: '#FEF3C7', fg: '#B45309', bold: true, h: HorizontalAlign.Center);
  final statusCol = _memoCols.length - 1;

  for (var r = 0; r < rows.length; r++) {
    final m = rows[r];
    final z = r.isOdd ? 1 : 0;
    final row = r + 1;
    _put(sh, 0, row, IntCellValue(r + 1), noStyle[z]);
    for (var c = 0; c < _memoCols.length; c++) {
      final style = c == statusCol ? (m.status == 'Selesai' ? selesai : belum) : colStyle[c][z];
      _put(sh, c + 1, row, _memoValue(_memoCols[c], m), style);
    }
    sh.setRowHeight(row, _memoRowHeight(m));
  }
}

/// Export daftar memo ke Excel (sheet Meter & MCB). Dipakai Dashboard dan Memo Selesai.
Future<ExportResult> exportMemosToExcel(List<Memo> list, {required String filePrefix}) async {
  final excel = Excel.createExcel();
  final meter = excel['Meter'];
  final mcb = excel['MCB'];

  _writeMemoSheet(meter, list.where((m) => m.jenisMemo == 'Meter').toList());
  _writeMemoSheet(mcb, list.where((m) => m.jenisMemo != 'Meter').toList());

  excel.delete('Sheet1');
  final bytes = excel.encode();
  if (bytes == null) throw Exception('Gagal membuat file Excel');

  final name = '$filePrefix-${DateTime.now().toIso8601String().substring(0, 10)}';
  final path = await FileSaver.instance.saveFile(
    name: name,
    bytes: Uint8List.fromList(bytes),
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
  return ExportResult('$name.xlsx', path);
}

/// Export hasil evaluasi (ringkasan + distribusi gangguan, merk, tahun) ke Excel.
Future<ExportResult> exportEvaluasiToExcel({
  required String periode,
  required String jenis,
  required int total,
  required int meter,
  required int mcb,
  required double? avgHari,
  required List<MapEntry<String, int>> gangguan,
  required List<MapEntry<String, int>> merk,
  required List<MapEntry<String, int>> tahun,
}) async {
  final excel = Excel.createExcel();
  TextCellValue t(String x) => TextCellValue(x);

  final ringkasan = excel['Ringkasan'];
  ringkasan.appendRow([t('Evaluasi Memo Selesai'), t('')]);
  for (final r in [
    ['Periode', periode],
    ['Jenis Memo', jenis == 'Semua' ? 'Semua (Meter & MCB)' : jenis],
    ['Total Memo Selesai', '$total'],
    ['Memo Meter', '$meter'],
    ['Memo MCB', '$mcb'],
    ['Rata-rata Waktu Penyelesaian', avgHari == null ? '-' : '${avgHari.toStringAsFixed(1)} hari'],
    ['Dibuat', DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')],
  ]) {
    ringkasan.appendRow([t(r[0]), t(r[1])]);
  }

  void distSheet(String name, String label, List<MapEntry<String, int>> data) {
    final sh = excel[name];
    sh.appendRow([t('No'), t(label), t('Jumlah'), t('Persen')]);
    final sum = data.fold<int>(0, (a, e) => a + e.value);
    for (int i = 0; i < data.length; i++) {
      final e = data[i];
      sh.appendRow([
        IntCellValue(i + 1),
        t(e.key),
        IntCellValue(e.value),
        t(sum == 0 ? '0%' : '${(e.value * 100 / sum).toStringAsFixed(1)}%'),
      ]);
    }
  }

  distSheet('Jenis Gangguan', 'Jenis Gangguan', gangguan);
  distSheet('Merk Meter', 'Merk Meter', merk);
  distSheet('Tahun Meter', 'Tahun Meter', tahun);

  excel.delete('Sheet1');
  final bytes = excel.encode();
  if (bytes == null) throw Exception('Gagal membuat file Excel');

  final name = 'evaluasi-memo-${DateTime.now().toIso8601String().substring(0, 10)}';
  final path = await FileSaver.instance.saveFile(
    name: name,
    bytes: Uint8List.fromList(bytes),
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
  return ExportResult('$name.xlsx', path);
}
