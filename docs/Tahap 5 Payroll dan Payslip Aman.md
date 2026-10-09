# Tahap 5 Payroll dan Payslip Aman

Tanggal verifikasi: 9 Oktober 2026
Status mobile lokal: **PASS**
Status exit gate live: **TERTUNDA**

## Hasil Implementasi

Alur employee payroll sudah tersedia melalui shared presentation dan repository yang dapat ditukar untuk demo atau production. Implementasi production memakai enam kontrak berikut:

- `GET /payroll/payslips`
- `GET /payroll/payslips/pin/status`
- `PUT /payroll/payslips/pin`
- `POST /payroll/payslips/my/unlock`
- `GET /payroll/payslips/my/{id}`
- `GET /payroll/payslips/my/{id}/pdf`

Daftar hanya menampilkan metadata periode. PIN tidak disimpan. Unlock token, detail nominal, dan byte PDF hanya hidup di memori serta dibersihkan saat expiry, lock manual, logout, pergantian identitas/company, atau aplikasi meninggalkan state aktif. Header employee `X-Payslip-Unlock` hanya dikirim untuk detail dan PDF; jalur admin tidak digunakan.

PDF divalidasi berdasarkan content type, signature, isi, dan batas 5 MB sebelum dirender dari `Uint8List`. Tidak tersedia ekspor atau cache file permanen milik aplikasi. Android memakai `FLAG_SECURE`. iOS memakai privacy cover ketika aplikasi inactive atau screen capture terdeteksi; iOS tidak dapat menjamin pemblokiran screenshot pengguna pada seluruh versi OS.

## Bukti Otomatis

- `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`: PASS, 260 file, 0 perubahan.
- `rtk flutter analyze`: PASS, 0 issue.
- `rtk flutter test`: PASS, 545 test.
- Safety, golden, dan resilience payroll: PASS, 48 test.
- Golden payroll: 12 gambar light/dark pada 320dp dan text scale 200%, sudah diinspeksi.
- `rtk flutter build apk --debug`: PASS, artifact `build/app/outputs/flutter-apk/app-debug.apk`.

## Cakupan yang Diverifikasi

- Setup PIN enam digit, unlock, lockout, expiry, dan explicit lock.
- Permission `payroll:read`, loading, empty, error, retry, dan route sensitif tanpa bottom navigation.
- Isolasi user, employee, company, logout, serta late response.
- Decimal string/number, komponen payroll asing, dan daftar tanpa nominal.
- PDF kosong, signature salah, content type salah, serta ukuran berlebih.
- Layout light/dark pada Android/iOS fixture, 320/430dp, dan text scale sampai 200%.

## Blocker Exit Gate Live

- HTTPS staging dan akun employee dengan `payroll:read` belum tersedia.
- Diperlukan fixture payslip approved/disbursed, set PIN, lockout, detail, dan PDF valid.
- Android/iOS real-device acceptance belum dijalankan untuk background/resume, recent-app preview, screenshot/capture behavior, account switch, dan jaringan buruk.
- Build iOS native serta CocoaPods harus divalidasi di macOS/CI.
- Flutter masih menampilkan warning migrasi Built-in Kotlin dari plugin `firebase_core`; build saat ini tetap berhasil.

Tahap berikutnya boleh dimulai, tetapi blocker di atas tetap menjadi syarat sebelum release candidate atau go-live.
