import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import '../models/memo.dart';

/// Hasil export: nama file dan lokasi penyimpanan (bisa kosong di platform yang tidak mengembalikan path).
class ExportResult {
  final String fileName, path;
  const ExportResult(this.fileName, this.path);
}

/// Export daftar memo ke Excel (sheet Meter & MCB). Dipakai Dashboard dan Memo Selesai.
Future<ExportResult> exportMemosToExcel(List<Memo> list, {required String filePrefix}) async {
  final excel = Excel.createExcel();
  final meter = excel['Meter'];
  final mcb = excel['MCB'];
  const headers = [
    'No', 'Tanggal', 'Nomor Memo', 'ID Pelanggan', 'Nama', 'Jenis', 'Tarif', 'Daya', 'Meter Lama',
    'Gangguan', 'Kondisi', 'Sisa Token', 'Token Belum Entry', 'Petugas', 'Telepon', 'Agenda',
    'Meter Baru', 'Petugas Pasang', 'Tgl Pasang', 'Status'
  ];
  for (final s in [meter, mcb]) {
    s.appendRow(headers.map((e) => TextCellValue(e)).toList());
  }

  int i = 1, j = 1;
  for (final m in list) {
    final row = [
      (m.jenisMemo == 'Meter' ? i++ : j++).toString(),
      m.tanggalMemo,
      m.nomorMemo,
      m.idPelanggan,
      m.namaPelanggan,
      m.jenisPelanggan,
      m.tarif,
      m.daya,
      m.nomorMeterLama,
      m.jenisGangguan,
      m.kondisi,
      m.sisaToken,
      '${m.tokenBelumDiEntry} ${m.tokenBelumDiEntry2}'.trim(),
      m.petugas,
      m.nomorTelepon,
      m.nomorAgenda,
      m.nomorMeterBaru,
      m.petugasPemasangan,
      m.tanggalPasang,
      m.status
    ].map((e) => TextCellValue(e)).toList();
    (m.jenisMemo == 'Meter' ? meter : mcb).appendRow(row);
  }

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
