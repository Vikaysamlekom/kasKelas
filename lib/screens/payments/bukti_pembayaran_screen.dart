import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/payment_model.dart';
import '../../models/school_profile_model.dart';
import '../../providers/payment_provider.dart';
import '../../repositories/school_profile_repo.dart';
import '../../services/pdf_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';

/// BUKTI PEMBAYARAN KAS: tampilan kwitansi + cetak/simpan PDF/bagikan.
class BuktiPembayaranScreen extends StatefulWidget {
  final int paymentId;

  const BuktiPembayaranScreen({super.key, required this.paymentId});

  @override
  State<BuktiPembayaranScreen> createState() => _BuktiPembayaranScreenState();
}

class _BuktiPembayaranScreenState extends State<BuktiPembayaranScreen> {
  PaymentModel? _payment;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PaymentProvider provider = context.read<PaymentProvider>();
    final PaymentModel? p = await provider.paymentById(widget.paymentId);
    if (mounted) {
      setState(() {
        _payment = p;
        _loading = false;
      });
    }
  }

  /// Generate bytes PDF bukti pembayaran (menggunakan profil sekolah).
  Future<Uint8List> _buildPdf() async {
    final PaymentModel p = _payment!;
    final SchoolProfileModel? profil = await SchoolProfileRepository().getProfile();
    return PdfService.receipt(
      p,
      namaSekolah: profil?.schoolName,
      namaBendahara: (profil?.treasurer != null && profil!.treasurer!.isNotEmpty)
          ? profil.treasurer
          : p.officerName,
    );
  }

  Future<void> _print() async {
    setState(() => _processing = true);
    try {
      await Printing.layoutPdf(
        name: PdfService.fileName(_payment!),
        onLayout: (PdfPageFormat format) => _buildPdf(),
      );
    } catch (e) {
      _snack('Gagal cetak: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _savePdf() async {
    setState(() => _processing = true);
    try {
      final Uint8List bytes = await _buildPdf();
      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory folder = Directory('${dir.path}/bukti');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final File file = File('${folder.path}/${PdfService.fileName(_payment!)}');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) {
        _snack('PDF tersimpan:\n${file.path}');
      }
    } catch (e) {
      if (mounted) _snack('Gagal simpan PDF: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _share() async {
    setState(() => _processing = true);
    try {
      final Uint8List bytes = await _buildPdf();
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/${PdfService.fileName(_payment!)}');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          text: 'Bukti Pembayaran Kas - ${_payment!.paymentCode}',
          downloadFallbackEnabled: true,
        ),
      );
    } catch (e) {
      if (mounted) _snack('Gagal membagikan PDF: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bukti Pembayaran')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payment == null
          ? const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Data tidak ditemukan',
              message: 'Bukti pembayaran tidak tersedia.',
            )
          : _buildBody(_payment!),
    );
  }

  Widget _buildBody(PaymentModel p) {
    final List<(String, String)> rows = <(String, String)>[
      ('No. Transaksi', p.paymentCode),
      ('Nama Siswa', p.studentName ?? '-'),
      ('NIS', p.studentNis ?? '-'),
      ('Kelas', p.className ?? '-'),
      ('Jenis Kas', p.cashTypeName ?? '-'),
      ('Periode', '${Formatters.namaBulan(p.month)} ${p.year}'),
      ('Nominal', Formatters.rupiah(p.amount)),
      ('Status', PaymentStatus.label(p.status)),
      ('Tanggal', Formatters.tanggalIso(p.paidDate)),
      ('Petugas', p.officerName ?? '-'),
      if (p.note != null && p.note!.isNotEmpty) ('Keterangan', p.note!),
    ];

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: <Widget>[
            // HEADER BUKTI
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.school_rounded, color: AppColors.orange, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'SMK BINTANG NUSANTARA',
                    style: AppText.sectionTitle.copyWith(color: Colors.white, fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BUKTI PEMBAYARAN KAS',
                    style: AppText.caption.copyWith(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.paymentCode,
                      style: AppText.label.copyWith(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DETAIL
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < rows.length; i++)
                    _row(rows[i].$1, rows[i].$2, last: i == rows.length - 1),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CATATAN
            Text(
              'Dokumen ini dibuat otomatis oleh aplikasi Kas Bintang '
              'Nusantara.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),

        // TOMBOL AKSI
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _processing
              ? const SizedBox(height: 52, child: Center(child: CircularProgressIndicator()))
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _print,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Cetak'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savePdf,
                        icon: const Icon(Icons.save_alt_rounded, size: 18),
                        label: const Text('Simpan PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Bagikan'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 2, child: Text(label, style: AppText.caption)),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
