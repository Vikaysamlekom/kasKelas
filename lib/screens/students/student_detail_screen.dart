import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/student_model.dart';
import '../../providers/session_provider.dart';
import '../../providers/students_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'student_form_screen.dart';

/// Detail siswa + aksi (ubah, ubah status, hapus).
/// Siswa dengan riwayat pembayaran TIDAK dapat dihapus, hanya status.
class StudentDetailScreen extends StatefulWidget {
  final int studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  StudentModel? _student;
  int _paymentCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final StudentsProvider provider = context.read<StudentsProvider>();
    final StudentModel? found = await _find(provider, widget.studentId);
    final int count = found == null
        ? 0
        : await provider.paymentCount(found.id!);
    if (mounted) {
      setState(() {
        _student = found;
        _paymentCount = count;
        _loading = false;
      });
    }
  }

  Future<StudentModel?> _find(StudentsProvider provider, int id) async {
    // Ambil langsung dari database agar tidak terpengaruh paginasi list.
    return provider.studentById(id);
  }

  Future<void> _edit() async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudentFormScreen(student: _student),
      ),
    );
    if (changed == true && mounted) {
      _student = null;
      _loading = true;
      setState(() {});
      _load();
    }
  }

  Future<void> _changeStatus() async {
    final StudentModel s = _student!;
    final String? newStatus = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Ubah Status Siswa', style: AppText.title),
              ),
              _StatusOption(
                label: 'Aktif',
                description: 'Siswa mengikuti pembelajaran',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.teal,
                onTap: () => Navigator.of(context).pop('aktif'),
              ),
              _StatusOption(
                label: 'Cuti',
                description: 'Izin tidak masuk untuk sementara',
                icon: Icons.hotel_rounded,
                color: AppColors.orange,
                onTap: () => Navigator.of(context).pop('cuti'),
              ),
              _StatusOption(
                label: 'Lulus',
                description: 'Siswa sudah lulus / pindah sekolah',
                icon: Icons.school_outlined,
                color: AppColors.blue,
                onTap: () => Navigator.of(context).pop('lulus'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (newStatus == null || newStatus == s.status || !mounted) return;

    final StudentsProvider provider = context.read<StudentsProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;
    await jalankanAksi(context, () async {
      await provider.changeStatus(s.id!, newStatus, userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status ${s.name} diubah menjadi $newStatus.')),
        );
        _load();
      }
    }, konteks: 'Ubah status siswa');
  }

  Future<void> _delete() async {
    final StudentModel s = _student!;
    if (_paymentCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak bisa dihapus karena memiliki riwayat pembayaran.\nGanti statusnya saja (mis. Lulus).',
          ),
        ),
      );
      return;
    }

    final bool ok = await showConfirmDialog(
      context,
      title: 'Hapus Siswa',
      message: 'Hapus ${s.name} (NIS ${s.nis})?\nData tidak bisa dikembalikan.',
    );
    if (!ok || !mounted) return;

    final StudentsProvider provider = context.read<StudentsProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;
    await jalankanAksi(context, () async {
      final bool removed = await provider.deleteStudent(s.id!, userId: userId);
      if (!mounted) return;
      if (removed) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak bisa dihapus karena memiliki riwayat pembayaran.\nGanti statusnya saja (mis. Lulus).',
            ),
          ),
        );
      }
    }, konteks: 'Hapus siswa');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Siswa')),
        body: const AppLoading(),
      );
    }
    final StudentModel s = _student!;
    final String genderLabel = s.gender == 'P' ? 'Perempuan' : 'Laki-laki';

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Siswa')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // KEPALA
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (s.gender == 'P' ? AppColors.blue : AppColors.teal)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.name,
                            style: AppText.title.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          StatusBadge.siswa(s.status),
                          const SizedBox(height: 6),
                          Text(
                            'NIS ${s.nis} · $genderLabel',
                            style: AppText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_paymentCount > 0) ...<Widget>[
                AppCard(
                  color: AppColors.orange.withValues(alpha: 0.08),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Siswa ini memiliki $_paymentCount pembayaran. '
                          'Data tidak dapat dihapus — ganti status saja.',
                          style: AppText.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // INFO
              AppCard(
                child: Column(
                  children: <Widget>[
                    _InfoRow(label: 'NISN', value: s.nisn ?? '-'),
                    _InfoRow(label: 'Kelas', value: s.className ?? '-'),
                    _InfoRow(label: 'Jurusan', value: s.majorName ?? '-'),
                    _InfoRow(label: 'No HP Wali', value: s.phone ?? '-'),
                    _InfoRow(label: 'Nama Wali', value: s.parentName ?? '-'),
                    _InfoRow(label: 'Alamat', value: s.address ?? '-'),
                    _InfoRow(
                      label: 'Bergabung',
                      value: Formatters.tanggalIso(s.joinDate),
                    ),
                    _InfoRow(
                      label: 'Riwayat Pembayaran',
                      value: '$_paymentCount transaksi',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // AKSI
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ubah Data Siswa'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _changeStatus,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('Ubah Status'),
              ),
              if (_paymentCount == 0) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus Siswa'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(description, style: AppText.caption),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label, style: AppText.label),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}