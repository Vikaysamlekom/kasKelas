import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/student_model.dart';
import '../../providers/classes_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/students_provider.dart';
import '../../services/csv_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_badge.dart';
import 'kelas_screen.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

/// Halaman data siswa: list + pencarian + filter kelas/jurusan/status,
/// plus import/export CSV.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentsProvider>().load();
      context.read<ClassesProvider>().load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Lazy loading: muat halaman berikutnya saat mendekati dasar list.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double remaining = _scrollController.position.maxScrollExtent - _scrollController.offset;
    if (remaining < 600) {
      context.read<StudentsProvider>().loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<StudentsProvider>().applyFilter(search: value);
      }
    });
  }

  Future<void> _openForm({StudentModel? student}) async {
    final bool? changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (_) => StudentFormScreen(student: student)));
    if (changed == true && mounted) {
      context.read<StudentsProvider>().load();
    }
  }

  Future<void> _openDetail(StudentModel student) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => StudentDetailScreen(studentId: student.id!)),
    );
    if (changed == true && mounted) {
      context.read<StudentsProvider>().load();
    }
  }

  Future<void> _importCsv() async {
    final StudentsProvider provider = context.read<StudentsProvider>();
    final String? userId = context.read<SessionProvider>().user?.id?.toString();
    final CsvImportResult result = await provider.importFromCsv(
      userId: userId == null ? null : int.tryParse(userId),
    );

    if (!mounted) return;
    if (result.successCount == 0 && result.errorCount == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Import dibatalkan.')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hasil Import CSV', style: AppText.title.copyWith(fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Berhasil: ${result.successCount} siswa\n'
                    'Gagal: ${result.errorCount} baris',
                    style: AppText.body,
                  ),
                  if (result.rows.any((CsvRowResult r) => r.error != null)) ...<Widget>[
                    const SizedBox(height: 12),
                    const Text('Rincian kegagalan:', style: AppText.sectionTitle),
                    const SizedBox(height: 6),
                    for (final CsvRowResult r in result.rows)
                      if (r.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Baris ${r.rowNumber}: ${r.error}',
                            style: AppText.bodySmall.copyWith(color: AppColors.danger),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
          ],
        );
      },
    );
  }

  Future<void> _exportCsv() async {
    try {
      final String path = await context.read<StudentsProvider>().exportToCsv();
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path)],
          text: 'Data Siswa Kas Bintang Nusantara',
          downloadFallbackEnabled: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export CSV: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentsProvider students = context.watch<StudentsProvider>();
    final ClassesProvider classes = context.watch<ClassesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siswa'),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (String value) {
              switch (value) {
                case 'import':
                  _importCsv();
                  break;
                case 'export':
                  _exportCsv();
                  break;
                case 'kelas':
                  Navigator.of(context)
                      .push<void>(MaterialPageRoute<void>(builder: (_) => const KelasScreen()));
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.file_download_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('Import Siswa (CSV)')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.file_upload_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('Export Siswa (CSV)')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'kelas',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.meeting_room_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('Kelola Kelas & Jurusan')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // PENCARIAN
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari nama, NIS, atau NISN...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // FILTER KELAS / JURUSAN / STATUS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  FilterDropdown<int>(
                    label: 'Kelas',
                    value: students.filter.classId,
                    items:
                        (classes.classes
                                .where((c) => c.kelas.isActive)
                                .map((c) => (c.kelas.name, c.kelas.id!)))
                            .toList(),
                    onChanged: (int? v) {
                      students.applyFilter(classId: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Jurusan',
                    value: students.filter.majorId,
                    items:
                        (classes.majors
                                .where((m) => m.major.isActive)
                                .map((m) => (m.major.name, m.major.id!)))
                            .toList(),
                    onChanged: (int? v) {
                      students.applyFilter(majorId: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<String>(
                    label: 'Status',
                    value: students.filter.status,
                    items: const <(String, String)>[
                      ('Aktif', 'aktif'),
                      ('Cuti', 'cuti'),
                      ('Lulus', 'lulus'),
                    ],
                    onChanged: (String? v) {
                      students.applyFilter(status: v ?? '');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // DAFTAR SISWA
            Expanded(
              child: _ListView(
                controller: _scrollController,
                isLoading: students.isLoading,
                isLoadingMore: students.isLoadingMore,
                total: students.total,
                students: students.students,
                onTap: _openDetail,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah Siswa'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Item kartu daftar siswa.
class _ListView extends StatelessWidget {
  final ScrollController controller;
  final bool isLoading;
  final bool isLoadingMore;
  final int total;
  final List<StudentModel> students;
  final void Function(StudentModel) onTap;

  const _ListView({
    required this.controller,
    required this.isLoading,
    required this.isLoadingMore,
    required this.total,
    required this.students,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (students.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Belum ada data siswa',
        message: 'Tekan "Tambah Siswa" atau import dari CSV untuk mulai.',
      );
    }
    // +1 baris untuk footer "memuat lebih banyak" / "total data".
    final int itemCount = students.length + 1;

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<StudentsProvider>().load(),
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: itemCount,
        separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          if (index == students.length) {
            return _footer();
          }
          final StudentModel s = students[index];
          return _StudentTile(student: s, onTap: () => onTap(s));
        },
      ),
    );
  }

  Widget _footer() {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text('Menampilkan ${students.length} dari $total siswa', style: AppText.caption),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;

  const _StudentTile({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String genderLabel = student.gender == 'P' ? 'Perempuan' : 'Laki-laki';
    final Color genderColor = student.gender == 'P' ? AppColors.blue : AppColors.teal;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: genderColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initial(student.name),
              style: TextStyle(color: genderColor, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  student.name,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'NIS ${student.nis} · ${student.className ?? '-'} · $genderLabel',
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (student.majorName != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    student.majorName!,
                    style: AppText.caption.copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge.siswa(student.status),
        ],
      ),
    );
  }

  String _initial(String name) {
    if (name.isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }
}
