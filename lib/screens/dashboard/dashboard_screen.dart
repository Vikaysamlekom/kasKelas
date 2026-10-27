import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/school_profile_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/session_provider.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/school_profile_repo.dart';
import '../pengeluaran/pengeluaran_screen.dart';
import '../settings/profil_sekolah_screen.dart';
import '../transactions/riwayat_transaksi_screen.dart';
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
  SchoolProfileModel? _schoolProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardProvider>().load();
        _loadSchoolProfile();
      }
    });
  }

  Future<void> _loadSchoolProfile() async {
    try {
      final SchoolProfileModel? profile = await SchoolProfileRepository()
          .getProfile();
      if (mounted) setState(() => _schoolProfile = profile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat profil sekolah: $e')),
      );
    }
  }

  Future<void> _refresh() async {
    await context.read<DashboardProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final DashboardProvider dashboard = context.watch<DashboardProvider>();
    final String? bendahara = context.read<SessionProvider>().user?.fullName;
    final DateTime now = DateTime.now();
    final String periode =
        '${Formatters.namaBulanPendek(now.month)} ${now.year}';

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
                child: IconButton(
                  tooltip: 'Buka profil sekolah',
                  onPressed: () => _openProfile(context),
                  icon: _buildSchoolLogo(36),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.list(
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => _openProfile(context),
                  child: Row(
                    children: <Widget>[
                      _buildSchoolLogo(56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _schoolProfile?.schoolName.trim().isNotEmpty ==
                                      true
                                  ? _schoolProfile!.schoolName
                                  : AppConstants.appName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sectionTitle,
                            ),
                            const SizedBox(height: 4),
                            Text('Profil Sekolah', style: AppText.caption),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ---------- RINGKASAN KEUANGAN ----------
                if (dashboard.isLoading && dashboard.summary == null)
                  const AppCard(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: AppLoading(),
                  )
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
                    onSaldoTap: () =>
                        _openScreen(context, const RiwayatTransaksiScreen()),
                    onPemasukanTap: () => context
                        .read<NavigationProvider>()
                        .setIndex(NavigationIndex.payments),
                    onPengeluaranTap: () =>
                        _openScreen(context, const PengeluaranScreen()),
                    onTransaksiTap: () =>
                        _openScreen(context, const RiwayatTransaksiScreen()),
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
                              onTap: () => context
                                  .read<NavigationProvider>()
                                  .setIndex(NavigationIndex.students),
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

  Widget _buildSchoolLogo(double size) {
    final String? path = _schoolProfile?.logoPath;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null || path.isEmpty
          ? Icon(Icons.school_rounded, size: size * 0.58, color: AppColors.navy)
          : Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (BuildContext _, Object _, StackTrace? _) => Icon(
                Icons.school_rounded,
                size: size * 0.58,
                color: AppColors.navy,
              ),
            ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProfilSekolahScreen()),
    );
    if (mounted) await _loadSchoolProfile();
  }

  Future<void> _openScreen(BuildContext context, Widget screen) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
