import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../database/db_helper.dart';
import '../../providers/session_provider.dart';
import '../../repositories/auth_repository.dart';

/// Layar Ubah PIN (kata sandi login bendahara).
/// Verifikasi PIN lama memakai hash SHA-256 + salt username (lihat DBHelper).
class UbahPinScreen extends StatefulWidget {
  const UbahPinScreen({super.key});

  @override
  State<UbahPinScreen> createState() => _UbahPinScreenState();
}

class _UbahPinScreenState extends State<UbahPinScreen> {
  final AuthRepository _auth = AuthRepository();

  final TextEditingController _lama = TextEditingController();
  final TextEditingController _baru = TextEditingController();
  final TextEditingController _konfirmasi = TextEditingController();

  bool _sembunyikan = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _ganti() async {
    final String lama = _lama.text;
    final String baru = _baru.text;
    final String konfirmasi = _konfirmasi.text;

    if (lama.isEmpty || baru.isEmpty) {
      setState(() => _error = 'PIN lama dan PIN baru wajib diisi.');
      return;
    }
    if (baru.length < 6) {
      setState(() => _error = 'PIN baru minimal 6 karakter.');
      return;
    }
    if (baru != konfirmasi) {
      setState(() => _error = 'Konfirmasi PIN tidak cocok.');
      return;
    }
    if (baru == lama) {
      setState(() => _error = 'PIN baru harus berbeda dari PIN lama.');
      return;
    }

    final SessionProvider session = context.read<SessionProvider>();
    final int? userId = session.user?.id;
    if (userId == null) {
      setState(() => _error = 'Sesi tidak ditemukan. Silakan login ulang.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final bool ok = await _auth.changePassword(
      userId: userId,
      oldPassword: lama,
      newPassword: baru,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      setState(() => _error = 'PIN lama salah.');
      return;
    }

    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'update',
      entityTable: DBHelper.tblUsers,
      entityId: userId,
      description: 'Mengubah PIN (kata sandi) pengguna',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN berhasil diubah.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah PIN')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            elevation: 0,
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.pin_rounded, color: AppColors.navy),
                      const SizedBox(width: 8),
                      Text(
                        'PIN Login',
                        style: AppText.sectionTitle.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PIN ini sama dengan kata sandi untuk masuk ke aplikasi '
                    '(${context.watch<SessionProvider>().user?.username ?? '-'}).',
                    style: AppText.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _pinField(_lama, 'PIN Lama', Icons.lock_outline_rounded),
                  const SizedBox(height: 12),
                  _pinField(_baru, 'PIN Baru', Icons.lock_reset_rounded),
                  const SizedBox(height: 12),
                  _pinField(
                    _konfirmasi,
                    'Konfirmasi PIN Baru',
                    Icons.lock_person_rounded,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppText.bodySmall
                                  .copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _loading ? null : _ganti,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Simpan PIN Baru'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Simpan PIN baru di tempat aman. Aplikasi tidak dapat '
                      'menampilkan PIN lama Anda.',
                      style: AppText.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinField(
    TextEditingController c,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: c,
      obscureText: _sembunyikan,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(64),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _sembunyikan = !_sembunyikan),
          icon: Icon(
            _sembunyikan
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
