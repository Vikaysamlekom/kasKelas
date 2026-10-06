import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../utils/formatters.dart';

/// Angka rupiah yang menghitung naik dari 0 saat pertama kali tampil
/// (efek "count up") supaya terasa hidup dan informatif.
///
/// Ukuran huruf dikecilkan secara otomatis bila nominal terlalu panjang
/// untuk lebar yang tersedia, sehingga angka tetap terbaca satu baris
/// pada layar HP kecil maupun nominal besar.
class AnimatedRupiah extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Color color;
  final Duration duration;
  final bool autoFit;

  const AnimatedRupiah({
    super.key,
    required this.value,
    required this.style,
    required this.color,
    this.duration = const Duration(milliseconds: 900),
    this.autoFit = true,
  });

  /// Perkiraan lebar teks: digit dan pemisah rata-rata ±0.58 em.
  static double _estimateWidth(String text, double fontSize) =>
      text.length * fontSize * 0.58;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final String label = Formatters.rupiah(value);
        double fontSize = style.fontSize ?? 14;
        if (autoFit && c.maxWidth.isFinite && c.maxWidth > 0) {
          final double estimate = _estimateWidth(label, fontSize);
          if (estimate > c.maxWidth) {
            fontSize = (fontSize * (c.maxWidth / estimate)).clamp(
              fontSize * 0.5,
              fontSize,
            );
          }
        }
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double v, Widget? _) => Text(
            Formatters.rupiah(v.round()),
            style: style.copyWith(color: color, fontSize: fontSize),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

/// Seksi "Ringkasan Keuangan" untuk Dashboard.
///
/// Susunan:
///   1. Kartu herogradien navy berisi **Sisa Saldo** + komposisi
///      pemasukan/pengeluaran + angka masuk & keluar bulan ini.
///   2. Dua kartu metrik: Total Pemasukan & Total Pengeluaran.
///   3. Satu kartu lebar: Transaksi Hari Ini.
///
/// Semua angka dihitung ulang dengan animasi halus, dan tidak memerlukan
/// koneksi internet apa pun.
class FinanceSummary extends StatelessWidget {
  final int sisaSaldo;
  final int totalPemasukan;
  final int totalPengeluaran;
  final int pemasukanBulanIni;
  final int pengeluaranBulanIni;
  final int transaksiHariIni;
  final String periodeLabel;

  const FinanceSummary({
    super.key,
    required this.sisaSaldo,
    required this.totalPemasukan,
    required this.totalPengeluaran,
    required this.pemasukanBulanIni,
    required this.pengeluaranBulanIni,
    required this.transaksiHariIni,
    required this.periodeLabel,
  });

  /// Porsi pengeluaran terhadap pemasukan (0..1). Aman saat keduanya 0.
  double get _rasioPengeluaran {
    if (totalPemasukan <= 0) return 0;
    return (totalPengeluaran / totalPemasukan).clamp(0.0, 1.0);
  }

  int get _persenPengeluaran => (100 * _rasioPengeluaran).round();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHero(),
        const SizedBox(height: 14),
        // Tinggi tetap membuat kedua kartu metrik sama tinggi.
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: 'Total Pemasukan',
                  icon: Icons.south_west_rounded,
                  accent: AppColors.teal,
                  accentDeep: const Color(0xFF2E8071),
                  value: totalPemasukan,
                  footer: totalPemasukan > 0
                      ? '${100 - _persenPengeluaran}% dari total arus kas'
                      : 'Belum ada pemasukan',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Total Pengeluaran',
                  icon: Icons.north_east_rounded,
                  accent: AppColors.orange,
                  accentDeep: const Color(0xFFB96D05),
                  value: totalPengeluaran,
                  footer: totalPengeluaran > 0
                      ? '$_persenPengeluaran% dari pemasukan'
                      : 'Belum ada pengeluaran',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _TransactionCard(
          jumlah: transaksiHariIni,
          tanggal: Formatters.tanggal(DateTime.now()),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // KARTU HERO — SISA SALDO
  // ------------------------------------------------------------------
  Widget _buildHero() {
    final bool positif = sisaSaldo >= 0;
    final Color statusWarna = positif ? AppColors.teal : AppColors.danger;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0A1F44), Color(0xFF16305C), Color(0xFF123F4A)],
          stops: <double>[0, 0.55, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Dekorasi cahaya di sudut.
          Positioned(
            top: -70,
            right: -50,
            child: _Glow(size: 170, color: AppColors.orange.withValues(alpha: 0.20)),
          ),
          Positioned(
            bottom: -80,
            right: 40,
            child: _Glow(size: 150, color: AppColors.teal.withValues(alpha: 0.22)),
          ),
          Positioned(
            top: 26,
            left: -30,
            child: _Glow(size: 90, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'SISA SALDO KAS',
                            style: AppText.label.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 1.1,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            periodeLabel,
                            style: AppText.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(positif: positif, warna: statusWarna),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedRupiah(
                  value: sisaSaldo,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  color: Colors.white,
                ),
                const SizedBox(height: 18),
                _CompositionBar(rasio: _rasioPengeluaran),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HeroMiniStat(
                        icon: Icons.arrow_downward_rounded,
                        warna: AppColors.teal,
                        label: 'Masuk ${periodeLabel.toLowerCase()}',
                        nilai: pemasukanBulanIni,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMiniStat(
                        icon: Icons.arrow_upward_rounded,
                        warna: AppColors.orange,
                        label: 'Keluar ${periodeLabel.toLowerCase()}',
                        nilai: pengeluaranBulanIni,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// KARTU METRIK (pemasukan / pengeluaran)
// ---------------------------------------------------------------------
class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final Color accentDeep;
  final int value;
  final String footer;

  const _MetricCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.accentDeep,
    required this.value,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Garis aksen di sisi atas.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[accent, accentDeep],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[accent, accentDeep],
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedRupiah(
                  value: value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                  color: AppColors.textPrimary,
                  duration: const Duration(milliseconds: 950),
                ),
                const SizedBox(height: 8),
                Text(
                  footer,
                  style: AppText.caption.copyWith(fontSize: 10.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// KARTU TRANSAKSI HARI INI
// ---------------------------------------------------------------------
class _TransactionCard extends StatelessWidget {
  final int jumlah;
  final String tanggal;

  const _TransactionCard({required this.jumlah, required this.tanggal});

  @override
  Widget build(BuildContext context) {
    final bool ada = jumlah > 0;
    final Color aksen = ada ? AppColors.teal : Colors.white.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            AppColors.navy,
            AppColors.navySoft,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Transaksi Hari Ini',
                  style: AppText.label.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tanggal,
                  style: AppText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: jumlah.toDouble()),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double v, Widget? _) => Text(
                  v.round().toString(),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
              ),
              Text(
                ada ? 'transaksi' : 'belum ada',
                style: AppText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          // Aksen tipis di sisi kanan sebagai penanda visual.
          if (ada) ...<Widget>[
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: aksen,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// PIECAK KECIL
// ---------------------------------------------------------------------

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Batang komposisi pemasukan vs pengeluaran.
class _CompositionBar extends StatelessWidget {
  final double rasio;

  const _CompositionBar({required this.rasio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                return Stack(
                  children: <Widget>[
                    // Sisa kas (bagian yang belum terpakai).
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.teal,
                            AppColors.teal.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                    // Pengeluaran menimpa dari kanan.
                    Positioned(
                      left: c.maxWidth * (1 - rasio),
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.orange,
                              AppColors.orange.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            _LegendDot(warna: AppColors.teal, teks: 'Sisa kas'),
            const SizedBox(width: 14),
            _LegendDot(warna: AppColors.orange, teks: 'Terpakai'),
            const Spacer(),
            Text(
              '${(100 * (1 - rasio)).round()}% / ${(100 * rasio).round()}%',
              style: AppText.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color warna;
  final String teks;

  const _LegendDot({required this.warna, required this.teks});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          teks,
          style: AppText.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final IconData icon;
  final Color warna;
  final String label;
  final int nilai;

  const _HeroMiniStat({
    required this.icon,
    required this.warna,
    required this.label,
    required this.nilai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: warna, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: AppText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                AnimatedRupiah(
                  value: nilai,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  color: Colors.white,
                  duration: const Duration(milliseconds: 950),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool positif;
  final Color warna;

  const _StatusPill({required this.positif, required this.warna});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            positif ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: warna,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            positif ? 'Aman' : 'Minus',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
