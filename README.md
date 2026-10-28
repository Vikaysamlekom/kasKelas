<div align="center">

# Kas Bintang Nusantara

**Kelola kas kelas dengan lebih rapi, praktis, dan transparan.**

Aplikasi pengelolaan kas siswa berbasis Flutter yang bekerja secara **offline** — dirancang untuk membantu bendahara mencatat setiap pemasukan dan pengeluaran dengan mudah.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![Android](https://img.shields.io/badge/Android-7.0%2B-3DDC84?style=for-the-badge&logo=android&logoColor=white)

[![Latest Release](https://img.shields.io/github/v/release/ranggawaridat/kasKelas?style=flat-square&label=Latest%20Release)](https://github.com/ranggawaridat/kasKelas/releases)
[![GitHub Stars](https://img.shields.io/github/stars/ranggawaridat/kasKelas?style=flat-square)](https://github.com/ranggawaridat/kasKelas/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/ranggawaridat/kasKelas?style=flat-square)](https://github.com/ranggawaridat/kasKelas/issues)

**[⬇️ Unduh APK](https://github.com/ranggawaridat/kasKelas/releases/latest)** · **[🐛 Laporkan Masalah](https://github.com/ranggawaridat/kasKelas/issues)** · **[💻 Lihat Source Code](https://github.com/ranggawaridat/kasKelas)**

</div>

---

## ✨ Tentang Aplikasi

**kasKelas (Kas Bintang Nusantara)** adalah aplikasi Android untuk membantu bendahara **SMK Bintang Nusantara** mengelola administrasi kas siswa. Mulai dari pembayaran dan tunggakan hingga pengeluaran dan laporan, semuanya bisa dicatat dalam satu aplikasi.

> 💡 **Offline-first:** Data operasional tersimpan secara lokal menggunakan SQLite. Aplikasi tidak memerlukan sinkronisasi cloud untuk digunakan.

## 🚀 Fitur Unggulan

| Fitur | Deskripsi |
| :--- | :--- |
| 👩‍🎓 **Manajemen Siswa & Kelas** | Kelola data siswa, jurusan, kelas, dan jenis kas. |
| 💰 **Pencatatan Pembayaran** | Catat pembayaran kas dan pantau tunggakan siswa. |
| 🧾 **Pengeluaran** | Kelola pengeluaran beserta kategorinya. |
| 📊 **Ringkasan & Laporan** | Pantau saldo, riwayat transaksi, laporan, dan log aktivitas. |
| 📤 **Ekspor Dokumen** | Ekspor atau bagikan data dalam format CSV dan PDF. |
| 🔐 **Keamanan PIN** | Lindungi akses dengan PIN pribadi dan pertanyaan pemulihan. |
| 💾 **Backup & Restore** | Buat, bagikan, dan pulihkan cadangan database. |
| 📵 **Akses Offline** | Data tersimpan di perangkat, tanpa ketergantungan pada cloud. |

## 🛠️ Teknologi

- **Flutter & Dart** — pengembangan aplikasi.
- **SQLite** — penyimpanan data lokal.
- **Android** — platform distribusi utama (minimal Android 7.0 / API 24).

## 📥 Instalasi Android

1. Buka halaman **[GitHub Releases](https://github.com/ranggawaridat/kasKelas/releases/latest)**.
2. Unduh file APK yang sesuai dengan perangkat. Jika tersedia, pilih **`app-release.apk`** untuk versi universal.
3. Buka APK di perangkat Android dan izinkan instalasi dari sumber tersebut jika diminta.
4. Jalankan aplikasi, lalu buat **PIN 6–8 digit**.
5. Atur pertanyaan pemulihan PIN dan buat backup awal setelah data selesai disiapkan.

> ⚠️ **Penting:** Jangan langsung menghapus aplikasi saat mengalami masalah pembaruan. Data tersimpan secara lokal dan dapat hilang jika aplikasi dihapus tanpa backup.

## 👨‍💻 Menjalankan dari Source Code

**Prasyarat:** Flutter SDK (dengan versi Dart yang sesuai `pubspec.yaml`), Android SDK, Git, serta emulator atau perangkat Android.

```bash
# Clone repository
git clone https://github.com/ranggawaridat/kasKelas.git

# Masuk ke direktori proyek
cd kasKelas

# Instal dependensi
flutter pub get

# Periksa kode dan jalankan pengujian
flutter analyze
flutter test

# Jalankan aplikasi
flutter run
```

### 📦 Build APK

```bash
# APK universal
flutter build apk --release

# APK terpisah berdasarkan arsitektur
flutter build apk --release --split-per-abi
```

Hasil build tersedia di `build/app/outputs/flutter-apk/`.

> **Catatan rilis:** Pastikan APK distribusi resmi ditandatangani menggunakan keystore rilis yang konsisten. Jangan unggah keystore, password, atau `key.properties` ke repository.

## 🔒 Privasi & Keamanan Data

Data siswa dan transaksi disimpan **di perangkat pengguna**, bukan di server aplikasi. Untuk menjaga data tetap aman:

- Buat backup secara berkala melalui **Pengaturan → Backup & Restore**.
- Simpan salinan backup di tempat aman dan terpisah dari perangkat.
- Jangan membagikan database, backup, CSV, atau PDF yang memuat data siswa secara publik.
- Periksa file backup sebelum melakukan restore, karena proses pemulihan akan mengganti data aplikasi saat ini.

## 🗂️ Struktur Proyek

```text
kasKelas/
├── android/         # Konfigurasi aplikasi Android
├── assets/          # Aset aplikasi
├── lib/             # Source code Flutter
├── test/            # Pengujian
├── web/             # Konfigurasi target web Flutter
├── pubspec.yaml     # Dependensi & metadata proyek
└── README.md        # Dokumentasi
```

## 🤝 Kontribusi & Masukan

Menemukan bug atau punya ide pengembangan? Silakan buat **[Issue](https://github.com/ranggawaridat/kasKelas/issues)** atau ajukan **[Pull Request](https://github.com/ranggawaridat/kasKelas/pulls)**.

Saat melaporkan masalah, sertakan versi aplikasi, versi Android, perangkat, serta langkah untuk mereproduksi masalah. **Jangan sertakan PIN atau data pribadi siswa.**
