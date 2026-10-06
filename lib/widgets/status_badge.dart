import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Badge status berwarna (aktif/lunas/belum/dll).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  /// Badge status siswa (aktif/cuti/lulus).
  factory StatusBadge.siswa(String status) {
    switch (status.toLowerCase()) {
      case 'aktif':
        return StatusBadge(label: 'Aktif', color: AppColors.teal);
      case 'cuti':
        return StatusBadge(label: 'Cuti', color: AppColors.orange);
      case 'lulus':
        return StatusBadge(label: 'Lulus', color: AppColors.blue);
      default:
        return StatusBadge(label: status, color: AppColors.textMuted);
    }
  }

  /// Badge status pembayaran (lunas/sebagian/pending/belum/batal).
  factory StatusBadge.pembayaran(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return StatusBadge(label: 'Lunas', color: AppColors.teal);
      case 'pending':
        return StatusBadge(label: 'Pending', color: AppColors.orange);
      case 'sebagian':
        return StatusBadge(label: 'Sebagian', color: AppColors.blue);
      case 'belum':
        return StatusBadge(label: 'Belum Bayar', color: AppColors.warning);
      case 'batal':
        return StatusBadge(label: 'Batal', color: AppColors.danger);
      default:
        return StatusBadge(label: status, color: AppColors.textMuted);
    }
  }

  /// Badge status pengeluaran (valid/batal).
  factory StatusBadge.kas(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return StatusBadge(label: 'Valid', color: AppColors.teal);
      case 'batal':
        return StatusBadge(label: 'Batal', color: AppColors.danger);
      default:
        return StatusBadge(label: status, color: AppColors.textMuted);
    }
  }

  /// Badge transaksi gabungan (pemasukan → status pembayaran,
  /// pengeluaran → status kas).
  factory StatusBadge.transaksi(String status, {required bool isIncome}) {
    return isIncome
        ? StatusBadge.pembayaran(status)
        : StatusBadge.kas(status);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.label.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}