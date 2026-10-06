import 'package:flutter_test/flutter_test.dart';

import 'package:kas_bintang_nusantara/utils/formatters.dart';

void main() {
  group('Formatters.rupiah', () {
    test('memformat angka menjadi Rupiah', () {
      expect(Formatters.rupiah(25000), 'Rp 25.000');
      expect(Formatters.rupiah(0), 'Rp 0');
    });
  });

  group('Formatters.namaBulan', () {
    test('mengembalikan nama bulan Indonesia', () {
      expect(Formatters.namaBulan(1), 'Januari');
      expect(Formatters.namaBulan(12), 'Desember');
    });
  });

  group('CodeGenerator.payment', () {
    test('menghasilkan kode pembayaran berurutan', () {
      final String code = CodeGenerator.payment('BR', 12);
      expect(code, startsWith('BR/'));
      expect(code, endsWith('/000012'));
    });
  });
}