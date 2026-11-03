import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/memo.dart';
import 'app_widgets.dart';
import 'dialog_frame.dart';

/// Detail memo (hanya-baca). Susunan field sama dengan form Tambah / Edit.
class MemoDetailDialog extends StatelessWidget {
  final Memo memo;
  const MemoDetailDialog({super.key, required this.memo});

  /// Pil status terang agar terbaca di atas pita biru header.
  Widget _headerStatus(String status) {
    final done = status == 'Selesai';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: done ? const Color(0xFF166534) : const Color(0xFF92400E))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = memo;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: size.width < 720 ? 10 : 24, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: size.height * 0.94),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DialogHeader(
            title: 'Detail Memo',
            filled: true,
            trailing: _headerStatus(m.status),
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 1. Informasi Pelanggan (4 field terkunci)
                SectionPanel(
                  icon: Icons.person_outline,
                  title: 'Informasi Pelanggan',
                  body: FormGrid(children: [
                    InfoField('ID Pelanggan', m.idPelanggan, locked: true),
                    InfoField('Nomor Meter Lama', m.nomorMeterLama, locked: true),
                    InfoField('Tarif', m.tarif, locked: true),
                    InfoField('Daya', m.daya, locked: true),
                  ]),
                ),
                // 2. Informasi Memo
                SectionPanel(
                  icon: Icons.description_outlined,
                  title: 'Informasi Memo',
                  body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SubHeading('Data Memo'),
                    FormGrid(children: [
                      InfoField('Nama Pelanggan', m.namaPelanggan, locked: true),
                      InfoField('Jenis Pelanggan', m.jenisPelanggan, locked: true),
                      InfoField('Tanggal Memo', showDateStr(m.tanggalMemo), locked: true),
                      InfoField('Nomor Memo', m.nomorMemo, locked: true),
                      InfoField('Jenis Gangguan', m.jenisGangguan, locked: true),
                      InfoField('Kondisi', m.kondisi, locked: true),
                      InfoField('Sisa Token / Stand Meter', m.sisaToken, locked: true),
                      InfoField('Token Belum Di-entry', m.tokenBelumDiEntry, locked: true),
                      InfoField('Jenis Memo', m.jenisMemo, locked: true),
                      InfoField('Petugas', m.petugas, locked: true),
                      InfoField('Nomor Telepon Pelanggan', m.nomorTelepon, locked: true),
                      InfoField('Nomor Agenda', m.nomorAgenda, locked: true),
                      InfoField('No Meter Baru', m.nomorMeterBaru, locked: true),
                      InfoField('Petugas Pemasangan', m.petugasPemasangan, locked: true),
                    ]),
                  ]),
                ),
                // 3. Informasi Pemasangan
                SectionPanel(
                  icon: Icons.build_outlined,
                  title: 'Informasi Pemasangan',
                  body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FormGrid(children: [
                      InfoField('Tanggal Pemasangan', showDateStr(m.tanggalPasang), locked: true),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Text('Status Memo',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.label)),
                      const SizedBox(width: 10),
                      StatusChip(m.status),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
          DialogFooter(children: [
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          ]),
        ]),
      ),
    );
  }
}
