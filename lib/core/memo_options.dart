/// Pilihan dropdown untuk form memo & stok meter.
///
/// >>> EDIT DI SINI jika daftar pilihan di sistem Anda berbeda. <<<
/// Nilai lama di database yang tidak ada di daftar ini tetap ditampilkan saat memo diedit.
class MemoOptions {
  static const jenisPelanggan = ['Pascabayar', 'Prabayar', 'AMI', 'PLTS', '3 Phasa', 'Tarif C'];

  static const jenisMemo = ['Meter', 'MCB'];

  /// Jenis stok meter hanya dua.
  static const jenisStok = ['Pascabayar', 'Prabayar'];

  /// Sama dengan daftar di aplikasi web (AddMemoModal).
  static const jenisGangguan = [
    'MCB Rusak',
    'Meter hilang bukan karena pelanggan',
    'Keypad tidak berfungsi (rusak)',
    'Token pembelian tidak bisa masuk',
    'KCT tidak dapat masuk',
    'Token baru tidak bisa masuk karena status terpakai',
    'Kredit kWh berkurang tanpa beban',
    'Kredit kWh menjadi nol (reset)',
    'Meter dianggap boros',
    'Kredit kWh bernilai minus',
    'Kredit kWh tidak berkurang',
    'Kredit kWh lebih besar dari kumulatif pembelian to...',
    'Display LCD Meter - Blank/cacat/mati',
    'Relay rusak',
    'Permasalahan Instalasi Pelanggan (IML)',
    'Program pemeliharaan meter (kasus khusus)',
    'Program meter tua',
    'Meter Rusak karena Serangga / Hewan',
    'Meter Rusak karena Bencana Alam',
    'Display LCD Meter - muncul Inscek',
    'Display LCD Meter - muncul Gndcek',
    'Error meter diluar kelas',
    'Display LCD Meter - Muncul Periksa',
    'LCD menunjukkan error/tidak normal',
    'Upgrade KRN',
    'Cover Meter rusak / pecah',
    'Meter ex P2TL',
    'Meter terbakar/tersambar petir',
    'Meter terminal netral keluar arus',
    'Saklar Temper Rusak',
    'Gangguan Firmware',
    'Kerusakan Fisik Meter karena Gangguan Eksternal',
  ];

  // "Sambung Langsung" dikategorikan sebagai Kondisi (bukan Jenis Gangguan).
  static const kondisi = ['Normal', 'Sambung Langsung'];
}
