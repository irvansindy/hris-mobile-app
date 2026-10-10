# Tahap 6 Task 4: Tap Resolver dan Simulator Inbox

Tanggal: 10 Oktober 2026

## Implementasi

- Tap/initial menunggu sesi employee siap. Sebelum login pertama, hanya satu pasangan ID yang dibatasi panjangnya disimpan di memori, bukan item atau isi notifikasi.
- Resolver mencari ID pada inbox akun aktif, halaman 1 dengan limit 50, lalu memakai allowlist route yang sudah tersedia. Tidak mencari seluruh riwayat atau menambahkan endpoint detail baru.
- Attendance, leave/leave_request, permission_request, dan work_calendar didukung. ID hilang/tidak valid/tidak ditemukan, error server, resource asing, approval, dan payslip membuka `/notifications`. PIN payslip tetap berlaku.
- Logout, pergantian user/company/revision, dan disposal membuang lookup serta callback lama. Dedup message ID/notification ID dibatasi 100 key per sesi; tap baru membatalkan tujuan lookup sebelumnya.
- Foreground hanya menginvalidasi unread/inbox yang sudah dibuat, tanpa navigasi, polling, banner payload, atau mengaktifkan inbox tersembunyi.
- Halaman Notifikasi memiliki status nonaktif atau panel debug `Simulasi push lokal`. Simulator menyediakan foreground, tap/background, initial/terminated, rotasi token, izin ditolak/diizinkan, kegagalan registrasi, dan retry. Registry tetap in-memory; token dummy tidak dikirim ke backend.

## Keputusan Implementasi

Bridge app-scoped menerima petunjuk event adapter sebelum autentikasi. Stream coordinator Task 3 tetap khusus sesi terikat dan registration, sehingga event awal tidak hilang sebelum restore. Subscription bridge berganti epoch mengikuti sesi. Adapter Firebase berikutnya harus mengirim initial event setelah subscription aplikasi siap.

Tap push tidak otomatis menandai item dibaca. Membuka resource bukan bukti isi notifikasi telah dibaca; mutation read tetap dilakukan oleh kartu inbox. Akibatnya, item yang dibuka lewat push masih unread sampai dibaca di inbox.

Guard `ref.exists` diperlukan: pada Riverpod 2.6.1, pemeriksaan dependency `Ref.invalidate` dalam debug dapat membuat provider yang belum aktif. Inbox yang belum dibuka akan mengambil data saat dibuka, bukan saat event foreground.

## Bukti Pengujian

`rtk flutter test test/features/notifications/push_route_test.dart test/features/notifications/push_simulator_test.dart`: 18 PASS.

Test mencakup restore/login, antrean terbaru, lookup terverifikasi, fallback/PIN, semua resource allowlist, stale lookup, logout/account/company switch, alias duplicate initial/opened, message ID opaque, dan batas dedup. Integrasi menggunakan auth controller dan router/HrmsApp sebenarnya, dengan I/O repository berupa fixture.

Klik widget simulator diuji pada light/dark, lebar 320dp dan teks 200%: ID input, ketiga event, rotasi token, penolakan/pemulihan izin, registrasi gagal, dan retry. Registrasi gagal berhenti pada status failed; flag injeksi kegagalan kembali normal setelah operasi. Disabled tidak membuat SDK/simulator. Test menemukan dan memperbaiki fetch inbox tidak aktif serta pending intent akun tanpa akses employee yang bertahan setelah logout.

Analyzer: 0 issue. Format: 274 file, 0 perubahan. `git diff --check`: bersih. Full suite: 616 PASS, termasuk golden, tanpa memperbarui gambar golden.

Panel mengikuti tema HRIS yang sudah ada, bukan redesign: tipografi/palet shared theme, kontrol wrap untuk layar sempit, jarak 8/12px, target tombol minimum 44px, dan status tertulis dengan live region. Antislop diterapkan selama implementasi. Dials panel: ENERGY 1 / RHYTHM 1 / MOTION 1. Kontras teks tombol/background light 6.35:1 dan dark 8.67:1; teks utama light 16.22:1 dan dark 16.67:1. Border kontrol memakai warna primary yang sama: test awal menemukan border light 2.82:1, kemudian diperbaiki dan test minimum 3:1 lulus. Aktivasi tombol via keyboard Enter juga lulus pada kedua tema. Tidak ada aset, badge, animasi, atau data perusahaan baru yang dikarang.

## Pengujian Manual

```bash
rtk flutter run --dart-define=DEMO_MODE=true
```

Buka Notifikasi, masukkan ID item inbox, lalu jalankan event. ID kosong membuka inbox. Untuk inbox server dengan simulator lokal debug, gunakan konfigurasi environment yang valid:

```bash
rtk flutter run --dart-define-from-file=.env --dart-define=PUSH_MODE=dummy
```

Simulator tidak menciptakan item inbox production dan tidak mengirim registration dummy ke server. Mode disabled tetap default untuk non-demo; dummy ditolak pada release/profile.

## Batas dan Lanjutan

Initial/terminated adalah simulasi urutan event, bukan pengujian kill/relaunch atau delivery OS. Firebase, APNs, push background nyata, privacy lock screen, serta acceptance Android/iOS masih menunggu konfigurasi partner dan gate live. Build APK, review keseluruhan Tahap 6, dan acceptance emulator dijadwalkan pada Task 5. Hasil lokal pada checkout aktif bukan bukti remote CI atau clean-checkout integration.
