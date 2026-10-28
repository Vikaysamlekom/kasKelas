import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/classes_provider.dart';
import '../../providers/cash_types_provider.dart';
import '../../models/cash_type_model.dart';
import '../../models/payment_period.dart';
import '../../providers/payment_provider.dart';
import '../../repositories/pembayaran_repo.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_badge.dart';

/// Halaman tunggakan: daftar siswa menunggak + sisa, filter
/// kelas/jurusan/periode/status, dan total nominal di atas.
class TunggakanScreen extends StatefulWidget {
  const TunggakanScreen({super.key});

  @override
  State<TunggakanScreen> createState() => _TunggakanScreenState();
}

class _TunggakanScreenState extends State<TunggakanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadTunggakan();
      context.read<ClassesProvider>().load();
      context.read<CashTypesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final PaymentProvider provider = context.watch<PaymentProvider>();
    final ClassesProvider classes = context.watch<ClassesProvider>();
    final CashTypesProvider cashTypes = context.watch<CashTypesProvider>();

    final List<TunggakanItem> items = _applyStatusFilter(
      provider.tunggakan,
      provider.tunggakanFilter.status,
    );
    final int total = items.fold<int>(
      0,
      (int sum, TunggakanItem t) => sum + t.sisa,
    );
    // Nama jenis kas yang jadi dasar kewajiban pada tampilan ini.
    CashTypeModel? selectedCashType;
    for (final CashTypeModel c in cashTypes.cashTypes) {
      if (c.id == provider.tunggakanFilter.cashTypeId) {
        selectedCashType = c;
        break;
      }
    }
    final DateTime periodDate =
        provider.tunggakanFilter.periodDate ?? DateTime.now();
    final String periodLabel = _periodLabel(selectedCashType, periodDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Tunggakan')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // TOTAL TUNGGAKAN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                color: AppColors.navy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total Tunggakan',
                      style: AppText.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(Formatters.rupiah(total), style: AppText.amountLarge),
                    const SizedBox(height: 6),
                    Text(
                      '${items.length} siswa belum melunasi '
                      '${selectedCashType?.name ?? 'kewajiban'} · '
                      '$periodLabel',
                      style: AppText.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // FILTER JENIS KAS (dasar kewajiban) / PERIODE / KELAS / JURUSAN
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  FilterDropdown<int>(
                    label: 'Jenis Kas',
                    value: provider.tunggakanFilter.cashTypeId,
                    items: cashTypes.cashTypes
                        .where((CashTypeModel c) => c.isActive)
                        .map((CashTypeModel c) => (c.name, c.id!))
                        .toList(),
                    onChanged: (int? v) {
                      if (v != null && v > 0) {
                        provider.applyTunggakanFilter(cashTypeId: v);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  if (selectedCashType?.frequency != PaymentFrequency.sekali)
                    SizedBox(
                      width: 210,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPeriodDate(provider, periodDate),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          periodLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    Chip(label: Text(periodLabel)),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Kelas',
                    value: provider.tunggakanFilter.classId,
                    items:
                        (classes.classes
                                .where((c) => c.kelas.isActive)
                                .map((c) => (c.kelas.name, c.kelas.id!)))
                            .toList(),
                    onChanged: (int? v) {
                      provider.applyTunggakanFilter(classId: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Jurusan',
                    value: provider.tunggakanFilter.majorId,
                    items:
                        (classes.majors
                                .where((m) => m.major.isActive)
                                .map((m) => (m.major.name, m.major.id!)))
                            .toList(),
                    onChanged: (int? v) {
                      provider.applyTunggakanFilter(majorId: v ?? 0);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // FILTER STATUS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  _StatusChip(
                    label: 'Semua',
                    selected: provider.tunggakanFilter.status == '',
                    onTap: () => provider.applyTunggakanFilter(status: ''),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Belum Bayar',
                    selected: provider.tunggakanFilter.status == 'belum',
                    onTap: () => provider.applyTunggakanFilter(status: 'belum'),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Sebagian',
                    selected: provider.tunggakanFilter.status == 'sebagian',
                    onTap: () =>
                        provider.applyTunggakanFilter(status: 'sebagian'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // DAFTAR TUNGGAKAN
            Expanded(
              child: _TunggakanList(
                isLoading: provider.isLoadingTunggakan,
                items: items,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TunggakanItem> _applyStatusFilter(
    List<TunggakanItem> all,
    String status,
  ) {
    final List<TunggakanItem> result = <TunggakanItem>[
      for (final TunggakanItem t in all)
        if (t.sisa > 0 && (status.isEmpty || t.status == status)) t,
    ];
    return result;
  }

  Future<void> _pickPeriodDate(
    PaymentProvider provider,
    DateTime initialDate,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: AppDateRange.clamp(initialDate),
      firstDate: AppDateRange.minDate,
      lastDate: AppDateRange.maxDate,
      helpText: 'Pilih tanggal dalam periode kewajiban',
    );
    if (picked != null) {
      provider.applyTunggakanFilter(
        periodDate: picked,
        month: picked.month,
        year: picked.year,
      );
    }
  }

  String _periodLabel(CashTypeModel? cashType, DateTime date) {
    if (cashType == null) return 'Pilih jenis kas';
    if (cashType.frequency == PaymentFrequency.sekali) return 'Sekali';
    final PaymentPeriod period = PaymentPeriod.forDate(
      date,
      cashType.frequency,
    );
    switch (cashType.frequency) {
      case PaymentFrequency.harian:
        return Formatters.tanggalPendekIso(PaymentPeriod.dateKey(period.start));
      case PaymentFrequency.mingguan:
        return '${Formatters.tanggalPendekIso(PaymentPeriod.dateKey(period.start))}'
            ' - ${Formatters.tanggalPendekIso(PaymentPeriod.dateKey(period.end))}';
      case PaymentFrequency.bulanan:
        return '${Formatters.namaBulan(period.start.month)} ${period.start.year}';
      case PaymentFrequency.semester:
        return 'Semester ${period.start.month == 1 ? 1 : 2} ${period.start.year}';
      case PaymentFrequency.tahunan:
        return '${period.start.year}';
      default:
        return Formatters.tanggalPendekIso(PaymentPeriod.dateKey(period.start));
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

class _TunggakanList extends StatelessWidget {
  final bool isLoading;
  final List<TunggakanItem> items;

  const _TunggakanList({required this.isLoading, required this.items});

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'Tidak ada tunggakan',
        message: 'Semua siswa sudah melunasi kewajiban pada periode terpilih.',
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<PaymentProvider>().loadTunggakan(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final TunggakanItem t = items[index];
          return _TunggakanTile(item: t);
        },
      ),
    );
  }
}

class _TunggakanTile extends StatelessWidget {
  final TunggakanItem item;

  const _TunggakanTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.name,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.pembayaran(item.status),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'NIS ${item.nis} · ${item.className ?? '-'}'
            '${item.majorName != null ? ' · ${item.majorName}' : ''}',
            style: AppText.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text('Bayar ', style: AppText.caption),
              Text(
                Formatters.rupiah(item.paid),
                style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(' / Kewajiban ', style: AppText.caption),
              Text(
                Formatters.rupiah(item.owed),
                style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('Sisa ', style: AppText.caption),
              Text(
                Formatters.rupiah(item.sisa),
                style: AppText.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
