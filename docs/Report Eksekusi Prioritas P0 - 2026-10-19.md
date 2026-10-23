# Report Eksekusi Prioritas P0

Tanggal: 19 Oktober 2026.
Acuan: [rekap seluruh task](<Rekap Seluruh Task Belum Selesai - 2026-10-19.md>).

## Urutan dan batas pekerjaan

Dependency P0 eksternal tetap PENDING: akun password-required, dua tenant,
kontrak izin, kesiapan attendance production, HTTPS, macOS/perangkat iOS,
identifier/signing dan kebijakan privacy. Tidak ada akses atau data server
yang dibuat-buat untuk menutup gate tersebut.

Pekerjaan lokal dimulai dari QA-01, kemudian diagnosis QA-02 dan inventaris
QA-03. Pengujian QA-04 dijalankan sebagai baseline sebelum perubahan tooling,
bukan bukti bahwa SDK release, remote CI atau acceptance native sudah selesai.

## QA-01: review baseline integrasi

Status: DONE untuk review/cleanup lokal, bukan merge atau persetujuan release.

- Baseline HEAD: `b90f8db62e53705d0e957459c2ee615b36274b78`, branch `master`.
- Checkout memuat perubahan staged/unstaged Firebase development, revisi API
  Oktober, test dan dokumentasi. Review memakai diff HEAD serta file untracked
  terkait. Tidak membuat commit, menggabungkan branch, atau memindahkan pekerjaan
  yang belum di-commit ke worktree baru.
- Perubahan auth/session, identitas employee, multi-slip, carry-over, kondisi
  aset, tracing, config native Firebase dan lifecycle push dibaca bersama tes
  regresinya. Ini review baseline oleh pelaksana, bukan independent security review.
- Kredensial smoke dan konfigurasi Firebase lokal tidak tracked dan cocok
  dengan aturan ignore. Isi file tidak dicetak.
- Pengguna menyetujui mengeluarkan 20 PNG diagnostik `test/failures` dari
  staging, tanpa menghapus file lokal. Tidak ada perubahan staged pada folder
  tersebut. Delapan PNG yang sebelumnya sudah tracked pada HEAD tetap tracked;
  aturan ignore tidak menghapus file tracked atau mengubah riwayat Git.
- `/test/failures/` ditambahkan ke `.gitignore`; upload artefak failure pada CI
  tetap bisa membaca direktori lokal meskipun diabaikan Git.
- Semua **28 PNG lokal** tetap tersimpan, termasuk 8 yang tidak staged.
  Fingerprint gabungan sebelum/sesudah cleanup sama:
  `218b9c5a244fb27b68fee2808933589826b632afb8a8efdb42eb1a0db5d47c13`.
- Tidak ada perubahan gambar pada `test/goldens`; tidak menjalankan
  `--update-goldens`. Tidak ada file material yang dihapus.

### Review golden historis

| Kelompok PNG diagnostik | Hubungan dengan golden acuan sekarang | Hasil |
| --- | --- | --- |
| Payroll detail light 320/text200 | Test image historis identik dengan golden sekarang | Gambar acuan diinspeksi; full suite terbaru lulus. |
| Payroll lockout light/dark 320/text200 | Test image historis identik dengan golden sekarang | Tombol submit disabled saat lockout; kedua acuan diinspeksi; suite lulus. |
| Profil fixture light/dark | Master image historis identik dengan golden sekarang; test image historis berbeda pada state dokumen | Kedua acuan diinspeksi; full suite terbaru lulus tanpa mengadopsi state error lama. |

PNG failure lama tidak membuktikan ada kegagalan golden aktif. Bukti saat ini
adalah hasil suite baru, bukan menghapus file failure agar terlihat hijau.

## Verifikasi baseline lokal untuk QA-04

| Pemeriksaan | Hasil aktual |
| --- | --- |
| `rtk flutter analyze` | Exit 0, tanpa issue. |
| `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test` | Exit 0, 282 file, 0 berubah. |
| `rtk flutter test --no-pub --coverage` | Exit 0, 653 tes lulus, sekitar 2 menit 3 detik. |
| Coverage `coverage/lcov.info` | 10.170 / 12.564 baris, 80,95%; snapshot informasional, bukan threshold rilis yang baru. |
| `rtk git diff --check HEAD` | Lulus. |

Log full suite: `/tmp/hris-priority-baseline-full-tests.log`.
Tes ini bukan pengulangan integration Android native, delivery FCM, iOS,
acceptance server, atau remote CI. QA-04 masih perlu revalidasi snapshot final
setelah toolchain/configuration berikutnya selesai.

## QA-02: diagnosis toolchain

Status: IN_PROGRESS; warning belum dinyatakan selesai.

Snapshot lokal: Flutter `3.50.0-0.1.pre`, master revision `19946f91c8`,
Dart `3.14.0-248.0.dev`, AGP `9.0.1`, Gradle `9.1.0`, firebase_core `4.15.0`,
firebase_messaging `16.7.0`. CI saat ini pin revision Flutter yang sama.
Ini fingerprint baseline, bukan persetujuan memakai master untuk production.

Investigasi awal menemukan:

- `android.builtInKotlin=true`; project app tidak menerapkan plugin KGP eksternal.
- Build script firebase_core lokal berisi conditional `apply plugin:
  'kotlin-android'` hanya untuk AGP <9 atau built-in Kotlin nonaktif.
- Detector pada SDK lokal `FlutterPluginUtils.kt` membaca script dengan regex,
  bukan status plugin Gradle runtime. Karena itu warning statis saja belum
  membuktikan branch conditional KGP benar-benar aktif pada build ini.
- `android.newDsl=false` masih deprecated dan perlu ditangani saat matriks
  kompatibilitas app/plugin/toolchain disepakati. Jangan sekadar menghapus
  flag tanpa membuktikan seluruh plugin kompatibel dengan DSL baru.

Probe runtime Gradle selesai, exit 0 (`BUILD SUCCESSFUL`):

| Project | External KGP aktif | android.builtInKotlin |
| --- | --- | --- |
| :app | false | true |
| :firebase_core | false | true |
| :firebase_messaging | false | true |

Probe dijalankan offline dengan init script diagnostik di
`/tmp/hris-kotlin-plugin-probe.gradle` dan task `:app:help`. Bukti ini berlaku
pada konfigurasi yang diuji; bukan jaminan seluruh build/flavor mendatang.
Warning deteksi statis belum hilang dan tidak disembunyikan. Tidak mengedit Flutter SDK,
pub cache, mematikan warning, mengubah versi plugin, atau mengganti SDK global.
SDK release final serta build Android/iOS harus tetap divalidasi sebelum QA-02
boleh ditutup.

## QA-03: inventaris native

Status: IN_PROGRESS; audit Android debug awal selesai, audit native keseluruhan belum selesai.

Inventaris dependency Android berhasil dengan Gradle `debugRuntimeClasspath`
secara offline, exit 0 (`BUILD SUCCESSFUL`), tanpa entry dependency `FAILED`.
Pembacaan graph non-constraint mengidentifikasi 165 nama module unik; ini
inventaris awal, bukan SBOM final atau jumlah artifact yang diaudit kerentanannya.
Versi resolved yang teramati: Kotlin stdlib `2.2.10`, Firebase BoM `34.19.0`,
firebase-common `22.2.1`, firebase-messaging `25.1.3`.
Hasil debug bukan daftar final seluruh varian release.
Belum ada `Podfile.lock` atau `Package.resolved` tracked pada checkout ini;
resolusi dependency iOS perlu runner macOS/build native, bukan disimpulkan kosong.

Log inventaris: `/tmp/hris-priority-native-dependencies.log`.
Log probe Kotlin: `/tmp/hris-priority-kotlin-probe.log`.

Inventaris tidak setara pemeriksaan kerentanan. Selanjutnya perlu versi
resolved/lockfile final, audit Gradle/Swift/CocoaPods, pemeriksaan advisory,
dan pengulangan audit setelah lockfile/toolchain berubah.

### Temuan JUnit debug dan perbaikan

Query [OSV batch API](https://api.osv.dev/v1/querybatch) untuk 165 pasangan
module/versi Maven teramati menghasilkan satu temuan: `junit:junit:4.12`,
[GHSA-269g-pwp5-87pp / CVE-2020-15250](https://github.com/advisories/GHSA-269g-pwp5-87pp).
Advisory membahas permission temporary folder dan diperbaiki mulai 4.13.1.
Ini bukan bukti kebocoran data HR pada aplikasi ini.

`dependencyInsight` menelusuri sumbernya:
`integration_test → androidx.test:runner:1.3.0 → junit:4.12`.
Probe `releaseRuntimeClasspath` tidak menemukan JUnit. Karena itu patch
dibatasi pada constraint **debugImplementation 4.13.2** di Gradle app, bukan
menambah dependency JUnit pada aplikasi release atau mengedit SDK/pub cache.

Bukti RED/GREEN:

- Probe Gradle benar-benar gagal sebelum patch karena JUnit 4.12 terpilih.
  Percobaan awal init script gagal pada included build Flutter yang tidak
  memiliki :app; script diperbaiki sebelum reproduksi RED yang valid.
- Hasil GREEN awal dengan graph kosong tidak dipakai sebagai bukti. Probe
  diperketat untuk menolak unresolved dependency dan mewajibkan JUnit ditemukan
  pada debug; setelah build/resolusi selesai, hasil nyata debug `[4.13.2]`,
  release `[]`, exit 0.
- `dependencyInsight` pascapatch mengonfirmasi selection by constraint dan
  conflict resolution 4.13.2 versus 4.12.
- Graph debug diekspor ulang dan OSV menerima 165 query/165 hasil; tidak ada
  advisory dikembalikan untuk snapshot pascapatch. Ini bukan jaminan tidak ada
  kerentanan yang belum tercatat atau audit binary native/iOS selesai.
- Full suite pascapatch kembali lulus 653 tes; analyzer tanpa issue dan format
  282 file/0 berubah. `pubspec.lock` dan golden acuan tidak berubah.
- APK development debug berhasil dibangun, APP_ENV=development,
  PUSH_MODE=disabled, logging=false. Warning KGP/DSL tetap terbuka pada QA-02.
  Build debug ini bukan artifact signed production.

Log tambahan: `/tmp/hris-priority-junit-red.log`,
`/tmp/hris-priority-junit-green.log`,
`/tmp/hris-priority-junit-post-fix-insight.log`,
`/tmp/hris-priority-native-dependencies-after.log`,
`/tmp/hris-priority-post-fix-full-tests.log`, dan
`/tmp/hris-priority-post-fix-build.log`.

Periksa ulang snapshot dependency release dan iOS setelah SDK/config final.
Integration fixture Android pascapatch lulus **2 skenario**, exit 0: absensi
fixture diterima/ditolak, masing-masing disertai logout A dan masuk B. Log:
`/tmp/hris-priority-post-fix-integration.log`. Tidak ada request atau mutasi
bisnis server pada putaran ini. APK path debug dapat ditimpa runner integration;
jangan menganggap APK test tersebut artifact distribusi final.

### Review patch dan batas keputusan

Reviewer terpisah melakukan review read-only pada constraint JUnit dan aturan
ignore; tidak menemukan Critical, Important, atau Minor dalam scope tersebut.
Reviewer memverifikasi constraint memilih versi patched hanya pada debug dan
aturan ignore tidak mengenai golden acuan. Tidak ada perubahan file/index
oleh reviewer.

Hal yang tidak dinilai reviewer: perubahan Firebase/build yang sudah ada,
kelengkapan database advisory, warning Kotlin, SDK/lockfile final, audit native
iOS, dan kesiapan release keseluruhan. Keputusan pelaksana: tidak menutupnya
dengan review patch kecil ini; semuanya tetap berada pada task QA/platform/
release terkait. Review patch bukan independent review seluruh branch.

## Status penutupan

QA-01 selesai untuk cleanup/review lokal. QA-03/04 masih IN_PROGRESS.
QA-02 menjadi PENDING setelah kandidat stable lulus 653 test tetapi build
Android gagal pada validasi built-in Kotlin di tiga matriks terisolasi.
Pin CI/SDK utama dipertahankan; lihat [report QA-02](<Report QA-02 Toolchain Release - 2026-10-19.md>).
Setelah perbaikan navigasi fixture dan pengembalian assertion pin CI, suite
utama kembali lulus 653 test dengan coverage (exit 0), analyzer bersih,
format 282/0, dan diff check bersih. Log: `/tmp/hris-qa02-main-final-tests.log`.
Task eksternal tidak berubah dari PENDING, dan modul DEFERRED tidak dibuka
kembali. Bukti hasil lanjutan dicatat di report ini sebelum mengubah tracker.

## Pembaruan 20 Oktober: QA-03

Audit debug/profile/release menemukan JUnit4.12 masih terbawa integration_test
pada profile. Constraint kini mencakup debug/profile4.13.2; regresi Gradle nyata
RED/GREEN dan release tetap tanpa JUnit. OSV ulang175 pasangan Maven dan188 Pub
tidak mengembalikan advisory. Full suite653 PASS, analyzer dan format bersih.
AAB validasi berhasil setelah registrant stale diregenerasi melalui build
standar; inventaris24 library ELF tersimpan. Bukan artifact signed production.

QA-03 tetap IN_PROGRESS untuk binary/provenance, build tooling, resolusi iOS,
dan audit matriks final. Lihat [report lengkap QA-03](<Report QA-03 Audit Dependency Native - 2026-10-20.md>)
beserta bukti JSON, batas pengujian, dan hasil review patch.
