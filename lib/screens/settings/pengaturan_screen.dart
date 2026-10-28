import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../database/db_helper.dart';
import '../../providers/session_provider.dart';
import '../../repositories/school_profile_repo.dart';
import '../../widgets/confirm_dialog.dart';
import '../pengeluaran/pengeluaran_screen.dart';
import '../payments/tunggakan_screen.dart';
import '../transactions/audit_log_screen.dart';
import 'about_us_screen.dart';
import 'backup_restore_screen.dart';
import 'profil_sekolah_screen.dart';
import 'ubah_pin_screen.dart';

/// Tab "Lainnya" — menu pengaturan & shortcut navigasi.
class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final SchoolProfileRepository _schoolProfileRepository = SchoolProfileRepository();
  String? _namaBendahara;

  @override
  void initState() {
    super.initState();
    _loadNamaBendahara();
  }

  Future<void> _loadNamaBendahara() async {
    try {
      final profile = await _schoolProfileRepository.getProfile();
      if (!mounted) return;
      final String? nama = profile?.treasurer?.trim();
      setState(() {
        _namaBendahara = nama != null && nama.isNotEmpty ? nama : null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memuat profil bendahara: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionProvider session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          //_kartuUser(session, _namaBendahara ?? session.user?.fullName ?? '-'),
          const SizedBox(height: 16),
          _label('PENGATURAN'),
          _tile(
            icon: Icons.school_outlined,
            title: 'Profil Sekolah',
            subtitle: 'Nama, alamat, kontak, logo, bendahara',
            onTap: () async {
              await _push<void>(context, const ProfilSekolahScreen());
              if (mounted) await _loadNamaBendahara();
            },
          ),
          _tile(
            icon: Icons.pin_rounded,
            title: 'Ubah PIN',
            subtitle: 'Ganti kata sandi login bendahara',
            onTap: () async {
              final bool? changed = await _push<bool>(context, const UbahPinScreen());
              if (changed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN berhasil diubah.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          _tile(
            icon: Icons.backup_rounded,
            title: 'Backup & Restore',
            subtitle: 'Cadangkan dan pulihkan database',
            onTap: () => _push<void>(context, const BackupRestoreScreen()),
          ),
          const SizedBox(height: 16),
          _label('TRANSAKSI'),
          _tile(
            icon: Icons.payments_outlined,
            title: 'Pengeluaran',
            subtitle: 'Catat & kelola pengeluaran kas',
            onTap: () => _push<void>(context, const PengeluaranScreen()),
          ),
          _tile(
            icon: Icons.event_busy_outlined,
            title: 'Tunggakan',
            subtitle: 'Daftar siswa yang belum lunas',
            onTap: () => _push<void>(context, const TunggakanScreen()),
          ),
          const SizedBox(height: 16),
          _label('LAINNYA'),
          _tile(
            icon: Icons.history_rounded,
            title: 'Audit Log',
            subtitle: 'Jejak aktivitas pengguna',
            onTap: () => _push<void>(context, const AuditLogScreen()),
          ),
          _tile(
            icon: Icons.info_outline_rounded,
            title: 'Tentang',
            subtitle: 'Informasi aplikasi dan kelompok pengabdi',
            onTap: () => _push<void>(context, const AboutUsScreen()),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.logout_rounded,
            title: 'Keluar',
            subtitle: 'Keluar dari aplikasi',
            color: AppColors.danger,
            onTap: () => _logout(context, session),
          ),
        ],
      ),
    );
  }

  Future<T?> _push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context, SessionProvider session) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Keluar',
      message:
          'Anda akan keluar dari aplikasi.\n'
          'Pastikan perubahan data sudah tersimpan.',
      confirmLabel: 'Keluar',
    );
    if (!ok || !context.mounted) return;

    await DBHelper.instance.logAudit(
      userId: session.user?.id,
      action: 'logout',
      entityTable: DBHelper.tblUsers,
      entityId: session.user?.id,
      description: 'User logout dari aplikasi',
    );
    await session.logout();
  }

  Widget _kartuUser(SessionProvider session, String namaBendahara) {
    return Card(
      elevation: 0,
      color: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    namaBendahara,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Username: ${session.user?.username ?? '-'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: AppText.bodySmall.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.6),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final Color c = color ?? AppColors.navy;
    return Card(
      elevation: 0,
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color == null ? AppColors.divider : color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c),
        ),
        subtitle: Text(subtitle, style: AppText.bodySmall),
        trailing: Icon(Icons.chevron_right_rounded, color: color ?? AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
