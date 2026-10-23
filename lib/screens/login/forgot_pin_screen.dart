import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pin_entry.dart';

/// Alur "Lupa PIN" dari halaman login.
///
/// Dua jalur pemulihan (data diatur oleh bendahara lewat menu Ubah PIN):
/// 1. **Pertanyaan keamanan** — jawab dua pertanyaan yang sudah disiapkan.
/// 2. **Kode pemulihan** — masukkan kode rahasia yang dicatat saat setup.
///
/// Setelah salah satu jalur terverifikasi, pengguna membuat PIN baru
/// (tulis + ulangi), lalu langsung masuk aplikasi tanpa login ulang.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

/// Tahapan alur lupa PIN.
enum _Tahap { load, belumDisetup, pilih, pertanyaan, kode, pinBaru }

/// Jalur verifikasi yang dipilih pengguna.
enum _Jalur { pertanyaan, kode }

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final FocusNode _focusNode = FocusNode();

  // Verifikasi
  final TextEditingController _jawaban1 = TextEditingController();
  final TextEditingController _jawaban2 = TextEditingController();
  final TextEditingController _kode = TextEditingController();

  // PIN baru (dua langkah: ketik → ulangi)
  String _pin = '';
  String? _pinPertama;
  bool _konfirmasi = false;

  _Tahap _tahap = _Tahap.load;
  _Jalur _jalur = _Jalur.pertanyaan;
  RecoveryInfo? _info;
  String? _error;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _muatInfo();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _jawaban1.dispose();
    _jawaban2.dispose();
    _kode.dispose();
    super.dispose();
  }

  /// Muat status pemulihan lalu tentukan tahap awal: pilih jalur bila
  /// keduanya tersedia, masuk langsung bila hanya satu, atau info bila
  /// pemulihan belum pernah diaktifkan.
  Future<void> _muatInfo() async {
    final SessionProvider session = context.read<SessionProvider>();
    final RecoveryInfo info = await session.recoveryInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      if (!info.siap) {
        _tahap = _Tahap.belumDisetup;
      } else if (info.questionsSet && info.codeSet) {
        _tahap = _Tahap.pilih;
      } else if (info.codeSet) {
        _tahap = _Tahap.kode;
      } else {
        _tahap = _Tahap.pertanyaan;
      }
    });
  }

  String get _pertanyaanAktif =>
      _jalur == _Jalur.pertanyaan ? (_info?.q1 ?? '') : '';
  String get _pertanyaanKedua => _info?.q2 ?? '';

  // ------------------------------------------------------------------
  // VERIFIKASI → PIN BARU
  // ------------------------------------------------------------------

  /// Pindah ke tahap tulis PIN baru (verifikasi jawaban/kode dilakukan
  /// SEKALIGUS saat PIN baru disimpan — atomik).
  void _lanjutKePinBaru() {
    if (_jalur == _Jalur.pertanyaan) {
      if (_jawaban1.text.trim().isEmpty || _jawaban2.text.trim().isEmpty) {
        setState(() => _error = 'Kedua jawaban wajib diisi.');
        return;
      }
    } else if (AuthRepository.normalisasiKodePemulihan(_kode.text).length < 8) {
      setState(() => _error = 'Kode pemulihan tidak lengkap.');
      return;
    }
    setState(() {
      _error = null;
      _tahap = _Tahap.pinBaru;
    });
  }

  void _tambahDigit(String digit) {
    if (_pin.length >= AppConstants.pinMaxLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _hapusDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  /// Konfirmasi PIN baru, lalu jalankan reset + verifikasi.
  Future<void> _konfirmasiPin() async {
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
    final ResetPinOutcome hasil;
    if (_jalur == _Jalur.pertanyaan) {
      hasil = await session.resetPinViaQuestions(
        answer1: _jawaban1.text,
        answer2: _jawaban2.text,
        newPin: _pin,
      );
    } else {
      hasil = await session.resetPinViaRecoveryCode(
        recoveryCode: _kode.text,
        newPin: _pin,
      );
    }
    if (!mounted) return;
    setState(() => _menyimpan = false);

    if (hasil.ok) {
      // Sesi sudah terbentuk → RootGate otomatis pindah ke aplikasi.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN berhasil direset. '
              'Gunakan PIN baru mulai sekarang.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    switch (hasil.error) {
      case RecoveryError.jawabanSalah:
        setState(() {
          _tahap = _Tahap.pertanyaan;
          _resetPinBaru();
          _error = 'Jawaban tidak cocok. '
              'Sisa ${_info?.sisaPercobaan ?? 1} percobaan '
              'sebelum terkunci.';
        });
        await _muatInfo();
      case RecoveryError.kodeSalah:
        setState(() {
          _tahap = _Tahap.kode;
          _resetPinBaru();
          _error = 'Kode pemulihan salah. '
              'Sisa ${_info?.sisaPercobaan ?? 1} percobaan '
              'sebelum terkunci.';
        });
        await _muatInfo();
      case RecoveryError.terkunci:
        setState(() {
          _resetPinBaru();
          _error = 'Terlalu banyak percobaan. '
              'Coba lagi dalam ${hasil.lockedMinutes} menit.';
        });
        await _muatInfo();
      case RecoveryError.belumDisetup:
        setState(() {
          _resetPinBaru();
          _tahap = _Tahap.belumDisetup;
        });
      case RecoveryError.gagal:
      case RecoveryError.none:
        setState(() => _error = 'Gagal reset PIN. Coba lagi.');
    }
  }

  void _resetPinBaru() {
    _pin = '';
    _pinPertama = null;
    _konfirmasi = false;
  }

  void _handleKey(KeyEvent event) {
    if (_tahap != _Tahap.pinBaru) return;
    final String? digit = pinDigitFromKey(event);
    if (digit != null) {
      _tambahDigit(digit);
      return;
    }
    switch (pinActionFromKey(event)) {
      case PinKeyAction.backspace:
        _hapusDigit();
      case PinKeyAction.confirm:
        _konfirmasiPin();
      case PinKeyAction.none:
        break;
    }
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa PIN')),
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _tahap == _Tahap.load
                    ? const Center(child: CircularProgressIndicator())
                    : _tahap == _Tahap.belumDisetup
                        ? _infoBelumDisetup()
                        : _tahap == _Tahap.pilih
                            ? _pilihanJalur()
                            : _tahap == _Tahap.pinBaru
                                ? _tulisPinBaru()
                                : _formVerifikasi(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu info pemulihan belum diaktifkan.
  Widget _infoBelumDisetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.lock_reset_rounded,
            size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          'Pemulihan PIN belum diaktifkan',
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 10),
        Text(
          'Layar ini butuh data pemulihan (pertanyaan keamanan atau kode '
          'pemulihan) yang diatur oleh bendahara lewat menu '
          'Pengaturan → Ubah PIN → Pemulihan PIN.',
          textAlign: TextAlign.center,
          style: AppText.bodySmall,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Kembali ke Login'),
        ),
      ],
    );
  }

  /// Pilih jalur pemulihan bila pertanyaan & kode keduanya tersedia.
  Widget _pilihanJalur() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Pilih cara pulihkan.',
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          onPressed: () => setState(() {
            _jalur = _Jalur.pertanyaan;
            _tahap = _Tahap.pertanyaan;
            _error = null;
          }),
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Jawab Pertanyaan Keamanan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => setState(() {
            _jalur = _Jalur.kode;
            _tahap = _Tahap.kode;
            _error = null;
          }),
          icon: const Icon(Icons.key_rounded),
          label: const Text('Gunakan Kode Pemulihan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: AppColors.navySoft,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Form jawaban pertanyaan keamanan ATAU kode pemulihan.
  Widget _formVerifikasi() {
    final bool viaPertanyaan = _tahap == _Tahap.pertanyaan;
    _jalur = viaPertanyaan ? _Jalur.pertanyaan : _Jalur.kode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          viaPertanyaan
              ? 'Jawab pertanyaan keamanan Anda.'
              : 'Masukkan kode pemulihan.',
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(
          viaPertanyaan
              ? 'Kedua jawaban dipakai untuk memverifikasi Anda sebagai '
                  'bendahara aplikasi ini.'
              : 'Kode rahasia yang Anda catat saat mengaktifkan pemulihan.',
          textAlign: TextAlign.center,
          style: AppText.bodySmall,
        ),
        const SizedBox(height: 24),
        if (viaPertanyaan) ...<Widget>[
          TextField(
            controller: _jawaban1,
            enabled: !_menyimpan,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Q1: $_pertanyaanAktif',
              prefixIcon: const Icon(Icons.help_outline_rounded),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _jawaban2,
            enabled: !_menyimpan,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Q2: $_pertanyaanKedua',
              prefixIcon: const Icon(Icons.help_outline_rounded),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ] else
          TextField(
            controller: _kode,
            enabled: !_menyimpan,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Kode Pemulihan',
              hintText: 'Contoh: 7QT2M-H8KP9',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),

        // Pesan error / lockout
        const SizedBox(height: 14),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppColors.danger),
            ),
          )
        else if ((_info?.lockedRemainingMinutes ?? 0) > 0)
          Text(
            'Terlalu banyak percobaan. Coba lagi dalam '
            '${_info!.lockedRemainingMinutes} menit.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppColors.warning),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _menyimpan ? null : _lanjutKePinBaru,
          icon: _menyimpan
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: const Text('Lanjut — Buat PIN Baru'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        if (_info!.questionsSet && _info!.codeSet)
          TextButton(
            onPressed: () => setState(() {
              _tahap = _Tahap.pilih;
              _error = null;
            }),
            child: Text(
              viaPertanyaan ? 'Ganti: pakai Kode Pemulihan' : 'Ganti: pakai '
                  'Pertanyaan Keamanan',
            ),
          ),
      ],
    );
  }

  /// Tahap tulis PIN baru (ketik → ulangi) dengan keypad yang sama.
  Widget _tulisPinBaru() {
    final String label = _konfirmasi ? 'Ulangi PIN Baru' : 'Buat PIN Baru';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(
          _konfirmasi
              ? 'Ketik kembali PIN yang sama untuk konfirmasi.'
              : 'PIN ${AppConstants.pinMinLength}–${AppConstants.pinMaxLength} '
                  'digit, bebas sesuai keinginan Anda.',
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
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
        ),
        const SizedBox(height: 16),
        PinKeypad(
          enabled: !_menyimpan,
          onDigit: _tambahDigit,
          onBackspace: _hapusDigit,
          onConfirm: _konfirmasiPin,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _menyimpan ? null : () => setState(() {
            _resetPinBaru();
            _error = null;
            _tahap = _jalur == _Jalur.pertanyaan
                ? _Tahap.pertanyaan
                : _Tahap.kode;
          }),
          child: const Text('Kembali'),
        ),
      ],
    );
  }
}