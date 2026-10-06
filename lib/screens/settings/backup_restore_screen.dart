import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../providers/session_provider.dart';
import '../../services/backup_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// Layar Backup & Restore: backup manual, restore dari file, daftar backup,
/// hapus backup, dan pengaturan backup otomatis.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _service = BackupService.instance;

  List<BackupFile> _files = <BackupFile>[];
  bool _loading = true;
  bool _busy = false;
  bool _autoEnabled = false;
  AutoBackupFrequency _freq = AutoBackupFrequency.mati;
  String _lastBackup = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<BackupFile> files = await _service.listBackupsSafe();
    final bool enabled = await _service.isAutoBackupEnabled();
    final AutoBackupFrequency freq = await _service.autoBackupFrequency();
    final String last = await _service.lastBackupLabel();
    if (!mounted) return;
    setState(() {
      _files = files;
      _autoEnabled = enabled;
      _freq = freq;
      _lastBackup = last;
      _loading = false;
    });
  }

  // ------------------------------------------------------------------
  // BACKUP MANUAL
  // ------------------------------------------------------------------

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      final String path = await _service.backupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup berhasil: ${p.basename(path)}'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesanErrorUmum(e, 'Backup database'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareBackup(BackupFile f) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(f.path)],
        downloadFallbackEnabled: true,
      ),
    );
  }

  // ------------------------------------------------------------------
  // RESTORE
  // ------------------------------------------------------------------

  Future<void> _pickAndRestore() async {
    final PlatformFile? picked = await FilePicker.pickFile(
      dialogTitle: 'Pilih file backup (.db)',
      type: FileType.custom,
      allowedExtensions: <String>['db'],
    );
    if (picked == null) return;
    final String? path = picked.path;
    if (path == null) return;
    await _confirmRestore(p.basename(path), path);
  }

  Future<void> _confirmRestore(String label, String path) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Restore Database',
      message: 'Restore akan MENGGANTI seluruh data saat ini dengan isi '
          'backup "$label".\n\n'
          'Data yang ada sekarang dan tidak ada di dalam backup akan HILANG '
          'permanen.\n\n'
          'Sebelum restore, salinan data saat ini akan dicadangkan otomatis. '
          'Anda akan logout setelah restore selesai. Lanjutkan?',
      confirmLabel: 'Ya, Restore',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.restore(path);
      if (!mounted) return;
      await context.read<SessionProvider>().logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore berhasil. Silakan login kembali.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesanErrorUmum(e, 'Restore database'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackup(BackupFile f) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Hapus File Backup',
      message: 'Hapus "${f.name}"? File ini tidak akan bisa dipulihkan.',
      confirmLabel: 'Hapus',
    );
    if (!ok || !mounted) return;
    await _service.deleteBackup(f.path);
    await _load();
  }

  // ------------------------------------------------------------------
  // BACKUP OTOMATIS
  // ------------------------------------------------------------------

  Future<void> _toggleAuto(bool value) async {
    await _service.setAutoBackup(enabled: value, frequency: _freq);
    if (value && _freq == AutoBackupFrequency.mati) {
      await _service.setAutoBackup(
        enabled: true,
        frequency: AutoBackupFrequency.harian,
      );
    }
    await _load();
  }

  Future<void> _changeFreq(AutoBackupFrequency f) async {
    setState(() => _freq = f);
    await _service.setAutoBackup(enabled: _autoEnabled, frequency: f);
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _cardAksi(),
                const SizedBox(height: 12),
                _cardOtomatis(),
                const SizedBox(height: 12),
                Text(
                  'Daftar File Backup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_files.isEmpty)
                  const EmptyState(
                    icon: Icons.save_alt_rounded,
                    title: 'Belum ada backup',
                    message: 'Buat backup pertama Anda dengan tombol "Backup '
                        'Sekarang" di atas.',
                  )
                else
                  for (final BackupFile f in _files) _tileFile(f),
              ],
            ),
    );
  }

  Widget _cardAksi() {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.backup_rounded, color: AppColors.navy),
                const SizedBox(width: 8),
                Text(
                  'Backup Database',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Backup terakhir: $_lastBackup',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _backupNow,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Backup Sekarang'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickAndRestore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore dari File...'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
              ),
            ),
            if (_busy) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardOtomatis() {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        children: <Widget>[
          SwitchListTile(
            value: _autoEnabled,
            onChanged: _busy ? null : _toggleAuto,
            title: const Text('Backup Otomatis'),
            subtitle: const Text('Backup dijalankan saat aplikasi dibuka'),
            secondary: const Icon(Icons.schedule_rounded, color: AppColors.teal),
          ),
          if (_autoEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: <Widget>[
                  const Text('Frekuensi:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<AutoBackupFrequency>(
                      segments: <ButtonSegment<AutoBackupFrequency>>[
                        const ButtonSegment<AutoBackupFrequency>(
                          value: AutoBackupFrequency.harian,
                          label: Text('Harian'),
                        ),
                        const ButtonSegment<AutoBackupFrequency>(
                          value: AutoBackupFrequency.mingguan,
                          label: Text('Mingguan'),
                        ),
                      ],
                      selected: <AutoBackupFrequency>{_freq},
                      onSelectionChanged: (Set<AutoBackupFrequency> s) {
                        _changeFreq(s.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileFile(BackupFile f) {
    return Card(
      elevation: 0,
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: AppColors.navy),
        title: Text(
          f.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${Formatters.tanggal(f.modified)} - ${f.sizeLabel}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (String v) {
            if (v == 'restore') {
              _confirmRestore(f.name, f.path);
            } else if (v == 'share') {
              _shareBackup(f);
            } else if (v == 'hapus') {
              _deleteBackup(f);
            }
          },
          itemBuilder: (BuildContext ctx) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'restore',
              child: Row(
                children: <Widget>[
                  Icon(Icons.restore_rounded),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Restore'),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: <Widget>[
                  Icon(Icons.share_rounded),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Bagikan / Simpan'),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'hapus',
              child: Row(
                children: <Widget>[
                  Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hapus',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
