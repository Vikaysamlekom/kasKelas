import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Indikator titik untuk input PIN.
///
/// Jumlah titik minimal [minDots]; bila PIN ternyata lebih panjang, titik
/// bertambah otomatis sehingga tetap bisa merepresentasikan PIN bebas panjang.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.hasError = false});

  /// Jumlah digit yang sudah dimasukkan.
  final int length;

  /// Tampilkan seluruh titik dengan warna gagal.
  final bool hasError;

  /// Jumlah titik minimum saat PIN masih kosong.
  static const int minDots = 4;

  @override
  Widget build(BuildContext context) {
    final int jumlah = length > minDots ? length : minDots;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(jumlah, (int i) {
        final bool filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? AppColors.danger
                : filled
                    ? AppColors.navy
                    : AppColors.divider,
          ),
        );
      }),
    );
  }
}

/// Key tombol konfirmasi (✓) pada keypad PIN — dipakai pengujian.
const Key pinConfirmKey = Key('pin-konfirmasi');

/// Digit angka dari event keyboard; `null` bila bukan angka.
String? pinDigitFromKey(KeyEvent event) {
  if (event is! KeyDownEvent) return null;
  final String label = event.logicalKey.keyLabel;
  if (label.length != 1) return null;
  final int code = label.codeUnitAt(0);
  if (code >= 48 && code <= 57) return label;
  return null;
}

/// Aksi non-digit pada keypad PIN.
enum PinKeyAction { backspace, confirm, none }

/// Petakan keyboard (backspace / enter) ke aksi keypad PIN.
PinKeyAction pinActionFromKey(KeyEvent event) {
  if (event is! KeyDownEvent) return PinKeyAction.none;
  if (event.logicalKey == LogicalKeyboardKey.backspace) {
    return PinKeyAction.backspace;
  }
  if (event.logicalKey == LogicalKeyboardKey.enter) {
    return PinKeyAction.confirm;
  }
  return PinKeyAction.none;
}

/// Keypad numerik untuk memasukkan PIN: angka, hapus (⌫) dan konfirmasi (✓).
///
/// PIN tidak disubmit otomatis setelah 4 digit karena panjang PIN bebas
/// mengikuti pilihan pengguna; pengguna menekan ✓ setelah selesai mengetik.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onConfirm,
    this.enabled = true,
  });

  /// Dipanggil untuk tiap angka yang ditekan.
  final ValueChanged<String> onDigit;

  /// Hapus satu digit terakhir.
  final VoidCallback onBackspace;

  /// Konfirmasi / kirim PIN yang sudah diketik.
  final VoidCallback onConfirm;

  /// Matikan seluruh keypad (misalnya sedang memproses).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: <Widget>[
        for (int n = 1; n <= 9; n++)
          _KeyButton(
            label: '$n',
            onTap: enabled ? () => onDigit('$n') : null,
          ),
        _KeyButton(
          key: pinConfirmKey,
          icon: Icons.check_rounded,
          accent: true,
          onTap: enabled ? onConfirm : null,
        ),
        _KeyButton(
          label: '0',
          onTap: enabled ? () => onDigit('0') : null,
        ),
        _KeyButton(
          icon: Icons.backspace_outlined,
          onTap: enabled ? onBackspace : null,
        ),
      ],
    );
  }
}

/// Tombol pada keypad PIN.
class _KeyButton extends StatelessWidget {
  const _KeyButton({
    super.key,
    required this.onTap,
    this.label = '',
    this.icon,
    this.accent = false,
  });

  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.navy : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent ? AppColors.navy : AppColors.divider,
            ),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 24,
                  color: accent
                      ? Colors.white
                      : onTap == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                )
              : Text(
                  label,
                  style: AppText.title.copyWith(
                    fontSize: 22,
                    color: onTap == null ? AppColors.textMuted : null,
                  ),
                ),
        ),
      ),
    );
  }
}
