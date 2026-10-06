import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/expense_category_model.dart';
import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/siswa_repo.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// Kelola kategori pengeluaran (extend/edit/nonaktifkan).
class KategoriPengeluaranScreen extends StatefulWidget {
  const KategoriPengeluaranScreen({super.key});

  @override
  State<KategoriPengeluaranScreen> createState() =>
      _KategoriPengeluaranScreenState();
}

class _KategoriPengeluaranScreenState extends State<KategoriPengeluaranScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadCategories();
    });
  }

  Future<void> _openForm([ExpenseCategoryModel? item]) async {
    final TransactionProvider provider = context.read<TransactionProvider>();
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryFormSheet(item: item),
    );
    if (saved == true) {
      await provider.loadCategories();
    }
  }

  Future<void> _delete(ExpenseCategoryModel category) async {
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Kategori',
      message:
          'Hapus kategori ${category.name}?\nJika sudah dipakai pengeluaran, '
          'kategori akan dinonaktifkan saja.',
    );
    if (!confirm || !mounted) return;
    final int? userId = context.read<SessionProvider>().user?.id;
    await jalankanAksi(context, () async {
      final DeleteResult result =
          await context.read<TransactionProvider>().deleteCategory(
                category.id!,
                userId: userId,
              );
      if (mounted) {
        showDeleteResult(context, result, 'Kategori ${category.name}');
      }
    }, konteks: 'Hapus kategori');
  }

  @override
  Widget build(BuildContext context) {
    final TransactionProvider provider = context.watch<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Pengeluaran')),
      body: SafeArea(
        child: provider.categories.isEmpty
            ? EmptyState(
                icon: Icons.category_outlined,
                title: 'Belum ada kategori',
                message: 'Tekan "+" untuk menambah kategori pengeluaran.',
              )
            : RefreshIndicator(
                color: AppColors.navy,
                onRefresh: () => provider.loadCategories(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: provider.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final ExpenseCategoryModel c = provider.categories[index];
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (c.isActive
                                      ? AppColors.orange
                                      : AppColors.textMuted)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.category_outlined,
                              size: 20,
                              color: c.isActive
                                  ? AppColors.orange
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  c.name,
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (c.description != null &&
                                    c.description!.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    c.description!,
                                    style: AppText.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (!c.isActive) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Nonaktif',
                                    style: AppText.caption.copyWith(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (c.isActive)
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _openForm(c),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 20, color: AppColors.navy),
                            ),
                          IconButton(
                            tooltip: c.isActive ? 'Hapus' : 'Aktifkan lagi',
                            onPressed: () {
                              if (c.isActive) {
                                _delete(c);
                              } else {
                                _reactivate(c);
                              }
                            },
                            icon: Icon(
                              c.isActive
                                  ? Icons.delete_outline
                                  : Icons.refresh_rounded,
                              size: 20,
                              color: c.isActive
                                  ? AppColors.danger
                                  : AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _reactivate(ExpenseCategoryModel category) async {
    final int? userId = context.read<SessionProvider>().user?.id;
    await context
        .read<TransactionProvider>()
        .saveCategory(
          id: category.id,
          name: category.name,
          description: category.description,
          userId: userId,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori ${category.name} diaktifkan.')),
      );
    }
  }
}

/// Bottom sheet form tambah/edit kategori (nama + deskripsi).
class _CategoryFormSheet extends StatefulWidget {
  final ExpenseCategoryModel? item;

  const _CategoryFormSheet({this.item});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _descController =
        TextEditingController(text: widget.item?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final TransactionProvider provider =
        context.read<TransactionProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;

    try {
      await provider.saveCategory(
        id: widget.item?.id,
        name: _nameController.text,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        userId: userId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.item == null ? 'Tambah Kategori' : 'Edit Kategori',
                  style: AppText.title,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kategori *',
                    prefixIcon: Icon(Icons.category_outlined),
                    hintText: 'Contoh: ATK',
                  ),
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Nama kategori wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    hintText: 'Opsional',
                  ),
                ),
                const SizedBox(height: 20),
                _isSaving
                    ? const SizedBox(
                        height: 52,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          widget.item == null
                              ? 'Simpan Kategori'
                              : 'Perbarui Kategori',
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}