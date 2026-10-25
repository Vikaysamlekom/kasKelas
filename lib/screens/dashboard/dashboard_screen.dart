import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/session_provider.dart';
import '../../repositories/dashboard_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/class_progress_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/finance_summary.dart';

/// Halaman utama Dashboard: saldo, statistik, dan progres per kelas.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
  }

  Future<void> _refresh() async {
    await context.read<DashboardProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final DashboardProvider dashboard = context.watch<DashboardProvider>();
    final String? bendahara = context.read<SessionProvider>().user?.fullName;
    final DateTime now = DateTime.now();
    final String periode = '${Formatters.namaBulanPendek(now.month)} ${now.year}';

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.navy,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            title: const Text('Dashboard'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    _initial(bendahara ?? 'B'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.list(
              children: <Widget>[
                // ---------- RINGKASAN KEUANGAN ----------
                if (dashboard.isLoading && dashboard.summary == null)
                  const AppCard(padding: EdgeInsets.symmetric(vertical: 56), child: AppLoading())
                else if (dashboard.summary == null)
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Gagal memuat data',
                      message: dashboard.errorMessage,
                    ),
                  )
                else ...<Widget>[
                  SectionHeader(
                    title: 'Ringkasan Keuangan',
                    subtitle: 'Periode $periode',
                    trailing: Text(
                      _sapaan(bendahara),
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceSummary(
                    sisaSaldo: dashboard.summary!.saldo,
                    totalPemasukan: dashboard.summary!.totalPemasukan,
                    totalPengeluaran: dashboard.summary!.totalPengeluaran,
                    pemasukanBulanIni: dashboard.summary!.pemasukanBulanIni,
                    pengeluaranBulanIni: dashboard.summary!.pengeluaranBulanIni,
                    transaksiHariIni: dashboard.summary!.transaksiHariIni,
                    periodeLabel: periode,
                  ),
                  const SizedBox(height: 24),

                  // ---------- PROGRES PER KELAS ----------
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SectionHeader(
                          title: 'Progres Pembayaran Kelas',
                          subtitle: 'Periode $periode',
                        ),
                        const SizedBox(height: 8),
                        if (dashboard.classProgress.isEmpty)
                          const EmptyState(
                            icon: Icons.group_outlined,
                            title: 'Belum ada data kelas',
                            message: 'Tambahkan kelas & siswa pada menu Siswa.',
                          )
                        else ...<Widget>[
                          for (final ClassProgress c in dashboard.classProgress)
                            ClassProgressTile(
                              className: c.className,
                              totalStudents: c.totalStudents,
                              paidStudents: c.paidStudents,
                              percent: c.percent,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sapaan(String? nama) {
    if (nama == null || nama.trim().isEmpty) return '';
    return 'Halo, ${nama.trim().split(' ').first}';
  }

  String _initial(String name) {
    final List<String> parts = name.trim().split(' ');
    if (parts.isEmpty) return 'B';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
