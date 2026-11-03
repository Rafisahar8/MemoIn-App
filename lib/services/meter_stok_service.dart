import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meter_stok.dart';

/// Stok meter memakai tabel `meter_stoks` dan fungsi `tambah_meter_stok` / `ubah_meter_stok`
/// dari skema SQL (validasi nomor ganda & nomor yang sudah terpakai dilakukan di database).
class MeterStokService {
  final _db = Supabase.instance.client;

  Future<List<MeterStok>> getAll() async {
    final rows = await _db.from('meter_stoks').select().order('created_at', ascending: false);
    return (rows as List).map((e) => MeterStok.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  /// Stok yang benar-benar tersedia: nomor yang sudah dipakai memo (No Meter Baru / Meter Lama)
  /// atau sudah ada di DIL otomatis dibuang dari daftar (dan dari tabel stok).
  Future<List<MeterStok>> getAvailable() async {
    final all = await getAll();
    final used = <String>{};
    final nums = all.map((e) => e.nomorMeter).where((e) => e.isNotEmpty).toList();
    for (var i = 0; i < nums.length; i += 100) {
      final chunk = nums.sublist(i, i + 100 > nums.length ? nums.length : i + 100);
      for (final r in await _db.from('memos').select('nomor_meter_baru').inFilter('nomor_meter_baru', chunk)) {
        used.add('${r['nomor_meter_baru']}'.trim());
      }
      for (final r in await _db.from('memos').select('nomor_meter_lama').inFilter('nomor_meter_lama', chunk)) {
        used.add('${r['nomor_meter_lama']}'.trim());
      }
      for (final r in await _db.from('pelanggan').select('nomor_meter_lama').inFilter('nomor_meter_lama', chunk)) {
        used.add('${r['nomor_meter_lama']}'.trim());
      }
    }
    final usedItems = all.where((e) => used.contains(e.nomorMeter.trim())).toList();
    if (usedItems.isNotEmpty) {
      try {
        await _db.from('meter_stoks').delete().inFilter(
            'id', usedItems.map((e) => int.tryParse(e.id) ?? e.id).toList());
      } catch (_) {
        // Gagal membersihkan tabel: daftar tetap disaring di sisi aplikasi.
      }
    }
    return all.where((e) => !used.contains(e.nomorMeter.trim())).toList();
  }

  /// Cari ID pelanggan yang sudah memakai nomor meter ini (di DIL atau di memo). Null = belum terpakai.
  Future<String?> findUser(String nomor) async {
    final n = nomor.trim();
    if (n.isEmpty) return null;
    final dil = await _db.from('pelanggan').select('id_pel').eq('nomor_meter_lama', n).limit(1);
    if (dil.isNotEmpty) return '${dil.first['id_pel']}';
    for (final col in ['nomor_meter_baru', 'nomor_meter_lama']) {
      final r = await _db.from('memos').select('id_pelanggan').eq(col, n).limit(1);
      if (r.isNotEmpty) return '${r.first['id_pelanggan']}';
    }
    return null;
  }

  /// Dipanggil saat memo disimpan: nomor yang dipakai langsung hilang dari stok.
  Future<void> removeByNumber(String nomor) async {
    final n = nomor.trim();
    if (n.isEmpty) return;
    try {
      await _db.from('meter_stoks').delete().eq('nomor_meter', n);
    } catch (_) {
      // Memo sudah tersimpan; stok tetap disaring otomatis saat halaman Stok Meter dibuka.
    }
  }

  Future<void> save(MeterStok item) async {
    final user = await findUser(item.nomorMeter);
    if (user != null) {
      throw Exception('No meter ${item.nomorMeter.trim()} sudah dipakai oleh ID Pelanggan $user');
    }
    if (item.id.isEmpty) {
      await _db.rpc('tambah_meter_stok', params: {
        'p_nomor': item.nomorMeter,
        'p_jenis': item.jenisPelanggan,
      });
    } else {
      await _db.rpc('ubah_meter_stok', params: {
        'p_id': int.tryParse(item.id) ?? item.id,
        'p_nomor': item.nomorMeter,
        'p_jenis': item.jenisPelanggan,
      });
    }
  }

  Future<void> delete(String id) async {
    await _db.from('meter_stoks').delete().eq('id', int.tryParse(id) ?? id);
  }

  Stream<List<MeterStok>> watchAll() =>
      _db.from('meter_stoks').stream(primaryKey: ['id']).map((rows) => rows.map(MeterStok.fromMap).toList());
}
