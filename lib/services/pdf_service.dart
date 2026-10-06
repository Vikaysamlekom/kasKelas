import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payment_model.dart';
import '../utils/formatters.dart';

/// Pembuat dokumen PDF (bukti pembayaran).
class PdfService {
  PdfService._();

  /// Nama file PDF untuk bukti pembayaran.
  static String fileName(PaymentModel payment) =>
      'bukti_${payment.paymentCode.replaceAll('/', '-')}.pdf';

  /// Layout dokumen bukti pembayaran kas.
  static Future<Uint8List> receipt(
    PaymentModel p, {
    String? namaSekolah,
    String? namaBendahara,
  }) async {
    final String sekolah = (namaSekolah != null && namaSekolah.isNotEmpty)
        ? namaSekolah
        : 'SMK BINTANG NUSANTARA';
    final String bendahara = (namaBendahara != null && namaBendahara.isNotEmpty)
        ? namaBendahara
        : (p.officerName ?? '-');
    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: theme,
        ),
        build: (pw.Context context) {
          final pw.Widget header = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Text(
                sekolah.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'BUKTI PEMBAYARAN KAS',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),
            ],
          );

          final List<(String, String)> rows = <(String, String)>[
            ('No. Transaksi', p.paymentCode),
            ('Nama Siswa', p.studentName ?? '-'),
            ('NIS', p.studentNis ?? '-'),
            ('Kelas', p.className ?? '-'),
            ('Jenis Kas', p.cashTypeName ?? '-'),
            ('Periode', '${Formatters.namaBulan(p.month)} ${p.year}'),
            (
              'Nominal',
              'Rp ${Formatters.angka(p.amount)}',
            ),
            ('Status', PaymentStatus.label(p.status)),
            ('Tanggal Bayar', Formatters.tanggalIso(p.paidDate)),
            ('Metode', _methodLabel(p.paymentMethod)),
            ('Petugas', p.officerName ?? '-'),
            if (p.note != null && p.note!.isNotEmpty) ('Keterangan', p.note!),
          ];

          final pw.Widget table = pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Table(
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey200,
                  width: 0.5,
                ),
              ),
              children: <pw.TableRow>[
                for (final (String label, String value) in rows)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(),
                    children: <pw.Widget>[
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          value,
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );

          final pw.Widget signature = pw.Container(
            margin: const pw.EdgeInsets.only(top: 32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  Formatters.tanggal(DateTime.now()),
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Bendahara',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 56),
                pw.Text(
                  bendahara,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ],
            ),
          );

          final pw.Widget footer = pw.Column(
            children: <pw.Widget>[
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Text(
                'Dokumen ini dibuat otomatis oleh aplikasi Kas Bintang Nusantara.\n'
                'Harap simpan untuk keperluan administrasi.',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );

          return <pw.Widget>[
            header,
            table,
            signature,
            footer,
          ];
        },
      ),
    );

    return doc.save();
  }

  static String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      default:
        return 'Tunai';
    }
  }
}