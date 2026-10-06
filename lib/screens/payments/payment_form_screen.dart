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

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int? _studentId;
  int? _cashTypeId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  late DateTime _paidDate;

  PeriodStatus? _statusInfo;
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
    if (_studentId == null) {
      if (mounted) setState(() => _statusInfo = null);
      return;
    }
    final PaymentProvider provider = context.read<PaymentProvider>();
    final PeriodStatus info =
        await provider.monthlyStatus(_studentId!, _month, _year);
    if (mounted && _studentId != null) {
      setState(() => _statusInfo = info);
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
    }
  }

  void _onCashTypeChanged(CashTypeModel? ct) {
    setState(() => _cashTypeId = ct?.id);
    if (ct != null && (_nominalController.text.isEmpty ||
        ct.amount.toString() == _nominalController.text)) {
      _nominalController.text = ct.amount.toString();
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
              DropdownButtonFormField<int>(
                initialValue: _studentId,
                decoration: const InputDecoration(
                  labelText: 'Siswa *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: provider.students.map((StudentModel s) {
                  return DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(
                      '${s.name} (${s.className ?? '-'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                validator: (int? v) => v == null ? 'Siswa wajib dipilih' : null,
                onChanged: (int? v) {
                  setState(() => _studentId = v);
                  _refreshStatus();
                },
              ),
              if (provider.students.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Belum ada siswa aktif. Tambahkan siswa di menu Siswa dulu.',
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
                    .map((CashTypeModel c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text('${c.name} · ${Formatters.rupiah(c.amount)}'),
                        ))
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
              if (cashTypes.cashTypes.where((CashTypeModel c) => c.isActive).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    cashTypes.isLoading
                        ? 'Memuat jenis kas...'
                        : 'Belum ada jenis kas aktif. Tambahkan dari menu '
                              'Siswa > Jenis Kas dulu.',
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
                    const Icon(Icons.badge_outlined,
                        color: AppColors.textMuted, size: 20),
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
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Status Siswa Periode Ini', style: AppText.caption),
                    const SizedBox(height: 8),
                    if (_statusInfo == null)
                      Text(
                        'Pilih siswa & periode untuk melihat status otomatis.',
                        style: AppText.bodySmall,
                      )
                    else ...<Widget>[
                      Row(
                        children: <Widget>[
                          StatusBadge.pembayaran(_statusInfo!.status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total bayar ${Formatters.rupiah(_statusInfo!.paid)} '
                              'vs kewajiban ${Formatters.rupiah(_statusInfo!.owed)}',
                              style: AppText.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _statusInfo!.sisa == 0
                            ? 'Kewajiban bulan ini sudah lunas.'
                            : 'Sisa tunggakan: ${Formatters.rupiah(_statusInfo!.sisa)}',
                        style: AppText.caption.copyWith(
                          color: _statusInfo!.sisa == 0
                              ? AppColors.teal
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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