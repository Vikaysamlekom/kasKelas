import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pin_entry.dart';
import 'forgot_pin_screen.dart';

/// Halaman masuk bendahara: memasukkan PIN yang dibuat sendiri oleh pengguna.
///
/// Tidak ada PIN bawaan — bila pengguna belum pernah membuat PIN, `RootGate`
/// menampilkan layar Buat PIN lebih dulu.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FocusNode _focusNode = FocusNode();
  String _pin = '';

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Bersihkan pesan error begitu pengguna memasukkan PIN lagi, supaya
  /// indikator tidak tetap merah (terlihat "stuck") setelah PIN salah.
  void _resetError() {
    if (!mounted) return;
    context.read<SessionProvider>().clearError();
  }

  /// Buka alur Lupa PIN (pertanyaan keamanan / kode pemulihan).
  Future<void> _bukaLupaPin() async {
    _focusNode.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) {
        return const ForgotPinScreen();
      }),
    );
    if (mounted) _focusNode.requestFocus();
  }

  void _appendDigit(String digit) {
    if (_pin.length >= AppConstants.pinMaxLength) return;
    _resetError();
    setState(() => _pin += digit);
  }

  void _backspace() {
    _resetError();
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.isEmpty) return;

    final SessionProvider session = context.read<SessionProvider>();
    session.clearError();

    final bool ok = await session.loginWithPin(_pin);
    if (!ok && mounted) {
      setState(() => _pin = '');
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
        _submit();
      case PinKeyAction.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionProvider session = context.watch<SessionProvider>();
    final String? error = session.errorMessage;

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
                    // LOGO & JUDUL
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
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppConstants.appTagline,
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall,
                    ),
                    const SizedBox(height: 36),

                    // LABEL PIN
                    Text(
                      'Masukkan PIN',
                      textAlign: TextAlign.center,
                      style: AppText.label,
                    ),
                    const SizedBox(height: 16),

                    PinDots(length: _pin.length, hasError: error != null),
                    const SizedBox(height: 16),

                    // PESAN ERROR
                    SizedBox(
                      height: 20,
                      child: session.isLoggingIn
                          ? const AppLoading(size: 18)
                          : error == null
                              ? null
                              : Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: AppText.bodySmall
                                      .copyWith(color: AppColors.danger),
                                ),
                    ),
                    const SizedBox(height: 16),

                    // KEYPAD NUMERIK
                    PinKeypad(
                      enabled: !session.isLoggingIn,
                      onDigit: _appendDigit,
                      onBackspace: _backspace,
                      onConfirm: _submit,
                    ),
                    const SizedBox(height: 8),

                    // LUPA PIN
                    TextButton.icon(
                      onPressed: _bukaLupaPin,
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: const Text('Lupa PIN?'),
                    ),
                    const SizedBox(height: 4),
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
