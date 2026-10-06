import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/pengeluaran_repo.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_badge.dart';
import 'detail_transaksi_screen.dart';

/// Halaman riwayat transaksi: gabungan pemasukan + pengeluaran
/// dengan filter jenis, kategori, dan pencarian.
class RiwayatTransaksiScreen extends StatefulWidget {
  const RiwayatTransaksiScreen({super.key});

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadRiwayat();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(TransactionItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DetailTransaksiScreen(
          transaction: item,
          onChanged: () => context.read<TransactionProvider>().loadRiwayat(),
        ),
      ),
    );
    if (mounted) {
      context.read<TransactionProvider>().loadRiwayat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TransactionProvider provider = context.watch<TransactionProvider>();
    final List<TransactionItem> items = provider.filteredRiwayat;

    // Ringkasan berbasis item non-batal yang sedang terlihat.
    int masuk = 0, keluar = 0;
    for (final TransactionItem t in items) {
      if (t.isVoided) continue;
      if (t.isIncome) {
        masuk += t.amount;
      } else {
        keluar += t.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // RINGKASAN
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    _SummaryItem(
                      label: 'Pemasukan',
                      value: Formatters.rupiah(masuk),
                      color: AppColors.teal,
                    ),
                    Container(
                        width: 1, height: 36, color: AppColors.divider),
                    _SummaryItem(
                      label: 'Pengeluaran',
                      value: Formatters.rupiah(keluar),
                      color: AppColors.danger,
                    ),
                    Container(
                        width: 1, height: 36, color: AppColors.divider),
                    _SummaryItem(
                      label: 'Saldo',
                      value: Formatters.rupiah(masuk - keluar),
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
            ),

            // FILTER JENIS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  _JenisChip(
                    label: 'Semua',
                    selected: provider.riwayatFilter.jenis == '',
                    onTap: () => provider.applyRiwayatFilter(jenis: ''),
                  ),
                  const SizedBox(width: 8),
                  _JenisChip(
                    label: 'Masuk',
                    selected: provider.riwayatFilter.jenis ==
                        TransactionType.pemasukan,
                    onTap: () => provider.applyRiwayatFilter(
                      jenis: TransactionType.pemasukan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _JenisChip(
                    label: 'Keluar',
                    selected: provider.riwayatFilter.jenis ==
                        TransactionType.pengeluaran,
                    onTap: () => provider.applyRiwayatFilter(
                      jenis: TransactionType.pengeluaran,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // FILTER KATEGORI + RESET
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  FilterDropdown<int>(
                    label: 'Kategori',
                    value: provider.riwayatFilter.kategori,
                    items: _buildKategoriItems(provider),
                    onChanged: (int? v) {
                      provider.applyRiwayatFilter(kategori: v);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      provider.clearRiwayatFilter();
                    },
                    tooltip: 'Reset Filter',
                    icon: const Icon(
                      Icons.filter_alt_off_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // PENCARIAN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (String v) =>
                    provider.applyRiwayatFilter(search: v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Cari kode / siswa / keperluan...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // DAFTAR TRANSAKSI
            Expanded(
              child: _RiwayatList(
                isLoading: provider.isLoadingRiwayat,
                items: items,
                onTap: _openDetail,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opsi kategori filter: positif → cash type (pemasukan),
  /// negatif → −kategori pengeluaran. Label diberi awalan Masuk/Keluar.
  List<(String, int)> _buildKategoriItems(TransactionProvider provider) {
    final List<(String, int)> items = <(String, int)>[];
    for (final ct in provider.incomeCategories) {
      if (ct.isActive) {
        items.add(('Masuk · ${ct.name}', ct.id!));
      }
    }
    for (final c in provider.categories) {
      if (c.isActive) {
        items.add(('Keluar · ${c.name}', -c.id!));
      }
    }
    return items;
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: AppText.caption),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JenisChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _JenisChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RiwayatList extends StatelessWidget {
  final bool isLoading;
  final List<TransactionItem> items;
  final void Function(TransactionItem) onTap;

  const _RiwayatList({
    required this.isLoading,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Tidak ada transaksi',
        message:
            'Belum ada transaksi yang cocok dengan filter atau pencarian.',
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<TransactionProvider>().loadRiwayat(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final TransactionItem t = items[index];
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => onTap(t),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (t.isIncome ? AppColors.teal : AppColors.danger)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    t.isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: t.isIncome ? AppColors.teal : AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        t.title,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: t.isVoided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t.code} · ${t.isIncome ? 'Pemasukan' : 'Pengeluaran'}'
                        '${t.categoryName == null ? '' : ' · ${t.categoryName}'}',
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Formatters.tanggalWaktuIso(t.date.toIso8601String()),
                        style: AppText.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${t.isIncome ? '' : '-'}${Formatters.rupiah(t.amount)}',
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: t.isVoided
                            ? AppColors.textMuted
                            : (t.isIncome ? AppColors.teal : AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (t.isVoided)
                      const StatusBadge(
                        label: 'Batal',
                        color: AppColors.danger,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}