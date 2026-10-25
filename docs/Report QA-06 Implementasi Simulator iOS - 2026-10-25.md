# Report QA-06: Implementasi Pengujian Simulator iOS

Tanggal: 25 Oktober 2026. Status: **implementasi lokal terverifikasi; eksekusi native CI PENDING**.

## Implementasi

- Selector `tool/select_ios_simulator.dart` membaca JSON simctl. Memilih iPhone
  available dengan runtime iOS minimal 15.5, membandingkan versi numerik dan
  memvalidasi UUID serta state Booted/Shutdown. Input tidak valid gagal exit 1.
- Job iOS mempertahankan build unsigned lalu menjalankan gate simulator wajib:
  pilih/boot perangkat, build debug simulator dengan HTTPS dummy dan logging/push
  disabled, jalankan RunnerTests, lalu dua flow fixture Flutter yang sudah ada.
- Empat XCTest menggantikan tes Swift contoh: proteksi disabled, inactive/active,
  pelepasan cover saat disable, dan siklus berulang tanpa penumpukan cover.
  Tes menginspeksi UIWindow nyata, memakai MainActor dan reset singleton melalui
  API yang sudah ada. Tidak mengubah production Swift atau UI.
- Log versi Xcode, arsitektur, inventory/UUID/runtime, build, XCTest, integration
  dan native.xcresult masuk artifact `ios-simulator-diagnostics`, termasuk saat
  langkah gagal. Pipefail tetap meneruskan kegagalan tool di balik tee.

## Verifikasi lokal

| Pemeriksaan | Hasil |
| --- | --- |
| Baseline worktree sebelum implementasi | 675 PASS, exit 0 |
| Selector | 11 RED pada stub, kemudian 11 PASS |
| Regresi workflow | Dua RED karena gate/diagnostics belum ada, kemudian total delapan tes workflow PASS |
| Tes terfokus selector + workflow | 19 PASS |
| CLI selector: inventory valid / kosong | Exit 0 dengan UUID/state / exit 1 |
| Script simulator: pemeriksaan syntax bash | PASS |
| Kegagalan tool terkontrol melalui pipeline tee | Exit 17 diteruskan, bukan success |
| Suite penuh dengan coverage | 688 PASS, exit 0, 2 menit 5 detik |
| Analyzer | Tidak ada issue |
| Format | 287 file, 0 perubahan |
| Diff whitespace dan lockfile/Gradle baseline | Bersih, dependency tidak berubah |

Empat XCTest belum dikompilasi/dijalankan pada host Linux. Probe pipeline memakai
tool pengganti yang sengaja gagal; bukan bukti Xcode atau simulator tersedia.
Review terfokus tidak menemukan Critical/Important/Minor dan memberi verdict
siap untuk validasi macOS CI, bukan native acceptance PASS.

## Isolasi dan keputusan pelaksanaan

Branch lokal: `qa/ios-simulator-2026-10-25`.
Worktree: `/tmp/hris-qa06-20261025.mBb6Fk/source`.
Baseline: `8b939c4ef51c72265d528f84ac2cf9236b245568`, sama tree dengan merge PR #1.
SDK sementara mengikuti pin CI `19946f91c8d9de18a4674460d015229cc0b2534f` karena
SDK utama sudah lebih baru. Tidak memodifikasi SDK utama atau cache dependency.
Lockfile worktree tetap SHA-256
`2d45b67589b1e2e3c61745c4f42f318481c09e7ea47eb0cab52164f6cf1d0f65`.
Perubahan lockfile, Gradle wrapper dan dokumentasi QA-05 di workspace utama
dipertahankan dan tidak dimasukkan otomatis ke implementasi ini.

Keputusan pelaksana: jalankan rencana inline setelah persetujuan implementasi;
gunakan SDK sementara alih-alih menguji dengan SDK utama yang berubah; emit UUID
dan state tervalidasi agar CI hanya mem-boot perangkat Shutdown; karakterisasi
native tetap pending hingga ada eksekusi macOS. Jika asumsi runtime/toolchain
tidak cocok, CI harus gagal dan hasil perlu dianalisis, bukan di-skip.

Log sementara: `/tmp/hris-qa06-20261025.mBb6Fk/`. Source harus disimpan pada branch
Git; jangan mengandalkan umur direktori /tmp untuk bukti permanen.

## Exit gate yang masih pending

Publikasi branch/PR QA-06 dan run macOS belum dilakukan. Setelah diizinkan,
catat SHA/run URL, konfigurasi runner, empat hasil XCTest, dua flow Flutter dan
artifact. Izin pembuatan PR melalui integrasi mungkin masih memerlukan tindakan
manual pengguna; tidak melakukan merge otomatis.

QA-06 keseluruhan tetap terbuka untuk sensor/izin aktual, APNs, restart/restore
storage, app switcher dan capture pada perangkat, serta signed release.
Tes cover terkontrol tidak mensertifikasi screenshot prevention, notifikasi
lifecycle OS, seluruh perangkat, live attendance atau Face ID production.
Tidak ada kredensial maupun transaksi server nyata dalam fixture.

Referensi: [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)
dan [Apple xcodebuild testing](https://developer.apple.com/library/archive/technotes/tn2339/_index.html).
