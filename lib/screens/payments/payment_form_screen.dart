import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/cash_type_model.dart';
import '../../models/payment_model.dart';
import '../../models/student_model.dart';
import '../../providers/cash_types_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/session_provider.dart';
import '../../repositories/pembayaran_repo.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Form pencatatan pembayaran kas baru.
class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class StudentPickerSheet extends StatefulWidget {
  const StudentPickerSheet({super.key, required this.students});

  final List<StudentModel> students;

  @override
  State<StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<StudentPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<StudentModel> filteredStudents = widget.students
        .where(
          (StudentModel student) => student.name.toLowerCase().contains(query),
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: 420,
          child: Column(
            children: <Widget>[
              Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Pilih Siswa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama siswa',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredStudents.isEmpty
                    ? const Center(child: Text('Siswa tidak ditemukan.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filteredStudents.length,
                        itemBuilder: (BuildContext context, int index) {
                          final StudentModel student = filteredStudents[index];
                          return ListTile(
                            title: Text(student.name),
                            subtitle: Text(student.className ?? '-'),
                            onTap: () => Navigator.of(context).pop(student),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int? _studentId;
  int? _cashTypeId;
  CashTypeModel? _selectedCashType;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  late DateTime _paidDate;

  PeriodStatus? _statusInfo;
  bool _isLoadingStatus = false;
  String? _statusError;
  int _statusRequestId = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paidDate = DateTime.now();
    _listenStatus();
    _muatSiswa();
  }

  /// Muat siswa aktif untuk dropdown. `PaymentProvider` sengaja melakukan
  /// cache (`if (_students.isNotEmpty) return`) supaya tidak query ulang
  /// setiap kali form dibuka — jadi form harus memicu pemuatannya sendiri.
  Future<void> _muatSiswa() async {
    try {
      await context.read<PaymentProvider>().loadActiveStudents();
    } catch (e) {
      if (mounted) _snack('Gagal memuat siswa: $e');
    }
  }

  void _listenStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashTypesProvider>().load();
      _refreshStatus();
    });
  }

  Future<void> _refreshStatus() async {
    final int requestId = ++_statusRequestId;
    if (_studentId == null || _cashTypeId == null) {
      if (mounted) {
        setState(() {
          _statusInfo = null;
          _isLoadingStatus = false;
          _statusError = null;
        });
      }
      return;
    }
    final int studentId = _studentId!;
    final int cashTypeId = _cashTypeId!;
    final int month = _month;
    final int year = _year;
    setState(() {
      _statusInfo = null;
      _isLoadingStatus = true;
      _statusError = null;
    });
    final PaymentProvider provider = context.read<PaymentProvider>();
    try {
      final PeriodStatus info = await provider.monthlyStatus(
        studentId,
        month,
        year,
        cashTypeId: cashTypeId,
        paidDate: _paidDate,
      );
      if (mounted && requestId == _statusRequestId) {
        setState(() {
          _statusInfo = info;
          _isLoadingStatus = false;
          _statusError = null;
        });
      }
    } catch (e) {
      if (mounted && requestId == _statusRequestId) {
        setState(() {
          _statusInfo = null;
          _isLoadingStatus = false;
          _statusError = 'Gagal memuat status pembayaran.';
        });
        _snack('Gagal memuat status pembayaran: $e');
      }
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: AppDateRange.clamp(_paidDate),
      firstDate: AppDateRange.minDate,
      lastDate: AppDateRange.maxDate,
    );
    if (picked != null) {
      setState(() => _paidDate = picked);
      _refreshStatus();
    }
  }

  void _onCashTypeChanged(CashTypeModel? ct) {
    // Simpan objek jenis kas terpilih — kewajiban & status kartu di bawah
    // mengikuti nominal jenis kas ini saja (bukan total semua jenis kas).
    final CashTypeModel? previous = _selectedCashType;
    setState(() {
      _cashTypeId = ct?.id;
      _selectedCashType = ct;
    });
    // Isi nominal otomatis hanya bila kosong atau masih bernilai nominal jenis
    // kas sebelumnya (agar angka yang diketik manual tidak tertimpa).
    final String text = _nominalController.text;
    if (ct != null &&
        (text.isEmpty ||
            (previous != null && text == previous.amount.toString()))) {
      _nominalController.text = ct.amount.toString();
    }
    _refreshStatus();
  }

  Future<StudentModel?> _showStudentPicker(List<StudentModel> students) async {
    return showModalBottomSheet<StudentModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StudentPickerSheet(students: students);
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_studentId == null) {
      _snack('Siswa wajib dipilih.');
      return;
    }
    if (_cashTypeId == null) {
      _snack('Jenis kas wajib dipilih.');
      return;
    }

    setState(() => _isSaving = true);
    final PaymentProvider provider = context.read<PaymentProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;

    try {
      await provider.addPayment(
        studentId: _studentId!,
        cashTypeId: _cashTypeId!,
        amount: int.parse(_nominalController.text.replaceAll('.', '')),
        month: _month,
        year: _year,
        paidDate: _paidDate.toIso8601String(),
        paymentMethod: PaymentMethod.tunai,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        userId: userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil dicatat.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Gagal menyimpan: $e');
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Kartu "Status Siswa Periode Ini": kewajiban mengikuti nominal jenis
  /// kas yang dipilih (bukan total semua jenis kas).
  Widget _buildStatusCard() {
    final PeriodStatus? status = _statusInfo;
    final CashTypeModel? kas = _selectedCashType;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Status Siswa Periode Ini', style: AppText.caption),
          const SizedBox(height: 8),
          if (_isLoadingStatus)
            const Row(
              children: <Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Memuat status pembayaran...'),
              ],
            )
          else if (_statusError != null)
            Text(
              _statusError!,
              style: AppText.bodySmall.copyWith(color: AppColors.danger),
            )
          else if (status == null || kas == null)
            Text(
              'Pilih siswa, jenis kas, & periode untuk melihat status '
              'otomatis.',
              style: AppText.bodySmall,
            )
          else if (status.owed <= 0) ...<Widget>[
            Row(
              children: <Widget>[
                StatusBadge.pembayaran(PaymentStatus.belum),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nominal ${kas.name} belum diatur. '
                    'Atur nominal di menu Jenis Kas.',
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                StatusBadge.pembayaran(status.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${kas.name} · '
                    'Kewajiban ${Formatters.rupiah(status.owed)} · '
                    'Total bayar ${Formatters.rupiah(status.paid)}',
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              status.sisa == 0
                  ? '${kas.name} periode ini sudah lunas.'
                  : 'Sisa tunggakan: ${Formatters.rupiah(status.sisa)}',
              style: AppText.caption.copyWith(
                color: status.sisa == 0 ? AppColors.teal : AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PaymentProvider provider = context.watch<PaymentProvider>();
    final CashTypesProvider cashTypes = context.watch<CashTypesProvider>();
    final SessionProvider session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pembayaran')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // SISWA
              FormField<int>(
                initialValue: _studentId,
                validator: (int? value) =>
                    value == null ? 'Siswa wajib dipilih' : null,
                builder: (FormFieldState<int> field) {
                  StudentModel? selectedStudent;
                  for (final StudentModel student in provider.students) {
                    if (student.id == field.value) {
                      selectedStudent = student;
                      break;
                    }
                  }
                  return InkWell(
                    onTap: provider.students.isEmpty
                        ? null
                        : () async {
                            final StudentModel? student =
                                await _showStudentPicker(provider.students);
                            if (student == null || !mounted) return;
                            setState(() => _studentId = student.id);
                            field.didChange(student.id);
                            _refreshStatus();
                          },
                    borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Siswa *',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                        errorText: field.errorText,
                      ),
                      child: Text(
                        selectedStudent == null
                            ? 'Pilih siswa'
                            : '${selectedStudent.name} (${selectedStudent.className ?? '-'})',
                        overflow: TextOverflow.ellipsis,
                        style: selectedStudent == null
                            ? AppText.body.copyWith(color: AppColors.textMuted)
                            : AppText.body,
                      ),
                    ),
                  );
                },
              ),
              if (provider.students.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Belum ada siswa aktif. Tambahkan siswa di menu Siswa.',
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 16),

              // JENIS KAS
              DropdownButtonFormField<int>(
                initialValue: _cashTypeId,
                decoration: const InputDecoration(
                  labelText: 'Jenis Kas *',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
                items: cashTypes.cashTypes
                    .where((CashTypeModel c) => c.isActive)
                    .map(
                      (CashTypeModel c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(
                          '${c.name} · ${Formatters.rupiah(c.amount)}',
                        ),
                      ),
                    )
                    .toList(),
                validator: (int? v) =>
                    v == null ? 'Jenis kas wajib dipilih' : null,
                onChanged: (int? v) {
                  CashTypeModel? ct;
                  for (final CashTypeModel c in cashTypes.cashTypes) {
                    if (c.id == v) {
                      ct = c;
                      break;
                    }
                  }
                  _onCashTypeChanged(ct);
                },
              ),
              if (cashTypes.cashTypes
                  .where((CashTypeModel c) => c.isActive)
                  .isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    cashTypes.isLoading
                        ? 'Memuat jenis kas...'
                        : 'Belum ada jenis kas aktif. Tambahkan dari menu '
                              'Siswa > Jenis Kas.',
                    style: AppText.caption.copyWith(
                      color: cashTypes.isLoading
                          ? AppColors.textMuted
                          : AppColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // PERIODE (BULAN & TAHUN)
              Text('Periode Pembayaran *', style: AppText.label),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(
                        labelText: 'Bulan',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (int m = 1; m <= 12; m++)
                          DropdownMenuItem<int>(
                            value: m,
                            child: Text(Formatters.namaBulan(m)),
                          ),
                      ],
                      onChanged: (int? v) {
                        if (v != null) {
                          setState(() => _month = v);
                          _refreshStatus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Tahun',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (final int y in AppDateRange.semuaTahun)
                          DropdownMenuItem<int>(value: y, child: Text('$y')),
                      ],
                      onChanged: (int? v) {
                        if (v != null) {
                          setState(() => _year = v);
                          _refreshStatus();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // TANGGAL
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Bayar *',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                  child: Text(
                    Formatters.tanggal(_paidDate),
                    style: AppText.body,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // NOMINAL
              TextFormField(
                controller: _nominalController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Nominal *',
                  prefixIcon: Icon(Icons.payments_outlined),
                  hintText: '20000',
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nominal wajib diisi';
                  }
                  if (int.tryParse(v) == 0) {
                    return 'Nominal harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // KETERANGAN
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'Opsional',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // PETUGAS (dari sesi login, otomatis)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.badge_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Petugas', style: AppText.caption),
                          const SizedBox(height: 2),
                          Text(
                            session.user?.fullName ?? '-',
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // INFO STATUS OTOMATIS (LUNAS / SEBAGIAN / BELUM BAYAR)
              // Nilai kewajiban mengacu pada JENIS KAS TERPILIH saja.
              _buildStatusCard(),
              const SizedBox(height: 20),

              // SIMPAN
              _isSaving
                  ? const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Simpan Pembayaran'),
                    ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
