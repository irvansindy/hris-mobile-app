# Report QA-03: Provenance Binary Native

Tanggal: 21 Oktober 2026. Status: **IN_PROGRESS**, bukan persetujuan release.
Acuan: [audit dependency sebelumnya](<Report QA-03 Audit Dependency Native - 2026-10-20.md>).

## Hasil

Hash AAB dan seluruh 24 ELF masih cocok dengan inventaris 20 Oktober.
Asal byte setiap ELF dapat dihubungkan dengan arsip dependency, hasil strip,
atau intermediate build lokal. Ini tidak membuktikan semua source bebas
kerentanan, build reproducible, atau artifact production siap distribusi.

Artifact yang diperiksa adalah AAB validasi 20 Oktober, debug-signed dengan
endpoint `ci.invalid`, bukan RC final atau APK yang dibangun ulang 21 Oktober.
SHA-256 AAB:
`1acb8134348a855461f635ca06e8f157801daf8c28d7e3c029db5154e4509f82`.
Tidak membangun ulang aplikasi atau menjalankan ELF dalam putaran audit ini.

## Pemetaan Android

| Library pada tiga ABI | Jumlah ELF | Bukti |
| --- | ---: | --- |
| DataStore shared counter | 3 | Sama byte dengan AAR `androidx.datastore:datastore-core-android:1.1.7` |
| ML Kit face detector | 3 | Sama byte dengan AAR `com.google.mlkit:face-detection:16.1.7` |
| Camera image processing dan surface util | 6 | Sama byte dengan AAR `androidx.camera:camera-core:1.6.2` |
| Flutter engine | 3 | Sesudah `llvm-strip --strip-unneeded`, salinan binary JAR engine cocok dengan AAB |
| PDFium | 3 | Cocok dengan isi arsip distributor yang digest unduhannya diverifikasi |
| Dart JNI | 3 | Cocok dengan intermediate stripped release JNI lokal |
| Application AOT | 3 | Cocok dengan intermediate stripped release aplikasi; bukan pembuktian clean rebuild |
| Total | 24 | Seluruh hash baseline diverifikasi ulang |

Pemeriksaan menginspeksi 100 arsip AAR/JAR cache yang cocok dengan koordinat
graph release sebelumnya, bukan menganggap semua isi cache sebagai dependency
aplikasi. Pemetaan AAR ke ELF membuktikan kesamaan byte dengan cache resolved;
tidak memverifikasi attestation atau mengunduh ulang seluruh Maven artifact.

Engine mengikuti koordinat release dengan revision
`39c38b759eba9bcf048f203176845d7b1baef159`. Hash raw berbeda karena simbol;
hasil strip dengan NDK `28.2.13676358` cocok pada ketiga ABI. Hanya salinan
di `/tmp` diproses; cache engine asli tidak dimodifikasi.

JNI berasal dari package terkunci `jni 1.0.3`. CMake cache yang cocok dengan
direktori output menyatakan source package tersebut, `RelWithDebInfo`, dan NDK
yang sama. Cache versi JNI lain tidak dipakai sebagai bukti versi terpilih.

## PDFium Android

[Rilis distributor chromium/7811](https://github.com/bblanchon/pdfium-binaries/releases/tag/chromium%2F7811)
menyebut versi `149.0.7811.0`; file `VERSION` pada arsip yang diunduh cocok.
Metadata GitHub API menyatakan release immutable. Digest ketiga arsip cocok
dengan digest aset rilis, lalu `lib/libpdfium.so` di dalamnya cocok dengan AAB.

| Aset | SHA-256 arsip |
| --- | --- |
| pdfium-android-arm.tgz | bb9250eefb33343f56f27f7e60c81ab3236d932c40e21557bf02ca4c276eb832 |
| pdfium-android-arm64.tgz | f51539cadeb5135534305b8bdf8685ce2fbe9991dbbc5b35f553108411b9ed14 |
| pdfium-android-x64.tgz | 23faaf6f993a39524d9dc7fafbb760e295f8bd5e9ffa46139bad2299fb5c80f3 |

File `args.gn` yang diperiksa menyatakan V8 dan XFA nonaktif. Flag tersebut
tidak menghapus kebutuhan menilai kerentanan parser, font/image codec, dan
komponen native lain. Tidak memverifikasi source revision attestation atau
reproducibility distributor.

Arsip Pub `pdfium_dart 0.3.1`, `pdfium_flutter 0.3.1`, dan `jni 1.0.3` juga
cocok dengan checksum lockfile. Source hook PDFium, podspec dan CMake yang
diperiksa cocok dengan file pada arsip package terkait.

### Gap integritas jalur build

Hook `pdfium_dart 0.3.1` mengunduh TGZ melalui HTTPS lalu mengekstrak library
tanpa pemeriksaan checksum arsip. Bila file output sudah ada, hook langsung
menggunakannya tanpa memverifikasi ulang byte cache.

Audit provenance ini sendiri tidak memasang guard build. Tindak lanjut pada
21 Oktober telah menambahkan [guard post-build Android](<Report QA-03 Guard Integritas PDFium - 2026-10-21.md>)
untuk memeriksa ulang cache dan AAB terhadap baseline yang ditinjau sebelum upload
CI. Pengujian lokal, termasuk AAB baru, lulus. Verifikasi arsip sebelum ekstraksi
oleh hook upstream belum tersedia; remote CI dan artifact signed final belum
disahkan. Tidak memodifikasi pub cache atau menambahkan bypass.

## PDFium Apple

[Rilis XCFramework yang dinyatakan package](https://github.com/espresso3389/pdfium-xcframework/releases/tag/v144.0.7811.0-20260502-190206)
berlabel `144.0.7811.0`, tetapi menyebut upstream branch `chromium/7811`.
Jangan menyamakan label versi Apple dengan versi Android tanpa pemetaan source.

ZIP aktual 23.356.480 byte cocok dengan hash podspec, SPM dan digest aset rilis:
`948d9257f53f01cbed74b81bb8adc8758e52ac9390751772de7889026d32d5a1`.
Metadata `Info.plist` memuat iOS arm64/device, arm64+x86_64/simulator,
Mac Catalyst dan macOS. Rilis XCFramework ini tidak ditandai immutable pada API.

Ini memperbarui bukti unduhan yang sebelumnya pending, tetapi bukan resolusi
Pod/SPM pada proyek, pemeriksaan IPA, code signing, atau acceptance iOS.
Podspec memverifikasi ZIP saat unduh; marker hash pada cache bukan verifikasi
ulang seluruh isi framework yang sudah diekstrak.

## Triage advisory, belum ada clearance native

[Advisory resmi Chrome 2 Juni 2026](https://chromereleases.googleblog.com/2026/06/stable-channel-update-for-desktop.html)
mencantumkan lima issue PDFium: `CVE-2026-11303`, `CVE-2026-11304`,
`CVE-2026-11305`, `CVE-2026-11306`, dan `CVE-2026-11307`, masing-masing
bertingkat Low pada sumber tersebut. Ini kandidat triage, bukan daftar lengkap
advisory native atau bukti HRIS dapat dieksploitasi.

Versi fixed Chrome tidak cukup untuk menetapkan affected/not-affected pada
standalone PDFium ini. Security perlu memetakan source/fix revision, patch
distributor, build flags dan komponen bundled. Tidak menyimpulkan CVE pasti
berlaku atau otomatis memilih upgrade dari perbandingan nomor versi saja.

Hasil OSV Maven/Pub pada report 20 Oktober tetap terbatas pada ekosistem yang
di-query. Putaran ini tidak menjalankan ulang OSV penuh, fuzzing, atau PoC;
tidak mengubah statusnya menjadi audit kerentanan binary yang sudah selesai.
Retriever awal untuk halaman advisory tidak mendapat isi artikel; verifikasi
kemudian memakai isi halaman resmi melalui akses web alternatif.

## Bukti dan verifikasi

[JSON provenance](audits/2026-10-21-native-provenance.json) menyimpan klasifikasi
24 library, hash sumber/arsip, koordinat resolved, hasil strip, metadata PDFium,
dan batas bukti. Pemeriksa sementara menolak hash AAB/ELF baseline yang berbeda
dan jumlah ELF bukan 24; perbandingan hash PDFium/Flutter/intermediate juga
berhenti bila tidak cocok.

Arsip, metadata upstream dan skrip pemeriksa sementara berada di
`/tmp/hris-qa03-20261021.lJfcYL/`. Binary tidak dijalankan. Tidak mengubah source
aplikasi, dependency, SDK, signing, data HR atau kredensial. Lockfile tetap
`2d45b67589b1e2e3c61745c4f42f318481c09e7ea47eb0cab52164f6cf1d0f65`.
Tidak menjalankan ulang suite aplikasi; verifikasi pada putaran ini adalah
integritas artifact dan konsistensi bukti, bukan perubahan fitur.

## Pending untuk release

1. Tutup gap verifikasi arsip PDFium sebelum ekstraksi dan sahkan pemeriksaan
   artifact signed final di CI. Guard cache/AAB post-build sudah diterapkan dan
   lulus lokal; bagian tersebut tidak lagi pending implementasi.
   Owner: Mobile + Security/DevOps.
2. Tentukan applicability advisory dan kebutuhan patch/upgrade native dari
   source evidence, bukan hanya hasil scanner package. Owner: Security + Mobile.
3. Resolve/build iOS pada macOS, simpan lockfile dan cocokkan IPA aktual.
4. Ulang pemetaan pada toolchain, commit bersih dan artifact signed final;
   simpan hasil CI serta sign-off Security/DevOps.

Empat pending ini bagian dari QA-03 yang sudah ada, bukan task payung tambahan.
