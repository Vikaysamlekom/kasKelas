import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../database/db_helper.dart';
import '../../providers/session_provider.dart';
import '../../repositories/auth_repository.dart';

/// Sheet untuk mengatur data pemulihan PIN:
/// * dua pertanyaan keamanan + jawaban (disimpan sebagai hash),
/// * kode pemulihan `XXXXX-XXXXX` (ditampilkan SEKALI, disimpan hash).
///
/// Dipakai dari menu Ubah PIN dan tawaran otomatis setelah login sukses.
Future<bool?> showRecoverySetupSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const RecoverySetupSheet(),
  );
}

/// Tawaran sekali per aplikasi terbuka: aktifkan pemulihan PIN atau nanti.
/// [info] sudah diperiksa memuat `siap == false` oleh pemanggil.
Future<void> showRecoveryPromptDialog(
  BuildContext context, {
  required RecoveryInfo info,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Aktifkan Pemulihan PIN'),
        content: Text(
          'Sekarang belum ada data pemulihan, sehingga PIN terlupa hanya '
          'bisa ditangani lewat Pengaturan → Backup & Restore.\n\n'
          'Aktifkan pertanyaan keamanan + kode pemulihan agar masuk kembali '
          'bisa dilakukan sendiri dari layar Lupa PIN di halaman login.',
          style: AppText.bodySmall,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              showRecoverySetupSheet(context);
            },
            child: const Text('Atur Sekarang'),
          ),
        ],
      );
    },
  );
}

class RecoverySetupSheet extends StatefulWidget {
  const RecoverySetupSheet({super.key});

  @override
  State<RecoverySetupSheet> createState() => _RecoverySetupSheetState();
}

class _RecoverySetupSheetState extends State<RecoverySetupSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Pilihan yang sedang aktif di dropdown (index daftar pertanyaan preset).
  int _q1Index = 0;
  int _q2Index = 1;

  final TextEditingController _a1 = TextEditingController();
  final TextEditingController _a2 = TextEditingController();

  /// Kode baru yang BaruDibuat & ditampilkan sekali (belum tersimpan).
  String? _kodeBaru;
  bool _pakaiKode = true;
  bool _sudahMencatatKode = false;
  bool _menyimpan = false;
  String? _error;
  RecoveryInfo? _info;

  @override
  void initState() {
    super.initState();
    _muatInfo();
  }

  @override
  void dispose() {
    _a1.dispose();
    _a2.dispose();
    super.dispose();
  }

  Future<void> _muatInfo() async {
    final RecoveryInfo info =
        await context.read<SessionProvider>().recoveryInfo();
    if (!mounted) return;
    setState(() => _info = info);
  }

  void _buatKode() {
    setState(() {
      _kodeBaru = AuthRepository.generateRecoveryCodePlain();
      _sudahMencatatKode = false;
      _error = null;
    });
  }

  Future<void> _salinKode() async {
    if (_kodeBaru == null) return;
    await Clipboard.setData(ClipboardData(text: _kodeBaru!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode pemulihan disalin.')),
      );
    }
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    final String a1 = _a1.text.trim();
    final String a2 = _a2.text.trim();
    if (a1.isEmpty || a2.isEmpty) {
      setState(() => _error = 'Kedua jawaban wajib diisi.');
      return;
    }
    if (a1.toLowerCase() == a2.toLowerCase()) {
      setState(() => _error =
          'Jawaban kedua sebaiknya berbeda — jawaban yang sama mudah '
          'ditebak.');
      return;
    }
    // Kode wajib diaktifkan bila belum pernah ada dan user memilih pakai.
    if (_pakaiKode && _kodeBaru == null && !(_info?.codeSet ?? false)) {
      setState(() => _error =
          'Tekan "Buat Kode Baru" untuk mengaktifkan kode pemulihan.');
      return;
    }
    if (_pakaiKode && _kodeBaru != null && !_sudahMencatatKode) {
      setState(() => _error =
          'Centang "Saya sudah mencatat kode ini" sebelum menyimpan.');
      return;
    }

    setState(() {
      _menyimpan = true;
      _error = null;
    });
    final SessionProvider session = context.read<SessionProvider>();
    final int? userId = session.user?.id;
    try {
      await session.activateRecovery(
            q1: AppConstants.recoveryQuestions[_q1Index],
            a1: a1,
            q2: AppConstants.recoveryQuestions[_q2Index],
            a2: a2,
            recoveryCode: (_pakaiKode && _kodeBaru != null) ? _kodeBaru : null,
          );
      await DBHelper.instance.logAudit(
        userId: userId,
        action: 'setup_recovery',
        entityTable: DBHelper.tblUsers,
        entityId: userId,
        description: 'Mengatur pertanyaan keamanan & kode pemulihan PIN',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pemulihan PIN aktif.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _menyimpan = false;
          _error = 'Gagal menyimpan: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool pertanyaanAktif = _info?.questionsSet ?? false;
    final bool kodeAktif = _info?.codeSet ?? false;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Pemulihan PIN', style: AppText.title),
                const SizedBox(height: 4),
                Text(
                  'Untuk halaman Lupa PIN: jawaban & kode disimpan sebagai '
                  "hash — tidak ada yang bisa membaca isinya.",
                  style: AppText.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _KeadaanChip(
                      label: 'Pertanyaan',
                      aktif: pertanyaanAktif,
                    ),
                    _KeadaanChip(label: 'Kode', aktif: kodeAktif),
                  ],
                ),
                const SizedBox(height: 16),

                // PERTANYAAN 1
                DropdownButtonFormField<int>(
                  initialValue: _q1Index,
                  decoration: const InputDecoration(
                    labelText: 'Pertanyaan Keamanan 1 *',
                    prefixIcon: Icon(Icons.help_outline_rounded),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (int i = 0;
                        i < AppConstants.recoveryQuestions.length;
                        i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(AppConstants.recoveryQuestions[i]),
                      ),
                  ],
                  onChanged: (int? v) =>
                      setState(() => _q1Index = v ?? _q1Index),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _a1,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Jawaban Pertanyaan 1 *',
                    prefixIcon: Icon(Icons.text_fields_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // PERTANYAAN 2
                DropdownButtonFormField<int>(
                  initialValue: _q2Index,
                  decoration: const InputDecoration(
                    labelText: 'Pertanyaan Keamanan 2 *',
                    prefixIcon: Icon(Icons.help_outline_rounded),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (int i = 0;
                        i < AppConstants.recoveryQuestions.length;
                        i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(AppConstants.recoveryQuestions[i]),
                      ),
                  ],
                  onChanged: (int? v) =>
                      setState(() => _q2Index = v ?? _q2Index),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _a2,
                  decoration: const InputDecoration(
                    labelText: 'Jawaban Pertanyaan 2 *',
                    prefixIcon: Icon(Icons.text_fields_rounded),
                  ),
                ),
                const SizedBox(height: 18),

                // KODE PEMULIHAN
                Card(
                  elevation: 0,
                  color: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.key_rounded,
                                size: 18, color: AppColors.navy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kode Pemulihan',
                                style: AppText.sectionTitle
                                    .copyWith(fontSize: 14),
                              ),
                            ),
                            Switch(
                              value: _pakaiKode,
                              onChanged: (bool v) =>
                                  setState(() => _pakaiKode = v),
                            ),
                          ],
                        ),
                        Text(
                          'Ditampilkan SEKALI saat dibuat — catat di buku '
                          'khusus atau password manager.',
                          style: AppText.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        if (_pakaiKode) ...<Widget>[
                          if (_kodeBaru != null) ...<Widget>[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.navy.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _kodeBaru!,
                                      textAlign: TextAlign.center,
                                      style: AppText.title.copyWith(
                                        fontSize: 20,
                                        letterSpacing: 2,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Salin',
                                    onPressed: _salinKode,
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 20),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: _sudahMencatatKode,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              dense: true,
                              title: const Text(
                                'Saya sudah mencatat kode ini',
                              ),
                              onChanged: (bool? v) => setState(
                                  () => _sudahMencatatKode = v ?? false),
                            ),
                          ] else
                            OutlinedButton.icon(
                              onPressed: _menyimpan ? null : _buatKode,
                              icon: const Icon(Icons.casino_rounded),
                              label: Text(kodeAktif
                                  ? 'Buat Kode Baru (perbarui)'
                                  : 'Buat Kode Baru'),
                            ),
                        ] else
                          Text(
                            kodeAktif
                                ? 'Kode yang sudah aktif tetap berlaku. '
                                    'Bila ingin nonaktif, hubungi pengembang.'
                                : 'Kode pemulihan tidak diaktifkan.',
                            style: AppText.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),

                // ERROR
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _menyimpan ? null : _simpan,
                  icon: _menyimpan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Simpan Pemulihan'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip kecil status aktif/nonaktif pemulihan.
class _KeadaanChip extends StatelessWidget {
  final String label;
  final bool aktif;

  const _KeadaanChip({required this.label, required this.aktif});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (aktif ? AppColors.teal : AppColors.textMuted)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: ${aktif ? 'Aktif' : 'Nonaktif'}',
        style: AppText.caption.copyWith(
          color: aktif ? AppColors.teal : AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}