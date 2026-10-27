import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/payment_model.dart';
import '../../providers/classes_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_badge.dart';
import 'bukti_pembayaran_screen.dart';
import 'payment_form_screen.dart';
import 'tunggakan_screen.dart';
import '../laporan/laporan_screen.dart';
import '../pengeluaran/pengeluaran_screen.dart';
import '../transactions/audit_log_screen.dart';
import '../transactions/riwayat_transaksi_screen.dart';

/// Halaman pembayaran: daftar transaksi + filter periode/kelas + form bayar.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().load();
      context.read<ClassesProvider>().load();
    });
  }

  Future<void> _openForm() async {
    await context.read<PaymentProvider>().loadActiveStudents();
    if (!mounted) return;
    final bool? changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (_) => const PaymentFormScreen()));
    if (changed == true && mounted) {
      context.read<PaymentProvider>().load();
    }
  }

  Future<void> _openBukti(PaymentModel payment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => BuktiPembayaranScreen(paymentId: payment.id!)),
    );
    if (mounted) {
      context.read<PaymentProvider>().load();
    }
  }

  Future<void> _delete(PaymentModel payment) async {
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Pembayaran',
      message: 'Hapus transaksi ${payment.paymentCode}?\nData tidak bisa dikembalikan.',
      confirmLabel: 'Ya, Hapus',
    );
    if (!confirm) return;
    if (!mounted) return;

    final int? userId = context.read<SessionProvider>().user?.id;
    await jalankanAksi(
      context,
      () => context.read<PaymentProvider>().deletePayment(payment.id!, userId: userId),
      konteks: 'Hapus pembayaran',
    );
  }

  @override
  Widget build(BuildContext context) {
    final PaymentProvider provider = context.watch<PaymentProvider>();
    final ClassesProvider classes = context.watch<ClassesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (String value) {
              final NavigatorState nav = Navigator.of(context);
              switch (value) {
                case 'tunggakan':
                  nav.push<void>(MaterialPageRoute<void>(builder: (_) => const TunggakanScreen()));
                case 'pengeluaran':
                  nav.push<void>(
                    MaterialPageRoute<void>(builder: (_) => const PengeluaranScreen()),
                  );
                case 'riwayat':
                  nav.push<void>(
                    MaterialPageRoute<void>(builder: (_) => const RiwayatTransaksiScreen()),
                  );
                case 'laporan':
                  nav.push<void>(MaterialPageRoute<void>(builder: (_) => const LaporanScreen()));
                case 'audit':
                  nav.push<void>(MaterialPageRoute<void>(builder: (_) => const AuditLogScreen()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'tunggakan',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.pending_actions_rounded),
                    SizedBox(width: 8),
                    Expanded(child: Text('Tunggakan')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pengeluaran',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.remove_circle_outline),
                    SizedBox(width: 8),
                    Expanded(child: Text('Pengeluaran')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'riwayat',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.receipt_long_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('Riwayat Transaksi')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'laporan',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.insert_chart_outlined_rounded),
                    SizedBox(width: 8),
                    Expanded(child: Text('Laporan')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'audit',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.history_rounded),
                    SizedBox(width: 8),
                    Expanded(child: Text('Audit Log')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // FILTER PERIODE & KELAS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  FilterDropdown<int>(
                    label: 'Bulan',
                    value: provider.filter.month,
                    items: _months,
                    onChanged: (int? v) {
                      provider.applyFilter(month: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Tahun',
                    value: provider.filter.year,
                    items: _years,
                    onChanged: (int? v) {
                      provider.applyFilter(year: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Kelas',
                    value: provider.filter.classId,
                    items:
                        (classes.classes
                                .where((c) => c.kelas.isActive)
                                .map((c) => (c.kelas.name, c.kelas.id!)))
                            .toList(),
                    onChanged: (int? v) {
                      provider.applyFilter(classId: v ?? 0);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // RINGKASAN PERIODE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Total Penerimaan', style: AppText.caption),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.rupiah(provider.totalPenerimaan),
                            style: AppText.amountMedium.copyWith(color: AppColors.navy),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 34, color: AppColors.divider),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Jumlah Transaksi', style: AppText.caption),
                          const SizedBox(height: 4),
                          Text(
                            '${provider.payments.length}',
                            style: AppText.amountMedium.copyWith(color: AppColors.navy),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // DAFTAR PEMBAYARAN
            Expanded(
              child: _PaymentList(
                isLoading: provider.isLoading,
                payments: provider.payments,
                onTap: _openBukti,
                onDelete: _delete,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.paid_outlined),
        label: const Text('Buat Pembayaran'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
    );
  }

  static final List<(String, int)> _months = _buildMonths();

  static List<(String, int)> _buildMonths() {
    final List<(String, int)> list = <(String, int)>[];
    for (int m = 1; m <= 12; m++) {
      list.add((Formatters.namaBulan(m), m));
    }
    return list;
  }

  static final List<(String, int)> _years = _buildYears();

  static List<(String, int)> _buildYears() {
    return <(String, int)>[for (final int y in AppDateRange.semuaTahun) (y.toString(), y)];
  }
}

class _PaymentList extends StatelessWidget {
  final bool isLoading;
  final List<PaymentModel> payments;
  final void Function(PaymentModel) onTap;
  final void Function(PaymentModel) onDelete;

  const _PaymentList({
    required this.isLoading,
    required this.payments,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && payments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (payments.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada pembayaran',
        message: 'Tekan "Buat Pembayaran" untuk mencatat transaksi pada periode terpilih.',
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<PaymentProvider>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: payments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final PaymentModel p = payments[index];
          return _PaymentTile(payment: p, onTap: () => onTap(p), onDelete: () => onDelete(p));
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PaymentTile({required this.payment, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_rounded, color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  payment.studentName ?? 'Siswa',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'NIS ${payment.studentNis ?? '-'} · '
                  '${payment.className ?? '-'} · ${payment.cashTypeName ?? '-'}',
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${Formatters.namaBulan(payment.month)} ${payment.year} · '
                  '${Formatters.tanggalPendekIso(payment.paidDate)}',
                  style: AppText.caption.copyWith(color: AppColors.textMuted),
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
                Formatters.rupiah(payment.amount),
                style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[StatusBadge.pembayaran(payment.status)],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
