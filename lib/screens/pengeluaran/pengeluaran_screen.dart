import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/expense_model.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/pengeluaran_repo.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_badge.dart';
import '../transactions/detail_transaksi_screen.dart';
import 'kategori_pengeluaran_screen.dart';
import 'pengeluaran_form_screen.dart';

/// Halaman pengeluaran: daftar + filter periode/kategori + entri baru.
class PengeluaranScreen extends StatefulWidget {
  const PengeluaranScreen({super.key});

  @override
  State<PengeluaranScreen> createState() => _PengeluaranScreenState();
}

class _PengeluaranScreenState extends State<PengeluaranScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final TransactionProvider provider = context.read<TransactionProvider>();
      provider.loadExpenses();
      provider.loadCategories();
    });
  }

  Future<void> _openForm() async {
    await context.read<TransactionProvider>().loadCategories();
    if (!mounted) return;
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PengeluaranFormScreen(),
      ),
    );
    if (changed == true && mounted) {
      context.read<TransactionProvider>().loadExpenses();
      context.read<TransactionProvider>().loadCategories();
    }
  }

  Future<void> _openDetail(ExpenseModel expense) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DetailTransaksiScreen(
          transaction: TransactionItem(
            type: TransactionType.pengeluaran,
            code: expense.expenseCode,
            amount: expense.amount,
            date: DateTime.tryParse(expense.expenseDate) ?? DateTime.now(),
            title: expense.description,
            subtitle: expense.categoryName,
            categoryName: expense.categoryName,
            note: expense.receiptNote,
            photoPath: expense.photoPath,
            status: expense.status,
            voidReason: expense.voidReason,
            expenseId: expense.id,
            officerName: expense.officerName,
            expenseCategoryId: expense.categoryId,
          ),
          onChanged: () {
            context.read<TransactionProvider>().loadExpenses();
            context.read<TransactionProvider>().loadCategories();
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<TransactionProvider>().loadExpenses();
      }
    });
  }

  void _clearFilters() {
    final TransactionProvider provider = context.read<TransactionProvider>();
    provider.applyExpenseFilter(year: 0);
    provider.applyExpenseFilter(month: 0);
    provider.applyExpenseFilter(categoryId: 0);
  }

  @override
  Widget build(BuildContext context) {
    final TransactionProvider provider = context.watch<TransactionProvider>();

    final List<ExpenseModel> valid =
        provider.expenses.where((e) => e.status != ExpenseStatus.batal).toList();
    final int total =
        valid.fold<int>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Kategori Pengeluaran',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const KategoriPengeluaranScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // FILTER PERIODE & KATEGORI
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  FilterDropdown<int>(
                    label: 'Tahun',
                    value: provider.expenseFilter.year,
                    items: _years,
                    onChanged: (int? v) {
                      provider.applyExpenseFilter(year: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Bulan',
                    value: provider.expenseFilter.month,
                    items: _months,
                    onChanged: (int? v) {
                      provider.applyExpenseFilter(month: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    label: 'Kategori',
                    value: provider.expenseFilter.categoryId,
                    items: provider.categories
                        .where((c) => c.isActive)
                        .map((c) => (c.name, c.id!))
                        .toList(),
                    onChanged: (int? v) {
                      provider.applyExpenseFilter(categoryId: v ?? 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearFilters,
                    tooltip: 'Reset Filter',
                    icon: const Icon(
                      Icons.filter_alt_off_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // RINGKASAN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Total Pengeluaran', style: AppText.caption),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.rupiah(total),
                            style: AppText.amountMedium.copyWith(
                              color: AppColors.danger,
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
                            '${provider.expenses.length}',
                            style: AppText.amountMedium.copyWith(
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // DAFTAR PENGELUARAN
            Expanded(
              child: _ExpenseList(
                isLoading: provider.isLoadingExpenses,
                expenses: provider.expenses,
                onTap: _openDetail,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Tambah Pengeluaran'),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
    );
  }

  static final List<(String, int)> _months = _buildMonths();
  static final List<(String, int)> _years = _buildYears();

  static List<(String, int)> _buildMonths() {
    final List<(String, int)> list = <(String, int)>[];
    for (int m = 1; m <= 12; m++) {
      list.add((Formatters.namaBulan(m), m));
    }
    return list;
  }

  static List<(String, int)> _buildYears() {
    return <(String, int)>[
      for (final int y in AppDateRange.semuaTahun) (y.toString(), y),
    ];
  }
}

class _ExpenseList extends StatelessWidget {
  final bool isLoading;
  final List<ExpenseModel> expenses;
  final void Function(ExpenseModel) onTap;

  const _ExpenseList({
    required this.isLoading,
    required this.expenses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && expenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (expenses.isEmpty) {
      return const EmptyState(
        icon: Icons.remove_circle_outline,
        title: 'Belum ada pengeluaran',
        message:
            'Tekan "Tambah Pengeluaran" untuk mencatat pengeluaran kas.',
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<TransactionProvider>().loadExpenses(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: expenses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final ExpenseModel e = expenses[index];
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => onTap(e),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        e.description,
                        style:
                            AppText.body.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${e.expenseCode} · ${e.categoryName ?? '-'}',
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        e.photoPath == null
                            ? Formatters.tanggalIso(e.expenseDate)
                            : '${Formatters.tanggalIso(e.expenseDate)} · Ada foto nota',
                        style: AppText.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '-${Formatters.rupiah(e.amount)}',
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: e.status == ExpenseStatus.batal
                            ? AppColors.textMuted
                            : AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge.kas(e.status),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}