import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_bintang_nusantara/core/constants.dart';
import 'package:kas_bintang_nusantara/core/theme.dart';
import 'package:kas_bintang_nusantara/database/db_helper.dart';
import 'package:kas_bintang_nusantara/models/user_model.dart';
import 'package:kas_bintang_nusantara/providers/classes_provider.dart';
import 'package:kas_bintang_nusantara/providers/navigation_provider.dart';
import 'package:kas_bintang_nusantara/providers/session_provider.dart';
import 'package:kas_bintang_nusantara/providers/students_provider.dart';
import 'package:kas_bintang_nusantara/repositories/auth_repository.dart';
import 'package:kas_bintang_nusantara/repositories/kelas_repo.dart';
import 'package:kas_bintang_nusantara/repositories/siswa_repo.dart';
import 'package:kas_bintang_nusantara/screens/login/login_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/profil_sekolah_screen.dart';
import 'package:kas_bintang_nusantara/screens/settings/ubah_pin_screen.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji alur masuk, ganti PIN, dan simpan profil sekolah.
///
/// PEMBATAS PENTING: `testWidgets` berjalan di FakeAsync, sehingga I/O
/// sqflite nyata SELALU menggantung di dalam widget test. Karena itu:
///   - Verifikasi kredensial sungguhan (hash kata sandi, sesi tersimpan)
///     diuji di `test()` biasa, di luar FakeAsync.
///   - Uji layar hanya memakai [_RekamAuth] yang selesai sinkron, plus
///     validasi sisi-klien yang tidak menyentuh database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String dbNameTest = 'auth_flows_test';
// Pakai kredensial bawaan aplikasi, supaya alur login default ikut teruji.
  final String userUji = AppConstants.defaultUsername;
  final String sandiUji = AppConstants.defaultPassword;

  Future<void> hapusSemuaDbTest() async {
    final String base = await getDatabasesPath();
    final Directory dir = Directory(base);
    if (!dir.existsSync()) return;
    for (final FileSystemEntity f in dir.listSync()) {
      if (f is! File) continue;
      if (!p.basename(f.path).startsWith(dbNameTest)) continue;
      try {
        f.deleteSync();
      } on FileSystemException {
        // Diabaikan: file mungkin masih terkunci Windows.
      }
    }
  }

/// Buat user uji dengan hash kata sandi yang benar (pakai hash resmi).
  Future<int> seedUser({required String username, required String password}) async {
    final String now = DateTime.now().toIso8601String();
    return DBHelper.instance.insert(DBHelper.tblUsers, <String, Object?>{
      'username': username,
      'password_hash': DBHelper.hashPassword(password, username),
      'full_name': 'Bendahara Uji',
      'nip': '19800101',
      'role': 'bendahara',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Tutup dulu supaya file bisa dihapus di Windows, lalu pakai nama unik
    // agar sisa file dari run sebelumnya tidak bentrok dengan UNIQUE index.
    await DBHelper.instance.close();
    DBHelper.dbNameOverride =
        '${dbNameTest}_${DateTime.now().millisecondsSinceEpoch}';
await hapusSemuaDbTest();
    await DBHelper.instance.database;
    // DB baru sudah berisi user bawaan aplikasi. Tambah satu user uji lagi
    // agar tes "ubah PIN" tidak mengubah kredensial bawaan.
    await seedUser(username: 'penguji', password: 'ujipin123');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDownAll(() async {
    await DBHelper.instance.close();
    DBHelper.dbNameOverride = null;
    await hapusSemuaDbTest();
  });

  List<SingleChildWidget> providers(SessionProvider session) {
    return <SingleChildWidget>[
      ChangeNotifierProvider<SessionProvider>.value(value: session),
      ChangeNotifierProvider<ClassesProvider>(
        create: (_) => ClassesProvider(classRepository: ClassRepository()),
      ),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
      ChangeNotifierProvider<StudentsProvider>(
        create: (_) => StudentsProvider(
          studentRepository: StudentRepository(),
          classRepository: ClassRepository(),
        ),
      ),
    ];
  }

  void smokeTest(String nama, Future<void> Function(WidgetTester) body) {
    testWidgets(nama, (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      try {
        await body(tester);
      } finally {
        await tester.pump(const Duration(seconds: 11));
      }
    });
  }

  Future<void> ketuk(WidgetTester tester, Finder f) async {
    await tester.pump();
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f.first);
  }

/// Cari field berdasarkan `labelText`. Layar Ubah PIN memakai `TextField`
  /// sedangkan layar Login memakai `TextFormField`, jadi harus menangani
  /// keduanya.
  Finder field(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (Widget w) => w is TextField || w is TextFormField,
        ),
      );

  /// Beri kesempatan I/O sqflite nyata selesai, lalu bangun ulang widget.
  ///
  /// Layar Profil Sekolah memanggil `getProfile()` di `initState`. Future itu
  /// dibuat di dalam FakeAsync, jadi tidak akan pernah selesai hanya dengan
  /// `pump()`. `runAsync` menjalankan event loop sungguhan; setelah itu
  /// `pump()` memproses callback lanjutannya.
  Future<void> siapAsync(WidgetTester tester) async {
    // `_save()` melakukan beberapa await berurutan (saveProfile, lalu dua
    // setSetting), jadi butuh beberapa putaran event loop nyata.
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> isi(WidgetTester tester, String label, String nilai) async {
    final Finder f = field(label);
    // `TextFormField` memuat `TextField` di dalamnya, jadi常常 ada 2 kandidat
    // untuk field yang sama. Ambil yang pertama.
    expect(f, findsWidgets, reason: 'Field "$label" tidak ditemukan');
    await tester.enterText(f.first, nilai);
    await tester.pump();
  }

  // ============================================================
  // VERIFIKASI KREDENSIAL (I/O nyata, di luar FakeAsync)
  // ============================================================

  group('Verifikasi kredensial', () {
    test('kredensial benar diterima dan sesi tersimpan', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SessionProvider session =
          SessionProvider(authRepository: AuthRepository());

      expect(await session.login(userUji, sandiUji), isTrue);
      expect(session.isLoggedIn, isTrue);
      expect(session.user?.username, userUji);
      expect(session.user?.fullName, AppConstants.defaultFullName);
    });

    test('kata sandi salah ditolak', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SessionProvider session =
          SessionProvider(authRepository: AuthRepository());

      expect(await session.login(userUji, 'sandi-salah'), isFalse);
      expect(session.isLoggedIn, isFalse);
      expect(session.errorMessage, isNotNull);
    });

    test('username tidak terdaftar ditolak', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SessionProvider session =
          SessionProvider(authRepository: AuthRepository());

      expect(await session.login('tidak-ada', sandiUji), isFalse);
      expect(session.isLoggedIn, isFalse);
    });

    test('PIN lama salah tidak mengubah kata sandi', () async {
      final AuthRepository auth = AuthRepository();
      final List<Map<String, Object?>> sebelum = await DBHelper.instance.query(
        DBHelper.tblUsers,
        where: 'username = ?',
        whereArgs: <Object?>['penguji'],
      );

      final bool ok = await auth.changePassword(
        userId: sebelum.first['id']! as int,
        oldPassword: 'pin-lama-salah',
        newPassword: 'pin-baru-123',
      );
      expect(ok, isFalse, reason: 'PIN lama salah harus ditolak');

      final List<Map<String, Object?>> sesudah = await DBHelper.instance.query(
        DBHelper.tblUsers,
        where: 'username = ?',
        whereArgs: <Object?>['penguji'],
      );
      expect(
        sesudah.first['password_hash'],
        sebelum.first['password_hash'],
        reason: 'Hash kata sandi tidak boleh berubah saat PIN lama salah',
      );
    });
  });

  // ============================================================
  // LAYAR LOGIN
  // ============================================================

  group('Layar Login', () {
    smokeTest('form kosong divalidasi, provider tidak dipanggil', (
      WidgetTester tester,
    ) async {
      final _RekamAuth auth = _RekamAuth();
      await tester.pumpWidget(
        MultiProvider(
          providers: providers(SessionProvider(authRepository: auth)),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await ketuk(tester, find.text('Masuk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(auth.panggil, isFalse, reason: 'Data kosong jangan diproses');
      expect(find.byType(TextFormField), findsWidgets);
    });

    smokeTest('kredensial ditolak: pesan error muncul ke pengguna', (
      WidgetTester tester,
    ) async {
      final _RekamAuth auth = _RekamAuth();
      await tester.pumpWidget(
        MultiProvider(
          providers: providers(SessionProvider(authRepository: auth)),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await isi(tester, 'Username', userUji);
      await isi(tester, 'Kata Sandi', 'sandi-salah');
      await ketuk(tester, find.text('Masuk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(auth.panggil, isTrue);
      expect(
        find.text('Login gagal. Periksa username/kata sandi.'),
        findsWidgets,
        reason: 'Login gagal tidak memberi pesan ke pengguna',
      );
    });
  });

  // ============================================================
  // LAYAR UBAH PIN
  // ============================================================

  group('Layar Ubah PIN', () {
    Future<void> bukaPin(WidgetTester tester, SessionProvider session) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers(session),
          child: MaterialApp(theme: AppTheme.light, home: const UbahPinScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    smokeTest('field kosong ditolak', (WidgetTester tester) async {
      await bukaPin(tester, SessionProvider(authRepository: _RekamAuth()));

      await ketuk(tester, find.text('Simpan PIN Baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('PIN lama dan PIN baru wajib diisi.'),
        findsOneWidget,
        reason: 'Validasi PIN kosong tidak tampil',
      );
    });

    smokeTest('PIN baru terlalu pendek ditolak', (WidgetTester tester) async {
      await bukaPin(tester, SessionProvider(authRepository: _RekamAuth()));

      await isi(tester, 'PIN Lama', '111111');
      await isi(tester, 'PIN Baru', '123');
      await isi(tester, 'Konfirmasi PIN Baru', '123');
      await ketuk(tester, find.text('Simpan PIN Baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('PIN baru minimal 6 karakter.'),
        findsOneWidget,
        reason: 'Validasi panjang PIN tidak tampil',
      );
    });

    smokeTest('konfirmasi tidak cocok ditolak', (WidgetTester tester) async {
      await bukaPin(tester, SessionProvider(authRepository: _RekamAuth()));

      await isi(tester, 'PIN Lama', '111111');
      await isi(tester, 'PIN Baru', '222222');
      await isi(tester, 'Konfirmasi PIN Baru', '333333');
      await ketuk(tester, find.text('Simpan PIN Baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Konfirmasi PIN tidak cocok.'),
        findsOneWidget,
        reason: 'Validasi konfirmasi PIN tidak tampil',
      );
    });

    smokeTest('PIN baru sama dengan PIN lama ditolak', (
      WidgetTester tester,
    ) async {
      await bukaPin(tester, SessionProvider(authRepository: _RekamAuth()));

      await isi(tester, 'PIN Lama', '222222');
      await isi(tester, 'PIN Baru', '222222');
      await isi(tester, 'Konfirmasi PIN Baru', '222222');
      await ketuk(tester, find.text('Simpan PIN Baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('PIN baru harus berbeda dari PIN lama.'),
        findsOneWidget,
        reason: 'Validasi PIN sama tidak tampil',
      );
    });

    smokeTest('tanpa sesi: diminta login ulang', (WidgetTester tester) async {
      await bukaPin(tester, SessionProvider(authRepository: _RekamAuth()));

      await isi(tester, 'PIN Lama', '111111');
      await isi(tester, 'PIN Baru', '222222');
      await isi(tester, 'Konfirmasi PIN Baru', '222222');
      await ketuk(tester, find.text('Simpan PIN Baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Sesi tidak ditemukan. Silakan login ulang.'),
        findsOneWidget,
        reason: 'Tanpa sesi harus memberi petunjuk, bukan crash',
      );
    });
  });

  // ============================================================
  // LAYAR PROFIL SEKOLAH
  // ============================================================

  group('Layar Profil Sekolah', () {
Future<void> bukaProfil(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers(SessionProvider(authRepository: _RekamAuth())),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProfilSekolahScreen(),
          ),
        ),
      );
      await tester.pump();
      await siapAsync(tester);
    }

    smokeTest('nama sekolah kosong ditolak', (WidgetTester tester) async {
      await bukaProfil(tester);

      await isi(tester, 'Nama Sekolah *', '   ');
      await ketuk(tester, find.text('Simpan Profil Sekolah'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Nama sekolah wajib diisi.'),
        findsWidgets,
        reason: 'Nama sekolah kosong harus ditolak',
      );
    });

    smokeTest('format email salah ditolak', (WidgetTester tester) async {
      await bukaProfil(tester);

      await isi(tester, 'Nama Sekolah *', 'SMA Nusantara');
      await isi(tester, 'Email', 'bukan-email');
      await ketuk(tester, find.text('Simpan Profil Sekolah'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

expect(
        find.text('Format email tidak valid.'),
        findsWidgets,
        reason: 'Email tidak valid harus ditolak',
      );
    });

    smokeTest('data valid tersimpan dan tampil sebagai konfirmasi', (
      WidgetTester tester,
    ) async {
      await bukaProfil(tester);

      await isi(tester, 'Nama Sekolah *', 'SMA Nusantara');
      await isi(tester, 'Email', 'info@nusantara.sch.id');
      await ketuk(tester, find.text('Simpan Profil Sekolah'));
      await siapAsync(tester);

      expect(
        find.text('Profil sekolah disimpan.'),
        findsWidgets,
        reason: 'Simpan profil tidak memberi konfirmasi ke pengguna',
      );

      final List<Map<String, Object?>> rows =
          await tester.runAsync(() => DBHelper.instance.query(
                DBHelper.tblSchoolProfile,
                where: 'school_name = ?',
                whereArgs: <Object?>['SMA Nusantara'],
              )) ??
          <Map<String, Object?>>[];
      expect(rows, isNotEmpty, reason: 'Profil tidak tersimpan ke database');
      expect(rows.first['email'], 'info@nusantara.sch.id');
    });
  });
}

// ============================================================================
// AUTH UJI COBA (selalu selesai sinkron, aman di FakeAsync)
// ============================================================================

class _RekamAuth extends AuthRepository {
  bool panggil = false;

  @override
  Future<UserModel?> login({
    required String username,
    required String password,
  }) async {
    panggil = true;
    return null;
  }
}