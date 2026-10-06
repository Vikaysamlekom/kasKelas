import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/student_model.dart';
import '../../providers/classes_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/students_provider.dart';
import '../../repositories/kelas_repo.dart';
import '../../repositories/siswa_repo.dart';
import 'kelas_screen.dart';

/// Form tambah / edit siswa.
class StudentFormScreen extends StatefulWidget {
  final StudentModel? student;

  const StudentFormScreen({super.key, this.student});

  bool get isEdit => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nisController;
  late final TextEditingController _nisnController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentController;
  late final TextEditingController _addressController;

  String _gender = 'L';
  String _status = 'aktif';
  int? _classId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final StudentModel? s = widget.student;
    _nisController = TextEditingController(text: s?.nis ?? '');
    _nisnController = TextEditingController(text: s?.nisn ?? '');
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _parentController = TextEditingController(text: s?.parentName ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _gender = s?.gender ?? 'L';
    _status = s?.status ?? 'aktif';
    _classId = s?.classId;

    // Pastikan daftar kelas selalu tersedia,apa pun entry point form ini.
    WidgetsBinding.instance.addPostFrameCallback((_) => _muatKelas());
  }

  /// Muat daftar kelas bila belum pernah dimuat (mis. form dibuka langsung
  /// dari halaman detail siswa, bukan dari daftar siswa).
  Future<void> _muatKelas() async {
    if (!mounted) return;
    final ClassesProvider provider = context.read<ClassesProvider>();
    if (provider.hasLoaded || provider.isLoading) return;
    try {
      await provider.load();
    } catch (_) {
      // Kesalahan sudah ditangkap di provider; form tetap bisa dibuka.
    }
  }

  @override
  void dispose() {
    _nisController.dispose();
    _nisnController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _parentController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kelas wajib dipilih.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final ClassesProvider classes = context.read<ClassesProvider>();
    int? majorId;
    for (final ClassWithMeta c in classes.classes) {
      if (c.kelas.id == _classId) {
        majorId = c.kelas.majorId;
        break;
      }
    }

    final Map<String, Object?> data = <String, Object?>{
      'nis': _nisController.text.trim(),
      'nisn': _nisnController.text.trim().isEmpty
          ? null
          : _nisnController.text.trim(),
      'name': _nameController.text.trim(),
      'gender': _gender,
      'class_id': _classId,
      'major_id': majorId,
      'parent_name': _parentController.text.trim().isEmpty
          ? null
          : _parentController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'status': _status,
    };

    final StudentsProvider students = context.read<StudentsProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;

    try {
      if (widget.isEdit) {
        await students.updateStudent(widget.student!.id!, data, userId: userId);
      } else {
        await students.addStudent(data, userId: userId);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DuplicateNisException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  /// Buka layar Kelas & Jurusan, lalu pilih otomatis kelas yang baru dibuat
  /// (atau satu-satunya kelas aktif) agar pengguna tidak perlu memilih ulang.
  Future<void> _kelolaKelas() async {
    final ClassesProvider provider = context.read<ClassesProvider>();
    final int sebelum = provider.classes.length;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const KelasScreen()),
    );
    if (!mounted) return;
    await _muatKelas();
    if (!mounted) return;

    final List<ClassWithMeta> aktif = provider.classes
        .where((ClassWithMeta c) => c.kelas.isActive)
        .toList();
    if (aktif.isEmpty) return;

    // Bila sebelumnya tidak ada kelas dan kini ada tepat satu, langsung pilih.
    if (_classId == null && sebelum == 0 && aktif.length == 1) {
      setState(() => _classId = aktif.first.kelas.id);
      return;
    }
    if (_classId == null && aktif.length == 1) {
      setState(() => _classId = aktif.first.kelas.id);
    }
  }

  /// Daftar pilihan kelas: seluruh kelas aktif, plus kelas milik siswa saat
  /// ini bila kelas tersebut sedang nonaktif (agar nilai lama tidak "hilang").
  List<DropdownMenuItem<int>> _classItems(ClassesProvider provider) {
    final List<ClassWithMeta> tampil = <ClassWithMeta>[];
    for (final ClassWithMeta c in provider.classes) {
      if (c.kelas.isActive || c.kelas.id == _classId) tampil.add(c);
    }
    return tampil
        .map(
          (ClassWithMeta c) => DropdownMenuItem<int>(
            value: c.kelas.id,
            child: Text(
              c.kelas.isActive ? c.kelas.name : '${c.kelas.name} (nonaktif)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  Widget _buildClassField(ClassesProvider provider) {
    final List<DropdownMenuItem<int>> items = _classItems(provider);

    // Belum ada kelas sama sekali → tampilkan empty state + aksi membuat kelas.
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.meeting_room_outlined,
              color: AppColors.danger,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada kelas',
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Setiap siswa wajib punya kelas. Buat kelas terlebih dahulu '
              'lalu pilih di sini.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: provider.isLoading ? null : _kelolaKelas,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                provider.isLoading ? 'Memuat data...' : 'Buat Kelas Sekarang',
              ),
            ),
          ],
        ),
      );
    }

    // Key memuat nilai terpilih + susunan item, sehingga field selalu
    // sinkron saat daftar kelas termuat belakangan atau berubah.
    final String sidikJari =
        items.map((DropdownMenuItem<int> i) => i.value).join('-');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<int>(
          key: ValueKey<String>('kelas-$_classId-$sidikJari'),
          initialValue: _classId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Kelas *',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          items: items,
          validator: (int? v) => v == null ? 'Kelas wajib dipilih' : null,
          onChanged: (int? v) => setState(() => _classId = v),
        ),
        if (provider.classes.where((ClassWithMeta c) => c.kelas.isActive).isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Semua kelas sedang nonaktif. Kelas terpilih tetap bisa disimpan.',
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClassesProvider classes = context.watch<ClassesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Ubah Siswa' : 'Tambah Siswa'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // NIS & NISN
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _nisController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'NIS *',
                        hintText: 'Nomor induk siswa',
                        counterText: '',
                      ),
                      maxLength: 20,
                      validator: (String? v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'NIS wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nisnController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'NISN',
                        hintText: 'Opsional',
                        counterText: '',
                      ),
                      maxLength: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // NAMA
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // JENIS KELAMIN
              Text('Jenis Kelamin *', style: AppText.label),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'L',
                    label: Text('Laki-laki'),
                    icon: Icon(Icons.male_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'P',
                    label: Text('Perempuan'),
                    icon: Icon(Icons.female_rounded),
                  ),
                ],
                selected: <String>{_gender},
                onSelectionChanged: (Set<String> sel) {
                  setState(() => _gender = sel.first);
                },
              ),
              const SizedBox(height: 16),

              // KELAS
              _buildClassField(classes),
              const SizedBox(height: 16),

              // NO HP WALI
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No HP Wali',
                  hintText: 'Contoh: 0812xxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // NAMA WALI
              TextFormField(
                controller: _parentController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Orang Tua/Wali',
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // STATUS
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'aktif',
                    child: Text('Aktif'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'cuti',
                    child: Text('Cuti'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'lulus',
                    child: Text('Lulus'),
                  ),
                ],
                onChanged: (String? v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 28),

              // SUBMIT
              _isSaving
                  ? const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : FilledButton(
                      onPressed: _submit,
                      child: Text(widget.isEdit ? 'Simpan Perubahan' : 'Simpan'),
                    ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}