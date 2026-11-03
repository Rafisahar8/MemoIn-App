class MeterStok {
  final String id, nomorMeter, jenisPelanggan, createdAt;
  const MeterStok({required this.id, required this.nomorMeter, required this.jenisPelanggan, this.createdAt = ''});
  factory MeterStok.fromMap(Map<String, dynamic> m) => MeterStok(id: '${m['id']}', nomorMeter: '${m['nomor_meter'] ?? ''}', jenisPelanggan: '${m['jenis_pelanggan'] ?? 'Pascabayar'}', createdAt: '${m['created_at'] ?? ''}');
  Map<String,dynamic> toMap() => {'nomor_meter': nomorMeter, 'jenis_pelanggan': jenisPelanggan};
}
