import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Baris progres pembayaran per kelas (label + bar + persentase).
class ClassProgressTile extends StatelessWidget {
  final String className;
  final int totalStudents;
  final int paidStudents;
  final double percent;

  const ClassProgressTile({
    super.key,
    required this.className,
    required this.totalStudents,
    required this.paidStudents,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final double p = (percent / 100).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  className,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$paidStudents/$totalStudents siswa · ${percent.toStringAsFixed(0)}%',
                style: AppText.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 80
                    ? AppColors.teal
                    : percent >= 50
                        ? AppColors.blue
                        : AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}