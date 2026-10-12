import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pin_entry.dart';

/// Layar pembuatan PIN pertama.
///
/// Aplikasi TIDAK menyediakan PIN bawaan, jadi saat pertama dibuka pengguna
/// diminta membuat PIN-nya sendiri. Setelah itu, setiap kali aplikasi dibuka
/// PIN tersebut wajib dimasukkan.
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final FocusNode _focusNode = FocusNode();

  /// PIN yang sedang diketik pada langkah aktif.
  String _pin = '';

  /// PIN hasil langkah pertama, dipakai untuk konfirmasi.
  String? _pinPertama;

  bool _konfirmasi = false;
  String? _error;
  bool _menyimpan = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    if (_pin.length >= AppConstants.pinMaxLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  /// Lanjut ke konfirmasi, atau simpan PIN bila sudah di langkah konfirmasi.
  Future<void> _confirm() async {
    if (_menyimpan) return;

    if (_pin.length < AppConstants.pinMinLength) {
      setState(() {
        _error = 'PIN minimal ${AppConstants.pinMinLength} digit.';
      });
      return;
    }

    if (!_konfirmasi) {
      setState(() {
        _pinPertama = _pin;
        _pin = '';
        _konfirmasi = true;
        _error = null;
      });
      return;
    }

    if (_pin != _pinPertama) {
      setState(() {
        _pin = '';
        _error = 'PIN tidak sama. Ketik ulang.';
      });
      return;
    }

    setState(() => _menyimpan = true);

    final SessionProvider session = context.read<SessionProvider>();
    final bool ok = await session.createInitialPin(_pin);
    if (!ok && mounted) {
      setState(() {
        _menyimpan = false;
        _pin = '';
        _error = session.errorMessage ?? 'Gagal membuat PIN. Coba lagi.';
      });
    }
  }

  void _handleKey(KeyEvent event) {
    final String? digit = pinDigitFromKey(event);
    if (digit != null) {
      _appendDigit(digit);
      return;
    }
    switch (pinActionFromKey(event)) {
      case PinKeyAction.backspace:
        _backspace();
      case PinKeyAction.confirm:
        _confirm();
      case PinKeyAction.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String label = _konfirmasi ? 'Ulangi PIN' : 'Buat PIN';
    final String hint = _konfirmasi
        ? 'Ketik kembali PIN yang sama untuk konfirmasi'
        : 'Pilih PIN ${AppConstants.pinMinLength}–'
            '${AppConstants.pinMaxLength} digit, bebas sesuai keinginanmu';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: KeyboardListener(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[AppColors.navy, AppColors.navySoft],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.pin_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Buat PIN Kamu',
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Belum ada PIN bawaan. Buat dulu agar aplikasi '
                      'terkunci dan hanya bisa dibuka olehmu.',
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall,
                    ),
                    const SizedBox(height: 36),

                    Text(label, textAlign: TextAlign.center, style: AppText.label),
                    const SizedBox(height: 8),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall,
                    ),
                    const SizedBox(height: 16),

                    PinDots(length: _pin.length),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 20,
                      child: _menyimpan
                          ? const AppLoading(size: 18)
                          : _error == null
                              ? null
                              : Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: AppText.bodySmall
                                      .copyWith(color: AppColors.danger),
                                ),
                    ),
                    const SizedBox(height: 16),

                    PinKeypad(
                      enabled: !_menyimpan,
                      onDigit: _appendDigit,
                      onBackspace: _backspace,
                      onConfirm: _confirm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
