# Report QA-03: Audit Dependency Native

Tanggal: 20 Oktober 2026. Status keseluruhan: **IN_PROGRESS**.
Acuan: [rekap task](<Rekap Seluruh Task Belum Selesai - 2026-10-19.md>).

Audit lokal Maven/Pub dan perbaikan JUnit profile selesai. Audit binary native,
resolusi iOS, serta pengulangan pada toolchain release final masih diperlukan.
Report ini bukan persetujuan go-live atau pernyataan aplikasi bebas kerentanan.

Pembaruan 21 Oktober: [audit provenance binary](<Report QA-03 Provenance Binary Native - 2026-10-21.md>)
memverifikasi ulang hash 24 ELF, memetakan AAR/Flutter/JNI/PDFium ke artifact,
dan mencocokkan unduhan XCFramework dengan checksum yang dinyatakan package.
Gap checksum hook Android, applicability advisory native, IPA dan artifact final
tetap terbuka. Hasil historis 20 Oktober di bawah tidak diganti dengan klaim
release clearance.

## Scope dan baseline

- HEAD `b90f8db62e53705d0e957459c2ee615b36274b78` dengan perubahan kerja aktif.
- SDK/CI utama tetap pada pin sebelumnya; promosi stable masih QA-02 PENDING.
- Gradle 9.1.0, AGP 9.0.1, built-in Kotlin; versi dependency tidak dinaikkan
  secara massal. Tidak mengubah SDK, pub cache, signing, atau konfigurasi Firebase.
- Tidak menjalankan login, mengirim absensi, atau mengubah data bisnis server.
- Graph memakai `incoming.resolutionResult`, menolak unresolved dependency dan
  graph kosong. Data diambil dari resolusi Gradle, bukan parsing tree teks.

## Hasil resolusi Android

| Configuration | Pasangan module/versi | JUnit sebelum | JUnit sesudah | Unresolved |
| --- | --- | --- | --- | --- |
| debugRuntimeClasspath | 165 | 4.13.2 | 4.13.2 | 0 |
| profileRuntimeClasspath | 165 | 4.12 | 4.13.2 | 0 |
| releaseRuntimeClasspath | 155 | Tidak ada | Tidak ada | 0 |
| coreLibraryDesugaring | 2 | Tidak ada | Tidak ada | 0 |

Gabungan pascapatch: **175 pasangan Maven unik**, termasuk metadata BoM dan
dependency khusus varian. Ini bukan jumlah library binary yang dipaketkan.
Snapshot juga memuat **188 package Pub hosted**, termasuk dependency dev/test;
root dan package SDK tidak dikirim sebagai package Pub.

Versi penting: Firebase BoM 34.19.0, firebase-common 22.2.1,
firebase-messaging 25.1.3, Kotlin stdlib 2.2.10,
desugar_jdk_libs 2.1.5. Lockfile Pub tidak diubah.

## Temuan JUnit dan perbaikan

`profileRuntimeClasspath` masih memilih JUnit 4.12 melalui:

```text
integration_test -> androidx.test:runner:1.3.0 -> junit:junit:4.12
```

Patch sebelumnya hanya mencakup debug. OSV mengembalikan
[GHSA-269g-pwp5-87pp](https://osv.dev/vulnerability/GHSA-269g-pwp5-87pp)
untuk pasangan profile tersebut. Ini temuan dependency pengujian, bukan bukti
kebocoran data HR atau eksploitasi aplikasi release.

Constraint JUnit 4.13.2 sekarang mencakup `debugImplementation` dan
`profileImplementation`. Release tetap tidak memuat JUnit. Tidak memakai
global force, menambah library test ke release, atau mengedit dependency upstream.

Regresi nyata tersimpan di `tool/verify_android_dependencies.gradle`:

```bash
# Jalankan dari android/
rtk proxy ./gradlew :app:verifyDependencySafety -I ../tool/verify_android_dependencies.gradle
```

- RED sebelum patch: task gagal karena profile memilih 4.12.
- GREEN sesudah patch: debug/profile 4.13.2, release kosong, graph tidak kosong
  dan tidak memiliki unresolved dependency.
- Jika SDK mendatang tidak lagi membawa JUnit pada debug/profile, graph tetap
  harus resolved dan tidak kosong. Semua JUnit yang ditemukan harus 4.13.2.
- Task ini guard regresi JUnit, bukan scanner seluruh dependency. Jalankan audit
  advisory ulang ketika graph/lockfile berubah. Task belum dipasang di remote CI.

## Hasil OSV

Query awal: 364 pasangan (176 Maven, 188 Pub), satu package terdampak:
JUnit 4.12 pada profile. Query pascapatch pada 20 Oktober 2026 pukul
11:13:13 UTC: **363 pasangan dan 363 respons**, tidak ada advisory dikembalikan.

Setiap putaran menyertakan satu query kontrol tambahan JUnit 4.12 yang wajib
mengembalikan GHSA di atas. Kontrol berhasil dan tidak dimasukkan dalam angka
package aplikasi. Tidak ada pagination yang tertunda. Urutan hasil mengikuti
[kontrak querybatch OSV](https://google.github.io/osv.dev/post-v1-querybatch/).

Hanya nama dan versi package publik dikirim; tidak mengirim source, password,
token, selfie, isi slip, atau data HR. Hasil tanpa advisory bergantung pada
cakupan database saat query dan tidak membuktikan tidak ada kerentanan lain.

Inventaris, scope per package, hasil sebelum/sesudah, timestamp, dan hash file
baseline disimpan di [bukti audit JSON](audits/2026-10-20-native-dependencies.json).

## iOS dan binary di luar graph Maven/Pub

| Area | Bukti lokal | Status |
| --- | --- | --- |
| Plugin iOS | 16 plugin terdaftar; 15 native, termasuk 1 dev integration_test. Ada 14 plugin native non-dev. | Inventaris deklarasi selesai; bukan graph transitive resolved. |
| Dependency manager | SPM pada metadata lokal false; generated Package.swift kosong. Belum ada Podfile, Podfile.lock, atau Package.resolved hasil resolusi. | PENDING macOS/Xcode dan dependency resolution. |
| Target iOS | Runner 15.5; podspec MLKit commons/face detection mensyaratkan 15.5. | Cocok pada deklarasi; build native belum diverifikasi. |
| Firebase iOS | Script firebase_core mendeklarasikan SDK 12.19.0. | Versi deklarasi, belum dibuktikan lockfile/build. |
| PDFium iOS | pdfium_flutter 0.3.1 merujuk XCFramework v144.0.7811.0, dengan checksum arsip di podspec/Package.swift. | PENDING verifikasi unduhan aktual, provenance, dan advisory binary. |
| PDFium non-iOS | Hook pdfium_dart 0.3.1 mengunduh release chromium/7811 melalui HTTPS dan memakai cache file; hook yang dibaca tidak memverifikasi checksum arsip. | PENDING kebijakan integritas/provenance dan pemetaan binary aktual. Bukan bukti artifact telah dimodifikasi. |

Host Linux ini tidak menyediakan Xcode, CocoaPods, atau Swift untuk acceptance
iOS. Jangan mengganti ketiadaan lockfile dengan daftar podspec lalu menyebutnya
audit iOS selesai. Checksum package Pub juga tidak membuktikan integritas semua
binary yang diunduh terpisah oleh hook.

## Verifikasi lokal dan batasnya

- Full suite dengan coverage: **653 test PASS**, exit 0, sekitar 1 menit 40 detik.
- Analyzer: tidak ada issue. Format: 282 file, 0 perubahan.
- Regresi Gradle JUnit dan ekspor graph: exit 0, BUILD SUCCESSFUL.
- JSON bukti audit dapat diparse dan jumlah record cocok dengan hasil query.
- Build AAB validasi setelah regenerasi standar: **PASS**, exit 0, sekitar
  122,7 detik, 88.295.186 byte (88,3 MB desimal).

### Build dan inventaris artifact

Percobaan pertama dengan `--no-pub` gagal pada `compileReleaseJavaWithJavac`:
registrant Java generated yang stale masih merujuk `IntegrationTestPlugin`,
sementara dependency release memang tidak membawa plugin dev tersebut.
File generated bukan tracked source. Build ulang memakai alur standar Flutter
tanpa `--no-pub` meregenerasi registrant, menghapus referensi dev, lalu berhasil.
Tidak mengedit registrant secara manual atau menambah integration_test/JUnit
ke release. Hash lockfile dan file baseline tetap cocok dengan bukti JSON.

```bash
rtk flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=BASE_URL=https://ci.invalid/api/v1 \
  --dart-define=ENABLE_LOGGING=false \
  --dart-define=PUSH_MODE=disabled
```

Artifact: `build/app/outputs/bundle/release/app-release.aab`.
SHA-256: `1acb8134348a855461f635ca06e8f157801daf8c28d7e3c029db5154e4509f82`.
Ini **release-validation dengan debug signing**, app ID lama dan endpoint
`ci.invalid` khusus kompilasi guard. Bukan signed staging/production atau artifact
untuk instalasi UAT. Warning KGP/DSL masih QA-02; tidak disembunyikan.

Ekstraksi hanya entry library dan pembacaan header melalui `readelf` menemukan
24 ELF: delapan nama pada masing-masing arm64-v8a, armeabi-v7a, dan x86_64:
libapp, libdartjni, libdatastore_shared_counter, libface_detector_v2_jni,
libflutter, libimage_processing_util_jni, libpdfium, dan libsurface_util_jni.
Nama, ukuran, hash, build ID dan alignment segmen disimpan di
[inventaris artifact](audits/2026-10-20-native-artifact.json).
Library tidak dieksekusi oleh proses inventaris. Pemeriksaan ini tidak memberi
clearance kerentanan binary, provenance upstream, atau acceptance perangkat.

`jarsigner -verify` menghasilkan exit 0 dan `jar verified`, tetapi juga memberi
warning chain PKIX/self-signed, signature tanpa timestamp, dan perbedaan
interpretasi entry JarFile/JarInputStream (termasuk manifest). Hasil tersebut
dicatat, bukan dianggap signing production PASS. Verifikasi distribusi melalui
tooling Android serta penyelesaian warning pada signing/artifact final tetap
bagian gate release; tidak menambahkan bypass atau mengganti key pada putaran ini.

Log sementara berada di `/tmp/hris-qa03-20261020.WGZoO7/`: `junit-red.log`,
`junit-green.log`, `profile-junit-insight.log`, `gradle-audit.log`,
`osv-before.json`, `osv-after.json`, `flutter-tests.log`, `release-build.log`
(percobaan gagal), `release-build-regenerated.log` (build berhasil), dan
`aab-signature.log` (hasil lengkap verifikasi beserta warning).
Direktori temporary bukan penyimpanan artifact release permanen; inventaris
yang disanitasi sudah disimpan di repository.

## Pending untuk menutup QA-03

1. Tetapkan toolchain/configuration final melalui QA-02, lalu ulang resolusi
   dan advisory scan. Evaluasi dependency build tooling/NDK/engine secara
   terpisah; daftar runtime Maven tidak mencakup semuanya.
2. Validasi library dalam AAB/IPA final, asal-versi-hash dan advisory native,
   terutama binary FFI/PDFium dan SDK vendor. Inventaris ELF bukan audit kode
   binary atau bukti tidak ada kerentanan.
3. Resolve iOS pada macOS, simpan lockfile/package resolution dan checksum
   artifact, audit dependency transitive, lalu build unsigned dan acceptance.
4. Simpan hasil remote CI pada commit final, artifact dan persetujuan owner
   Security/DevOps. Guard JUnit manual tidak menggantikan gate CI tersebut.

Temuan JUnit profile selesai secara lokal. QA-03 tetap IN_PROGRESS karena
keempat syarat di atas belum seluruhnya terpenuhi; task eksternal tidak ditutup.

## Review patch

Reviewer terpisah melakukan review read-only pada constraint profile, regresi
Gradle, README dan bukti JSON. Tidak ada temuan Critical, Important, atau Minor
dalam scope tersebut; hash file bukti cocok dengan file saat review.

Reviewer tidak menilai perubahan user lain di checkout, perilaku API/Firebase,
signing/SDK yang sudah ada, cakupan kerentanan iOS/binary native, atau keberhasilan
build release yang saat itu belum selesai. Keputusan pelaksana: review kecil
ini hanya menerima patch JUnit; semua area tersebut tetap pada gate terkait.
Tidak menyatakan seluruh branch siap merge atau release.
