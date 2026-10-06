import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/cash_type_model.dart';
import '../../providers/cash_types_provider.dart';
import '../../providers/session_provider.dart';
import '../../repositories/siswa_repo.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// Halaman manajemen Jenis Kas / Iuran (CRUD).
class JenisKasScreen extends StatelessWidget {
  const JenisKasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jenis Kas')),
      body: SafeArea(
        child: _JenisKasList(
          onEdit: (CashTypeModel c) => _openForm(context, existing: c),
          onDelete: (CashTypeModel c) => _delete(context, c),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Jenis Kas'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {CashTypeModel? existing}) async {
    final CashTypesProvider provider = context.read<CashTypesProvider>();
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          _CashTypeForm(provider: provider, existing: existing),
    );
    if (saved == true) {
      provider.load();
    }
  }

  Future<void> _delete(BuildContext context, CashTypeModel item) async {
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Jenis Kas',
      message: item.amount == 0
          ? 'Hapus ${item.name}?\nData tidak bisa dikembalikan.'
          : 'Apakah ${item.name} sudah pernah dipakai transaksi?\n'
              'Jika ya, jenis kas hanya akan dinonaktifkan.',
      confirmLabel: 'Ya',
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final CashTypesProvider provider = context.read<CashTypesProvider>();
    try {
      final DeleteResult result = await provider.delete(
        item.id!,
        userId: context.read<SessionProvider>().user?.id,
      );
      if (context.mounted) {
        showDeleteResult(context, result, item.name);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses: ${_CashTypeFormState._pesanGagal(e)}')),
      );
    }
  }
}

class _JenisKasList extends StatelessWidget {
  final ValueChanged<CashTypeModel> onEdit;
  final ValueChanged<CashTypeModel> onDelete;

  const _JenisKasList({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final CashTypesProvider provider = context.watch<CashTypesProvider>();
    if (provider.isLoading && provider.cashTypes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.cashTypes.isEmpty) {
      return const EmptyState(
        icon: Icons.money_outlined,
        title: 'Belum ada jenis kas',
        message: 'Tambahkan jenis kas/iuran untuk mulai mencatat pembayaran.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: provider.cashTypes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final CashTypeModel c = provider.cashTypes[index];
        final bool active = c.isActive;
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (active ? AppColors.orange : AppColors.textMuted)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: active ? AppColors.orange : AppColors.textMuted,
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
                            c.name,
                            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!active) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Nonaktif',
                              style: AppText.caption.copyWith(
                                color: AppColors.danger,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Formatters.rupiah(c.amount)} · ${_frequencyLabel(c.frequency)} · jatuh tempo tgl ${c.dueDay}',
                      style: AppText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
                onPressed: () => onEdit(c),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: () => onDelete(c),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _frequencyLabel(String f) {
  switch (f) {
    case PaymentFrequency.bulanan:
      return 'Bulanan';
    case PaymentFrequency.semester:
      return 'Semester';
    case PaymentFrequency.tahunan:
      return 'Tahunan';
    case PaymentFrequency.sekali:
      return 'Sekali';
    default:
      return f;
  }
}

/// Form jenis kas (bottom sheet).
class _CashTypeForm extends StatefulWidget {
  final CashTypesProvider provider;
  final CashTypeModel? existing;

  const _CashTypeForm({required this.provider, this.existing});

  @override
  State<_CashTypeForm> createState() => _CashTypeFormState();
}

class _CashTypeFormState extends State<_CashTypeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _amount;
  late final TextEditingController _desc;
  late String _frequency;
  late int _dueDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final CashTypeModel? c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _code = TextEditingController(text: c?.code ?? '');
    _amount = TextEditingController(
      text: c == null ? '' : Formatters.angka(c.amount),
    );
    _desc = TextEditingController(text: c?.description ?? '');
    _frequency = c?.frequency ?? PaymentFrequency.bulanan;
    _dueDay = c?.dueDay ?? 10;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final int amount = int.tryParse(
          _amount.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    final int? userId = context.read<SessionProvider>().user?.id;
    try {
      await widget.provider.save(
        id: widget.existing?.id,
        name: _name.text,
        code: _code.text,
        amount: amount,
        frequency: _frequency,
        dueDay: _dueDay,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        userId: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis kas tersimpan.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      // Tanpa catch, _saving tetap true sehingga tombol Simpan mati
      // permanen saat nama/kode duplikat atau database gagal.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_pesanGagal(e))),
      );
    }
  }

  /// Ubah error teknis menjadi kalimat yang bisa dipahami pengguna.
  static String _pesanGagal(Object e) {
    if (e is AppException) return e.message;
    if (e is StateError) return e.message;
    return 'Gagal menyimpan jenis kas: $e';
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
                widget.existing == null ? 'Tambah Jenis Kas' : 'Ubah Jenis Kas',
                style: AppText.title,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama *',
                  hintText: 'Contoh: Kas Bulanan',
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Kode *',
                        hintText: 'BULANAN',
                      ),
                      validator: (String? v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Kode wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Nominal *',
                        prefixText: 'Rp ',
                      ),
                      validator: (String? v) {
                        final String clean =
                            (v ?? '').replaceAll('.', '').replaceAll(',', '');
                        final int amount = int.tryParse(clean) ?? 0;
                        return amount > 0 ? null : 'Nominal wajib diisi';
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frekuensi *'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: PaymentFrequency.bulanan,
                    child: Text('Bulanan'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentFrequency.semester,
                    child: Text('Semester'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentFrequency.tahunan,
                    child: Text('Tahunan'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentFrequency.sekali,
                    child: Text('Sekali / Sumbangan'),
                  ),
                ],
                onChanged: (String? v) =>
                    setState(() => _frequency = v ?? PaymentFrequency.bulanan),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: _dueDay.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Jatuh Tempo Tiap Tanggal *',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                validator: (String? v) {
                  final int day = int.tryParse(v ?? '') ?? 0;
                  return (day >= 1 && day <= 31) ? null : 'Tanggal 1-31';
                },
                onChanged: (String? v) {
                  _dueDay = int.tryParse(v ?? '') ?? _dueDay;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  hintText: 'Opsional',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _saving
                  ? const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : FilledButton(onPressed: _save, child: const Text('Simpan')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}