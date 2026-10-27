import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Splash screen Kas Bintang Nusantara.
///
/// Total durasi: ± 1,2 detik.
///
/// Urutan animasi:
/// 1. Background navy muncul (0–240 ms).
/// 2. Logo fade-in + scale-up (60–420 ms).
/// 3. Nama aplikasi fade-in + slide-up (300–660 ms).
/// 4. Tampilan bertahan sebentar (660–900 ms).
/// 5. Fade-out + transisi putih (900–1200 ms).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  /// Dipanggil setelah animasi selesai.
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Durasi splash dipercepat dari 2800 ms menjadi 1200 ms.
  static const Duration _durasi = Duration(milliseconds: 1200);

  // Warna background awal.
  static const Color _navyGelap = Color(0xFF06122E);

  // Controller animasi utama.
  late final AnimationController _controller = AnimationController(vsync: this, duration: _durasi)
    ..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onFinished();
      }
    })
    ..forward();

  // ============================================================
  // 1. BACKGROUND ANIMATION
  // 0% – 20% (0–240 ms)
  // ============================================================

  late final Animation<double> _bg = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
  );

  // ============================================================
  // 2. LOGO ANIMATION
  // 5% – 35% (60–420 ms)
  // ============================================================

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.35, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.35, curve: Curves.easeOutCubic),
    ),
  );

  // ============================================================
  // 3. TEXT ANIMATION
  // 25% – 55% (300–660 ms)
  // ============================================================

  late final Animation<double> _teksOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
  );

  late final Animation<Offset> _teksOffset =
      Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
        ),
      );

  // ============================================================
  // 4. HOLD ANIMATION
  // 55% – 75% (660–900 ms)
  // ============================================================

  // Tidak membutuhkan animasi tambahan.
  // Logo dan teks tetap terlihat.

  // ============================================================
  // 5. FADE OUT ANIMATION
  // 75% – 100% (900–1200 ms)
  // ============================================================

  late final Animation<double> _isiKeluar = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
  );

  // ============================================================
  // 6. WHITE TRANSITION
  // 78% – 100% (936–1200 ms)
  // ============================================================

  late final Animation<double> _voalPutih = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.78, 1.0, curve: Curves.easeInOut),
  );

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGO WIDGET
  // ============================================================

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
      child: Image.asset('ic_launcher.png', width: 84, height: 84, fit: BoxFit.contain),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

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
              // =================================================
              // BACKGROUND
              // =================================================

              Container(color: Color.lerp(_navyGelap, AppColors.navy, _bg.value)),

              // =================================================
              // LOGO + APP NAME
              // =================================================
              Opacity(
                opacity: 1 - _isiKeluar.value,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // LOGO
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(scale: _logoScale.value, child: _logo()),
                      ),

                      const SizedBox(height: 24),

                      // APP NAME
                      Opacity(
                        opacity: _teksOpacity.value,
                        child: Transform.translate(
                          offset: _teksOffset.value,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // WHITE FADE TRANSITION
              // =================================================
              ColoredBox(color: Colors.white.withValues(alpha: _voalPutih.value)),
            ],
          );
        },
      ),
    );
  }
}
