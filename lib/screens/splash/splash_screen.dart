import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Splash screen animasi aplikasi.
///
/// Urutan animasi (± 2,8 detik):
/// 1. Background navy muncul mulus (dari navy gelap ke navy utama).
/// 2. Logo muncul dengan efek fade-in + scale-up.
/// 3. Nama aplikasi "Kas Bintang Nusantara" fade-in + slide-up.
/// 4. Tahan sejenak di tengah layar.
/// 5. Seluruh tampilan fade-out (putih) → lanjut ke halaman utama.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  /// Dipanggil tepat setelah seluruh animasi selesai.
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _durasi = Duration(milliseconds: 2800);

  /// Warna dasar sebelum background utama muncul.
  static const Color _navyGelap = Color(0xFF06122E);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _durasi)
        ..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed && mounted) {
            widget.onFinished();
          }
        })
        ..forward();

  // 1. Background: 0% – 30%
  late final Animation<double> _bg = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
  );

  // 2. Logo: 15% – 48% (fade-in + scale-up)
  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 0.48, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.82,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.48, curve: Curves.easeOutCubic),
    ),
  );

  // 3. Teks nama aplikasi: 45% – 70% (fade-in + slide-up)
  late final Animation<double> _teksOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 0.70, curve: Curves.easeOutCubic),
  );
  late final Animation<Offset> _teksOffset = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.70, curve: Curves.easeOutCubic),
    ),
  );

  // 4. Tahan: 70% – 82%

  // 5. Fade-out isi: 82% – 100%, disertai voal putih agar mulus
  //    menyatu ke halaman berikutnya.
  late final Animation<double> _isiKeluar = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
  );
  late final Animation<double> _voalPutih = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.84, 1.0, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _logo() {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, Color(0xFFF2F5FB)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.school_rounded,
        size: 52,
        color: AppColors.navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyGelap,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // BACKGROUND (navy gelap → navy utama)
              Container(
                color: Color.lerp(_navyGelap, AppColors.navy, _bg.value),
              ),

              // ISI: logo + nama aplikasi
              Opacity(
                opacity: 1 - _isiKeluar.value,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _logo(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: _teksOpacity.value,
                        child: Transform.translate(
                          offset: _teksOffset.value,
                          child: Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // VOAL PUTIH penutup animasi fade-out
              ColoredBox(
                color: Colors.white.withValues(alpha: _voalPutih.value),
              ),
            ],
          );
        },
      ),
    );
  }
}
