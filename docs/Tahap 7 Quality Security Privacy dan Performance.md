# Tahap 7: Quality, Security, Privacy, dan Performance

Tanggal verifikasi: 10-11 Oktober 2026. Status: quality dan integration lokal PASS; exit gate release belum PASS.

## Perubahan

- Integrasi baseline tahap sebelumnya pada `9e92230`, termasuk helper permission, cleanup sesi, kontrak API, shared presentation, dan golden yang sebelumnya masih lokal. `AGENTS.md` yang sudah ada tidak diubah.
- Backup cloud dan transfer antarperangkat Android dibatasi melalui manifest dan sembilan domain exclusion. Resource hasil build diperiksa dengan `aapt2`, bukan hanya source XML.
- Keterangan izin kamera iOS menyebut setup Face ID, selfie verifikasi server, dan template demo lokal. Ini bukan persetujuan privacy policy untuk distribusi.
- Race refresh/logout diperbaiki: hasil refresh tidak dipublikasikan setelah lifecycle revision berubah selama penulisan secure storage. Regression menahan write, menjalankan logout, lalu memastikan sesi lama tidak kembali.
- Pin Flutter CI disamakan dengan SDK lokal yang diverifikasi: `19946f91c8d9de18a4674460d015229cc0b2534f`. Versinya masih channel master, bukan penetapan SDK stable untuk release.
- Android CI ditambah integration flow fixture di emulator API 35. Job macOS build iOS tanpa signing sudah tersedia; tidak dibuat ulang.
- Ditambah regresi locale perangkat ID/EN dan reduced motion. Locale aplikasi tetap Indonesia sesuai konfigurasi saat ini; pengujian ini tidak menyatakan semua halaman mendukung terjemahan Inggris.
- Cache Kotlin diabaikan oleh Git. Gambar failure lama, kredensial lokal, dan konfigurasi Firebase tidak dimasukkan ke commit.

## Bukti pengujian

Checkout bersih dibuat melalui clone lokal, tanpa `.env`, akun smoke, atau artifact dari working directory utama.

| Pemeriksaan | Hasil yang sudah diamati |
| --- | --- |
| Baseline penuh sebelum hardening | 619 test PASS |
| Backup Android | RED 3 test sebelum fix, GREEN 3 sesudah fix |
| Locale/reduced motion | 4 test PASS |
| Refresh/logout race | RED sebelum guard, GREEN sesudah guard; suite autentikasi 30 PASS |
| Workflow CI | 5 test PASS, termasuk konfigurasi integration emulator |
| Checkout bersih `a2c8cb4` | Format 276 file tanpa perubahan, analyzer 0 issue, 627 test PASS |
| Checkout final `f2e6ff5` | Format 276 file tanpa perubahan, analyzer 0 issue, seluruh 628 test PASS |
| Coverage Dart final | 9959/12352 line tercakup (80,63%); tidak mencakup kode native Android/iOS |
| Integration Android emulator final | 2 flow PASS: absensi diterima/ditolak, cancel, pengajuan, notifikasi, logout A ke B. Fixture tanpa akun/API live. |
| Android debug integration build final | PASS; APK fixture dipasang ke emulator, package flags tanpa `ALLOW_BACKUP`. Bukan APK distribusi. Cleartext debug tetap pengecualian yang diizinkan. |
| Android release App Bundle final | PASS dengan perintah CI normal; 88,3 MB, HTTPS compile-only dan logging off. App ID lama/debug signing; bukan artifact distribusi. |
| Lockfile sesudah resolve | Tidak berubah |
| Android profile build | PASS pada snapshot `d7e65a9`; bukan artifact release/distribusi |
| APK profile manifest | `allowBackup=false`, `fullBackupContent=false`, `usesCleartextTraffic=false`; resource extraction rules tersedia |
| Review independen | Race refresh diperbaiki; tidak ada Critical/Important tersisa dalam scope yang direview |

Log final disimpan lokal (Git-ignored) di `.superpowers/sdd/2026-10-11-stage7-quality/`: `full-tests.log`, `integration.log`, serta log release build/retry. Report ini menyimpan ringkasan hasilnya. Verifikasi GitHub Actions remote belum dijalankan; tidak ada push dalam pekerjaan ini.

App Bundle validasi final berukuran 88256630 byte; SHA-256 `78cd39e39bbc054ea166f7482eb11ce146ab58f8bd4b27e4b3d4cb370cbcdb35`. Artifact berasal dari source `f2e6ff5`, bukan build dengan signing/endpoint distribusi.

Setelah integration test, jangan memakai `--no-pub` untuk berpindah ke release build pada SDK ini: registrant native dapat masih memuat plugin dev `integration_test`, sedangkan release Gradle mengecualikannya. Percobaan tersebut gagal di `compileReleaseJavaWithJavac`. Pengulangan memakai perintah CI normal berhasil (Gradle 144,3 detik): Flutter meregenerasi tooling dengan filter dependency release, tanpa edit `GeneratedPluginRegistrant.java`. Log gagal dan retry disimpan terpisah.

## Audit keamanan dan privasi

| Data/kontrol | Kondisi dan batasan |
| --- | --- |
| Access/refresh token dan sesi | Secure storage; refresh single-flight dan logout isolation memiliki regression. Backup/migrasi iOS belum diuji fisik. |
| Face template demo | Secure store dengan namespace Android terpisah dan identitas employee/company. Bukan bukti keamanan biometrik setara hardware Face ID iOS. |
| Selfie production dan lokasi | Dipakai pada request absensi; cleanup temporary capture tersedia. Retensi server dan penghapusan data tetap perlu konfirmasi backend. |
| Logging | Regression metadata-only network logging dan release logging guard tersedia; jangan mengaktifkan body/header logger pada build production. |
| Payroll/PIN | Vault dan sensitive-screen tests tersedia. Screenshot/recording native Android/iOS tetap memerlukan acceptance fisik. |
| Transport | Cleartext hanya pengecualian debug; release memerlukan HTTPS. Build menggunakan `https://ci.invalid/api/v1`, bukan server staging yang dapat diakses. |
| Firebase | Tetap dummy/disabled sesuai keputusan pengguna. Cleanup token legacy perlu diselaraskan dengan coordinator sebelum provider nyata diaktifkan. |

Aturan cloud dan device transfer mengikuti [dokumentasi Android Auto Backup](https://developer.android.com/identity/data/autobackup). Tidak ada klaim bahwa exclusion Android membuktikan kebijakan Keychain iOS atau seluruh perilaku OEM.

Audit OSV pada 10 Oktober atas 188 package hosted Pub dari lockfile mengembalikan 188 hasil, tanpa advisory dan tanpa pagination. Cakupannya tidak termasuk dependency native Gradle/Swift/CocoaPods, source Git/path, atau kerentanan yang belum masuk database. API dan ordering hasil: [OSV querybatch](https://google.github.io/osv.dev/post-v1-querybatch/).

- SHA-256 lockfile: `2d45b67589b1e2e3c61745c4f42f318481c09e7ea47eb0cab52164f6cf1d0f65`.
- SHA-256 query metadata: `dbffff4cbdf7363f00f1a9d41c0353f5260e9847cd0b1dd28a656351e47052b3`.
- SHA-256 response: `4efe6b9cb33995f0632e7c419c9a8e7b676fd0d059ee65935d5e45aa5149ee5b`.

## Baseline performa emulator

Snapshot profile `d7e65a9`, Pixel_10a x86_64 API 37.1, GPU software. Pengukuran dilakukan bersamaan dengan suite lokal sehingga bukan benchmark perangkat target.

- Tiga process-cold launch melalui `am start -W`: TotalTime 4647, 5321, dan 5417 ms; median 5321 ms. Ini waktu Activity Android, bukan Flutter first-frame atau kesiapan seluruh halaman.
- PSS: 133631 KB; RSS: 258208 KB pada satu pengamatan halaman login. Bukan uji kebocoran memori.
- APK profile universal: 141370519 byte. Jangan dipakai sebagai ukuran download Play Store atau APK release per ABI.
- Jank Flutter, battery camera/GPS, ukuran IPA, dan target performa perangkat fisik belum diukur.

Warning `firebase_core` tentang KGP masih muncul. Package terpasang 4.15.0 menggunakan cabang kondisional untuk Kotlin; proyek memakai AGP 9.0.1 dan `android.builtInKotlin=true`. Build berhasil, tetapi warning tidak disembunyikan dan tidak dinyatakan selesai. Tidak ada patch pub cache atau upgrade dependency massal.

Pemeriksaan [source detector Flutter pada SDK yang dipin](https://github.com/flutter/flutter/blob/19946f91c8d9de18a4674460d015229cc0b2534f/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt) memastikan scanner memakai regex atas build script, bukan state plugin Gradle saat runtime. Karena itu warning atas deklarasi kondisional ini tidak membuktikan cabang KGP sedang dijalankan. SDK CI master dengan revision khusus didukung oleh [setup script flutter-action](https://github.com/subosito/flutter-action/blob/v2/setup.sh).

## Lanjutan

Gate yang belum tertutup ada di [Acceptance Release Gate Tertunda](Tahap%207%20Acceptance%20Release%20Gate%20Tertunda.md). Tahap 7 belum memenuhi exit gate full CI remote dan acceptance native/perangkat target.
