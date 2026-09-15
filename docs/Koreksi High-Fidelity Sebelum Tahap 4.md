# Laporan Koreksi High-Fidelity Sebelum Tahap 4

Tanggal verifikasi: 14 September 2026.

Status: selesai untuk seluruh layar yang saat ini dapat diakses. Tahap 4 belum dimulai.

## Klarifikasi sumber desain

- `HRIS Mobile Redesign.html` diperlakukan sebagai sumber kebenaran high-fidelity untuk struktur layar, urutan section, ukuran, spacing, bentuk, warna, tipografi, navigasi, dan hirarki aksi.
- `support.js` adalah runtime serta parser yang membuat prototipe HTML interaktif. File ini berkaitan langsung dengan HTML, tetapi tidak diimpor atau disalin ke aplikasi Flutter.
- Data Maya, perusahaan, lokasi, jam, statistik, agenda, notifikasi, pesan, dan payroll dalam prototipe adalah data contoh. Implementasi hanya menampilkan data server atau empty/error state yang jujur.

## Hasil koreksi layar

| Area | Implementasi high-fidelity | Perlindungan data nyata |
|---|---|---|
| Splash | Latar primary penuh, lingkaran dekoratif, logo jam 96 px, judul, copy restore, dan progress bawah mengikuti komposisi HTML. | Pesan mengikuti proses restore sesi nyata. |
| Login | Header H + HRIS, pilihan ID/EN, date pill, headline, credential card, field, CTA, MFA, error, loading, dan success overlay mengikuti susunan HTML. | Identitas contoh, biometric, QR, recovery, dan bantuan disembunyikan sampai capability nyata tersedia. |
| Shell | Floating navigation empat tujuan, center attendance action 62 x 62 radius 24, inset 14, tinggi 76, serta shortcut FAB 50 x 50 mengikuti HTML. | Center action membuka alur absensi nyata. Shortcut hanya tampil bila route, endpoint, dan permission tersedia. |
| Dashboard | Sticky identity header, headline, tiga kartu ringkasan absensi, quick action, pengumuman, dan saldo cuti mengikuti urutan serta komposisi HTML. | Team, shift, heatmap, pesan, notifikasi, dan payroll disembunyikan bila belum memiliki sumber nyata. |
| Absensi | Header dan CTA cuti, ringkasan record, geofence/policy, aksi transaksi, filter status, pemilih bulan, dan riwayat menjadi satu alur scroll seperti HTML. Top safe-area menjaga header di bawah status bar. | Tidak ada status lokasi prediktif, grafik rekaan, atau perubahan sukses lokal. |
| Pengajuan | Header, dua action card, filter jenis/status, riwayat, form, dan detail memakai komposisi kartu serta header desain. | Count, list, status, dan detail berasal dari API. Tipe yang belum didukung tidak ditampilkan. |
| Kalender | Header, kontrol bulan, grid Senin-first, pemilihan tanggal, agenda, dan top safe-area mengikuti layar HTML. | Bulan/tahun aktual dipakai. Event serta legend contoh tidak disalin; empty state tampil sampai integrasi RD-013. |
| Profil | Avatar 88 px, identitas, chips, grup Kontak, Kepegawaian, Dokumen, Pengaturan, Keluar, dan top safe-area mengikuti komposisi HTML. | Field kosong tidak diganti data contoh. Menu tanpa endpoint atau perilaku nyata disembunyikan. |
| State akun | Ganti kata sandi dan employee access unavailable memakai brand, card, spacing, input, serta action yang sama dengan sistem desain. | Perilaku bootstrap, validasi, dan logout tetap memakai implementasi nyata. |

## Perbedaan yang disengaja dari prototipe

- Notifikasi, Pesan, dan Payroll belum dibuat karena merupakan scope tahap berikutnya dan kontrak end-to-end belum tersedia.
- Dashboard tidak menampilkan section Tim, Shift, atau Heatmap tanpa endpoint yang dapat diverifikasi.
- Kalender tidak menampilkan agenda contoh.
- Profil tidak menampilkan dokumen, lokasi, setting, versi, atau nominal contoh.
- Metode login biometric dan QR tidak ditampilkan sebelum capability perangkat serta backend tersedia.
- Layout beradaptasi pada lebar kecil dan text scaling. Ukuran 390 x 844 tetap menjadi baseline visual, bukan ukuran layar tetap.

## Berkas utama

- Theme dan shared components: `lib/core/theme/app_theme.dart`, `lib/core/widgets/app_components.dart`, `lib/core/widgets/app_navigation.dart`.
- Auth: `lib/features/authentication/presentation/screens`.
- Shell: `lib/app/shell/main_shell.dart`.
- Dashboard: `lib/features/dashboard/presentation/screens/home_screen.dart`.
- Absensi: `lib/features/attendance/presentation/screens/attendance_screen.dart`.
- Pengajuan: `lib/features/self_service/presentation/screens`.
- Kalender: `lib/features/calendar/presentation/screens/calendar_screen.dart`.
- Profil: `lib/features/profile/presentation/screens/profile_screen.dart`.

## Verifikasi

- `flutter analyze`: PASS, tidak ada issue.
- `flutter test`: PASS, 169 test.
- Reference geometry 390 x 844: PASS. Navigation surface 362 x 76 dan center action 62 x 62 tervalidasi.
- Status bar inset: PASS. Header Absensi/Kalender dan avatar Profil tetap berada di bawah inset sistem 30 dp.
- Responsive matrix 320 px: PASS pada light/dark dan text scale 1.0/2.0 tanpa overflow.
- Contrast utama: PASS. Primary/white 6.99:1, light text/background 16.22:1, muted/surface 4.83:1, dark text/surface 14.67:1, dan dark muted/surface 6.83:1.
- `flutter build apk --debug`: PASS, menghasilkan `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web --release`: PASS, menghasilkan `build/web`.
- Web build masih memberi warning Wasm dari `flutter_secure_storage_web` karena legacy web imports. Build JavaScript release tetap berhasil.
- `git diff --check`: PASS.

## Batas sebelum Tahap 4

- Penyelarasan presentasi Kalender dan Profil sudah dilakukan agar seluruh shell konsisten, tetapi acceptance API RD-013 dan RD-016 belum dinyatakan selesai.
- Implementasi Notifikasi RD-014 dan keputusan scope Pesan RD-015 belum dimulai.
- Tidak ada perubahan scope atau implementasi fitur Tahap 4 yang dinyatakan selesai melalui koreksi ini.

## Antislop Delivery Gate

- R-02 PASS: copy baru tidak memakai em dash.
- R-03 dan R-34 PASS: 320 px dengan text scale 200 persen lulus pada light dan dark.
- R-17, R-18, dan R-38 PASS: tidak ada statistik, identitas, event, atau konten prototipe yang dipakai sebagai data aplikasi.
- R-23 PASS: tidak ada aset generatif atau foto contoh baru.
- R-24 dan R-26 PASS: action yang terlihat memiliki handler nyata; action tanpa capability disembunyikan.
- R-25 PASS: pasangan warna utama melewati WCAG AA untuk teks normal.
- R-27 PASS: state loading, empty, error, dan retry tetap tersedia pada layar data.
- R-32 PASS: kontrol Material memiliki keyboard focus dan tap target minimal 44 dp.
- R-33 PASS: implementasi berada di source Flutter dan tidak bergantung pada patch runtime prototipe.
- R-35 PASS: analyzer, 169 test, APK debug, web release, dan diff check lulus.
- UI PASS: struktur, hirarki, palette, typography, radius, shadow, section order, dan navigasi diturunkan langsung dari HTML.
- Mobile PASS: baseline 390 x 844, viewport 320 px, safe area, text scaling, dan bottom navigation tervalidasi.
- Human PASS: contrast, semantics, live error, focus, tap target, empty state, dan copy jujur dipertahankan.
- Code comments PASS: perubahan tidak menambah komentar naratif, separator, atau TODO samar.
- Copywriting PASS: CTA spesifik, Bahasa Indonesia ringkas, tanpa buzzword dan tanpa data rekaan.
