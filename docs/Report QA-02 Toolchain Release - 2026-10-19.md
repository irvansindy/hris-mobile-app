# Report QA-02: Toolchain Release

Tanggal: 19 Oktober 2026. Status: **PENDING** untuk promosi toolchain release.
Investigasi lokal selesai; kandidat stable belum memenuhi gate build Android.

## Keputusan

Pertahankan pin CI dan SDK utama yang masih bekerja. Jangan mempromosikan
stable hanya karena unit/widget/golden test lulus. Tidak menggunakan flag skip
validasi, mengedit SDK/pub cache, atau menaikkan Firebase major untuk menutup
warning tanpa bukti kompatibilitas.

QA-02 tetap terpisah dari audit dependency QA-03 dan acceptance perangkat.
Tidak ada login, absensi, atau mutasi bisnis server pada pengujian ini.

## Lingkungan pengujian

- Baseline repository: `b90f8db62e53705d0e957459c2ee615b36274b78`, dengan
  perubahan kerja aktif, bukan checkout bersih.
- SDK utama: Flutter `3.50.0-0.1.pre`, pin CI
  `19946f91c8d9de18a4674460d015229cc0b2534f`.
- Kandidat: Flutter `3.47.7`, Dart `3.13.5`, tag resmi pada
  `abaf9c523780a608bd46686fd5e53740a07077f8`.
- SDK dan snapshot aplikasi terisolasi di `/tmp/hris-qa02.i0sSKn`.
  Tidak menyalin kredensial smoke, `.env`, atau konfigurasi Firebase pribadi.
- Resolve kandidat menghapus transitive `listen` dan mengganti `test_api`
  `0.7.14` menjadi `0.7.12`. Lockfile repository utama tidak diubah.

Versi kandidat diverifikasi melalui [arsip resmi Flutter](https://docs.flutter.dev/install/archive).

## Hasil kandidat stable

| Pemeriksaan | Hasil |
| --- | --- |
| Analyzer | PASS, tidak ada issue |
| Format | PASS, 282 file, 0 perubahan |
| Suite awal | 652 PASS, 1 gagal pada navigasi fixture |
| Fixture setelah perbaikan | 2 PASS |
| Suite ulang setelah perbaikan | 653 PASS |
| Android debug, AGP 9.0.1 / Gradle 9.1.0 | FAIL, validasi Kotlin |
| Android debug, AGP 9.1.0 / Gradle 9.3.1 | FAIL, validasi Kotlin yang sama |
| Pasangan kedua + classpath KGP 2.4.0 | FAIL, tetap mendeteksi Kotlin 2.2.10 |

Ketiga build berhenti saat konfigurasi plugin Flutter: Kotlin `2.2.10`
lebih rendah daripada batas `2.2.20`. Belum menghasilkan APK kandidat;
iOS kandidat belum diuji. Perubahan matriks hanya ada pada snapshot sementara.

## Perbaikan yang dipertahankan

`test/support/redesign_flow.dart` mengetuk ulang tab Beranda setelah submit
cuti, sebelum membuka shortcut Pengajuan. Halaman mempertahankan posisi scroll;
shortcut di atas viewport sebelumnya tidak ditemukan helper yang mencari ke
bawah. Ketukan tab memakai perilaku scroll-to-top aplikasi yang sudah ada.
Tidak mengubah production UI, repository, atau golden acuan.

Eksperimen assertion CI stable dikembalikan karena kandidat belum layak
dipromosikan. Guard pin CI lama tetap diuji; tidak melonggarkan gate agar hijau.

Verifikasi ulang workspace utama setelah perbaikan harness: **653 test PASS**
dengan coverage, exit 0 (1 menit 47 detik); analyzer tidak menemukan issue;
format 282 file tanpa perubahan; `git diff --check` bersih. Ini hasil lokal,
bukan bukti remote CI atau acceptance live. Build/emulator baseline terakhir
tercatat di report P0; tidak dijalankan ulang setelah perubahan harness ini.

## Diagnosis dan batas bukti

[Issue Flutter 192167](https://github.com/flutter/flutter/issues/192167)
mendokumentasikan kegagalan validasi built-in Kotlin yang sama dan penutupan
melalui PR 192206. Status issue closed tidak membuktikan perbaikan tersedia di
tag kandidat: source `DependencyVersionChecker.kt` pada tag yang diuji masih
memanggil `checkKGPVersion` tanpa pengecualian built-in Kotlin, dan build nyata
tetap gagal. Belum menetapkan tag stable pengganti yang terbukti kompatibel.

Warning `firebase_core` berbeda dari kegagalan tersebut. Probe runtime baseline
menunjukkan plugin Kotlin eksternal tidak diterapkan pada app/core/messaging,
tetapi detector statis tetap menemukan deklarasi bersyarat di plugin.
[Issue Flutter 189770](https://github.com/flutter/flutter/issues/189770)
membahas keterbatasan detector tersebut. Warning bukan bukti build gagal,
tetapi kompatibilitas versi mendatang tetap harus diverifikasi.

Inspeksi arsip resmi `firebase_core` 5.0.0 masih menemukan penerapan Kotlin
bersyarat; upgrade major tidak dibuktikan menyelesaikan warning. Upgrade juga
membawa perubahan SDK native menurut [changelog Firebase Core](https://pub.dev/packages/firebase_core/changelog).
Dependency aplikasi tidak dinaikkan pada investigasi ini.

## Bukti lokal

Log sementara, bukan artifact CI permanen:

- `/tmp/hris-qa02-stable-version.log`
- `/tmp/hris-qa02-stable-pub-get.log`
- `/tmp/hris-qa02-stable-analyze.log`
- `/tmp/hris-qa02-stable-format.log`
- `/tmp/hris-qa02-stable-tests.log`
- `/tmp/hris-qa02-flow-green.log`
- `/tmp/hris-qa02-stable-tests-final.log`
- `/tmp/hris-qa02-stable-build.log`
- `/tmp/hris-qa02-stable-build-pair.log`
- `/tmp/hris-qa02-stable-build-matrix.log`
- `/tmp/hris-qa02-main-final-tests.log`

## Pending dan syarat penutupan

1. Verifikasi distribusi/tag Flutter resmi yang memuat perbaikan built-in Kotlin;
   uji matriks native terisolasi sebelum mengubah pin CI dan lockfile utama.
2. Ulang analyzer, format, full suite, build Android, dan fixture emulator pada
   matriks terpilih. Validasi iOS melalui macOS/CI.
3. Selesaikan kompatibilitas plugin/DSL dan klasifikasi warning pada toolchain
   final. Jangan menyamakan hilangnya warning dengan release readiness.
4. Simpan hasil remote CI, artifact, versi dependency, dan batas signing.

Sambil menunggu QA-02, bagian audit QA-03 yang tidak bergantung pada promosi SDK
dapat dilanjutkan. Audit final tetap harus diulang setelah matriks diputuskan.
