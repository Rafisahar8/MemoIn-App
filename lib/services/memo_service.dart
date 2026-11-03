import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/memo.dart';
import 'meter_stok_service.dart';

class MemoService {
  final _db = Supabase.instance.client;

  /// Naik setiap kali data memo / stok berubah. Semua halaman mendengarkan ini dan memuat ulang,
  /// karena halaman disimpan terus di memori (tidak dibuat ulang saat pindah menu).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void notifyChanged() => changes.value++;

  Future<List<Memo>> getAll() async {
    final rows = await _db.from('memos').select().order('tanggal_memo', ascending: false);
    return (rows as List).map((e) => Memo.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Memo> save(Memo memo) async {
    final data = memo.toMap();
    final Map<String, dynamic> row;
    if (memo.id.isEmpty) {
      row = await _db.from('memos').insert(data).select().single();
    } else {
      row = await _db.from('memos').update(data).eq('id', int.tryParse(memo.id) ?? memo.id).select().single();
    }
    // Nomor meter baru yang dipakai memo otomatis keluar dari Stok Meter.
    await MeterStokService().removeByNumber(memo.nomorMeterBaru);
    notifyChanged();
    return Memo.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _db.from('memos').delete().eq('id', int.tryParse(id) ?? id);
    notifyChanged();
  }

  /// Hapus banyak memo sekaligus (dipakai tombol "Hapus semua data" di Dashboard & Memo Selesai).
  /// Ringkasan di halaman Evaluasi tersimpan terpisah di perangkat, jadi tidak ikut terhapus.
  Future<void> deleteMany(List<String> ids) async {
    final keys = ids.map((id) => int.tryParse(id) ?? id).toList();
    for (var i = 0; i < keys.length; i += 100) {
      final end = i + 100 > keys.length ? keys.length : i + 100;
      await _db.from('memos').delete().inFilter('id', keys.sublist(i, end));
    }
    notifyChanged();
  }

  /// Cari pelanggan berdasarkan ID Pelanggan atau Nomor Meter Lama (fungsi `cari_pelanggan`).
  Future<Map<String, dynamic>?> findCustomer(String keyword) async {
    final rows = await _db.rpc('cari_pelanggan', params: {'p_keyword': keyword});
    if (rows is! List || rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Stream<List<Memo>> watchAll() =>
      _db.from('memos').stream(primaryKey: ['id']).order('tanggal_memo').map((rows) => rows.map(Memo.fromMap).toList());
}
