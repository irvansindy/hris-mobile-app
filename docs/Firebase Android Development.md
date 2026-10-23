# Firebase Android Development

## Lingkup

Firebase pribadi digunakan hanya untuk Android development debug, project
`hrm-app-c9feb`, package sementara `com.example.hrm_app`. Demo tetap menggunakan
dummy push. Konfigurasi production, flavor, APNs, signing, dan release ditunda.

File client telah ditempatkan di `android/app/src/debug/google-services.json`
dan diabaikan Git. File asli di `Documents/hris-firebase-dev` tidak diubah.
Jangan menaruh service-account JSON, private key, atau server key di Flutter,
`.env`, repository, maupun laporan pengujian.

## Implementasi

- `PUSH_MODE=firebase` memilih adapter FCM nyata pada development debug Android.
- Auto-init token dinonaktifkan; token diminta setelah izin disetujui.
- Token tidak diregistrasikan ke API HRIS, baik HTTP maupun HTTPS. Mode ini
  khusus pengujian Firebase Console, bukan integrasi push backend production.
- Pesan foreground memperbarui inbox; tap memakai coordinator/deep-link guard
  yang sudah ada. Payload hanya diteruskan sebagai ID, bukan route arbitrer.
- Panel debug menyediakan aktivasi/retry dan salin token atas tindakan pengguna.
  Token tidak ditampilkan di UI atau log; clipboard hanya untuk Console pribadi.
- Logout menghapus token melalui coordinator. Respons izin lama diabaikan;
  operasi token native diurutkan meskipun pemanggil mengalami timeout.
  Menutup provider/aplikasi sendiri bukan jaminan penghapusan token; gunakan logout.
- Guard Dart dan Gradle menolak Firebase pribadi pada profile/release atau
  environment selain development. Demo tidak mengaktifkan plugin Google Services.

## Menjalankan

Gunakan `.env` lokal yang sudah ada untuk API. Tidak perlu menambahkan key Firebase.

```bash
rtk flutter run --dart-define-from-file=.env --dart-define=APP_ENV=development --dart-define=DEMO_MODE=false --dart-define=PUSH_MODE=firebase --dart-define=ENABLE_LOGGING=false
```

Untuk demo lokal:

```bash
rtk flutter run --dart-define=DEMO_MODE=true
```

## Acceptance manual yang masih diperlukan

1. Login akun employee dengan identitas employee/company valid.
2. Buka Notifikasi; aktifkan izin melalui panel Firebase development.
3. Setelah status siap Console, salin token. Jangan kirim token ke chat/laporan.
4. Di Firebase Console project development, buat test notification dan masukkan
   token perangkat sebagai target. Gunakan judul/body generik tanpa data HR sensitif.
5. Uji foreground: inbox dimuat ulang, tanpa banner OS foreground.
6. Uji background: notification OS diterima; tap tidak membuka data yang tidak
   diizinkan. Sertakan `notificationId` valid untuk uji deep link inbox.
7. Uji terminated: buka dari notifikasi; pastikan restore/login dan guard tujuan
   bekerja. Pesan Console tanpa `notificationId` bukan bukti detail routing valid.
8. Uji izin ditolak, retry, logout, pergantian akun, dan jaringan terputus.
   Salin ulang token setelah login ulang; token lama tidak dianggap tetap valid.
9. Hapus token dari clipboard setelah pengujian dan logout.

## Hasil verifikasi lokal

- Adapter: dua regresi lifecycle terbukti gagal sebelum fix dan lulus sesudah fix.
- Review ulang: tidak ada temuan Critical/Important tersisa dalam lingkup
  development login/logout/pergantian akun.
- Analyzer: lulus, tanpa issue.
- Suite terfokus notifikasi dan konfigurasi: 83 tes lulus.
- Suite penuh final `rtk flutter test --no-pub --coverage`: 637 tes lulus.
- Format: 280 file, tanpa perubahan format yang diperlukan.
- APK development Firebase final: berhasil dibangun di
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Guard native: build profile dengan `PUSH_MODE=firebase` ditolak dengan
  `Personal Firebase configuration is debug-only.` sesuai rancangan.
- Warning kompatibilitas KGP `firebase_core` masih muncul; ini bukan kegagalan
  build, tetapi tetap perlu diselesaikan sebelum upgrade Flutter berikutnya.
- Emulator: tertunda. AVD `Pixel_10a` gagal startup karena ruang disk partisi
  sekitar 890 MB. Tidak ada file pengguna yang dihapus.
- Test SDK tersedia di `integration_test/firebase_development_smoke_test.dart`;
  belum dinyatakan lulus. Pengujian ini hanya memeriksa pembuatan/penghapusan
  token, bukan delivery Console atau registrasi backend.

Setelah emulator tersedia dan izin notifikasi diberikan pada aplikasi yang
terpasang, jalankan test SDK berikut. Tes ini membuat lalu menghapus token
perangkat development; salin ulang token melalui aplikasi untuk tes Console.

```bash
rtk flutter test integration_test/firebase_development_smoke_test.dart -d emulator-5554 --dart-define=APP_ENV=development --dart-define=DEMO_MODE=false --dart-define=PUSH_MODE=firebase --dart-define=ENABLE_LOGGING=false
```

### Pembaruan verifikasi 19 Oktober 2026

Emulator `Pixel_10a` kini berhasil boot (Android 17, Google Play services
tersedia). Smoke SDK di atas lulus 1 tes setelah izin notifikasi diberikan
pada instalasi test: token FCM berhasil diperoleh lalu dihapus. Timeout pada
percobaan sebelumnya terjadi saat menunggu dialog izin Android. Tidak ada
perubahan kode aplikasi, token yang dicetak, atau registrasi token ke HRIS.
Delivery Firebase Console dan integrasi backend tetap belum diuji.

Lihat [laporan verifikasi integrasi](<Verifikasi Integrasi Pasca Migrasi API - 2026-10-19.md>).

Tahap 8 belum selesai: HTTPS, app ID/bundle ID final, flavor, Firebase resmi
per environment, APNs, signing, privacy declarations, dan distribusi internal
Android/iOS tetap menjadi gate release.

Referensi: [Firebase Android setup](https://firebase.google.com/docs/android/setup),
[FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[receive messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
