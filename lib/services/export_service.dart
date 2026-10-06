import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/formatters.dart';

/// Ekspor laporan keuangan: PDF (dengan kop sekolah) dan CSV (bisa dibuka
/// dengan Microsoft Excel).
class ExportService {
  ExportService._();

  static const String kopSekolah = 'SMK BINTANG NUSANTARA';
  static const String judulDokumen = 'LAPORAN KEUANGAN KAS';

  /// Bangun PDF laporan dengan kop, meta (periode/tanggal cetak/bendahara),
  /// ringkasan opsional, tabel data, dan tanda tangan bendahara.
  static Future<Uint8List> reportPdf({
    required String judul,
    required String periodeLabel,
    required String bendahara,
    required List<String> kolom,
    required List<List<String>> baris,
    List<String> ringkasan = const <String>[],
    String? sekolah,
  }) async {
    final String kop = (sekolah != null && sekolah.isNotEmpty) ? sekolah.toUpperCase() : kopSekolah;
    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: theme,
        ),
        build: (pw.Context context) {
          return <pw.Widget>[
            _header(kop),
            pw.SizedBox(height: 10),
            pw.Text(
              judul,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(2),
              },
              children: <pw.TableRow>[
                _metaRow('Periode', periodeLabel),
                _metaRow('Tanggal Cetak', Formatters.tanggal(DateTime.now())),
                _metaRow('Bendahara', bendahara),
              ],
            ),
            if (ringkasan.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    for (final String line in ringkasan)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          line,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 12),
            if (baris.isEmpty)
              pw.Text(
                'Tidak ada data pada periode ini.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: kolom,
                data: baris,
                headerStyle: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.blueGrey900,
                ),
                cellPadding: const pw.EdgeInsets.all(5),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
            pw.SizedBox(height: 24),
            _signature(bendahara),
            pw.SizedBox(height: 8),
            _footer(),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Bangun teks CSV (bisa dibuka Excel). Berisi kop + meta di bagian
  /// atas lalu tabel data.
  static String reportCsv({
    required String judul,
    required String periodeLabel,
    required String bendahara,
    required List<String> kolom,
    required List<List<String>> baris,
    List<String> ringkasan = const <String>[],
    String? sekolah,
  }) {
    final String kop = (sekolah != null && sekolah.isNotEmpty) ? sekolah.toUpperCase() : kopSekolah;
    final List<List<String>> lines = <List<String>>[];
    lines.add(<String>[kop]);
    lines.add(<String>[judulDokumen]);
    lines.add(<String>[judul]);
    lines.add(<String>[]);
    lines.add(<String>['Periode', periodeLabel]);
    lines.add(<String>[
      'Tanggal Cetak',
      Formatters.tanggal(DateTime.now()),
    ]);
    lines.add(<String>['Bendahara', bendahara]);
    if (ringkasan.isNotEmpty) {
      lines.add(<String>[]);
      for (final String line in ringkasan) {
        lines.add(<String>[line]);
      }
    }
    lines.add(<String>[]);
    lines.add(kolom);
    lines.addAll(baris);

    return const ListToCsvConverter().convert(lines);
  }

  // ------------------------------------------------------------------
  // HELPERS PDF
  // ------------------------------------------------------------------

  static pw.Widget _header([String? sekolah]) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Text(
          sekolah ?? kopSekolah,
          style: pw.TextStyle(
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          judulDokumen,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.TableRow _metaRow(String label, String value) {
    return pw.TableRow(
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _signature(String bendahara) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: <pw.Widget>[
          pw.Text(
            'Bendahara',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 50),
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
  }

  static pw.Widget _footer() {
    return pw.Column(
      children: <pw.Widget>[
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text(
          'Dokumen dibuat otomatis oleh aplikasi Kas Bintang Nusantara.',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey500,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
}