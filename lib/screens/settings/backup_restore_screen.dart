import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../providers/session_provider.dart';
import '../../services/backup_service.dart';
import '../../utils/file_export.dart';
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
  String? _autoBackupError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (kIsWeb) {
      try {
        final List<BackupFile> files = await _service.listWebAutoBackups();
        final bool enabled = await _service.isAutoBackupEnabled();
        final AutoBackupFrequency freq = await _service.autoBackupFrequency();
        final String last = await _service.lastBackupLabel();
        final String? error = await _service.lastAutoBackupError();
        if (!mounted) return;
        setState(() {
          _files = files;
          _autoEnabled = enabled;
          _freq = freq;
          _lastBackup = last;
          _autoBackupError = error;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _autoBackupError = pesanErrorUmum(e, 'Memuat backup browser');
          _loading = false;
        });
      }
      return;
    }
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
      _autoBackupError = null;
      _loading = false;
    });
  }

  // ------------------------------------------------------------------
  // BACKUP MANUAL
  // ------------------------------------------------------------------

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        final Uint8List bytes = await _service.createWebBackup();
        final String name = BackupService.webFileNameFor(DateTime.now());
        await shareOrDownloadBytes(
          bytes: bytes,
          fileName: name,
          mimeType: 'application/json',
          text: 'Backup ${AppConstants.appName}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup siap diunduh: $name'),
            backgroundColor: AppColors.success,
          ),
        );
        await _load();
        return;
      }

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
    if (kIsWeb) {
      try {
        await shareOrDownloadBytes(
          bytes: await _service.webAutoBackupBytes(f.path),
          fileName: f.name,
          mimeType: 'application/json',
          text: 'Backup ${AppConstants.appName}',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(pesanErrorUmum(e, 'Mengunduh backup'))),
          );
        }
      }
      return;
    }

    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(f.path)], downloadFallbackEnabled: true),
    );
  }

  // ------------------------------------------------------------------
  // RESTORE
  // ------------------------------------------------------------------

  Future<void> _pickAndRestore() async {
    if (kIsWeb) {
      final PlatformFile? picked = await FilePicker.pickFile(
        dialogTitle: 'Pilih file backup (.json)',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (picked == null) return;

      try {
        final Uint8List bytes = await picked.readAsBytes();
        if (bytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File backup kosong atau tidak bisa dibaca.'),
              ),
            );
          }
          return;
        }
        await _confirmRestoreAction(
          picked.name,
          () => _service.restoreWebBackup(bytes),
          web: true,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pesanErrorUmum(e, 'Membaca file backup'))),
        );
      }
      return;
    }

    final PlatformFile? picked = await FilePicker.pickFile(
      dialogTitle: 'Pilih file backup (.db)',
      type: FileType.custom,
      allowedExtensions: <String>['db'],
    );
    if (picked == null) return;
    final String? path = picked.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File backup tidak bisa dibaca di perangkat ini.'),
          ),
        );
      }
      return;
    }
    await _confirmRestore(p.basename(path), path);
  }

  Future<void> _confirmRestore(String label, String path) {
    return _confirmRestoreAction(label, () => _service.restore(path));
  }

  Future<void> _confirmRestoreAction(
    String label,
    Future<void> Function() restore, {
    bool web = false,
  }) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Restore Database',
      message: web
          ? 'Restore akan MENGGANTI seluruh data web saat ini dengan isi '
                'file "$label".\n\n'
                'Pastikan file JSON ini berasal dari aplikasi Kas Bintang '
                'Nusantara dan sudah Anda simpan di tempat aman.\n\n'
                'Anda akan logout setelah restore selesai. Lanjutkan?'
          : 'Restore akan MENGGANTI seluruh data saat ini dengan isi '
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
      await restore();
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
      title: kIsWeb ? 'Hapus Snapshot Backup' : 'Hapus File Backup',
      message: 'Hapus "${f.name}"? Backup ini tidak akan bisa dipulihkan.',
      confirmLabel: 'Hapus',
    );
    if (!ok || !mounted) return;
    try {
      if (kIsWeb) {
        await _service.deleteWebAutoBackup(f.path);
      } else {
        await _service.deleteBackup(f.path);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesanErrorUmum(e, 'Menghapus backup'))),
      );
    }
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
    if (kIsWeb && value) {
      await _service.runScheduledBackupIfDue();
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
                if (kIsWeb) ...<Widget>[
                  const SizedBox(height: 12),
                  _cardInfoWeb(),
                ],
                const SizedBox(height: 12),
                if (kIsWeb || _files.isNotEmpty) ...<Widget>[
                  Text(
                    kIsWeb
                        ? 'Snapshot Otomatis di Browser'
                        : 'Daftar File Backup',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_files.isEmpty)
                    const EmptyState(
                      icon: Icons.save_alt_rounded,
                      title: 'Belum ada snapshot otomatis',
                      message:
                          'Aktifkan Backup Otomatis untuk menyimpan '
                          'snapshot di browser ini.',
                    )
                  else
                    for (final BackupFile f in _files) _tileFile(f),
                ],
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
                Icon(
                  kIsWeb ? Icons.cloud_download_rounded : Icons.backup_rounded,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 8),
                Text(
                  kIsWeb ? 'Backup Data (Web)' : 'Backup Database',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${kIsWeb ? 'Backup otomatis terakhir' : 'Backup terakhir'}: '
              '$_lastBackup',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (kIsWeb) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Backup manual diunduh sebagai JSON. Simpan file tersebut '
                'di luar browser untuk cadangan tambahan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _backupNow,
              icon: Icon(
                kIsWeb ? Icons.download_rounded : Icons.save_alt_rounded,
              ),
              label: Text(kIsWeb ? 'Unduh Backup (JSON)' : 'Backup Sekarang'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickAndRestore,
              icon: const Icon(Icons.restore_rounded),
              label: Text(
                kIsWeb ? 'Restore dari File JSON...' : 'Restore dari File...',
              ),
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

  Widget _cardInfoWeb() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded, color: AppColors.teal),
                const SizedBox(width: 8),
                Text(
                  'Backup di Web',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Data aplikasi web tersimpan di penyimpanan browser (IndexedDB). '
              'Backup otomatis menyimpan hingga '
              '${BackupService.webAutoBackupRetention} snapshot di browser ini '
              'sesuai frekuensi yang dipilih. Snapshot dapat dipulihkan atau '
              'diunduh dari daftar di bawah. Unduhan otomatis ke folder '
              'perangkat tidak diizinkan browser; gunakan Backup Data (Web) '
              'untuk mengunduh salinan JSON secara manual.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_autoBackupError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Backup otomatis terakhir gagal: $_autoBackupError',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.danger),
              ),
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
            subtitle: Text(
              kIsWeb
                  ? 'Snapshot disimpan di browser saat aplikasi dibuka'
                  : 'Backup dijalankan saat aplikasi dibuka',
            ),
            secondary: const Icon(
              Icons.schedule_rounded,
              color: AppColors.teal,
            ),
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
              if (kIsWeb) {
                _confirmRestoreAction(
                  f.name,
                  () => _service.restoreWebAutoBackup(f.path),
                  web: true,
                );
              } else {
                _confirmRestore(f.name, f.path);
              }
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
                  Expanded(child: Text('Restore')),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: <Widget>[
                  Icon(Icons.share_rounded),
                  SizedBox(width: 8),
                  Expanded(child: Text('Bagikan / Simpan')),
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
