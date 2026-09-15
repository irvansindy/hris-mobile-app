# Tahap 5: RD-017 sampai RD-020

Tanggal: 15 September 2026. Scope: menyelesaikan hardening lokal redesign sebelum acceptance perangkat/staging. Referensi tetap HTML pengguna; avatar lingkaran mengikuti revisi eksplisit pengguna. Tidak dilakukan push, deployment, upgrade SDK, atau penggantian sesi emulator.

## Ringkasan status

| Task | Status | Bukti dan batas |
|---|---|---|
| RD-017 | BLOCKED backend | Audit payroll selesai; kontrak list tanpa nominal, PIN/unlock expiry dan PDF belum tersedia. |
| RD-018 | REVIEW lokal | Light/dark, locale Indonesia, teks panjang, empat text scale, keyboard/safe-area simulasi dan golden diuji; perangkat nyata belum. |
| RD-019 | REVIEW lokal | Reduced motion dan feedback nonblocking diuji; frame rendering perangkat kelas menengah belum diukur. |
| RD-020 | REVIEW lokal, belum DONE release | Regresi/fixture/golden dan CI diperluas; integration perangkat, CI macOS dan staging belum dibuktikan. |

## RD-017: keputusan keamanan payroll

[Audit kontrak slip gaji](<RD-017 Kontrak Slip Gaji Terlindungi.md>) mencatat kebutuhan backend secara terpisah dari endpoint yang sudah disepakati. Dokumen API terbaru hanya menyediakan list/detail payslip, belum mekanisme unlock server yang memenuhi acceptance redesign.

Tidak ada request payroll pada bootstrap/Profil, sheet PIN semu, biometric unlock lokal, nominal/PDF contoh atau tombol download/share yang belum bekerja. Regresi mempertahankan tidak terpetakannya salary Profil dan tidak dirilisnya tombol Slip gaji, bahkan untuk fixture dengan `payroll:read`. Screenshot protection dan cleanup payroll belum diimplementasikan karena fitur belum dapat diintegrasikan aman.

## RD-018: layout, locale dan aksesibilitas

- Material/Cupertino localization Indonesia dipasang pada aplikasi; tanggal input, Batal dan dialog native Material tidak lagi mengikuti default Inggris. `CFBundleLocalizations` iOS mencatat `id`. Bahasa login ID/EN tetap hanya copy login yang memang tersedia, bukan klaim seluruh aplikasi bilingual.
- Dependency `intl` disesuaikan ke 0.20.3 mengikuti `flutter_localizations` SDK. `table_calendar` dan dependency transitifnya dihapus karena tidak dipakai: Kalender sudah memakai grid custom. Tidak dilakukan upgrade dependency massal.
- Matriks 32 konfigurasi: dua tema, empat skala teks 1.0/1.3/1.5/2.0, dua ukuran 320 x 568 dan 430 x 932, serta dua `TargetPlatform` Android/iOS. Setiap konfigurasi memeriksa 11 screen dan lima shared states, termasuk scroll, string panjang dan safe-area top 44/bottom 34. Konfigurasi platform bukan bukti menjalankan iOS/Android native.
- Navigasi dapat menampung label dua baris hingga teks 200%; tinggi menyesuaikan. Layar employee-access unavailable dapat discroll. Label kata sandi panjang memakai label terpisah ketika teks besar agar tidak terpotong; CTA formulir/auth mempunyai minimum tinggi, bukan tinggi yang memotong teks.
- Dropdown cuti memakai menu wrap, expanded field dan tooltip nama penuh untuk selection yang ringkas. Overflow jenis cuti panjang ditemukan pada audit dan diperbaiki.
- Date picker default tetap kalender. Pada text scale di atas 1.4, dialog memakai mode input-only SDK agar header kalender tidak overflow pada layar kecil, tanpa mengurangi text scale seluruh aplikasi. Mode input dan locale/reduced motion diuji; tidak dibuat parser tanggal atau estimasi saldo yang menggantikan validasi server.
- Simulasi keyboard 250dp pada layar 320 x 568 dengan teks 200% memeriksa field login/change-password tetap dapat dicapai di atas keyboard. Keyboard native, gesture serta layout kamera/izin tetap perlu perangkat.
- Contrast tests memeriksa 13 pasangan teks minimal 4.5:1 dan dua pasangan outline control minimal 3:1. Checker subtitle light `#667085` pada `#F3F4F6`: 4.52:1; subtitle dark `#9AA8BD` pada `#161F31`: 6.83:1. Footer splash/feedback baru memakai putih solid agar teks kecil tetap terbaca.
- Format Rupiah payroll tidak dibuat sebagai formatter/data nominal tak terpakai. Acceptance itu menunggu kontrak payroll.

## RD-019: motion yang mengikuti kebutuhan pengguna

`AppMotion` membaca preferensi platform melalui [MediaQuery.disableAnimationsOf](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html). Durasi FAB/scroll/theme menjadi nol, sheet/dialog memakai `AnimationStyle.noAnimation`, dan transisi halaman melewati efek visual ketika preferensi aktif. Default transisi Android/iOS/macOS tetap memakai builder platform SDK ketika motion diizinkan.

Semua sheet produksi yang dirilis memakai safe area atas dan kebijakan motion yang sama. Flutter mendokumentasikan bahwa `useSafeArea: false` menghapus padding atas sehingga SafeArea di dalam sheet tidak cukup untuk memulihkannya. [Dokumentasi showModalBottomSheet](https://api.flutter.dev/flutter/material/showModalBottomSheet.html)

Loading dengan reduced motion memakai hourglass statis dan live semantics, bukan spinner berulang atau persen fiktif. Busy state tetap berlangsung sampai operasi selesai. Donut kehadiran tetap determinate berdasarkan nilai yang tersedia; tidak ditambah animasi loop. Feedback login normal tidak menangkap tap dan tidak lagi menampilkan progress persiapan sesudah sesi siap. Pada reduced motion overlay/timer feedback tidak ditunggu. Memilih ulang tab kembali ke atas langsung melalui `jumpTo`.

Tujuh motion tests melindungi helper, FAB, loading statis/semantics, sheet/dialog close, serta delegate halaman. Router test tambahan melindungi login tanpa overlay, scroll-to-top dan tombol absensi saat disable animations aktif. Tidak ada angka FPS/dropped frame yang diklaim tanpa pengukuran perangkat.

## RD-020: regresi, baseline dan CI

`test/support/redesign_flow_fixture.dart` menyediakan repository sesi A/B, absensi, lokasi, pengajuan, kalender dan notifikasi yang hanya diimpor test. Tidak memakai jaringan, akun nyata, kamera/GPS native atau secure storage produksi. Repository fixture diganti berdasarkan sesi agar uji isolasi tidak memakai state akun lama.

Dua alur lengkap memakai router/aplikasi nyata: login A, chat unavailable, baca notifikasi, kalender sebelumnya/berikutnya, absensi cancel lalu submit sukses/ditolak, pengajuan cuti dengan input tanggal Indonesia, daftar pengajuan, system back, logout dan login B. Test membuktikan penolakan tidak menghasilkan absensi sukses, submit cancel tidak dipanggil, badge baru pulih dan repository absensi/pengajuan A tidak dibawa ke B. Fixture tidak membuktikan otorisasi server.

Alur yang sama tersedia pada `integration_test/redesign_flow_test.dart` melalui IntegrationTestWidgetsFlutterBinding. Dependency integration_test SDK hanya untuk pengujian. Menjalankannya di emulator akan mengganti sesi aplikasi aktif; belum dilakukan tanpa persetujuan pengguna. Perintah setelah izin dan pemilihan device:

```sh
flutter test integration_test/redesign_flow_test.dart -d <device-id>
```

CI memformat `lib test tool integration_test`, menganalisis, menjalankan safety guards dan seluruh suite dengan coverage. Golden gagal diunggah sebagai artifact untuk diperiksa; baseline tidak diperbarui otomatis CI. Android tetap membangun guarded production AAB. Signing release Android masih memakai debug signing config yang sudah ada; artifact diberi nama debug-signed-validation agar tidak disalahartikan sebagai unsigned atau siap Play Store. Signing production tidak dibuat tanpa keystore/kebijakan rilis. Job iOS baru memakai macOS, production HTTPS/logging-off, `--no-codesign` dan artifact app unsigned, bukan IPA siap distribusi. Belum ada workflow remote yang dipicu.

Pin SDK CI disamakan dengan SDK lokal yang benar-benar diuji: Flutter master commit `2553f89be1efa62eeb7b3aeea68fc9f80336ee54`, Flutter 3.48.0-1.0.pre-739 dan Dart 3.14.0 dev. SDK lokal berbeda dari pin Tahap 4; penyesuaian ini mencatat lingkungan aktual, bukan menjalankan upgrade SDK. Native build dan golden perlu diuji ulang sebelum mengganti pin berikutnya.

### Baseline visual baru

16 golden light/dark pada 320 x 720 dan teks 200% mencakup login, change-password, employee-access unavailable, pengajuan, form cuti/izin, loading dan error. Font Plus Jakarta Sans/MaterialIcons serta shadow sebenarnya dipakai. Clock login dioverride menjadi 14 September 2026 agar golden tidak berubah setiap hari. Screenshot merupakan posisi scroll awal; widget tests memeriksa bagian bawah melalui scroll.

- [Login light](../test/goldens/stage5/login_fixture_light_320_text200.png), [Login dark](../test/goldens/stage5/login_fixture_dark_320_text200.png)
- [Change password light](../test/goldens/stage5/change_password_fixture_light_320_text200.png), [Change password dark](../test/goldens/stage5/change_password_fixture_dark_320_text200.png)
- [Cuti light](../test/goldens/stage5/leave_form_fixture_light_320_text200.png), [Cuti dark](../test/goldens/stage5/leave_form_fixture_dark_320_text200.png)
- [Loading light](../test/goldens/stage5/loading_fixture_light_320_text200.png), [Loading dark](../test/goldens/stage5/loading_fixture_dark_320_text200.png)

Baseline Beranda/Kalender/Notifikasi/Profil 390 x 844 Tahap 4 tetap diuji tanpa regenerasi. Gambar login/change-password/cuti/loading Tahap 5 diperiksa visual dari file lokal; tidak dianggap screenshot emulator.

### Quality gate lokal

- `dart format --output=none --set-exit-if-changed lib test tool integration_test`: PASS, 163 file, 0 perubahan.
- `flutter analyze`: PASS, tidak ada issue.
- `flutter test --coverage --reporter=expanded`: PASS, 283 test termasuk 32 konfigurasi matriks UI dan 16 golden baru. Coverage tersedia pada `coverage/lcov.info`.
- `flutter build apk --debug`: PASS, `build/app/outputs/flutter-apk/app-debug.apk`; tidak diinstal ke emulator.
- `flutter build web --release` dengan `APP_ENV=production`, `BASE_URL=https://ci.invalid/api/v1` dan `ENABLE_LOGGING=false`: PASS untuk JavaScript, output `build/web`. Wasm dry-run masih gagal karena legacy imports dependency flutter_secure_storage_web; tidak diklaim mendukung Wasm.
- `flutter build appbundle --release` dengan environment production/HTTPS/logging-off yang sama: PASS, `build/app/outputs/bundle/release/app-release.aab` (57.3 MB). Artifact validasi memakai debug signing, bukan signing Play Store.
- Setelah penjelasan signing/nama artifact diperbaiki, empat architecture CI tests diuji ulang: PASS. Jumlah suite tetap 283; tidak ada perubahan runtime produksi setelah suite lengkap.
- `git diff --check`: PASS.
- Linux lokal tidak mendukung build iOS; konfigurasi job macOS bukan bukti build lulus. Device integration, staging, real permission/GPS/selfie dan performa belum diuji dalam Tahap 5.

### Click-through lokal

- Auth: field, visibility password, submit/validation/error/retry serta flow logout diuji regresi; footer/link konfigurasi tetap tidak mengarang URL privasi.
- Shell/Beranda: empat tab, selection ulang, FAB absensi, quick action cuti, inbox badge dan chat unavailable/Tutup bekerja. Tidak ada badge chat rekaan atau tombol payroll belum tersedia.
- Absensi: cancel tanpa submit, GPS/selfie mocked sesuai capability, submit sukses/ditolak dan recovery app settings diuji. Kamera/GPS/izin/settings native belum dibuktikan pada perangkat.
- Pengajuan: jenis, rentang tanggal, alasan, review, Batal/Kirim, daftar/filter/page/detail/cancel yang tersedia dilindungi fixture atau test kontrak/widget sebelumnya. Galeri/lampiran native dan keputusan approval server bukan acceptance lokal.
- Kalender: bulan sebelumnya/berikutnya, tanggal, Today, retry/refresh dan keyboard dilindungi regresi Tahap 4; alur fixture menguji perpindahan bulan.
- Notifikasi: semua/belum dibaca/approval, read/read-all, retry/load-more/refresh, item resource, sheet Tutup dan Kembali dilindungi regresi. Push native belum tersedia.
- Profil: tema, metadata, retry/detail dan Keluar diuji. Informasi bahasa/versi tidak menjadi toggle palsu; dokumen/atasan/payroll yang belum dikontrakkan tidak dirilis sebagai kontrol mati.

## Antislop Delivery Gate: hanya scope UI lokal yang diuji

### Hard Gate

- R-02 PASS: copy baru tidak memakai em dash.
- R-03 PASS: matriks dua ukuran, empat skala dan kedua tema/platform host tidak overflow.
- R-17 PASS: fixture berada di test; produksi tetap menggunakan server/empty state.
- R-18 PASS: tidak ada identitas atau testimonial rekaan dalam provider produksi.
- R-23 PASS: tidak dibuat foto/logo/aset dekoratif baru; font/ikon tetap aset berlisensi yang ada.
- R-24 PASS: resource route allowlist dan protected route tetap diuji.
- R-25 PASS: pasangan utama teks/control memenuhi contrast tests; checker subtitle light/dark dijalankan.
- R-26 PASS: kontrol dalam scope memiliki handler; payroll/chat/push tidak dipalsukan.
- R-27 PASS: shared loading/empty/error/offline/permission serta state fitur diuji.
- R-28 PASS: tidak menambahkan FAQ/promosi.
- R-32 PASS: keyboard/semantics/loading, Escape sheet/dialog dan system back lokal diuji.
- R-33 PASS: source diedit dengan apply_patch; formatter/golden generator hanya untuk output mekanis.
- R-34 PASS: light/dark dan preferensi tema tetap dilindungi regresi.
- R-35 REVIEW release: bukti lokal dicatat; perangkat/staging/macOS CI belum lulus acceptance.
- R-36 PASS: tidak mengklaim PIN/screenshot protection/payroll atau server smoke yang belum tersedia.
- R-37 PASS: Design Read ESS Indonesia dengan dials 2/2/2 dinyatakan sebelum implementasi.
- R-38 PASS: fixture test tidak dimasukkan ke bootstrap atau provider produksi.

### Purpose Gate

- R-01 PASS: tidak ada gradient/glow baru.
- R-04 PASS: hourglass menyampaikan proses aktif ketika animasi dinonaktifkan.
- R-06 PASS: Plus Jakarta Sans dan hierarki handoff dipertahankan.
- R-07 PASS: grid hanya kalender nyata, bukan background dekorasi.
- R-08 PASS: chevron tetap navigasi/tanggal, bukan ornamen CTA.
- R-09 PASS: badge/filter mempunyai count/selection yang bermakna.
- R-10 PASS: tidak menambahkan glassmorphism.
- R-12 PASS: elevation/shadow tetap token handoff.
- R-13 PASS: tidak ada glow dekoratif tambahan.
- R-14 PASS: composition screen tidak diubah menjadi kartu seragam tanpa fungsi.
- R-19 PASS: reduced motion statis; motion normal hanya proses/interaksi aktif.
- R-22 PASS: tidak menambahkan ilustrasi generik.

### Liveliness

- Dials PASS: ENERGY 2 / RHYTHM 2 / MOTION 2 tidak dinaikkan.
- Konsistensi PASS: perubahan hanya hardening desain HTML dan revisi avatar pengguna.
- Fokus PASS: dialog input menyelesaikan pemilihan tanggal, bukan menambah layar dekoratif.
- Whitespace PASS: safe-area, scroll dan label panjang mempunyai ruang yang terukur.
- Accent PASS: biru tetap aksi/seleksi, semantic tones untuk status.
- Motif PASS: font, kartu lembut dan avatar inisial tetap konsisten.
- Design Read PASS: acuan handoff pengguna dan scope ESS dinyatakan sebelum tindakan.

### Craftsmanship dan quality locks

- C-1 PASS: perubahan label/nav/date mode dicatat sebagai responsivitas, bukan reinterpretasi tampilan normal.
- C-2 PASS: kontrol tetap terhubung; fitur tanpa kontrak tetap unavailable/hidden.
- C-3 PASS: setiap perubahan melayani aksesibilitas, feedback atau verifikasi rilis.
- C-4 REVIEW perangkat: widget/golden/keyboard simulasi tersedia; native gesture/performance belum.
- C-5 PASS: fixture, host test, build-only artifact dan staging dibedakan eksplisit.
- R-05 PASS: tidak menambah template hero/stat/chart.
- R-11 PASS: avatar lingkaran sesuai koreksi pengguna; radius control/kartu tetap handoff.
- R-15 PASS: CTA menyebut tindakan nyata Batal/Kirim/Tutup/Muat ulang.
- R-16 PASS: tidak ada buzzword pemasaran baru.
- R-20 PASS: hardening spesifik auth/ESS/absensi/payroll, bukan dashboard generik.
- R-21 PASS: light default dan preferensi dark dipertahankan.
- R-29 PASS: warna memakai token tema bersama.
- R-30 PASS: referensi adalah HTML pengguna, bukan produk lain.
- R-31 PASS: alasan layout/motion/locale/dependency dicatat bersama bukti test.

### Checklist skill pendamping

- UI PASS lokal: hardening mempertahankan komposisi normal; golden kecil/teks besar diperiksa.
- Mobile PASS lokal, REVIEW native: wrap/scroll, target/nav/safe-area dan keyboard simulasi diuji.
- Human PASS lokal, REVIEW native: contrast, semantics, keyboard, teks besar dan reduced motion diuji.
- Copy PASS: Bahasa Indonesia dan batas unavailable/fixture dinyatakan tanpa klaim keberhasilan semu.

## Syarat berikutnya sebelum DONE release

1. Backend melengkapi kontrak perlindungan payroll RD-017; tanpa itu payroll dikeluarkan dari scope rilis.
2. Jalankan integration fixture dengan izin penggantian sesi emulator, lalu QA Android/iOS nyata: gesture/keyboard, lokasi, kamera/selfie, izin permanen, galeri/file dan lifecycle.
3. Jalankan workflow quality/Android/iOS pada remote runner; sediakan keystore/signing production Android dan signing/distribution iOS terpisah, bukan artifact debug-signed/unsigned CI.
4. Ukur rendering/performance di perangkat kelas menengah, termasuk cold restore, scroll dan kamera; jangan menyimpulkan FPS dari durasi test host.
5. Sediakan server HTTPS staging, akun employee/manager khusus uji serta fixture deployment tersanitasi. Verifikasi auth restore/refresh, identitas/company, absensi nyata sukses/ditolak dan isolation antarakun.
6. Kontrak/kebijakan live yang sebelumnya tertunda tetap diperlukan: timezone kantor, kalender tim, push token, atasan/dokumen, URL privasi dan konfigurasi transport production.

Warning kompatibilitas `package_info_plus` yang menerapkan KGP tetap dicatat; migrasi plugin harus dilakukan sebelum upgrade Flutter yang mewajibkan Built-in Kotlin, bukan hanya disembunyikan dari log. [Panduan migrasi Flutter](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
