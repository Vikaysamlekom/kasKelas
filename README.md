# Kas Bintang Nusantara

Aplikasi Android untuk membantu bendahara SMK Bintang Nusantara mengelola
administrasi kas siswa. Aplikasi dibuat dengan Flutter dan menyimpan data
secara lokal di perangkat menggunakan SQLite.

> **Penting:** Data tidak disinkronkan ke cloud. Buat dan salin backup secara
> berkala agar data tetap aman jika perangkat hilang atau aplikasi dihapus.

## Fitur

- Mengelola data siswa, jurusan, kelas, dan jenis kas.
- Mencatat pembayaran, tunggakan, serta pengeluaran dan kategorinya.
- Melihat ringkasan saldo, riwayat transaksi, laporan, dan log aktivitas.
- Mengekspor atau membagikan data dan dokumen dalam format CSV/PDF.
- Melindungi akses aplikasi dengan PIN pribadi.
- Membuat, membagikan, dan memulihkan backup database.
- Menggunakan aplikasi secara offline; data operasional disimpan di SQLite
  pada perangkat.

## Informasi aplikasi

| Informasi | Nilai |
| --- | --- |
| Nama aplikasi | Kas Bintang Nusantara |
| Application ID | `com.bintangnusantara.kas` |
| Versi paket Android | `1.0.5` (`versionCode` `5`) |
| Minimum Android | Android 7.0 (API 24) |
| Penyimpanan data | SQLite lokal |
| Akun awal | Pengguna membuat PIN sendiri saat pertama kali membuka aplikasi |

## Instalasi di Android

APK rilis tidak disimpan di repository. Unduh APK dari halaman rilis atau
salinan distribusi yang disediakan, lalu pilih sesuai perangkat:

| APK | Perangkat |
| --- | --- |
| `arm64-v8a` | Sebagian besar HP Android modern |
| `armeabi-v7a` | Perangkat Android 32-bit yang lebih lama |
| `x86_64` | Emulator atau perangkat Intel yang kompatibel |
| `universal` | Berbagai arsitektur dalam satu file; ukuran file lebih besar |

Jika tidak yakin arsitektur perangkat, gunakan APK `universal` bila tersedia.

1. Salin atau unduh APK ke perangkat Android.
2. Buka APK menggunakan aplikasi Files atau pengelola file.
3. Jika diminta, izinkan instalasi aplikasi dari sumber tersebut, lalu lanjutkan
   instalasi.
4. Buka aplikasi dan buat PIN berisi 6–8 digit. Tidak ada PIN bawaan.
5. Siapkan pertanyaan pemulihan agar fitur **Lupa PIN** dapat digunakan.

PIN diminta setiap kali aplikasi dibuka dan dapat diganti melalui
**Pengaturan → Ubah PIN**.

### Jika APK tidak dapat dipasang

- **Aplikasi tidak terpasang atau tanda tangan berbeda:** versi sebelumnya
  mungkin ditandatangani dengan kunci yang berbeda. Menghapus aplikasi lama
  dapat diperlukan sebelum memasang APK baru. **Penghapusan aplikasi juga
  menghapus data lokal**; buat dan salin backup terlebih dahulu.
- **Versi Android tidak didukung:** perangkat harus menjalankan Android 7.0
  atau lebih baru.
- **Instalasi diblokir:** aktifkan izin instalasi untuk aplikasi yang digunakan
  membuka APK, kemudian coba lagi.
