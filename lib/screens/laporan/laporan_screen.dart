import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/laporan_model.dart';
import '../../models/payment_model.dart';
import '../../models/school_profile_model.dart';
import '../../providers/cash_types_provider.dart';
import '../../providers/classes_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/laporan_repository.dart';
import '../../repositories/school_profile_repo.dart';
import '../../services/export_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_badge.dart';

enum _JenisLaporan { pemasukan, pengeluaran, saldo, siswa }

/// Halaman Laporan Keuangan: pemilihan jenis laporan, periode, filter,
/// dan ekspor PDF / CSV / berbagi file.
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  final LaporanRepository _repo = LaporanRepository();

  _JenisLaporan _jenis = _JenisLaporan.pemasukan;
  PeriodeJenis _periode = PeriodeJenis.bulanIni;
  KelompokLaporan _kelompok = KelompokLaporan.perBulan;
  LaporanFilter _filter = const LaporanFilter();

  DateTime? _customStart;
  DateTime? _customEnd;

  List<LaporanBaris> _baris = <LaporanBaris>[];
  LaporanSaldo? _saldo;
  List<LaporanPembayaranSiswa> _siswa = <LaporanPembayaranSiswa>[];

  bool _loading = false;
  bool _processing = false;
  String? _lastFile;
  String? _error;
  SchoolProfileModel? _profil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
      _loadProfil();
      _compute();
    });
  }

  Future<void> _loadProfil() async {
    final SchoolProfileModel? profil = await SchoolProfileRepository().getProfile();
    if (mounted && profil != null) setState(() => _profil = profil);
  }

  void _loadOptions() {
    context.read<ClassesProvider>().load();
    context.read<CashTypesProvider>().load();
    context.read<TransactionProvider>().loadCategories();
  }

  PeriodeLaporan _periodeSekarang() =>
      PeriodeLaporan.dari(_periode, a: _customStart, b: _customEnd);

  Future<void> _compute() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final PeriodeLaporan p = _periodeSekarang();
      if (_jenis == _JenisLaporan.saldo) {
        final LaporanSaldo s = await _repo.saldo(periode: p);
        if (mounted) {
          setState(() {
            _saldo = s;
            _baris = const <LaporanBaris>[];
            _siswa = const <LaporanPembayaranSiswa>[];
          });
        }
      } else if (_jenis == _JenisLaporan.siswa) {
        final List<LaporanPembayaranSiswa> r = await _repo.pembayaranSiswa(
          periode: p,
          classId: _filter.classId,
          majorId: _filter.majorId,
          statusFilter: _filter.statusSiswa,
        );
        if (mounted) {
          setState(() {
            _siswa = r;
            _baris = const <LaporanBaris>[];
            _saldo = null;
          });
        }
      } else {
        final bool income = _jenis == _JenisLaporan.pemasukan;
        final List<LaporanBaris> r = income
            ? await _repo.pemasukan(
                periode: p,
                kelompok: _kelompok,
                classId: _filter.classId,
                majorId: _filter.majorId,
                cashTypeId: _filter.cashTypeId,
              )
            : await _repo.pengeluaran(
                periode: p,
                kelompok: _kelompok,
                categoryId: _filter.categoryId,
              );
        if (mounted) {
          setState(() {
            _baris = r;
            _saldo = null;
            _siswa = const <LaporanPembayaranSiswa>[];
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat laporan: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------
  // EKSPOR & BAGIKAN
  // ------------------------------------------------------------

  String get _judul {
    switch (_jenis) {
      case _JenisLaporan.pemasukan:
        return 'Laporan Pemasukan';
      case _JenisLaporan.pengeluaran:
        return 'Laporan Pengeluaran';
      case _JenisLaporan.saldo:
        return 'Laporan Saldo';
      case _JenisLaporan.siswa:
        return 'Laporan Pembayaran Siswa';
    }
  }

  List<String> get _ringkasan {
    switch (_jenis) {
      case _JenisLaporan.saldo:
        final LaporanSaldo? s = _saldo;
        if (s == null) return const <String>[];
        return <String>[
          'Saldo Awal: Rp ${Formatters.angka(s.saldoAwal)}',
          'Pemasukan: Rp ${Formatters.angka(s.pemasukan)}',
          'Pengeluaran: Rp ${Formatters.angka(s.pengeluaran)}',
          'Saldo Akhir: Rp ${Formatters.angka(s.saldoAkhir)}',
        ];
      case _JenisLaporan.siswa:
        int tagihan = 0, bayar = 0, tunggakan = 0;
        for (final LaporanPembayaranSiswa s in _siswa) {
          tagihan += s.tagihan;
          bayar += s.bayar;
          tunggakan += s.tunggakan;
        }
        return <String>[
          'Tagihan: Rp ${Formatters.angka(tagihan)}',
          'Terkumpul: Rp ${Formatters.angka(bayar)}',
          'Tunggakan: Rp ${Formatters.angka(tunggakan)}',
          'Siswa: ${_siswa.length}',
        ];
      default:
        return const <String>[];
    }
  }

  List<String> get _kolom {
    switch (_jenis) {
      case _JenisLaporan.saldo:
        return const <String>['Komponen', 'Nominal'];
      case _JenisLaporan.siswa:
        return const <String>[
          'NIS',
          'Nama',
          'Kelas',
          'Jurusan',
          'Tagihan',
          'Bayar',
          'Tunggakan',
          'Status',
        ];
      default:
        return const <String>['Kelompok', 'Jumlah', 'Nominal'];
    }
  }

  List<List<String>> get _dataBaris {
    switch (_jenis) {
      case _JenisLaporan.saldo:
        final LaporanSaldo? s = _saldo;
        if (s == null) return const <List<String>>[];
        return <List<String>>[
          <String>['Saldo Awal', 'Rp ${Formatters.angka(s.saldoAwal)}'],
          <String>['Pemasukan', 'Rp ${Formatters.angka(s.pemasukan)}'],
          <String>['Pengeluaran', 'Rp ${Formatters.angka(s.pengeluaran)}'],
          <String>['Saldo Akhir', 'Rp ${Formatters.angka(s.saldoAkhir)}'],
        ];
      case _JenisLaporan.siswa:
        return _siswa
            .map(
              (LaporanPembayaranSiswa s) => <String>[
                s.nis,
                s.name,
                s.className ?? '-',
                s.majorName ?? '-',
                '${s.tagihan}',
                '${s.bayar}',
                '${s.tunggakan}',
                PaymentStatus.label(s.status),
              ],
            )
            .toList();
      default:
        return _baris
            .map((LaporanBaris b) => <String>[b.label, '${b.jumlah}', '${b.nominal}'])
            .toList();
    }
  }

  Future<void> _exportPdf() async {
    final SchoolProfileModel? profil = await SchoolProfileRepository().getProfile();
    await _export(
      ext: 'pdf',
      builder: () => ExportService.reportPdf(
        judul: _judul,
        periodeLabel: _periodeSekarang().label,
        bendahara: _bendahara(profil),
        kolom: _kolom,
        baris: _dataBaris,
        ringkasan: _ringkasan,
        sekolah: _sekolah(profil),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final SchoolProfileModel? profil = await SchoolProfileRepository().getProfile();
    await _export(
      ext: 'csv',
      builder: () => Future<String>.value(
        ExportService.reportCsv(
          judul: _judul,
          periodeLabel: _periodeSekarang().label,
          bendahara: _bendahara(profil),
          kolom: _kolom,
          baris: _dataBaris,
          ringkasan: _ringkasan,
          sekolah: _sekolah(profil),
        ),
      ),
    );
  }

  Future<void> _export({required String ext, required Future<dynamic> Function() builder}) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final dynamic content = await builder();
      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory folder = Directory('${dir.path}/laporan');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final String name = 'laporan_${_slug(_judul)}_${_timeStamp()}.$ext';
      final File file = File('${folder.path}/$name');
      if (content is List<int>) {
        await file.writeAsBytes(content, flush: true);
      } else {
        await file.writeAsString(content as String, flush: true);
      }
      setState(() => _lastFile = file.path);
      if (mounted) {
        _snack('Tersimpan:\n${file.path}');
      }
      await _shareFile(file);
    } catch (e) {
      if (mounted) _snack('Gagal ekspor: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _shareLast() async {
    final String? path = _lastFile;
    if (path == null) {
      _snack('Belum ada file hasil ekspor. Tekan Export PDF/CSV.');
      return;
    }
    final File file = File(path);
    if (!await file.exists()) {
      _snack('File lama tidak ditemukan. Export ulang.');
      return;
    }
    await _shareFile(file);
  }

  Future<void> _shareFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(file.path, mimeType: file.path.endsWith('.pdf') ? 'application/pdf' : 'text/csv'),
        ],
        text: '$_judul - ${_sekolah()}',
        downloadFallbackEnabled: true,
      ),
    );
  }

  /// Nama bendahara: dari profil sekolah, fallback ke user yang login.
  String _bendahara([SchoolProfileModel? profil]) {
    final String? t = profil?.treasurer;
    if (t != null && t.isNotEmpty) return t;
    return context.read<SessionProvider>().user?.fullName ?? '-';
  }

  /// Nama sekolah untuk kop laporan: dari profil, fallback ke konstanta.
  String _sekolah([SchoolProfileModel? profil]) {
    final SchoolProfileModel? src = profil ?? _profil;
    final String n = src?.schoolName ?? '';
    return n.isNotEmpty ? n : ExportService.kopSekolah;
  }

  String _slug(String text) => text.toLowerCase().replaceAll(' ', '_');

  String _timeStamp() {
    final DateTime now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: <Widget>[
            // JENIS LAPORAN
            _JenisSection(
              jenis: _jenis,
              onChanged: (_JenisLaporan j) {
                setState(() {
                  _jenis = j;
                  _kelompok = KelompokLaporan.perBulan;
                  _filter = const LaporanFilter();
                });
                _compute();
              },
            ),
            const SizedBox(height: 16),

            // PERIODE
            Text('Periode', style: AppText.sectionTitle),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final PeriodeJenis p in PeriodeJenis.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PickChip(
                        label: _periodeLabel(p),
                        selected: _periode == p,
                        onTap: () {
                          setState(() => _periode = p);
                          _compute();
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_periode == PeriodeJenis.custom) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DatePickTile(
                      label: 'Dari',
                      date: _customStart,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DatePickTile(
                      label: 'Sampai',
                      date: _customEnd,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // FILTER KHUSUS JENIS
            if (_jenis != _JenisLaporan.saldo) ...<Widget>[
              _FilterSection(
                jenis: _jenis,
                kelompok: _kelompok,
                filter: _filter,
                onKelompok: (KelompokLaporan k) {
                  setState(() => _kelompok = k);
                  _compute();
                },
                onFilter: (LaporanFilter f) {
                  setState(() => _filter = f);
                  _compute();
                },
              ),
              const SizedBox(height: 16),
            ],

            // KONTEN
            _buildContent(),
          ],
        ),
      ),
      bottomNavigationBar: _buildExportBar(),
    );
  }

  Widget _buildExportBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Export PDF'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _exportCsv,
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: const Text('Export CSV'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _processing ? null : _shareLast,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Bagikan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, title: 'Terjadi kesalahan', message: _error);
    }
    switch (_jenis) {
      case _JenisLaporan.pemasukan:
      case _JenisLaporan.pengeluaran:
        return _GroupedContent(_jenis, _baris);
      case _JenisLaporan.saldo:
        return _SaldoContent(_saldo);
      case _JenisLaporan.siswa:
        return _SiswaContent(_siswa);
    }
  }

  String _periodeLabel(PeriodeJenis p) {
    switch (p) {
      case PeriodeJenis.hariIni:
        return 'Hari ini';
      case PeriodeJenis.mingguIni:
        return 'Minggu ini';
      case PeriodeJenis.bulanIni:
        return 'Bulan ini';
      case PeriodeJenis.bulanLalu:
        return 'Bulan lalu';
      case PeriodeJenis.semester:
        return 'Semester';
      case PeriodeJenis.tahun:
        return 'Tahun';
      case PeriodeJenis.custom:
        return 'Custom';
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final DateTime initial = isStart
        ? (_customStart ?? DateTime.now())
        : (_customEnd ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: AppDateRange.clamp(initial),
      firstDate: AppDateRange.minDate,
      lastDate: AppDateRange.maxDate,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
      } else {
        _customEnd = picked;
      }
    });
    _compute();
  }
}

// ------------------------------------------------------------
// SEKSI JENIS LAPORAN
// ------------------------------------------------------------

class _JenisSection extends StatelessWidget {
  final _JenisLaporan jenis;
  final ValueChanged<_JenisLaporan> onChanged;

  const _JenisSection({required this.jenis, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Jenis Laporan', style: AppText.sectionTitle),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = (constraints.maxWidth - 24) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _JenisCard(
                    width: w,
                    icon: Icons.south_west_rounded,
                    label: 'Pemasukan',
                    selected: jenis == _JenisLaporan.pemasukan,
                    onTap: () => onChanged(_JenisLaporan.pemasukan),
                  ),
                  _JenisCard(
                    width: w,
                    icon: Icons.north_east_rounded,
                    label: 'Pengeluaran',
                    selected: jenis == _JenisLaporan.pengeluaran,
                    onTap: () => onChanged(_JenisLaporan.pengeluaran),
                  ),
                  _JenisCard(
                    width: w,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo',
                    selected: jenis == _JenisLaporan.saldo,
                    onTap: () => onChanged(_JenisLaporan.saldo),
                  ),
                  _JenisCard(
                    width: w,
                    icon: Icons.groups_rounded,
                    label: 'Pembayaran Siswa',
                    selected: jenis == _JenisLaporan.siswa,
                    onTap: () => onChanged(_JenisLaporan.siswa),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JenisCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _JenisCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy.withValues(alpha: 0.07) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: selected ? AppColors.navy : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppText.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.navy : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.navy : AppColors.divider),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DatePickTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.event_outlined)),
        child: Text(date == null ? 'Pilih' : Formatters.tanggal(date!), style: AppText.body),
      ),
    );
  }
}

// ------------------------------------------------------------
// FILTER KHUSUS JENIS LAPORAN
// ------------------------------------------------------------

class _FilterSection extends StatelessWidget {
  final _JenisLaporan jenis;
  final KelompokLaporan kelompok;
  final LaporanFilter filter;
  final ValueChanged<KelompokLaporan> onKelompok;
  final ValueChanged<LaporanFilter> onFilter;

  const _FilterSection({
    required this.jenis,
    required this.kelompok,
    required this.filter,
    required this.onKelompok,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final ClassesProvider classes = context.watch<ClassesProvider>();
    final CashTypesProvider cashTypes = context.watch<CashTypesProvider>();
    final TransactionProvider tx = context.watch<TransactionProvider>();

    final List<(String, int)> classItems = classes.classes
        .where((c) => c.kelas.isActive)
        .map((c) => (c.kelas.name, c.kelas.id!))
        .toList();
    final List<(String, int)> majorItems = classes.majors
        .where((m) => m.major.isActive)
        .map((m) => (m.major.name, m.major.id!))
        .toList();
    final List<(String, int)> cashTypeItems = cashTypes.cashTypes
        .where((c) => c.isActive)
        .map((c) => (c.name, c.id!))
        .toList();
    final List<(String, int)> categoryItems = tx.categories
        .where((c) => c.isActive)
        .map((c) => (c.name, c.id!))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Filter', style: AppText.sectionTitle),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              if (jenis == _JenisLaporan.pemasukan ||
                  jenis == _JenisLaporan.pengeluaran) ...<Widget>[
                FilterDropdown<KelompokLaporan>(
                  label: 'Kelompok',
                  value: kelompok,
                  items: _kelompokItems,
                  onChanged: (KelompokLaporan? v) {
                    if (v != null) onKelompok(v);
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (jenis != _JenisLaporan.pengeluaran && jenis != _JenisLaporan.siswa) ...<Widget>[
                FilterDropdown<int>(
                  label: 'Kelas',
                  value: filter.classId,
                  items: classItems,
                  onChanged: (int? v) {
                    onFilter(filter.copyWith(classId: () => v == null || v == 0 ? null : v));
                  },
                ),
                const SizedBox(width: 8),
                FilterDropdown<int>(
                  label: 'Jurusan',
                  value: filter.majorId,
                  items: majorItems,
                  onChanged: (int? v) {
                    onFilter(filter.copyWith(majorId: () => v == null || v == 0 ? null : v));
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (jenis == _JenisLaporan.pemasukan) ...<Widget>[
                FilterDropdown<int>(
                  label: 'Jenis Kas',
                  value: filter.cashTypeId,
                  items: cashTypeItems,
                  onChanged: (int? v) {
                    onFilter(filter.copyWith(cashTypeId: () => v == null || v == 0 ? null : v));
                  },
                ),
              ],
              if (jenis == _JenisLaporan.pengeluaran) ...<Widget>[
                FilterDropdown<int>(
                  label: 'Kategori',
                  value: filter.categoryId,
                  items: categoryItems,
                  onChanged: (int? v) {
                    onFilter(filter.copyWith(categoryId: () => v == null || v == 0 ? null : v));
                  },
                ),
              ],
              if (jenis == _JenisLaporan.siswa) ...<Widget>[
                for (final (String label, String value) in _statusItems)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PickChip(
                      label: label,
                      selected: filter.statusSiswa == value,
                      onTap: () {
                        onFilter(
                          filter.copyWith(
                            statusSiswa: () => filter.statusSiswa == value ? null : value,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static final List<(String, KelompokLaporan)> _kelompokItems = _build();

  static List<(String, KelompokLaporan)> _build() {
    return <(String, KelompokLaporan)>[
      ('Per Tanggal', KelompokLaporan.perTanggal),
      ('Per Bulan', KelompokLaporan.perBulan),
      ('Per Kelas', KelompokLaporan.perKelas),
      ('Per Jurusan', KelompokLaporan.perJurusan),
      ('Per Jenis Kas', KelompokLaporan.perJenisKas),
      ('Per Kategori', KelompokLaporan.perKategori),
    ];
  }

  static const List<(String, String)> _statusItems = <(String, String)>[
    ('Lunas', 'lunas'),
    ('Sebagian', 'sebagian'),
    ('Belum Bayar', 'belum'),
  ];
}

// ------------------------------------------------------------
// KONTEN: GRUP / SALDO / SISWA
// ------------------------------------------------------------

class _GroupedContent extends StatelessWidget {
  final _JenisLaporan jenis;
  final List<LaporanBaris> baris;

  const _GroupedContent(this.jenis, this.baris);

  @override
  Widget build(BuildContext context) {
    if (baris.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Tidak ada data',
        message: 'Belum ada transaksi pada periode & filter ini.',
      );
    }
    final int totalJumlah = baris.fold<int>(0, (sum, b) => sum + b.jumlah);
    final int totalNominal = baris.fold<int>(0, (sum, b) => sum + b.nominal);
    final bool income = jenis == _JenisLaporan.pemasukan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Total Nominal', style: AppText.caption),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.rupiah(totalNominal),
                      style: AppText.amountMedium.copyWith(
                        color: income ? AppColors.teal : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.divider),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Jumlah Transaksi', style: AppText.caption),
                    const SizedBox(height: 4),
                    Text(
                      '$totalJumlah',
                      style: AppText.amountMedium.copyWith(color: AppColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...baris.map(
          (LaporanBaris b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (income ? AppColors.teal : AppColors.danger).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      income ? Icons.south_west_rounded : Icons.north_east_rounded,
                      size: 20,
                      color: income ? AppColors.teal : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(b.label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        Formatters.rupiah(b.nominal),
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: income ? AppColors.teal : AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('${b.jumlah} transaksi', style: AppText.caption),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaldoContent extends StatelessWidget {
  final LaporanSaldo? saldo;

  const _SaldoContent(this.saldo);

  @override
  Widget build(BuildContext context) {
    final LaporanSaldo? s = saldo;
    if (s == null) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Tidak ada data',
        message: 'Tidak dapat menghitung saldo pada periode ini.',
      );
    }
    return Column(
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(18),
          color: AppColors.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'SALDO AKHIR',
                style: AppText.caption.copyWith(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(Formatters.rupiah(s.saldoAkhir), style: AppText.amountLarge),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SaldoRow(
          label: 'Saldo Awal',
          value: Formatters.rupiah(s.saldoAwal),
          color: AppColors.navy,
        ),
        _SaldoRow(label: 'Pemasukan', value: Formatters.rupiah(s.pemasukan), color: AppColors.teal),
        _SaldoRow(
          label: 'Pengeluaran',
          value: Formatters.rupiah(s.pengeluaran),
          color: AppColors.danger,
        ),
      ],
    );
  }
}

class _SaldoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SaldoRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: <Widget>[
            Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              value,
              style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiswaContent extends StatelessWidget {
  final List<LaporanPembayaranSiswa> siswa;

  const _SiswaContent(this.siswa);

  @override
  Widget build(BuildContext context) {
    if (siswa.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Tidak ada siswa',
        message: 'Belum ada siswa yang cocok dengan filter ini.',
      );
    }
    int tagihan = 0, bayar = 0, tunggakan = 0;
    for (final LaporanPembayaranSiswa s in siswa) {
      tagihan += s.tagihan;
      bayar += s.bayar;
      tunggakan += s.tunggakan;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            children: <Widget>[
              _MiniStat(label: 'Tagihan', value: Formatters.rupiah(tagihan)),
              _MiniStat(label: 'Terkumpul', value: Formatters.rupiah(bayar)),
              _MiniStat(
                label: 'Tunggakan',
                value: Formatters.rupiah(tunggakan),
                color: tunggakan > 0 ? AppColors.danger : AppColors.teal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            columnSpacing: 18,
            horizontalMargin: 12,
            headingRowColor: WidgetStateProperty.all<Color>(AppColors.navy.withValues(alpha: 0.07)),
            columns: const <DataColumn>[
              DataColumn(label: Text('NIS', style: AppText.label)),
              DataColumn(label: Text('Nama', style: AppText.label)),
              DataColumn(label: Text('Kelas', style: AppText.label)),
              DataColumn(label: Text('Tagihan', style: AppText.label)),
              DataColumn(label: Text('Bayar', style: AppText.label)),
              DataColumn(label: Text('Tunggakan', style: AppText.label)),
              DataColumn(label: Text('Status', style: AppText.label)),
            ],
            rows: siswa
                .map(
                  (LaporanPembayaranSiswa s) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(s.nis, style: AppText.bodySmall)),
                      DataCell(
                        Text(
                          s.name,
                          style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(s.className ?? '-', style: AppText.bodySmall)),
                      DataCell(Text(Formatters.rupiah(s.tagihan), style: AppText.bodySmall)),
                      DataCell(Text(Formatters.rupiah(s.bayar), style: AppText.bodySmall)),
                      DataCell(
                        Text(
                          Formatters.rupiah(s.tunggakan),
                          style: AppText.bodySmall.copyWith(
                            color: s.tunggakan > 0 ? AppColors.danger : AppColors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(StatusBadge.pembayaran(s.status)),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppText.label),
          Text(
            value,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
