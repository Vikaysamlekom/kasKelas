import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/pengeluaran_repo.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
import '../payments/bukti_pembayaran_screen.dart';

/// Detail satu transaksi (pemasukan/pengeluaran) + aksi batalkan (void).
class DetailTransaksiScreen extends StatefulWidget {
  final TransactionItem transaction;
  final VoidCallback? onChanged;

  const DetailTransaksiScreen({
    super.key,
    required this.transaction,
    this.onChanged,
  });

  @override
  State<DetailTransaksiScreen> createState() => _DetailTransaksiScreenState();
}

class _DetailTransaksiScreenState extends State<DetailTransaksiScreen> {
  bool _isVoiding = false;

  Future<void> _openBukti() async {
    final int? paymentId = widget.transaction.paymentId;
    if (paymentId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BuktiPembayaranScreen(paymentId: paymentId),
      ),
    );
  }

  Future<void> _void() async {
    final String? reason = await _askVoidReason();
    if (reason == null || !mounted) return;

    setState(() => _isVoiding = true);
    final TransactionProvider provider = context.read<TransactionProvider>();
    final int? userId = context.read<SessionProvider>().user?.id;
    final TransactionItem t = widget.transaction;

    try {
      if (t.isIncome) {
        await provider.voidPayment(t.paymentId!, reason: reason, userId: userId);
      } else {
        await provider.voidExpense(t.expenseId!, reason: reason, userId: userId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dibatalkan.')),
        );
        widget.onChanged?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVoiding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan: $e')),
        );
      }
    }
  }

  Future<String?> _askVoidReason() {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Batalkan Transaksi',
            style: AppText.title.copyWith(fontSize: 17),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Pembatalan akan menandai transaksi sebagai Batal dan '
                  'mencatat ke audit log. Data tidak dihapus.',
                  style: AppText.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Pembatalan *',
                    hintText: 'Alasan wajib diisi',
                  ),
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Alasan pembatalan wajib diisi';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Ya, Batalkan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TransactionItem t = widget.transaction;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // KARTU UTAMA
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (t.isIncome
                                  ? AppColors.teal
                                  : AppColors.danger)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          t.isIncome
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: t.isIncome ? AppColors.teal : AppColors.danger,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(t.code, style: AppText.caption),
                            const SizedBox(height: 2),
                            Text(
                              t.isIncome ? 'Pemasukan Kas' : 'Pengeluaran Kas',
                              style: AppText.sectionTitle,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge.transaksi(t.status, isIncome: t.isIncome),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    t.title,
                    style: AppText.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t.isIncome ? '' : '-'}${Formatters.rupiah(t.amount)}',
                    style: AppText.amountMedium.copyWith(
                      fontSize: 26,
                      color: t.isVoided
                          ? AppColors.textMuted
                          : (t.isIncome ? AppColors.teal : AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // RINCIAN
            AppCard(
              child: Column(
                children: <Widget>[
                  _InfoRow(label: 'Kode Transaksi', value: t.code),
                  _InfoRow(
                    label: 'Tanggal',
                    value: Formatters.tanggalWaktuIso(
                      t.date.toIso8601String(),
                    ),
                  ),
                  if (t.categoryName != null)
                    _InfoRow(label: 'Kategori', value: t.categoryName!),
                  if (t.isIncome && t.studentNis != null)
                    _InfoRow(label: 'NIS', value: t.studentNis!),
                  if (t.isIncome && t.title.isNotEmpty)
                    _InfoRow(label: 'Siswa', value: t.title),
                  if (t.isIncome && t.className != null)
                    _InfoRow(label: 'Kelas', value: t.className!),
                  if (t.isIncome && t.periodMonth != null)
                    _InfoRow(
                      label: 'Periode',
                      value:
                          '${Formatters.namaBulan(t.periodMonth!)} ${t.periodYear}',
                    ),
                  if (t.isIncome && t.paymentMethod != null)
                    _InfoRow(
                      label: 'Metode',
                      value: t.paymentMethod!,
                    ),
                  if (t.officerName != null && t.officerName!.isNotEmpty)
                    _InfoRow(label: 'Petugas', value: t.officerName!),
                  if (t.note != null && t.note!.isNotEmpty)
                    _InfoRow(label: 'Keterangan', value: t.note!),
                  if (!t.isIncome && t.photoPath != null) ...<Widget>[
                    _InfoRow(label: 'Foto Nota', value: 'Ada'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // FOTO NOTA (pengeluaran)
            if (!t.isIncome && t.photoPath != null) ...<Widget>[
              _PhotoNota(path: t.photoPath!),
              const SizedBox(height: 12),
            ],

            // INFO PEMBATALAN
            if (t.isVoided) ...<Widget>[
              AppCard(
                color: AppColors.danger.withValues(alpha: 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.block_rounded, color: AppColors.danger),
                    const SizedBox(height: 8),
                    Text('Transaksi Batal', style: AppText.sectionTitle),
                    const SizedBox(height: 4),
                    Text(
                      t.voidReason ?? '-',
                      style: AppText.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // AKSI
            if (t.isIncome && !t.isVoided) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _openBukti,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Lihat Bukti Pembayaran'),
              ),
              const SizedBox(height: 10),
            ],
            if (!t.isVoided) ...<Widget>[
              _isVoiding
                  ? const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : OutlinedButton.icon(
                      onPressed: _void,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Batalkan Transaksi'),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(label, style: AppText.caption),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoNota extends StatelessWidget {
  final String path;

  const _PhotoNota({required this.path});

  @override
  Widget build(BuildContext context) {
    final File? file = File(path).existsSync() ? File(path) : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: file == null
            ? const SizedBox(
                height: 140,
                child: Center(
                  child: Text('File foto nota tidak ditemukan.',
                      style: AppText.caption),
                ),
              )
            : Image.file(
                file,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}