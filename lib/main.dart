import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'database/db_helper.dart';
import 'providers/cash_types_provider.dart';
import 'providers/classes_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/session_provider.dart';
import 'providers/students_provider.dart';
import 'providers/transaction_provider.dart';
import 'repositories/audit_repo.dart';
import 'repositories/auth_repository.dart';
import 'repositories/cash_type_repo.dart';
import 'repositories/dashboard_repository.dart';
import 'repositories/kelas_repo.dart';
import 'repositories/pembayaran_repo.dart';
import 'repositories/pengeluaran_repo.dart';
import 'repositories/siswa_repo.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/login/create_pin_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/payments/payments_screen.dart';
import 'screens/settings/pengaturan_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/students/students_screen.dart';
import 'services/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error handling global: setiap error build UI maupun error async
  // yang tidak tertangani dicatat ke log agar mudah ditelusuri.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER] ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[UNHANDLED] $error\n$stack');
    return true;
  };

  // Inisialisasi database di awal agar login berjalan cepat.
  try {
    await DBHelper.instance.database;
  } catch (e, stack) {
    debugPrint('Gagal inisialisasi database: $e\n$stack');
  }

  // Backup otomatis (harian/mingguan) bila sudah Due.
  unawaited(BackupService.instance.runScheduledBackupIfDue());

  runApp(const KasBintangNusantaraApp());
}

class KasBintangNusantaraApp extends StatelessWidget {
  const KasBintangNusantaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(
            authRepository: AuthRepository(),
          )..restoreSession(),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(
            repository: DashboardRepository(),
          ),
        ),
        ChangeNotifierProvider<StudentsProvider>(
          create: (_) => StudentsProvider(
            studentRepository: StudentRepository(),
            classRepository: ClassRepository(),
          ),
        ),
        ChangeNotifierProvider<ClassesProvider>(
          create: (_) => ClassesProvider(
            classRepository: ClassRepository(),
          ),
        ),
        ChangeNotifierProvider<CashTypesProvider>(
          create: (_) => CashTypesProvider(
            cashTypeRepository: CashTypeRepository(),
          ),
        ),
        ChangeNotifierProvider<PaymentProvider>(
          create: (_) => PaymentProvider(
            paymentRepository: PaymentRepository(),
            classRepository: ClassRepository(),
            studentRepository: StudentRepository(),
            cashTypeRepository: CashTypeRepository(),
          ),
        ),
        ChangeNotifierProvider<TransactionProvider>(
          create: (_) => TransactionProvider(
            expenseRepository: ExpenseRepository(),
            paymentRepository: PaymentRepository(),
            cashTypeRepository: CashTypeRepository(),
            auditLogRepository: AuditLogRepository(),
          ),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('id', 'ID'),
        supportedLocales: const <Locale>[
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RootGate(),
      ),
    );
  }
}

/// Gatepintu utama: tampilkan splash animasi, lalu layar Buat PIN bila PIN
/// belum pernah dibuat, LoginScreen bila sudah, MainScreen jika sudah masuk.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _splashSelesai = false;

  @override
  Widget build(BuildContext context) {
    final SessionProvider session = context.watch<SessionProvider>();

    // Splash animasi berjalan dulu (restore sesi berjalan paralel di belakang).
    if (!_splashSelesai) {
      return SplashScreen(
        onFinished: () => setState(() => _splashSelesai = true),
      );
    }

    if (!session.hasTriedRestore) {
      // Masih memulihkan sesi → layar splash sederhana.
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.school_rounded, size: 56, color: AppColors.navy),
              SizedBox(height: 12),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (!session.isLoggedIn) {
      // Belum pernah membuat PIN → wajib membuat PIN sendiri lebih dulu.
      if (!session.isPinSet) return const CreatePinScreen();
      return const LoginScreen();
    }

    return const MainScreen(
      pages: <Widget>[
        DashboardScreen(),
        StudentsScreen(),
        PaymentsScreen(),
        PengaturanScreen(),
      ],
    );
  }
}