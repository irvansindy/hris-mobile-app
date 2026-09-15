# RD-005 sampai RD-008: Shell dan Autentikasi

Tanggal implementasi: 14 September 2026.

Tahap 2 membangun komponen UI bersama, router berbasis session, presentasi login, floating navigation, serta capability gate untuk quick action. Implementasi ini memakai kontrak desain dari Tahap 1 dan tidak mengaktifkan fitur yang belum memiliki endpoint serta route nyata.

Acuan:

- [Breakdown Task Redesign](<Breakdown Task Redesign HRIS Mobile App.md>)
- [Laporan fondasi redesign](<RD-001-004 Fondasi Redesign.md>)
- [API Integration Revision](<API_INTEGRATION_REVISION.md>)

## 1. Ringkasan hasil

| Task | Status | Hasil utama |
|---|---|---|
| RD-005 | `DONE lokal` | Komponen bersama, state standar, skeleton, dan widget test responsif tersedia. |
| RD-006 | `DONE lokal` | `MaterialApp.router` dan `StatefulShellRoute.indexedStack` menangani empat branch, deep link, back, serta state per session. |
| RD-007 | `DONE lokal` | Splash mengikuti proses restore tanpa timer buatan. Login menangani validasi, MFA, failure state, dan success overlay berbasis identity aktual. |
| RD-008 | `DONE lokal` | Floating navigation dan FAB Absensi aktif. Quick action hanya muncul jika endpoint, route, dan permission tersedia. |

## 2. RD-005: komponen dan state bersama

Komponen berikut tersedia di `core/widgets`:

- `AppSurfaceCard`
- `AppSectionHeader`
- `AppStatusChip`
- `AppInitialAvatar`
- `AppBadgeIconButton`
- `AppSegmentedControl`
- `AppBottomSheetShell`
- `AppSkeletonBlock`
- `AppStateView`
- `AppFloatingNavigation`
- `AppQuickActionOverlay`

`AppStateView` menyediakan state loading, empty, error, offline, dan permission. Pesan, konteks, serta tindakan berikutnya diberikan oleh screen pemakai sehingga komponen tidak menghasilkan pesan generik atau angka contoh.

Keputusan implementasi:

- Status memakai icon dan label agar makna tidak bergantung pada warna.
- Skeleton hanya menggambar bentuk surface. Skeleton tidak memuat nama, nominal, atau statistik palsu.
- Bottom sheet membatasi tinggi isi, dapat menggulir, menghormati safe area, dan menambah ruang sesuai keyboard inset.
- Target tombol icon dan segmented control memiliki area sentuh minimum 44 dp.
- Floating navigation memakai shadow karena elemen ini berada di atas konten. Card biasa tetap datar dengan border ringan.

## 3. RD-006: router dan main shell

Dependency `go_router` ditambahkan untuk memisahkan navigation state dari state widget halaman. Router dibuat ulang saat `featureSessionProvider` berubah. Posisi branch dan scroll controller dari akun lama ikut dibuang.

### 3.1 Route aktif

| Route | Lapisan | Navigation bar | Perilaku |
|---|---|---|---|
| `/` | root | Tidak ada | Entry restore session. |
| `/loading` | root | Tidak ada | Splash selama restore masih berjalan. |
| `/login` | root | Tidak ada | Form autentikasi. |
| `/change-password` | root | Tidak ada | Wajib ganti password sebelum shell. |
| `/employee-access-unavailable` | root | Tidak ada | Session valid tanpa employee/company context. |
| `/home` | shell branch 0 | Ada | Beranda. |
| `/attendance` | shell branch 1 | Ada | Absensi. |
| `/calendar` | shell branch 2 | Ada | Kalender. |
| `/profile` | shell branch 3 | Ada | Profil. |
| `/requests` | root | Tidak ada | Pengajuan dibuka sebagai alur sekunder. |

Redirect mempertahankan parameter `from` untuk deep link yang terlindungi. Session tanpa autentikasi kembali ke login. Session dengan kewajiban ganti password atau identity employee/company yang belum lengkap tidak dapat masuk ke shell.

Empat branch memakai indexed stack agar state tab tetap tersedia saat pengguna berpindah tab. Shell dan branch menerima scroll controller yang sama. Mengetuk tab aktif menjalankan scroll-to-top pada branch tersebut.

Form, detail, camera, dan protected payroll flow ditempatkan sebagai top-level route di luar shell ketika task pemiliknya diimplementasikan. Tahap ini membuktikan pola tersebut melalui `/requests`. Route camera dan payroll belum dibuat karena termasuk RD-009 serta RD-017.

## 4. RD-007: splash dan login

Splash tidak memakai delay minimum. Screen tampil selama `restoreSession()` masih pending dan langsung berpindah setelah hasil tersedia.

Login menyediakan:

- layout satu kolom pada ponsel dan identity panel pada lebar minimal 780 dp;
- pilihan Bahasa Indonesia dan Inggris;
- validasi email, password, serta kode MFA;
- loading CTA yang tetap muat pada lebar 320 dp dengan text scale 200 persen;
- pesan invalid credential, lockout, gangguan jaringan, dan failure backend lain dari domain `Failure`;
- autofill hint, password visibility control, urutan aksi keyboard, dan padding berdasarkan keyboard inset;
- success overlay hanya setelah session memiliki employee dan company context;
- nama employee dari session pada success overlay.

Lupa kata sandi, biometric, Face ID, dan QR tidak ditampilkan karena capability, kontrak recovery, serta route nyata belum tersedia.

## 5. RD-008: floating navigation dan quick action

Urutan destination aktif adalah Beranda, Absensi, Kalender, dan Profil. FAB fingerprint berada di tengah dan membuka branch Absensi. FAB tidak mengubah status absensi dan tidak menjalankan clock-in atau clock-out secara lokal.

Quick action memakai registry berikut:

| Shortcut | Permission | Endpoint/route saat ini | Hasil |
|---|---|---|---|
| Ajukan cuti | `leave:create` | Belum tersedia | Disembunyikan. |
| Klaim lembur | Tidak ditetapkan | Belum tersedia | Disembunyikan. |
| Reimbursement | Tidak ditetapkan | Belum tersedia | Disembunyikan. |
| Slip gaji | `payroll:read` | Belum tersedia | Disembunyikan. |

Filter mewajibkan request context, endpoint aktif, route non-null, dan permission jika shortcut memerlukannya. Dengan kondisi API sekarang, tidak ada quick action yang terlihat dan tidak ada dead control.

Overlay quick action sudah mendukung action tap, backdrop dismiss, tombol Escape, penutupan saat tab berubah, dan penutupan saat scroll. Haptic memakai API platform Flutter pada pemilihan destination dan FAB.

## 6. Keputusan visual

Design Read tetap sama: Employee Self-Service untuk karyawan Indonesia, surface light dengan kartu lembut, serta absensi sebagai fokus utama. Dial tetap `ENERGY 2 / RHYTHM 2 / MOTION 2`.

| Keputusan | Implementasi | Alasan |
|---|---|---|
| Focal point | Satu FAB Absensi berwarna primary | Menempatkan tugas harian utama tanpa menambah CTA yang bersaing. |
| Surface | Solid color, border ringan, dan radius token | Menjaga hierarchy pada energy level 2. |
| Shadow | Hanya pada floating navigation dan elevation yang memang bertumpuk | Menjelaskan lapisan tanpa membuat seluruh card terlihat mengambang. |
| Login lebar | Primary identity panel dan form dengan lebar baca maksimum 430 dp | Memakai ruang desktop tanpa meregangkan form. |
| Login sempit | Form satu kolom dengan header yang dapat bertumpuk | Mencegah layout desktop diperkecil ke ponsel. |
| Ilustrasi | Tidak ditambahkan | Handoff tidak membutuhkan asset bitmap baru untuk menyelesaikan tugas autentikasi. |
| Unsupported action | Disembunyikan | Pengguna hanya melihat kontrol yang dapat dijalankan. |

## 7. Bukti click-through dan test

| Pemeriksaan | Bukti |
|---|---|
| Restore pending | Splash tetap terlihat sampai future restore selesai. |
| Restore tanpa session | Router membuka login tanpa delay tambahan. |
| Validasi login | Email tidak valid dan field kosong menghasilkan pesan field. |
| Failure login | Credential, lockout, dan network failure tampil sebagai pesan domain. |
| MFA | Challenge memunculkan field kode dan meneruskan kode pada submit berikutnya. |
| Success bootstrap | Overlay memakai `Employee Nyata` dari session fixture yang memiliki employee/company context. |
| Main destinations | Empat branch tampil dengan label Bahasa Indonesia. |
| FAB tengah | FAB memilih branch Absensi dan tidak memanggil transaksi attendance. |
| Tab aktif | Controller branch terverifikasi kembali ke offset nol. |
| Alur tanpa nav | `/requests` menyembunyikan floating navigation dan back kembali ke shell. |
| Capability gate | Kombinasi endpoint, route, dan permission diuji. Hanya capability lengkap yang lolos. |
| Quick action overlay | Action, backdrop, dan Escape menjalankan dismiss yang sesuai. |
| Pergantian akun | Akun B kembali ke Beranda tanpa route atau draft akun A. |
| Responsive | Login dan komponen bersama lulus pada lebar 320 dp serta text scale 200 persen. |
| Tema | Login dan shell diuji pada light dan dark theme. |

Hasil perintah:

| Perintah | Hasil |
|---|---|
| `flutter analyze` | Lulus, tidak ada issue. |
| Suite terarah RD-005 sampai RD-008 | 21 test lulus. |
| `flutter test` | 160 test lulus. |
| `flutter build apk --debug` | Lulus, menghasilkan `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build web --release` | Lulus, menghasilkan `build/web`. |
| Contrast dark on-primary | 8.67:1, lulus AA untuk teks normal dan besar. |

Web build masih mencatat peringatan Wasm dari `flutter_secure_storage_web` yang memakai legacy `dart:html` dan `dart:js_util`. Peringatan tersebut tidak menggagalkan build JavaScript dan bukan regresi Tahap 2.

## 8. Delivery gate Tahap 2

- Purpose PASS: absensi menjadi satu-satunya focal action dan route sekunder tidak memenuhi navigation utama.
- Mobile layout PASS: login berubah menjadi layout satu kolom pada ponsel dan diuji pada 320 dp dengan text scale 200 persen.
- Navigation PASS: empat destination, central FAB, route tanpa nav, back, state branch, dan scroll-to-top diuji.
- Accessibility PASS: status memakai icon serta label, loading memiliki teks, control minimum 44 dp, dan overlay dapat ditutup dengan Escape.
- State handling PASS: shared component menyediakan loading, empty, error, offline, permission, dan retry.
- Data integrity PASS: skeleton tidak membawa data contoh dan success login memakai identity session.
- Capability PASS: shortcut tanpa endpoint atau route tetap tersembunyi.
- Copy PASS: login tidak memuat klaim keamanan, metode login, atau fitur recovery yang belum terbukti.
- Comment hygiene PASS untuk file Tahap 2: komentar baru hanya dipakai bila menjelaskan kontrak yang tidak terlihat dari kode.
- Verification PASS: analyzer, seluruh test, Android build, dan Web build selesai tanpa error.

## 9. Batas Tahap 2

Pengujian autentikasi langsung ke server belum dilakukan karena akun uji belum tersedia. Contract test lokal tetap meliputi login, identity, refresh Bearer, dan logout.

Tahap 2 belum mendesain ulang isi Dashboard, Absensi, Riwayat, atau Pengajuan. Tahap 3 menangani RD-009 sampai RD-012, termasuk transaksi attendance nyata, sinkronisasi data server, dan route form/detail. Registry quick action baru dapat menampilkan shortcut setelah task pemilik endpoint menyediakan route yang bekerja.
