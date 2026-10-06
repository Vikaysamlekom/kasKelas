import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/expense_category_model.dart';
import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

/// Form pencatatan pengeluaran kas baru (opsional foto nota).
class PengeluaranFormScreen extends StatefulWidget {
  const PengeluaranFormScreen({super.key});

  @override
  State<PengeluaranFormScreen> createState() => _PengeluaranFormScreenState();
}

class _PengeluaranFormScreenState extends State<PengeluaranFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  int? _categoryId;
  DateTime _expenseDate = DateTime.now();
  File? _photo;
  bool _isSaving = false;

  @override
  void dispose() {
    _nominalController.dispose();
    _keperluanController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: AppDateRange.clamp(_expenseDate),
      firstDate: AppDateRange.minDate,
      lastDate: AppDateRange.maxDate,
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  /// Ambil foto nota dari galeri lalu salin ke folder dokumen aplikasi
  /// agar tersimpan permanen (temp ImagePicker bisa dibersihkan sistem).
  Future<void> _pickPhoto() async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      // Galeri tidak tersedia / di-access service tanpa galeri.
      if (mounted) _snack('Tidak dapat membuka galeri: $e');
      return;
    }
    if (picked == null || !mounted) return;

    try {
      final Directory supportDir = await getApplicationDocumentsDirectory();
      final Directory notaDir = Directory(p.join(supportDir.path, 'nota'));
      if (!await notaDir.exists()) {
        await notaDir.create(recursive: true);
      }
      final String fileName =
          'nota_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
      final File saved = await File(picked.path).copy(p.join(notaDir.path, fileName));
      if (mounted) {
        setState(() => _photo = saved);
      }
    } catch (e) {
      if (mounted) {
        _snack('Gagal menyimpan foto nota: $e');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      _snack('Kategori wajib dipilih.');
      return;
    }

    setState(() => _isSaving = true);
    final TransactionProvider provider = context.read<TransactionProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;

    try {
      await provider.addExpense(
        categoryId: _categoryId!,
        amount: int.parse(_nominalController.text.replaceAll('.', '')),
        expenseDate: _expenseDate.toIso8601String(),
        description: _keperluanController.text.trim(),
        receiptNote: _keteranganController.text.trim().isEmpty
            ? null
            : _keteranganController.text.trim(),
        photoPath: _photo?.path,
        userId: userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengeluaran berhasil dicatat.')),
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
    final TransactionProvider provider = context.watch<TransactionProvider>();
    final SessionProvider session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pengeluaran')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // KATEGORI
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: provider.categories
                    .where((ExpenseCategoryModel c) => c.isActive)
                    .map((ExpenseCategoryModel c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                validator: (int? v) =>
                    v == null ? 'Kategori wajib dipilih' : null,
                onChanged: (int? v) => setState(() => _categoryId = v),
              ),
              if (provider.categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Belum ada kategori. Tambahkan lewat ikon kategori di halaman '
                    'Pengeluaran.',
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 16),

              // TANGGAL
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Pengeluaran *',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                  child: Text(
                    Formatters.tanggal(_expenseDate),
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
                  hintText: '150000',
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

              // KEPERLUAN
              TextFormField(
                controller: _keperluanController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Keperluan *',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                  hintText: 'Contoh: Pembelian ATK kantor',
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Keperluan wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // KETERANGAN
              TextFormField(
                controller: _keteranganController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'Opsional',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // FOTO NOTA
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Foto Nota', style: AppText.label),
                    const SizedBox(height: 4),
                    Text(
                      'Opsional — bukti/foto nota pengeluaran.',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 12),
                    if (_photo != null)
                      Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _photo!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                onPressed: () =>
                                    setState(() => _photo = null),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Ambil / Pilih Foto'),
                      ),
                  ],
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
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      label: const Text('Simpan Pengeluaran'),
                    ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}