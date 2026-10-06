import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Dropdown filter dengan tampilan chip (dipakai di daftar siswa,
/// pembayaran, dan tunggakan). Items berupa record `(label, value)`.
/// Nilai 0/null memicu opsi "Semua" lewat hint.
class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(String, T)> items;
  final ValueChanged<T?> onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value == null ? null : _findValue(),
          isDense: true,
          hint: Text('$label: Semua', style: AppText.bodySmall),
          icon: const Icon(Icons.expand_more_rounded, size: 20),
          items: items
              .map((record) => DropdownMenuItem<T>(
                    value: record.$2,
                    child: Text(record.$1, style: AppText.bodySmall),
                  ))
              .toList(),
          onChanged: (T? v) {
            if (v == value) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  T? _findValue() {
    if (value == null) return null;
    for (final (String, T) item in items) {
      if (item.$2 == value) return item.$2;
    }
    return null;
  }
}