import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../database/db_helper.dart';
import '../../models/class_model.dart';
import '../../models/major_model.dart';
import '../../providers/classes_provider.dart';
import '../../providers/session_provider.dart';
import '../../repositories/kelas_repo.dart';
import '../../repositories/siswa_repo.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// Halaman manajemen Kelas & Jurusan (tab).
///
/// Tombol aksi (FAB) menyesuaikan tab yang sedang aktif, sehingga pengguna
/// selalu punya cara membuat Kelas maupun Jurusan baru.
class KelasScreen extends StatefulWidget {
  const KelasScreen({super.key});

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTab);
  }

  void _onTab() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTab);
    _tabController.dispose();
    super.dispose();
  }

  bool get _diTabJurusan => _tabController.index == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelas & Jurusan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Kelas', icon: Icon(Icons.meeting_room_outlined)),
            Tab(text: 'Jurusan', icon: Icon(Icons.account_tree_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[_KelasTab(), _JurusanTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-kelas-jurusan',
        onPressed: () =>
            _diTabJurusan ? _JurusanTab.openForm(context) : _KelasTab.openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(_diTabJurusan ? 'Tambah Jurusan' : 'Tambah Kelas'),
      ),
    );
  }
}

// ============================================================
// TAB KELAS
// ============================================================

class _KelasTab extends StatelessWidget {
  const _KelasTab();

  /// Buka form tambah/ubah kelas. Mengembalikan id kelas yang tersimpan.
  static Future<int?> openForm(BuildContext context, {ClassWithMeta? existing}) async {
    final ClassesProvider provider = context.read<ClassesProvider>();
    final int? savedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => _KelasForm(classes: provider, existing: existing),
    );
    if (savedId != null) provider.load();
    return savedId;
  }

  Future<void> _delete(BuildContext context, ClassWithMeta item) async {
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Kelas',
      message: item.studentCount > 0
          ? 'Kelas ${item.kelas.name} masih dipakai ${item.studentCount} siswa '
                'aktif.\nKelas akan diubah menjadi NONAKTIF.'
          : 'Hapus kelas ${item.kelas.name}?\nData tidak bisa dikembalikan.',
      confirmLabel: 'Ya',
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final ClassesProvider provider = context.read<ClassesProvider>();
    await jalankanAksi(context, () async {
      final DeleteResult result = await provider.deleteClass(
        item.kelas.id!,
        userId: context.read<SessionProvider>().user?.id,
      );
      if (context.mounted) {
        showDeleteResult(context, result, 'Kelas ${item.kelas.name}');
      }
    }, konteks: 'Hapus kelas');
  }

  @override
  Widget build(BuildContext context) {
    final ClassesProvider classes = context.watch<ClassesProvider>();
    if (classes.isLoading && classes.classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (classes.classes.isEmpty) {
      return EmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'Belum ada kelas',
        message: 'Buat kelas terlebih dahulu, lalu barulah bisa menambah siswa.',
        action: FilledButton.icon(
          onPressed: () => openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Buat Kelas'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: classes.classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final ClassWithMeta c = classes.classes[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (c.kelas.isActive ? AppColors.navy : AppColors.textMuted).withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'X${c.kelas.level}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: c.kelas.isActive ? AppColors.navy : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            c.kelas.name,
                            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!c.kelas.isActive) ...<Widget>[
                          const SizedBox(width: 6),
                          _MiniTag('Nonaktif', AppColors.danger),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${c.majorName ?? 'Tanpa jurusan'} · wali: ${c.kelas.homeroomTeacher ?? '-'}',
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${c.studentCount} siswa aktif · ${c.kelas.academicYear}',
                      style: AppText.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
                onPressed: () => openForm(context, existing: c),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: () => _delete(context, c),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Form kelas (bottom sheet).
class _KelasForm extends StatefulWidget {
  final ClassesProvider classes;
  final ClassWithMeta? existing;

  const _KelasForm({required this.classes, this.existing});

  @override
  State<_KelasForm> createState() => _KelasFormState();
}

class _KelasFormState extends State<_KelasForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _wali;
  late int _level;
  int? _majorId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ClassModel? c = widget.existing?.kelas;
    _name = TextEditingController(text: c?.name ?? '');
    _wali = TextEditingController(text: c?.homeroomTeacher ?? '');
    _level = c?.level ?? 10;
    _majorId = c?.majorId;
  }

  @override
  void dispose() {
    _name.dispose();
    _wali.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ClassesProvider provider = context.read<ClassesProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;
    final String nama = _name.text.trim();
    try {
      // Kolom nama kelas punya batasan UNIQUE: cek dulu agar pengguna
      // mendapat pesan jelas, bukan error database yang membingungkan.
      if (await ClassRepository().classNameExists(nama, excludeId: widget.existing?.kelas.id)) {
        if (!mounted) return;
        setState(() => _saving = false);
        _pesan('Nama kelas "$nama" sudah dipakai. Gunakan nama lain.');
        return;
      }

      final int id = await provider.saveClass(
        id: widget.existing?.kelas.id,
        name: _name.text,
        level: _level,
        majorId: _majorId,
        homeroomTeacher: _wali.text.trim().isEmpty ? null : _wali.text.trim(),
        academicYear: widget.existing?.kelas.academicYear ?? '2026/2027',
        userId: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kelas "$nama" tersimpan.')));
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _tampilPesanGagal('Gagal menyimpan kelas', e);
    }
  }

  void _pesan(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: error ? AppColors.danger : null, content: Text(text, maxLines: 3)),
    );
  }

  void _tampilPesanGagal(String judul, Object e) {
    _pesan(e is AppException ? e.message : pesanErrorUmum(e, judul), error: true);
  }

  /// Buat jurusan baru langsung dari form kelas, lalu pilih otomatis.
  Future<void> _buatJurusan() async {
    final int? id = await _JurusanTab.openForm(context);
    if (!mounted || id == null) return;
    setState(() => _majorId = id);
  }

  @override
  Widget build(BuildContext context) {
    // Watch supaya dropdown Jurusan ikut berubah begitu jurusan baru dibuat.
    final List<MajorWithMeta> majors = context
        .watch<ClassesProvider>()
        .majors
        .where((MajorWithMeta m) => m.major.isActive)
        .toList();
    // Jurusan terpilih tetap tampil walau sedang nonaktif.
    final List<MajorWithMeta> opsiJurusan = <MajorWithMeta>[];
    for (final MajorWithMeta m in majors) {
      opsiJurusan.add(m);
    }
    if (_majorId != null && !opsiJurusan.any((MajorWithMeta m) => m.major.id == _majorId)) {
      opsiJurusan.add(MajorWithMeta(major: context.read<ClassesProvider>().majorById(_majorId)!));
    }
    final String sidikJariJurusan = opsiJurusan.map((MajorWithMeta m) => m.major.id).join('-');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(widget.existing == null ? 'Tambah Kelas' : 'Ubah Kelas', style: AppText.title),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Kelas *',
                  hintText: 'Contoh: XII TKJ 1',
                ),
                validator: (String? v) {
                  final String value = v?.trim() ?? '';
                  if (value.isEmpty) {
                    return 'Nama kelas wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: ValueKey<String>('tingkat-$_level'),
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Tingkat *'),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(value: 10, child: Text('10')),
                  DropdownMenuItem<int>(value: 11, child: Text('11')),
                  DropdownMenuItem<int>(value: 12, child: Text('12')),
                ],
                onChanged: (int? v) => setState(() => _level = v ?? 10),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: ValueKey<String>('jurusan-$_majorId-$sidikJariJurusan'),
                initialValue: _majorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jurusan', hintText: 'Opsional'),
                items: opsiJurusan
                    .map(
                      (MajorWithMeta m) => DropdownMenuItem<int>(
                        value: m.major.id,
                        child: Text(m.major.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (int? v) => setState(() => _majorId = v),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _buatJurusan,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    majors.isEmpty ? 'Belum ada jurusan? Buat sekarang' : 'Tambah jurusan lain',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _wali,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Wali Kelas', hintText: 'Opsional'),
              ),
              const SizedBox(height: 20),
              _saving
                  ? const SizedBox(height: 52, child: Center(child: CircularProgressIndicator()))
                  : FilledButton(onPressed: _save, child: const Text('Simpan')),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB JURUSAN
// ============================================================

class _JurusanTab extends StatelessWidget {
  const _JurusanTab();

  /// Buka form tambah/ubah jurusan. Mengembalikan id jurusan tersimpan.
  static Future<int?> openForm(BuildContext context, {MajorWithMeta? existing}) async {
    final ClassesProvider provider = context.read<ClassesProvider>();
    final int? savedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => _MajorForm(provider: provider, existing: existing),
    );
    if (savedId != null) provider.load();
    return savedId;
  }

  Future<void> _delete(BuildContext context, MajorWithMeta item) async {
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Jurusan',
      message: item.classCount > 0
          ? 'Jurusan ${item.major.name} masih dipakai ${item.classCount} kelas.\n'
                'Jurusan akan diubah menjadi NONAKTIF.'
          : 'Hapus jurusan ${item.major.name}?\nData tidak bisa dikembalikan.',
      confirmLabel: 'Ya',
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final ClassesProvider provider = context.read<ClassesProvider>();
    await jalankanAksi(context, () async {
      final DeleteResult result = await provider.deleteMajor(
        item.major.id!,
        userId: context.read<SessionProvider>().user?.id,
      );
      if (context.mounted) {
        showDeleteResult(context, result, 'Jurusan ${item.major.name}');
      }
    }, konteks: 'Hapus jurusan');
  }

  @override
  Widget build(BuildContext context) {
    final ClassesProvider classes = context.watch<ClassesProvider>();
    if (classes.isLoading && classes.majors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (classes.majors.isEmpty) {
      return EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'Belum ada jurusan',
        message:
            'Jurusan bersifat opsional, tetapi berguna untuk mengelompokkan '
            'kelas dan membuat laporan.',
        action: FilledButton.icon(
          onPressed: () => openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Buat Jurusan'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: classes.majors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final MajorWithMeta m = classes.majors[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (m.major.isActive ? AppColors.teal : AppColors.textMuted).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  m.major.code.isEmpty ? '?' : m.major.code[0],
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: m.major.isActive ? AppColors.teal : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            m.major.name,
                            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!m.major.isActive) ...<Widget>[
                          const SizedBox(width: 6),
                          _MiniTag('Nonaktif', AppColors.danger),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('Kode ${m.major.code} · ${m.classCount} kelas', style: AppText.caption),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
                onPressed: () => openForm(context, existing: m),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: () => _delete(context, m),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Form jurusan (bottom sheet).
class _MajorForm extends StatefulWidget {
  final ClassesProvider provider;
  final MajorWithMeta? existing;

  const _MajorForm({required this.provider, this.existing});

  @override
  State<_MajorForm> createState() => _MajorFormState();
}

class _MajorFormState extends State<_MajorForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final MajorModel? m = widget.existing?.major;
    _name = TextEditingController(text: m?.name ?? '');
    _code = TextEditingController(text: m?.code ?? '');
    _desc = TextEditingController(text: m?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final int? userId = context.read<SessionProvider>().user?.id;
    final String nama = _name.text.trim();
    final String kode = _code.text.trim().toUpperCase();
    final ClassRepository repo = ClassRepository();
    try {
      // Nama jurusan UNIQUE, kode dipakai untuk pengelompokan laporan.
      final List<Map<String, Object?>> dup = await DBHelper.instance.rawQuery(
        'SELECT id FROM majors WHERE (name = ? OR code = ?) AND id != ?',
        <Object?>[nama, kode, widget.existing?.major.id ?? -1],
      );
      if (dup.isNotEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        _pesan('Jurusan dengan nama atau kode "$kode" sudah dipakai.');
        return;
      }
      if (await repo.majorCodeExists(kode, excludeId: widget.existing?.major.id)) {
        if (!mounted) return;
        setState(() => _saving = false);
        _pesan('Kode jurusan "$kode" sudah dipakai.');
        return;
      }

      final int id = await widget.provider.saveMajor(
        id: widget.existing?.major.id,
        name: nama,
        code: kode,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        userId: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Jurusan "$nama" tersimpan.')));
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _tampilPesanGagal('Gagal menyimpan jurusan', e);
    }
  }

  void _pesan(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: error ? AppColors.danger : null, content: Text(text, maxLines: 3)),
    );
  }

  void _tampilPesanGagal(String judul, Object e) {
    _pesan(e is AppException ? e.message : pesanErrorUmum(e, judul), error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.existing == null ? 'Tambah Jurusan' : 'Ubah Jurusan',
                style: AppText.title,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Jurusan *',
                  hintText: 'Contoh: Teknik Komputer dan Jaringan',
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nama jurusan wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode Jurusan *',
                  hintText: 'Contoh: TKJ',
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Kode jurusan wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Deskripsi', hintText: 'Opsional'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _saving
                  ? const SizedBox(height: 52, child: Center(child: CircularProgressIndicator()))
                  : FilledButton(onPressed: _save, child: const Text('Simpan')),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniTag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppText.caption.copyWith(color: color, fontSize: 9.5)),
    );
  }
}
