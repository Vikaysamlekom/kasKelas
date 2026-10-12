# Kas Bintang Nusantara

Aplikasi pengelolaan kas siswa untuk bendahara SMK Bintang Nusantara.
Berjalan **100% offline** — tidak ada permission `INTERNET` sama sekali di APK rilis.
Seluruh data (siswa, kelas, kas, transaksi, laporan) tersimpan di SQLite lokal di HP.

| Item | Nilai |
| --- | --- |
| Package | `com.bintangnusantara.kas` |
| Versi | 1.0.4 (versionCode 5) |
| minSdk / targetSdk | 24 (Android 7.0) / 36 (Android 16) |
| Login bawaan | Tidak ada — pengguna membuat PIN sendiri saat pertama dibuka |

## 1. Memasang APK di HP

Folder `dist/kas-bintang-nusantara-1.0.4/` berisi 4 file:

| File | Untuk | Ukuran |
| --- | --- | --- |
| `...-arm64-v8a.apk` | **HP modern (2017 ke atas)** — pilih ini | 23,6 MB |
| `...-armeabi-v7a.apk` | HP lama 32-bit | 21,5 MB |
| `...-x86_64.apk` | Emulator / tablet Intel | 25,0 MB |
| `...-universal.apk` | Semua tipe HP, satu file | 60,9 MB |

Kalau tidak yakin, pakai `universal`. Ukurannya besar tapi akan jalan di HP apa pun.

Langkah instalasi:

1. Salin file APK ke HP (kabel USB, Google Drive, atau WhatsApp).
2. Buka file APK dari Manajer File.
3. Android akan meminta izin **"Pasang aplikasi tidak dikenal"** — aktifkan untuk
   aplikasi Files/Chrome yang dipakai membuka APK, lalu tekan **Pasang**.
4. Saat pertama dibuka, **buat PIN sendiri** (6–8 digit) — tidak ada PIN
   bawaan. PIN ini wajib dimasukkan setiap kali aplikasi dibuka dan bisa
   diubah sewaktu-waktu di **Pengaturan → Ubah PIN**.

> APK sudah ditandatangani dan tidak bisadiedit. Android mungkin menampilkan
> peringatan soal "sumber tidak dikenal" — itu normal untuk APK yang di luar Play Store.

### Kalau HP menolak instalasi

出现 "App not installed" biasanya karena:
- **Signed with a different certificate** → APK lama versi masih terpasang. Uninstall
  dulu lewat **Pengaturan → Aplikasi → Kas Bintang Nusantara → Uninstall**, lalu pasang ulang.
  ⚠️ **Uninstall menghapus semua data kas.** Ambil backup dulu lewat
  **Pengaturan → Backup & Restore**.
- **Android di bawah 7.0** → tidak didukung (butuh Android 7.0 ke atas).
- **Lupa mengaktifkan izin sumber tidak dikenal** seperti di langkah 3.

## 2. Cadangkan data (penting)

Data kas tersimpan di dalam aplikasi. **Menghapus aplikasi = menghapus data.**
Backup ada di **Pengaturan → Backup & Restore**:

- Backup database `.db` ke folder internal aplikasi.
- Pilih frekuensi otomatis: harian / mingguan.
- Restore hanya menerima file yang header-nya `SQLite format 3`, jadi file
  kerusakan ditolak dengan pesan jelas.

Cadangkan juga ke luar HP: di layar Backup & Restore, tombol Bagikan/Restore
mengirim file `.db` lewat WhatsApp atau simpan ke Drive.

## 3. Struktur project

```
lib/
  core/            tema, konstanta, penanganan error
  database/        db_helper.dart — skema 11 tabel, index, seeding, migrasi
  models/          model data (fromMap / toMap)
  repositories/    semua query SQL ada di sini
  providers/       ChangeNotifier untuk state UI
  screens/         halaman per fitur
  services/        backup, CSV, ekspor PDF/CSV
  widgets/         komponen UI reusable
test/
  db_offline_test.dart   22 uji integrasi SQLite (jalur offline utama)
  backup_service_test.dart, widget_test.dart
```

Semua akses database terpusat di `DBHelper` sehingga setiap query dibungkus
`AppException` dengan pesan berbahasa Indonesia.

## 4. Pengembangan

```bash
flutter pub get
flutter analyze          # harus "No issues found"
flutter test             # 30 test
flutter run              # uji di perangkat
```

### Build APK rilis

Butuh Android SDK. Arahkan lewat `android/local.properties`:

```properties
sdk.dir=E:/SDK
flutter.sdk=C:\flutter
```

Lalu:

```bash
# Satu APK per arsitektur ( Recommended untuk dikirim via WhatsApp)
flutter build apk --release --split-per-abi

# Satu APK untuk semua HP
flutter build apk --release
```

Hasil ada di `build/app/outputs/flutter-apk/`.

### Signing rilis

Buat keystore sekali seumur hidup aplikasi:

```bash
keytool -genkey -v -keystore android/bintang-nusantara-release.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10950 \
  -alias bintangnusantara
```

Isi `android/key.properties` (sudah di-gitignore, **jangan** di-commit):

```properties
storeFile=bintang-nusantara-release.jks
storePassword=<password>
keyAlias=bintangnusantara
keyPassword=<password>
```

> **Backup `bintang-nusantara-release.jks` sekarang.** Kalau file ini hilang, Anda
> tidak bisa menerbitkan versi 2.0 — Android menolak APK bertanda tangan berbeda
> dari versi yang sudah terpasang.

Tanpa `key.properties`, build tetap jalan memakai debug key (cukup untuk uji,
tidak boleh dipakai rilis) dan Gradle akan mencetak peringatan.

### Naikkan versi

Ubah `version:` di `pubspec.yaml` (contoh `1.0.4+5`). Naikkan `+1` setiap
rilis supaya Android mengenali pembaruan. `AppConstants.appVersion` di
`lib/core/constants.dart` ikut disamakan karena tampil di dalam aplikasi.

### Uji integrasi

`test/db_offline_test.dart` menjalankan database SQLite sungguhan di PC lewat
FFI, jadi alur kas (login, bayar, batalkan, laporan, saldo) bisa diverifikasi
tanpa perangkat. Jalankan dengan `flutter test`.

## 5. Catatan rilis

### 1.0.4 (versionCode 5)

- **Tidak ada PIN bawaan.** Saat pertama dibuka, pengguna diminta membuat PIN
  sendiri (6–8 digit). Setelah itu PIN tersebut wajib dimasukkan setiap kali
  aplikasi dibuka. Verifikasi PIN kini membandingkan hash tersimpan, bukan
  kode PIN tetap.
- Diperbaiki: pesan "PIN salah" tidak lagi menempel setelah pengguna mengetik
  ulang — indikator titik tidak tetap merah.
- Diperbaiki: data kas & siswa tidak ikut backup otomatis sistem Android
  (`allowBackup=false`). Sebelumnya, uninstall lalu pasang ulang bisa membuat
  data lama ter-restore sendiri dari cloud. Cadangan tetap tersedia lewat
  **Pengaturan → Backup & Restore**.
- Diperbaiki: tunggakan tidak lagi terisi otomatis dari nominal jenis kas
  bawaan (Rp 25.000 + Rp 10.000 = Rp 35.000). Semua nominal awal Rp 0.
- Kalimat versi di Pengaturan mengikuti versi APK.
- 143 tes lulus, `flutter analyze` bersih.

### 1.0.0

- Diperbaiki: saldo di Dashboard menghitung pengeluaran yang sudah dibatalkan.
  Sebelumnya pantalla Dashboard dan Laporan bisa menampilkan saldo berbeda.
- Diperbaiki: `PaymentRepository.sumPeriod` ikut memperhitungkan transaksi batal.
- Diperkuat: pengambilan foto nota dan logo sekolah kini menampilkan pesan
  bila kamera/galeri tidak tersedia, tidak lagi error diam-diam.
- `ndk.abiFilters` dilewati otomatis saat `--split-per-abi`, supaya tiap APK
  hanya memuat satu arsitektur (mencegah crash `UnsatisfiedLinkError` di HP ARM64).
- APK ditandatangani dengan v1 + v2 + v3.
