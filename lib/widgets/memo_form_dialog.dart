import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/memo_options.dart';
import '../models/memo.dart';
import '../services/memo_service.dart';
import 'app_widgets.dart';
import 'dialog_frame.dart';

/// Form Tambah / Edit Memo.
/// Urutan isian mengikuti tampilan: Informasi Pelanggan -> Informasi Memo -> Informasi Pemasangan.
class MemoFormDialog extends StatefulWidget {
  final Memo? initial;
  const MemoFormDialog({super.key, this.initial});
  @override
  State<MemoFormDialog> createState() => _MemoFormDialogState();
}

class _MemoFormDialogState extends State<MemoFormDialog> {
  final formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> c = {};
  String? jenisMemo, jenisPelanggan, jenisGangguan, kondisi;
  String tanggalMemo = '', tanggalPasang = '';
  bool saving = false, lookup = false;
  // Hasil pencarian pelanggan (mode tambah): null = belum dicari, true = ditemukan, false = tidak ditemukan.
  // Mode edit: data pelanggan sudah ada dan terkunci.
  late bool? customerFound = widget.initial != null ? true : null;
  final searchCtrl = TextEditingController();
  final service = MemoService();

  @override
  void initState() {
    super.initState();
    final edit = widget.initial != null;
    final m = widget.initial ?? const Memo();
    // Memo baru: semua dropdown kosong ("Pilih ...").
    String? opt(String v) => edit && v.isNotEmpty ? v : null;
    jenisMemo = opt(m.jenisMemo);
    jenisPelanggan = opt(m.jenisPelanggan);
    jenisGangguan = opt(m.jenisGangguan);
    kondisi = opt(m.kondisi);
    tanggalMemo = m.tanggalMemo;
    tanggalPasang = m.tanggalPasang;
    final values = {
      'idPelanggan': m.idPelanggan,
      'namaPelanggan': m.namaPelanggan,
      'nomorMemo': m.nomorMemo,
      'sisaToken': m.sisaToken,
      'tokenBelumDiEntry': m.tokenBelumDiEntry,
      'petugas': m.petugas,
      'nomorTelepon': m.nomorTelepon,
      'nomorAgenda': m.nomorAgenda,
      'nomorMeterBaru': m.nomorMeterBaru,
      'petugasPemasangan': m.petugasPemasangan,
      'tarif': m.tarif,
      'daya': m.daya,
      'nomorMeterLama': m.nomorMeterLama,
      'merkMeterLama': m.merkMeterLama,
      'typeMeterLama': m.typeMeterLama,
      'tahunMeterLama': m.tahunMeterLama,
    };
    for (final e in values.entries) {
      c[e.key] = TextEditingController(text: e.value);
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  String v(String key) => c[key]?.text.trim() ?? '';

  Future<void> chooseDate(bool pasang) async {
    final memoDate = parseDate(tanggalMemo);
    final d = await pickDate(context, parseDate(pasang ? tanggalPasang : tanggalMemo),
        minDate: pasang ? memoDate : null);
    if (d != null) {
      setState(() {
        if (pasang) {
          tanggalPasang = isoDate(d);
        } else {
          tanggalMemo = isoDate(d);
          // Tanggal pasang tidak boleh sebelum tanggal memo.
          final p = parseDate(tanggalPasang);
          if (p != null && p.isBefore(d)) tanggalPasang = isoDate(d);
        }
      });
    }
  }

  Future<void> findCustomer() async {
    final keyword = searchCtrl.text.trim();
    if (keyword.isEmpty) {
      showWarning(context, 'Masukkan ID Pelanggan atau Nomor Meter terlebih dahulu');
      return;
    }
    setState(() => lookup = true);
    try {
      final row = await service.findCustomer(keyword);
      if (!mounted) return;
      if (row == null) {
        setState(() {
          customerFound = false;
          for (final k in ['idPelanggan', 'tarif', 'daya', 'nomorMeterLama', 'merkMeterLama', 'typeMeterLama', 'tahunMeterLama']) {
            c[k]!.clear();
          }
          jenisPelanggan = null;
        });
        return;
      }
      String s(String k) => '${row[k] ?? ''}';
      setState(() {
        final id = s('id_pel').isNotEmpty ? s('id_pel') : s('id_pelanggan');
        c['idPelanggan']!.text = id.isNotEmpty ? id : keyword;
        if (s('nama_pelanggan').isNotEmpty) c['namaPelanggan']!.text = s('nama_pelanggan');
        c['tarif']!.text = s('tarif');
        c['daya']!.text = s('daya');
        c['nomorMeterLama']!.text = s('nomor_meter_lama');
        c['merkMeterLama']!.text = s('merk_meter_lama');
        c['typeMeterLama']!.text = s('type_meter_lama');
        c['tahunMeterLama']!.text = s('tahun_meter_lama');
        final jp = s('jenis_pelanggan');
        if (MemoOptions.jenisPelanggan.contains(jp)) jenisPelanggan = jp;
        customerFound = true;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => lookup = false);
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    if (tanggalMemo.isEmpty) {
      showError(context, 'Tanggal Memo wajib diisi');
      return;
    }
    setState(() => saving = true);
    final m = Memo(
        id: widget.initial?.id ?? '',
        tanggalMemo: tanggalMemo,
        nomorMemo: v('nomorMemo'),
        idPelanggan: v('idPelanggan'),
        namaPelanggan: v('namaPelanggan'),
        jenisPelanggan: jenisPelanggan!,
        tarif: v('tarif'),
        daya: v('daya'),
        nomorMeterLama: v('nomorMeterLama'),
        merkMeterLama: v('merkMeterLama'),
        typeMeterLama: v('typeMeterLama'),
        tahunMeterLama: v('tahunMeterLama'),
        jenisGangguan: jenisGangguan!,
        kondisi: kondisi!,
        sisaToken: v('sisaToken'),
        tokenBelumDiEntry: v('tokenBelumDiEntry'),
        jenisMemo: jenisMemo!,
        petugas: v('petugas'),
        nomorTelepon: v('nomorTelepon'),
        nomorAgenda: v('nomorAgenda'),
        nomorMeterBaru: v('nomorMeterBaru'),
        petugasPemasangan: v('petugasPemasangan'),
        tanggalPasang: tanggalPasang);
    Navigator.pop(context, m);
  }

  // ---------------------------------------------------------------- komponen form

  Widget _field(String label, Widget input) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
          const SizedBox(height: 6),
          input,
        ],
      );

  Widget _text(String key, String label, {String? hint, bool required = false, TextInputType? type}) => _field(
        label,
        TextFormField(
          controller: c[key],
          keyboardType: type,
          decoration: InputDecoration(hintText: hint),
          validator: required ? (x) => x == null || x.trim().isEmpty ? '$label wajib diisi' : null : null,
        ),
      );

  Widget _drop(String label, String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    final list = [...items];
    if (value != null && !list.contains(value)) list.insert(0, value); // nilai lama dari database
    return _field(
      label,
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(color: AppTheme.faint, fontSize: 14)),
        dropdownColor: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.muted),
        items: list.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: onChanged,
        validator: (x) => x == null ? '$label wajib dipilih' : null,
      ),
    );
  }

  Widget _date(String label, String value, VoidCallback onTap, {VoidCallback? onClear}) =>
      _field(label, DateBox(value: parseDate(value), onTap: onTap, onClear: onClear));

  Widget _section(IconData icon, String title, Widget body) => SectionPanel(icon: icon, title: title, body: body);

  /// Banner hasil pencarian: hijau "ditemukan" / kuning "tidak ditemukan".
  Widget _banner(bool ok) {
    final bg = ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7);
    final line = ok ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A);
    final fg = ok ? const Color(0xFF166534) : const Color(0xFF92400E);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusControl), border: Border.all(color: line)),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_outlined, size: 20, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(ok ? 'Pelanggan ditemukan.' : 'Pelanggan tidak ditemukan.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final done = tanggalPasang.isNotEmpty;
    final isNew = widget.initial == null;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: size.width < 720 ? 10 : 24, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: size.height * 0.94),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          DialogHeader(
            title: isNew ? 'Tambah Memo Baru' : 'Edit Memo',
            filled: true,
            closable: !saving,
            onClose: () => Navigator.pop(context),
          ),
          // Isi
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Form(
                key: formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // 1. Informasi Pelanggan
                  _section(
                    Icons.person_outline,
                    'Informasi Pelanggan',
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (isNew) ...[
                        const Text('ID Pelanggan / Nomor Meter',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
                        const SizedBox(height: 2),
                        const Text('Masukkan ID Pelanggan atau Nomor Meter Lama.',
                            style: TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                        const SizedBox(height: 10),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: TextFormField(
                              controller: searchCtrl,
                              onFieldSubmitted: (_) => findCustomer(),
                              decoration: const InputDecoration(hintText: 'Contoh: 521900100001 atau 86003333878'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: AppTheme.controlHeight,
                            child: ElevatedButton.icon(
                              onPressed: lookup ? null : findCustomer,
                              icon: lookup
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.search, size: 20),
                              label: Text(lookup ? 'Mencari...' : 'Cari'),
                            ),
                          ),
                        ]),
                        if (customerFound != null) ...[const SizedBox(height: 12), _banner(customerFound!)],
                      ],
                      if (customerFound == true) ...[
                        if (isNew) const SizedBox(height: 12),
                        // Hanya 4 field, terkunci (baca-saja) di tambah maupun edit.
                        FormGrid(children: [
                          InfoField('ID Pelanggan', v('idPelanggan'), locked: true),
                          InfoField('Nomor Meter Lama', v('nomorMeterLama'), locked: true),
                          InfoField('Tarif', v('tarif'), locked: true),
                          InfoField('Daya', v('daya'), locked: true),
                        ]),
                      ],
                    ]),
                  ),
                  // 2. Informasi Memo
                  _section(
                    Icons.description_outlined,
                    'Informasi Memo',
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SubHeading('Data Memo'),
                      FormGrid(children: [
                        _text('namaPelanggan', 'Nama Pelanggan', hint: 'Nama pelanggan', required: true),
                        _drop('Jenis Pelanggan', 'Pilih Jenis Pelanggan', jenisPelanggan, MemoOptions.jenisPelanggan,
                            (x) => setState(() => jenisPelanggan = x)),
                        _date('Tanggal Memo', tanggalMemo, () => chooseDate(false)),
                        _text('nomorMemo', 'Nomor Memo', required: true),
                        _drop('Jenis Gangguan', 'Pilih Jenis Gangguan', jenisGangguan, MemoOptions.jenisGangguan,
                            (x) => setState(() => jenisGangguan = x)),
                        _drop('Kondisi', 'Pilih Kondisi', kondisi, MemoOptions.kondisi,
                            (x) => setState(() => kondisi = x)),
                        _text('sisaToken', 'Sisa Token / Stand Meter'),
                        _text('tokenBelumDiEntry', 'Token Belum Di-entry'),
                        _drop('Jenis Memo', 'Pilih Jenis Memo', jenisMemo, MemoOptions.jenisMemo,
                            (x) => setState(() => jenisMemo = x)),
                        _text('petugas', 'Petugas', hint: 'Nama Petugas Lapangan', required: true),
                        _text('nomorTelepon', 'Nomor Telepon Pelanggan',
                            hint: '08xxxxxxxxxx', type: TextInputType.phone),
                        _text('nomorAgenda', 'Nomor Agenda', required: true),
                        _text('nomorMeterBaru', 'No Meter Baru', hint: 'Nomor Meter Pengganti'),
                        _text('petugasPemasangan', 'Petugas Pemasangan', hint: 'Nama Petugas Pemasangan'),
                      ]),
                    ]),
                  ),
                  // 3. Informasi Pemasangan
                  _section(
                    Icons.build_outlined,
                    'Informasi Pemasangan',
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FormGrid(children: [
                        _date('Tanggal Pemasangan', tanggalPasang, () => chooseDate(true),
                            onClear: () => setState(() => tanggalPasang = '')),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Text('Status Memo',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
                        const SizedBox(width: 10),
                        StatusChip(done ? 'Selesai' : 'Belum Selesai'),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          // Footer
          DialogFooter(children: [
            OutlinedButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Batal')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: saving || customerFound != true ? null : save, child: const Text('Simpan Memo')),
          ]),
        ]),
      ),
    );
  }
}
