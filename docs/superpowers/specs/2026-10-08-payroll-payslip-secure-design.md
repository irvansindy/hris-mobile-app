# Payroll dan Payslip Aman

Tanggal: 8 Oktober 2026  
Status: Implementasi lokal selesai; acceptance live tertunda
Scope: aplikasi Flutter employee self-service

## Tujuan

Menyediakan daftar, pengaturan PIN, unlock, detail, dan PDF slip gaji melalui jalur self-service backend tanpa membocorkan PIN, unlock token, atau nominal. Implementasi hanya memakai kontrak employee dengan header `X-Payslip-Unlock`; jalur admin `X-Payroll-Unlock-Token` berada di luar scope.

## Arsitektur

Feature baru berada di `lib/features/payroll/` dan mengikuti pemisahan `domain`, `data`, serta `presentation`. Screen dan controller dipakai bersama oleh demo dan production. Perbedaannya hanya pada implementasi repository yang dipasang melalui provider.

Domain menyediakan model ringkasan terkunci, status PIN, sesi unlock, detail komponen, dan dokumen PDF. Repository mengekspos operasi berikut:

- mengambil maksimal 20 ringkasan dari `GET /payroll/payslips`;
- membaca status PIN dari `GET /payroll/payslips/pin/status`;
- mengatur PIN melalui `PUT /payroll/payslips/pin`;
- membuka akses melalui `POST /payroll/payslips/my/unlock`;
- mengambil detail dan PDF melalui endpoint `/payroll/payslips/my/{id}`.

Data source melakukan validasi envelope, tipe data, employee/company aktif, ukuran PDF maksimum, dan content type. Header unlock ditambahkan hanya oleh method detail dan PDF, bukan interceptor global.

## Unlock Vault dan Lifecycle

`PayslipUnlockVault` menyimpan token, expiry, dan fingerprint sesi (`userId`, `employeeId`, `companyId`) hanya di memori. PIN tidak pernah disimpan. Vault tidak memakai `flutter_secure_storage`, shared preferences, database, atau disk cache.

Vault dibersihkan ketika:

- aplikasi memasuki `inactive`, `paused`, atau `detached`;
- logout, session invalidation, pergantian akun, employee, atau company;
- waktu `expiresAt` tercapai;
- backend mengembalikan `PAYSLIP_UNLOCK_INVALID`;
- pengguna memilih kunci kembali.

Pembersihan vault juga meng-invalidasi state detail dan PDF agar nominal tidak tertahan dalam provider. Kembali dari background selalu meminta PIN ulang.

## Alur Pengguna

Quick action **Slip gaji** tersedia hanya jika endpoint diaktifkan dan permission matcher menerima `payroll:read` atau wildcard yang sah.

Layar daftar menampilkan periode, status, tanggal terbit, dan ikon terkunci. Response daftar tidak boleh dipetakan ke field nominal. Memilih periode membaca status PIN:

1. `pinSet == false`: tampilkan form password akun, PIN tepat enam digit, dan konfirmasi PIN. Setelah sukses, pengguna tetap harus menjalankan unlock.
2. `lockedUntil` masih aktif: tampilkan waktu tunggu berdasarkan timestamp server dan nonaktifkan submit.
3. PIN tersedia: tampilkan form PIN. Unlock sukses membuka detail yang dipilih sampai vault dibersihkan.

Detail menampilkan periode, status, pendapatan, potongan, total, dan komponen yang dikenali. Kode komponen yang tidak dikenal tetap ditampilkan memakai label aman dari server atau kode mentah yang dinormalisasi, tanpa crash atau menebak makna.

PDF diminta hanya setelah vault valid. Byte response dirender dalam viewer in-memory. Aplikasi tidak membuat URL publik atau file cache permanen. Aksi ekspor tidak disediakan pada scope ini karena akan menghasilkan salinan di luar kontrol aplikasi.

## Keamanan Tampilan

Layar setup PIN, unlock, detail, dan PDF ditandai sensitif. Android memasang `FLAG_SECURE` selama route sensitif aktif dan melepasnya saat route selesai. iOS menutup konten dengan privacy overlay ketika aplikasi tidak aktif dan ketika screen capture terdeteksi. UI tidak mengklaim dapat mencegah seluruh screenshot pada iOS.

PIN memakai input numerik tersamarkan, tidak masuk semantics value, analytics, exception message, atau log. Network logger tetap meredaksi header, body PIN/password, response token, nominal, dan byte PDF.

## Error dan State

- `PAYSLIP_PIN_INVALID`: tetap di form dan tampilkan PIN salah, tanpa logout.
- `PAYSLIP_PIN_LOCKED` atau rate limit 429: nonaktifkan submit dan tampilkan waktu tunggu bila tersedia.
- `PAYSLIP_PIN_NOT_SET`: arahkan ke setup PIN.
- `PAYSLIP_PIN_REAUTH_FAILED`: tandai password akun salah, tanpa refresh token.
- `PAYSLIP_UNLOCK_INVALID`: bersihkan vault dan kembali ke unlock.
- 401 autentikasi biasa: mengikuti lifecycle session aplikasi.
- 404 detail: tampilkan slip tidak tersedia tanpa mengungkap kepemilikan.
- `PAYSLIP_PDF_TOO_LARGE`, content type salah, atau PDF invalid: jangan render byte dan tampilkan kegagalan aman.
- offline/timeout: retry eksplisit; mutasi PIN dan unlock tidak diulang otomatis.

Setiap screen memiliki loading, empty, error, permission-denied, dan expired state. Navigasi bawah tidak muncul pada flow payroll sensitif.

## Demo dan Production

Demo repository menyediakan ringkasan, status PIN, unlock berdurasi singkat, detail, lockout, expiry, dan PDF fixture lokal tanpa menggunakan repository production. Nilai demo diberi penanda jelas dan tidak pernah aktif pada build production. Komposisi widget dan controller harus identik di kedua mode.

## Pengujian dan Acceptance

- Contract test memverifikasi method, path, body, header, envelope, binary PDF, dan seluruh kode error payroll.
- Repository test memastikan daftar tidak menerima nominal dan header unlock tidak bocor ke request lain.
- Lifecycle test memastikan vault serta provider nominal bersih saat background, logout, expiry, dan account/company switch.
- Widget test mencakup setup PIN, unlock, lockout, detail, komponen asing, PDF gagal, retry, dan permission.
- Golden test mencakup light/dark pada lebar 320dp dan text scale 200%.
- Safety test memindai log/storage dan memastikan jalur admin tidak dipakai.
- Acceptance emulator menguji seluruh alur demo. Positive live dan real-device acceptance dicatat terpisah bila akun payroll fixture belum tersedia.

## Batas Selesai

Tahap ini selesai lokal ketika seluruh flow menggunakan shared presentation, unlock hanya hidup di memori, proteksi lifecycle/platform aktif, seluruh test dan analyzer hijau, serta tidak ada PIN/token/nominal pada log atau storage. Exit gate live memerlukan akun employee dengan `payroll:read`, minimal satu payslip approved/disbursed, kemampuan set PIN, fixture lockout, dan PDF valid dari staging HTTPS.
