# RD-001 sampai RD-004: Fondasi Redesign

Tanggal implementasi: 14 September 2026.

Dokumen ini menjadi kontrak desain, matriks capability, spesifikasi responsif dan aksesibilitas, serta laporan implementasi theme untuk Tahap 1 redesign HRIS Mobile App.

Acuan:

- [Breakdown Task Redesign](<Breakdown Task Redesign HRIS Mobile App.md>)
- [API Integration Revision](<API_INTEGRATION_REVISION.md>)
- design handoff eksternal `HRIS Mobile App Redesign/design_handoff_hris_mobile/README.md`
- prototipe eksternal `HRIS Mobile App Redesign/design_handoff_hris_mobile/HRIS Mobile Redesign.html`

## 1. RD-001: kontrak desain

Status: `DONE`.

Design Read: aplikasi Employee Self-Service untuk karyawan Indonesia, memakai light surface, kartu lembut, dan aksi absensi sebagai fokus utama. Dial desain: `ENERGY 2 / RHYTHM 2 / MOTION 2`.

### 1.1 Token warna

| Peran | Light | Dark | Penggunaan |
|---|---|---|---|
| Primary | `#315B8C` | `#8FB4DC` | Aksi utama, active state, dan focus indicator. |
| Primary dark | `#26496F` | `#0B1220` sebagai on-primary | Kedalaman gradient yang hanya dipakai pada area fokus. |
| Primary tint | `#E7EEF6` | `#22364E` | Selected container dan icon background. |
| Screen | `#F3F4F6` | `#0B1220` | Latar utama. |
| Card | `#FFFFFF` | `#161F31` | Surface konten. |
| Chip/track | `#F3F4F6` / `#EEF1F6` | `#1E2A3F` | Grouped control dan progress track. |
| Ink | `#0F172A` | `#EEF2F8` | Teks utama. |
| Muted | `#6B7280` pada card | `#9AA8BD` | Teks sekunder. |
| Divider | `#E8EAEE` | `#26334A` | Pemisah dekoratif, bukan satu-satunya penanda control. |
| Success | `#15803D` / `#DCFCE7` | `#4ADE80` / `#16351F` | Status berhasil dengan label atau icon. |
| Warning | `#B45309` / `#FEF3C7` | `#FBBF24` / `#3A2E12` | Status menunggu/peringatan dengan label atau icon. |
| Danger | `#B91C1C` / `#FEE2E2` | `#F87171` / `#3A1C1C` | Error atau penolakan dengan label atau icon. |

Penyesuaian aksesibilitas:

- Muted text di atas screen light memakai `#667085`. Nilai handoff `#6B7280` hanya dipakai di atas card putih karena rasionya pada `#F3F4F6` hanya 4.39:1.
- Border control light memakai `#8993A4` dan dark memakai `#5C6B82`. Divider handoff terlalu tipis kontrasnya untuk menjadi satu-satunya batas input.
- Inactive navigation tidak memakai `#A3A8B2` untuk label kecil karena rasionya pada putih hanya 2.39:1. Theme memakai muted text yang lolos AA.

### 1.2 Tipografi

Font family: `PlusJakartaSans`, dibundel sebagai variable font dengan lisensi SIL Open Font License.

| Peran | Ukuran | Weight | Tracking |
|---|---:|---:|---:|
| Login hero | 30 | 600 | -1.1 |
| Splash hero | 26 | 600 | -0.6 |
| Screen title | 22 | 500 | -0.6 |
| Profile name | 17 | 600 | -0.4 |
| Card title | 13.5 | 600 | -0.3 |
| Body | 12.5 sampai 13.5 | 400 sampai 500 | 0 |
| Secondary | 11.5 | 400 | 0 |
| Micro/navigation | 9.5 sampai 11 | 400 sampai 500 | sesuai fungsi |

Weight 700 hanya tersedia untuk kebutuhan khusus. Screen baru tidak menaikkan heading reguler ke 700 atau 800.

### 1.3 Spacing, radius, shadow, dan motion

| Kelompok | Nilai |
|---|---|
| Spacing | 4, 8, 12, 16, 20, 24, 32 |
| Screen horizontal | 20 |
| Scroll bottom reserve | 130 |
| Radius icon | 12 |
| Radius input | 18 |
| Radius small card/button | 20 |
| Radius card | 22 |
| Radius large card | 26 |
| Radius sheet/navigation | 30 |
| Motion | 180, 220, 300, 340, 450 ms |
| Enter curve | `cubic-bezier(0.22, 0.9, 0.3, 1)` |
| Success curve | `cubic-bezier(0.22, 1.5, 0.36, 1)` |

Shadow hanya menandai elevation. Card memakai shadow tipis, primary action memakai shadow primary, dan floating navigation memakai shadow paling tinggi. Surface biasa tetap datar.

### 1.4 Inventaris perubahan source

| Area | Baseline sebelum Tahap 1 | Kontrak redesign |
|---|---|---|
| Primary | `#2563EB` | `#315B8C` |
| Font | Inter melalui `google_fonts` | Plus Jakarta Sans asset lokal |
| Background | `#F8FAFC` | `#F3F4F6` |
| Card radius | 16 | 22 sebagai default |
| Input radius | 12 | 18 |
| Theme token | Warna utama dan beberapa surface | Warna, spacing, radius, shadow, motion, dan typography |
| Navigation | Material NavigationBar standar | Floating navigation pada RD-006/RD-008 |

### 1.5 Batas fidelity

Harus dipertahankan:

- identitas warna, typography, hierarchy, spacing rhythm, bentuk card, dan focal point per screen;
- dark theme yang setara, bukan turunan otomatis yang belum diverifikasi;
- perpindahan Pengajuan ke quick action dan absensi sebagai aksi utama setelah router siap.

Harus disesuaikan:

- data dummy diganti data server atau empty state;
- toggle absensi prototipe diganti orchestrator GPS/selfie/policy server;
- PIN demo diganti verifikasi server;
- alternative login disembunyikan sampai capability tersedia;
- fixed canvas diganti layout berbasis constraint;
- dead control tidak ikut dibuat.

## 2. RD-002: matriks data dan capability

Status: `DONE` untuk audit lokal. Capability live tetap mengikuti kontrak dan fixture server pada task HRIS terkait.

| Screen/section | Kondisi mobile saat audit | Sumber atau dependency | Keputusan redesign |
|---|---|---|---|
| Session dan identity | Tersedia | `/auth/login`, `/auth/me`, Bearer refresh | Gunakan identity session dan company scope. |
| Splash | Belum menjadi screen khusus | Restore session lokal | Jangan menahan session restore selama 2.4 detik. |
| Login password | Tersedia | `/auth/login` | Redesign dapat memakai controller yang ada. |
| Biometric, QR, Face ID login | Belum tersedia | Kontrak/device capability belum terbukti | Sembunyikan. |
| Dashboard identity | Tersedia | Request context/session | Gunakan nama dan company aktif dari session. |
| Attendance hari ini | Tersedia lokal | `/attendance/me/today` | Menjadi sumber tunggal Dashboard, FAB, dan Attendance. |
| Clock-in/out | Tersedia lokal | `/attendance/me/check-in`, `/attendance/me/check-out` | Pertahankan GPS/selfie/policy dan server result. |
| Saldo cuti | Parsial | `/leave/balances/employee`, fixture live belum ada | Tampilkan hanya setelah response valid. |
| Pengumuman | Parsial | Dashboard membaca `/notifications` | Pisahkan announcement type setelah schema terverifikasi. |
| Heatmap kehadiran | Belum tersedia | Riwayat `/attendance/me?month=YYYY-MM` belum diintegrasikan | Sembunyikan sampai data periode tersedia. |
| Tim hari ini | Belum tersedia | Endpoint/schema belum dipetakan | Sembunyikan. |
| Shift berikutnya | Belum tersedia | Kalender/shift resolved belum diintegrasikan | Sembunyikan. |
| Pengajuan | Unavailable di jalur produksi | Leave/permission/overtime contracts | Jangan memakai `DemoRequestLocalDataSource`. |
| Kalender | Unavailable di jalur produksi | `/work-calendars/me/resolved`, holidays | Jangan memakai `DemoCalendarLocalDataSource`. |
| Notifikasi inbox | Belum ada feature module | Notifications endpoints | Implementasikan pada RD-014 setelah DTO tersedia. |
| Pesan/chat | Tidak ada module dan kontrak | Backend contract belum terbukti | Tombol disembunyikan sampai RD-015 lolos gate. |
| Profil | Tersedia parsial | `/employees/:id` | Gunakan data server dan tandai section unavailable secara terpisah. |
| Slip gaji | Belum ada module | `/payroll/payslips`, kontrak PIN/unlock belum ada | Jangan meminta atau menyimpan nominal sebelum unlock server. |
| Theme preference | Tersedia | Shared preferences/controller | Pertahankan dan pindahkan control ke Profil pada RD-016. |

### 2.1 Klasifikasi data

| Kelas | Contoh | Aturan |
|---|---|---|
| Preferensi lokal | Theme, locale | Boleh disimpan tanpa identitas personal, tetap dibersihkan jika scope-nya per akun. |
| Data akun | Profil, attendance, leave, request, notification | Cache wajib memakai account/company scope dan dibersihkan saat session berakhir. |
| Data sensitif | Payslip, salary, dokumen, selfie | Tidak masuk log. Cache hanya jika terenkripsi dan kontrak produk mengharuskannya. |
| Capture sementara | Foto selfie, PDF sementara | Simpan sesingkat mungkin dan hapus setelah upload/share selesai atau dibatalkan. |

### 2.2 Aturan visibility

1. Section tampil jika endpoint, schema, permission, dan state session tersedia.
2. Empty response menampilkan empty state, bukan data contoh.
3. Kegagalan section menampilkan retry pada section terkait, bukan angka nol.
4. `403` menyembunyikan capability yang memang tidak dimiliki dan menampilkan penjelasan bila route dibuka langsung.
5. Pergantian account/company membangun ulang state dan membatalkan hasil request lama.

## 3. RD-003: spesifikasi responsif dan aksesibilitas

Status: `DONE` sebagai acceptance specification. Implementasi komponen dan screen dilakukan mulai RD-005.

### 3.1 Verification bands

Band berikut dipakai untuk pengujian. Reflow tetap dipicu ketika konten tidak lagi muat, bukan karena nama perangkat tertentu.

| Band | Lebar logical | Aturan utama |
|---|---:|---|
| Compact | kurang dari 360 | Header dapat bertumpuk, stat menjadi 2 kolom dengan item prioritas membentang, dan action card dapat menjadi 1 kolom. |
| Standard | 360 sampai 430 | Mengikuti komposisi referensi 390 x 844. |
| Wide phone | 431 sampai 599 | Batasi lebar baca, tambah whitespace, jangan meregangkan card tanpa batas. |
| Large surface | 600 atau lebih | Gunakan centered content rail dan maksimal 2 kolom jika urutan baca tetap jelas. |

Tidak ada screen produksi yang mengunci lebar atau tinggi ke 390 x 844. Area scroll memakai bottom padding yang mencakup navigation dan safe inset.

### 3.2 Text scaling dan overflow

- Uji text scale 1.0, 1.3, 1.5, dan 2.0.
- Pada scale di atas 1.3, trio stat dan action row boleh collapse lebih awal.
- Jangan memakai fixed-height container untuk teks dinamis.
- Teks identitas memakai `Flexible`/ellipsis hanya untuk informasi yang tersedia lengkap di screen detail.
- Pada scale 1.5 atau lebih, navigation hanya menampilkan label destination aktif. Semua destination tetap memiliki semantics dan tooltip.
- Long email, company name, leave type, status, dan error message harus wrap tanpa horizontal scroll.

### 3.3 Tap, focus, semantics, dan feedback

- Target interaktif minimum 44 x 44 logical pixel dengan jarak antar-target.
- Icon-only button wajib memiliki tooltip dan semantics label.
- Status tidak boleh disampaikan melalui warna saja. Gunakan label, icon, atau keduanya.
- Focus traversal mengikuti urutan visual. Enter/Space mengaktifkan control dan Escape menutup dialog/sheet pada platform keyboard.
- Focus indicator memakai primary color yang memiliki contrast minimum 3:1 pada surface light/dark.
- Loading state memiliki label yang dapat diumumkan screen reader.
- Perubahan hasil transaksi memakai live region/announcement yang singkat dan tidak menduplikasi snackbar.

### 3.4 Keyboard, safe area, dan system chrome

- Form menggunakan resize/scroll sehingga field aktif tidak tertutup keyboard.
- Bottom sheet memiliki max height berbasis viewport dan konten internal dapat scroll.
- Floating navigation tidak menutupi list item terakhir atau CTA.
- FAB menjauh dari gesture area dan tetap dapat dijangkau pada safe inset besar.
- Status bar icon mengikuti brightness theme dan tidak memakai warna fixed.

### 3.5 State minimum per area

| Area | State wajib |
|---|---|
| Auth | restoring, form, validating, submitting, invalid credential, lockout, network error, success bootstrap |
| Dashboard section | loading, data, empty, error, unauthorized, refresh |
| Attendance action | checking policy, requesting permission, acquiring location, capturing selfie, confirming, submitting, rejected, success |
| List | initial loading, data, filtered empty, first-use empty, pagination loading/error, refresh error |
| Form | pristine, invalid, attachment progress/error, submitting, success, duplicate prevention |
| Protected payroll | locked, verifying, wrong PIN, locked out, expired unlock, data, download/share error |

## 4. RD-004: implementasi theme dan typography

Status: `DONE` secara lokal.

Perubahan:

- `AppColors` mengikuti palette redesign dan menyediakan semantic light/dark.
- `AppSpacing`, `AppRadius`, `AppShadows`, dan `AppMotion` menjadi token terpusat.
- `AppTypography` memetakan scale handoff ke Material `TextTheme`.
- `ThemeData` light/dark diperbarui untuk app bar, card, input, button, chip, navigation, sheet, snackbar, dan progress indicator.
- Plus Jakarta Sans variable font serta OFL license dibundel di `assets/fonts`.
- Dependency `google_fonts` dihapus agar first launch tidak membutuhkan download font.
- Input dan outlined control memakai border yang lolos non-text contrast 3:1.

### 4.1 Hasil contrast check

| Pasangan | Rasio | Hasil |
|---|---:|---|
| Light ink / screen | 16.22:1 | AA normal pass |
| Light accessible muted / screen | 4.52:1 | AA normal pass |
| Handoff muted / card | 4.83:1 | AA normal pass |
| White / primary | 6.99:1 | AA normal pass |
| Dark ink / screen | 16.67:1 | AA normal pass |
| Dark muted / card | 6.83:1 | AA normal pass |
| Dark primary / card | 7.63:1 | AA normal pass |
| Light control border / card | 3.10:1 | Non-text pass |
| Dark control border / card | 3.04:1 | Non-text pass |
| Light semantic status pairs | 4.51:1 sampai 5.30:1 | AA normal pass |
| Dark semantic status pairs | 5.57:1 sampai 7.96:1 | AA normal pass |

### 4.2 File implementasi

- `lib/core/theme/app_theme.dart`
- `assets/fonts/PlusJakartaSans-VariableFont_wght.ttf`
- `assets/fonts/OFL.txt`
- `pubspec.yaml`
- `pubspec.lock`
- `test/core/app_theme_test.dart`

## 5. Batas Tahap 1

Tahap ini mengubah theme global sehingga screen lama mulai menerima warna dan font baru. Pixel-perfect screen, shared redesign components, floating navigation, dan perubahan layout per screen belum termasuk Tahap 1. Pekerjaan tersebut dimulai pada RD-005 setelah laporan ini disetujui.

## 6. Bukti verifikasi

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze` | Lulus, tidak ada issue. |
| `flutter test test/core/app_theme_test.dart` | 5 test lulus. |
| `flutter test` | 147 test lulus. |
| Android debug build | Lulus, `app-debug.apk` berhasil dibuat. |
| Android font manifest | `PlusJakartaSans` dan variable font tercantum di APK. |
| Web release build | Lulus dan font lokal tercantum di `FontManifest.json`. |
| Web Wasm dry run | Memberi peringatan dependency `flutter_secure_storage_web` masih memakai legacy web API. Build JavaScript tetap berhasil. |
| Contrast | Seluruh pasangan teks/status yang didaftarkan lulus 4.5:1 dan control border lulus 3:1. |

Pengujian akun/server live tidak diperlukan untuk perubahan token. Pemeriksaan visual seluruh screen dan click-through lengkap dilakukan pada tahap screen terkait, mulai RD-005. Tahap 1 tidak menambahkan control interaktif baru.

## 7. Delivery gate Tahap 1

- Hard gate PASS untuk scope Tahap 1: tidak ada data, klaim, navigation item, atau control baru; theme light/dark berhasil dianalisis, diuji, dan dibangun.
- Purpose gate PASS: alasan warna, typography, spacing, radius, shadow, dan motion tercatat pada bagian kontrak desain.
- Liveliness PASS: Design Read dan dial `ENERGY 2 / RHYTHM 2 / MOTION 2` tercatat; primary accent dibatasi untuk hierarchy dan aksi utama.
- Accessibility PASS untuk token: contrast teks/status dan batas control diuji dengan perhitungan WCAG; spesifikasi tap, focus, semantics, reflow, keyboard, dan text scale sudah menjadi acceptance RD-003.
- Craftsmanship PASS untuk scope Tahap 1: font dibundel, dependency runtime font dihapus, token terpusat, analyzer bersih, seluruh test lulus, dan Android/Web build berhasil.
