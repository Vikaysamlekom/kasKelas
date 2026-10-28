import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../database/db_helper.dart';
import '../../models/school_profile_model.dart';
import '../../providers/session_provider.dart';
import '../../repositories/school_profile_repo.dart';
import '../../widgets/confirm_dialog.dart';

/// Layar Profil Sekolah: nama, NPSN, alamat, telepon, email, kepala sekolah,
/// nama bendahara, dan logo. Data ini dipakai di PDF bukti pembayaran & laporan.
class ProfilSekolahScreen extends StatefulWidget {
  const ProfilSekolahScreen({super.key});

  @override
  State<ProfilSekolahScreen> createState() => _ProfilSekolahScreenState();
}

class _ProfilSekolahScreenState extends State<ProfilSekolahScreen> {
  final SchoolProfileRepository _repo = SchoolProfileRepository();
  final TextEditingController _nama = TextEditingController();
  final TextEditingController _npsn = TextEditingController();
  final TextEditingController _alamat = TextEditingController();
  final TextEditingController _telepon = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _kepala = TextEditingController();
  final TextEditingController _bendahara = TextEditingController();

  String? _logoPath;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _nama,
      _npsn,
      _alamat,
      _telepon,
      _email,
      _kepala,
      _bendahara,
    ]) {
      c.addListener(_markDirty);
    }
    _load();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _nama,
      _npsn,
      _alamat,
      _telepon,
      _email,
      _kepala,
      _bendahara,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final SchoolProfileModel? p = await _repo.getProfile();
    if (!mounted) return;
    final String namaBendaharaAkun =
        context.read<SessionProvider>().user?.fullName ?? AppConstants.defaultFullName;
    if (p != null) {
      _nama.text = p.schoolName;
      _npsn.text = p.npsn ?? '';
      _alamat.text = p.address ?? '';
      _telepon.text = p.phone ?? '';
      _email.text = p.email ?? '';
      _kepala.text = p.headmaster ?? '';
      _bendahara.text = p.treasurer?.trim().isNotEmpty == true ? p.treasurer! : namaBendaharaAkun;
      _logoPath = p.logoPath;
    } else {
      _bendahara.text = namaBendaharaAkun;
    }
    setState(() {
      _loading = false;
      _dirty = false;
    });
  }

  // ------------------------------------------------------------------
  // LOGO
  // ------------------------------------------------------------------

  Future<void> _pickLogo(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
    } catch (e) {
      // Kamera/galeri tidak tersedia di perangkat ini.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Tidak dapat membuka kamera/galeri: $e')));
      }
      return;
    }
    if (picked == null || !mounted) return;

    // Salin ke Documents/profil agar file tetap ada walau cache dibersihkan.
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory(p.join(docs.path, 'profil'));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      final String ext = p.extension(picked.path).isEmpty ? '.png' : p.extension(picked.path);
      final File dest = File(p.join(dir.path, 'logo_${DateTime.now().microsecondsSinceEpoch}$ext'));
      await File(picked.path).copy(dest.path);
      if (!mounted) return;
      setState(() {
        _logoPath = dest.path;
        _dirty = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan logo: $e')));
      }
    }
  }

  Future<void> _hapusLogo() async {
    if (_logoPath == null) return;
    final bool ok = await showConfirmDialog(
      context,
      title: 'Hapus Logo',
      message: 'Logo sekolah akan dihapus?',
      confirmLabel: 'Hapus',
    );
    if (!ok || !mounted) return;
    if (!mounted) return;
    setState(() {
      _logoPath = null;
      _dirty = true;
    });
  }

  // ------------------------------------------------------------------
  // SIMPAN
  // ------------------------------------------------------------------

  Future<void> _save() async {
    if (_nama.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nama sekolah wajib diisi.')));
      return;
    }
    final String email = _email.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Format email tidak valid.')));
      return;
    }

    setState(() => _saving = true);
    final SessionProvider session = context.read<SessionProvider>();
    final String namaBendahara = _bendahara.text.trim().isEmpty
        ? (session.user?.fullName ?? AppConstants.defaultFullName)
        : _bendahara.text.trim();

    try {
      await _repo.saveProfile(
        SchoolProfileModel(
          schoolName: _nama.text.trim(),
          npsn: _npsn.text.trim(),
          address: _alamat.text.trim(),
          phone: _telepon.text.trim(),
          email: email,
          headmaster: _kepala.text.trim(),
          treasurer: namaBendahara,
          logoPath: _logoPath,
          updatedAt: DateTime.now(),
        ),
      );

      // Sinkronkan ke tabel settings (dipakai dashboard & export).
      final DBHelper db = DBHelper.instance;
      await db.setSetting('school_name', _nama.text.trim());
      await db.setSetting('treasurer_name', namaBendahara);
    } catch (e) {
      // Tanpa catch, _saving tetap true sehingga tombol Simpan mati permanen.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanErrorUmum(e, 'Simpan profil sekolah'))));
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil sekolah disimpan.'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final bool leave = await showConfirmDialog(
          context,
          title: 'Keluar tanpa menyimpan?',
          message: 'Perubahan profil sekolah belum disimpan.',
          confirmLabel: 'Keluar',
        );
        if (leave && context.mounted) {
          if (!mounted) return;
          setState(() => _dirty = false);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profil Sekolah'),
          actions: <Widget>[
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Simpan'),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _cardBendahara(),
                  const SizedBox(height: 12),
                  _cardLogo(),
                  const SizedBox(height: 12),
                  _cardIdentitas(),
                  const SizedBox(height: 12),
                  _cardKontak(),
                  const SizedBox(height: 12),
                  _cardPimpinan(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Simpan Profil Sekolah'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.navy,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _cardBendahara() {
    final String username = context.read<SessionProvider>().user?.username ?? 'Akun bendahara';

    return _card(
      title: 'Profil Bendahara',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.navy, AppColors.navySoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _bendahara,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    return CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      child: Text(
                        _inisial(value.text),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _bendahara,
                    builder: (BuildContext context, TextEditingValue value, _) {
                      final String nama = value.text.trim();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            nama.isEmpty ? 'Nama bendahara' : nama,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BENDAHARA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _field(
            _bendahara,
            'Nama Bendahara',
            Icons.person_outline_rounded,
            helper: 'Nama ini akan ditampilkan pada laporan.',
          ),
        ],
      ),
    );
  }

  String _inisial(String nama) {
    final List<String> bagian = nama.trim().split(RegExp(r'\s+'))
      ..removeWhere((String kata) => kata.isEmpty);
    if (bagian.isEmpty) return 'B';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return '${bagian.first[0]}${bagian.last[0]}'.toUpperCase();
  }

  Widget _cardLogo() {
    return _card(
      title: 'Logo Sekolah',
      icon: Icons.image_outlined,
      child: Column(
        children: <Widget>[
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: _logoPath == null
                ? const Icon(Icons.school_rounded, size: 48, color: AppColors.textMuted)
                : Image.file(
                    File(_logoPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext _, Object _, StackTrace? _) => const Icon(
                      Icons.broken_image_rounded,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // `Wrap`, bukan `Row`: Row meneruskan lebar tak terbatas ke anak
          // yang tidak dibungkus Expanded, sehingga OutlinedButton melempar
          // "BoxConstraints forces an infinite width". Wrap juga otomatis
          // turun baris di layar sempit.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _pickLogo(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Kamera'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickLogo(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galeri'),
              ),
              if (_logoPath != null) ...<Widget>[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _hapusLogo,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  tooltip: 'Hapus logo',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardIdentitas() {
    return _card(
      title: 'Identitas Sekolah',
      icon: Icons.badge_outlined,
      child: Column(
        children: <Widget>[
          _field(_nama, 'Nama Sekolah *', Icons.school_outlined),
          const SizedBox(height: 12),
          _field(_npsn, 'NPSN', Icons.numbers_rounded),
        ],
      ),
    );
  }

  Widget _cardKontak() {
    return _card(
      title: 'Kontak',
      icon: Icons.contact_page_outlined,
      child: Column(
        children: <Widget>[
          _field(_alamat, 'Alamat', Icons.location_on_outlined, maxLines: 3),
          const SizedBox(height: 12),
          _field(_telepon, 'Telepon', Icons.phone_outlined, keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _cardPimpinan() {
    return _card(
      title: 'Kepala Sekolah',
      icon: Icons.how_to_reg_outlined,
      child: Column(
        children: <Widget>[_field(_kepala, 'Kepala Sekolah', Icons.person_outline_rounded)],
      ),
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: AppColors.navy),
                const SizedBox(width: 8),
                Text(title, style: AppText.sectionTitle.copyWith(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? helper,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
