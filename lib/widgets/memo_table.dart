import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/memo.dart';
import 'app_widgets.dart';

/// Tabel memo dengan kolom yang sama di Dashboard & Memo Selesai:
/// NO, TANGGAL MEMO, ID PELANGGAN, TARIF, DAYA, JENIS PELANGGAN, JENIS GANGGUAN, JENIS MEMO, STATUS, AKSI.
class MemoTable extends StatelessWidget {
  final List<Memo> list;
  final bool loading;
  final void Function(Memo) onDetail;
  final void Function(Memo) onEdit;
  final void Function(Memo)? onDelete;
  final String emptyText;
  final IconData emptyIcon;

  const MemoTable({
    super.key,
    required this.list,
    required this.loading,
    required this.onDetail,
    required this.onEdit,
    this.onDelete,
    this.emptyText = 'Tidak ada memo yang sesuai.',
    this.emptyIcon = Icons.inbox_outlined,
  });

  static const columns = [
    'No', 'Tanggal Memo', 'ID Pelanggan', 'Tarif', 'Daya', 'Jenis Pelanggan',
    'Jenis Gangguan', 'Jenis Memo', 'Status', 'Aksi',
  ];

  List<Widget> _actions(Memo m) => [
        IconAction(icon: Icons.visibility_outlined, color: AppTheme.accent, tooltip: 'Detail', onTap: () => onDetail(m)),
        IconAction(icon: Icons.edit_outlined, color: AppTheme.warning, tooltip: 'Edit', onTap: () => onEdit(m)),
        if (onDelete != null)
          IconAction(icon: Icons.delete_outline, color: AppTheme.danger, tooltip: 'Hapus', onTap: () => onDelete!(m)),
      ];

  @override
  Widget build(BuildContext context) {
    if (loading) return const TableSkeleton(columns: columns);
    if (list.isEmpty) return EmptyState(emptyText, icon: emptyIcon);
    return ResponsiveTable(
      columns: columns,
      rows: [
        for (int i = 0; i < list.length; i++)
          [
            Text('${i + 1}'),
            Text(showDateStr(list[i].tanggalMemo)),
            Text(list[i].idPelanggan, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(list[i].tarif),
            Text(list[i].daya),
            StatusChip(list[i].jenisPelanggan),
            SizedBox(width: 150, child: Text(list[i].jenisGangguan, overflow: TextOverflow.ellipsis)),
            StatusChip(list[i].jenisMemo),
            StatusChip(list[i].status),
            Row(mainAxisSize: MainAxisSize.min, children: _actions(list[i])),
          ],
      ],
      cardBuilder: (i) => RecordCard(
        title: list[i].idPelanggan,
        subtitle: showDateStr(list[i].tanggalMemo),
        badges: [StatusChip(list[i].jenisMemo), StatusChip(list[i].status)],
        fields: {
          'Tarif / Daya': '${list[i].tarif} / ${list[i].daya}',
          'Jenis Pelanggan': list[i].jenisPelanggan,
          'Jenis Gangguan': list[i].jenisGangguan,
        },
        actions: _actions(list[i]),
      ),
    );
  }
}
