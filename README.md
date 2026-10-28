# Kas Bintang Nusantara

Aplikasi Android untuk membantu bendahara SMK Bintang Nusantara mengelola
administrasi kas siswa. Aplikasi dibuat dengan Flutter dan menyimpan data
operasional secara lokal di perangkat menggunakan SQLite.

> **Penting:** Data tidak disinkronkan ke cloud. Buat backup secara berkala,
> salin backup ke tempat yang aman, dan jangan membagikan file backup atau
> ekspor yang berisi data siswa dan transaksi kepada publik.

## Fitur

- Mengelola data siswa, jurusan, kelas, dan jenis kas.
- Mencatat pembayaran, tunggakan, pengeluaran, serta kategori pengeluaran.
- Melihat ringkasan saldo, riwayat transaksi, laporan, dan log aktivitas.
- Mengekspor atau membagikan data dan dokumen dalam format CSV/PDF.
- Melindungi akses aplikasi dengan PIN pribadi dan pertanyaan pemulihan PIN.
- Membuat, membagikan, dan memulihkan backup database.
- Menggunakan aplikasi secara offline; data operasional disimpan di SQLite pada
  perangkat.

## Informasi aplikasi

| Informasi | Nilai |
| --- | --- |
| Nama aplikasi | Kas Bintang Nusantara |
| Application ID | `com.bintangnusantara.kas` |
| Versi saat ini | `1.0.8` (version code `6`) |
| Minimum Android | Android 7.0 (API 24) |
| Penyimpanan data | SQLite lokal |
| Akun awal | Pengguna membuat PIN sendiri saat pertama kali membuka aplikasi |

## Unduh dan pasang

Unduh APK dari [GitHub Releases](https://github.com/ranggawaridat/kasKelas/releases).
Pilih APK universal untuk kemudahan, atau APK khusus arsitektur untuk ukuran
unduhan yang lebih kecil.

| APK | Cocok untuk |
| --- | --- |
| `app-release.apk` | APK universal, pilihan paling mudah untuk kebanyakan pengguna |
| `app-arm64-v8a-release.apk` | Sebagian besar HP Android modern |
| `app-armeabi-v7a-release.apk` | Perangkat Android 32-bit yang lebih lama |
| `app-x86_64-release.apk` | Emulator atau perangkat Intel yang kompatibel |

Arsitektur APK hanya dapat dipasang pada perangkat yang cocok. Jika tidak yakin,
unduh APK universal jika tersedia.

1. Unduh APK ke perangkat Android.
2. Buka file menggunakan aplikasi Files atau pengelola file.
3. Jika diminta, izinkan instalasi aplikasi dari sumber tersebut, lalu lanjutkan
   instalasi.
4. Buka aplikasi dan buat PIN berisi 6–8 digit. Tidak ada PIN bawaan.
5. Siapkan pertanyaan pemulihan agar fitur **Lupa PIN** dapat digunakan.
6. Buat backup pertama setelah data sekolah dan kelas siap diisi.

PIN diminta setiap kali aplikasi dibuka dan dapat diganti melalui
**Pengaturan → Ubah PIN**.

### Jika APK tidak dapat dipasang

- **Aplikasi tidak terpasang atau tanda tangan berbeda:** APK mungkin
  ditandatangani dengan kunci yang berbeda dari versi sebelumnya. Jangan
  langsung menghapus aplikasi: penghapusan akan menghilangkan data lokal.
  Buat backup di versi lama dan pastikan file backup tersimpan di luar
  perangkat sebelum melakukan tindakan yang berisiko menghapus data.
- **Versi Android tidak didukung:** perangkat harus menjalankan Android 7.0
  (API 24) atau lebih baru.
- **Instalasi diblokir:** aktifkan izin instalasi untuk aplikasi yang digunakan
  membuka APK, kemudian coba lagi.
- **APK arsitektur tidak cocok:** unduh APK universal atau pilih varian yang
  sesuai dengan perangkat.

## Backup dan keamanan data

- Data kas dan siswa disimpan di perangkat, bukan di server aplikasi.
- Backup tidak dibuat otomatis oleh Android. Gunakan menu **Pengaturan →
  Backup & Restore** secara berkala.
- Simpan salinan backup di lokasi aman yang terpisah dari perangkat. Sebelum
  mengganti atau menghapus aplikasi, pastikan file backup dapat ditemukan.
- File backup, CSV, dan PDF dapat berisi informasi sensitif. Perlakukan file
  tersebut seperti dokumen sekolah yang bersifat rahasia.
- Pemulihan backup mengganti data aplikasi dengan isi backup yang dipilih.
  Periksa file dan tanggal backup sebelum memulihkan.

## Menjalankan dari source

### Persyaratan

- Flutter SDK yang menyediakan Dart sesuai batas versi di `pubspec.yaml`.
- Android SDK dan perangkat Android atau emulator untuk pengujian.
- Git.

### Setup dan pemeriksaan

Jalankan perintah berikut dari folder repository:

```powershell
flutter pub get
flutter analyze
flutter test
```

Jalankan aplikasi pada perangkat atau emulator yang terhubung:

```powershell
flutter run
```

## Build APK

APK universal berisi pustaka untuk arsitektur Android yang dikonfigurasi proyek.
Ini pilihan termudah untuk distribusi umum, tetapi ukuran unduhannya lebih
besar:

```powershell
flutter build apk --release
```

File hasil build:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Untuk menghasilkan APK terpisah berdasarkan arsitektur:

```powershell
flutter build apk --release --split-per-abi
```

File hasil build berada di `build/app/outputs/flutter-apk/`, umumnya dengan
nama `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, dan
`app-x86_64-release.apk`. Pengguna harus mengunduh varian yang sesuai.

## Panduan rilis GitHub

### 1. Siapkan versi

Sebelum setiap rilis:

1. Tentukan versi baru dengan pola `MAJOR.MINOR.PATCH`, misalnya `1.0.9`.
2. Naikkan nomor versi di `pubspec.yaml` dengan menambah `versionCode`, misalnya
   `1.0.9+7`. `versionCode` harus selalu lebih besar daripada rilis sebelumnya.
3. Perbarui versi yang ditampilkan di README dan catat perubahan yang terlihat
   oleh pengguna.
4. Jalankan `flutter pub get`, `flutter analyze`, dan `flutter test`.
5. Uji APK pada perangkat Android, termasuk alur login/PIN, transaksi, backup,
   dan pemulihan backup.

### 2. Buat dan simpan kunci rilis

Untuk pembaruan yang dapat dipasang di atas versi sebelumnya, semua rilis harus
menggunakan kunci penandatanganan yang sama. Kehilangan kunci atau membuat
kunci baru dapat mencegah pengguna memperbarui aplikasi tanpa menghapus versi
lama; penghapusan aplikasi berisiko menghilangkan data lokal.

Jika belum punya keystore, buat satu kali dari PowerShell. Simpan di lokasi
pribadi di luar repository dan buat cadangan aman:

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\kas-bintang-release.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias kas-bintang-release
```

Buat file `android/key.properties` secara lokal dengan isi berikut. Ganti
placeholder dengan nilai sebenarnya; `storeFile` harus menunjuk ke lokasi
keystore yang dibuat. Gunakan `/` pada path di file properties untuk menghindari
masalah escape karakter Windows.

```properties
storePassword=GANTI_DENGAN_PASSWORD_KEYSTORE
keyPassword=GANTI_DENGAN_PASSWORD_ALIAS
keyAlias=upload
storeFile=C:/Users/NAMA_USER/upload-keystore.jks
```

Jangan pernah memasukkan `key.properties`, password, atau file `.jks`/`.keystore`
ke GitHub. Simpan password dan cadangan keystore di tempat aman. Tanpa
`android/key.properties`, konfigurasi proyek menggunakan debug key untuk build
release; hasilnya hanya untuk pengujian dan **tidak boleh dibagikan sebagai
rilis resmi**.

### 3. Build dan periksa APK

Pastikan versi yang akan dirilis sudah tercantum di `pubspec.yaml`, lalu pilih
salah satu cara build di bagian [Build APK](#build-apk). Pasang APK hasil build
dan uji pada perangkat sebelum mengunggahnya.

Untuk mencatat checksum SHA-256 APK di PowerShell:

```powershell
Get-FileHash .\build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

Untuk APK terpisah, jalankan perintah yang sama pada setiap file yang akan
diunggah. Cantumkan checksum pada catatan rilis agar pengguna dapat memeriksa
file yang diunduh.

### 4. Terbitkan di GitHub Releases

1. Pastikan perubahan rilis sudah masuk ke branch utama repository.
2. Buat tag versi, misalnya `v1.0.9`, pada commit yang akan dirilis:

   ```powershell
   git tag -a v1.0.9 -m "Kas Bintang Nusantara 1.0.9"
   git push origin v1.0.9
   ```

3. Buka tab **Releases** repository, pilih **Draft a new release**, lalu pilih
   tag tersebut.
4. Tulis ringkasan perubahan, perbaikan, dan catatan penting untuk pengguna.
5. Unggah APK yang sudah diuji. Untuk distribusi mudah, unggah APK universal;
   untuk unduhan yang lebih kecil, unggah APK per arsitektur dan jelaskan
   perbedaannya.
6. Tambahkan checksum SHA-256 dan publikasikan rilis.
7. Pastikan tautan unduhan dan instruksi instalasi bekerja dari perangkat
   Android.

Gunakan GitHub Releases sebagai tempat resmi untuk file APK. Hindari mengunggah
APK ke commit repository atau menyimpan file build di Git LFS tanpa kebutuhan
khusus.

## Strategi distribusi dan landing page

Untuk distribusi yang hanya menggunakan GitHub, pisahkan peran kedua fiturnya:

- **GitHub Releases**: tempat unduhan APK dan catatan tiap versi. Tautan rilis
  terbaru: <https://github.com/ranggawaridat/kasKelas/releases/latest>.
- **GitHub Pages**: landing page statis tersedia di folder [`docs/`](./docs/).
  Aktifkan melalui **Settings → Pages**, pilih **Deploy from a branch**, branch
  utama, dan folder **/docs**. Setelah diterbitkan, alamatnya biasanya
  `https://ranggawaridat.github.io/kasKelas/`. Tombol unduh pada halaman
  mengarah ke GitHub Releases; unggah APK di sana, bukan ke folder website.

Untuk memperbarui landing page, edit file di `docs/` dan push perubahan ke
branch utama. GitHub Pages akan menerbitkan versi terbarunya. Jangan jadikan
landing page sebagai tempat penyimpanan APK: GitHub Releases lebih sesuai untuk
file unduhan, checksum, dan catatan perubahan.

## Bantuan dan pelaporan masalah

Untuk pertanyaan atau laporan kendala, kirim email ke
[ranggawaridat@gmail.com](mailto:ranggawaridat@gmail.com) atau buat issue di
[GitHub Issues](https://github.com/ranggawaridat/kasKelas/issues). Sertakan
versi aplikasi, versi Android, jenis perangkat, langkah untuk mengulang kendala,
dan hasil yang diharapkan. Jangan sertakan PIN, password, database, backup,
atau data pribadi siswa pada issue publik.
