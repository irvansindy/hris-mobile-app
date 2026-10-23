# Report QA-03: Guard Integritas PDFium

Tanggal: 21 Oktober 2026. Hasil lokal: **PASS**. QA-03 tetap **IN_PROGRESS**.

## Implementasi

`tool/verify_native_pdfium.dart` memeriksa cache Android dan isi AAB secara
terpisah terhadap hash tiga ABI dari [audit provenance](<Report QA-03 Provenance Binary Native - 2026-10-21.md>).
Versi terkunci `pdfium_dart` dan `pdfium_flutter` harus `0.3.1`.
Binary berubah, ABI hilang/tidak dikenal, entry duplikat, symlink cache Android,
ZIP tidak valid, atau versi package yang belum ditinjau menggagalkan pemeriksaan.
Tidak ada opsi bypass atau pembaruan baseline otomatis.

CI menjalankan guard setelah build AAB dan sebelum upload artifact. Pemanggilan
langsung menghindari build hooks yang dipicu oleh `dart run`:

```bash
rtk dart --packages=.dart_tool/package_config.json tool/verify_native_pdfium.dart
```

Argumen opsional pertama adalah lokasi AAB. Jalankan dari root repository;
perlu `unzip` dan `shasum`, serta `zip` untuk tes fixture. Tidak menambah dependency,
mengubah pub cache, menaikkan versi package, atau mengubah hash lockfile.

## Pengujian

| Pemeriksaan | Hasil |
| --- | --- |
| Tes checker: fixture valid, cache/AAB berubah, ABI hilang/tambahan, duplikat, symlink, lockfile dan ZIP invalid | 17 PASS |
| Tes struktur CI, termasuk urutan build → guard → upload tanpa bypass | 6 PASS |
| Suite penuh `flutter test --no-pub --coverage` | 671 PASS, exit 0 |
| `flutter analyze` | Tidak ada issue |
| Format `lib test tool integration_test` | 284 file, 0 berubah |
| CLI dengan AAB tidak tersedia | Ditolak, exit 1 |
| Build AAB validasi baru dan guard pada cache/AAB aktual | PASS, exit 0 |

Tes diperiksa RED sebelum implementasi, termasuk regresi entry PDFium tambahan
di root ZIP dan kewajiban gate CI. Review patch terfokus tidak menemukan masalah
yang perlu diperbaiki; reviewer juga menjalankan ulang 23 tes terkait.

Artifact baru berukuran **88.297.270 byte**, SHA-256:
`e76e7ddee8fb1ecb914781c5a676d419b85caf28679a8908b66b0347d9216d0d`.
Build memakai `APP_ENV=production`, `BASE_URL=https://ci.invalid/api/v1`,
`ENABLE_LOGGING=false`, dan `PUSH_MODE=disabled`. Ini AAB validasi debug-signed
dengan identitas aplikasi saat ini, **bukan release candidate siap distribusi**.
Peringatan KGP `firebase_core` masih muncul; build berhasil, bukan penutupan QA-02.

Lockfile tetap SHA-256
`2d45b67589b1e2e3c61745c4f42f318481c09e7ea47eb0cab52164f6cf1d0f65`.
Log lokal berada di `/tmp/hris-native-guard-20261021.vKSy4z/` dan dapat terhapus;
hasil remote CI belum dijalankan atau disahkan dalam pekerjaan ini.

## Pending dan batas bukti

- Verifikasi arsip sebelum ekstraksi oleh hook upstream belum tersedia. Guard ini
  membatasi upload artifact, bukan melindungi seluruh proses build sebelumnya.
- Hash cocok bukan bukti bebas CVE, source attestation, atau reproducible build.
  Triage advisory native dan keputusan patch tetap memerlukan Security.
- Resolusi dependency, pemeriksaan IPA, signing dan acceptance iOS tetap pending.
- Ulang verifikasi pada toolchain final dan artifact signed; simpan bukti remote CI
  serta sign-off Security/DevOps sebelum release.

Tidak mengubah status QA-03 menjadi DONE. Rekap tetap **50 task aktif**; pekerjaan
ini menyelesaikan subtask guard post-build, bukan seluruh gate audit native.
