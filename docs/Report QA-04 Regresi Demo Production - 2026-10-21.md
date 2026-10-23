# Report QA-04: Regresi Demo dan Non-Demo

Pembaruan: 21 Oktober 2026. Status: **IN_PROGRESS**.
Baseline berikut dijalankan pada 20 Oktober. Patch dan pengujian ulang
21 Oktober dicatat terpisah di bawah agar hasil kedua snapshot tidak tercampur.

## Hasil yang sudah diverifikasi

| Pemeriksaan | Hasil 20 Oktober |
| --- | --- |
| Full suite dengan coverage | 653 test PASS, exit 0, sekitar 2 menit 7 detik |
| Coverage | 10.166 / 12.564 baris, 80,91%; informasional, bukan threshold baru |
| Analyzer | Tidak ada issue |
| Format | 282 file, 0 perubahan |
| Golden acuan | Tidak diubah; tidak memakai --update-goldens |
| Integration Android fixture | 2 skenario PASS, exit 0; sekitar 1 menit 16 detik setelah install |
| Build APK demo aktual | PASS, assembleDebug sekitar 87,6 detik |
| Build APK non-demo, config production | PASS, assembleDebug sekitar 49,2 detik; bootstrap belum diuji |

Snapshot source: HEAD `b90f8db62e53705d0e957459c2ee615b36274b78` dengan
perubahan kerja aktif, bukan checkout bersih. SHA-256 pubspec.lock tetap
`2d45b67589b1e2e3c61745c4f42f318481c09e7ea47eb0cab52164f6cf1d0f65`.

## Cakupan otomatis dan batasnya

Suite mencakup struktur shared presentation Home, Absensi, Pengajuan, Kalender,
Profil, Payroll dan halaman pendukung. Matriks widget menguji light/dark,
skala teks 1/1,3/1,5/2 dan viewport 320x568 serta 430x932 dengan platform theme
Android/iOS. Platform theme iOS bukan build atau acceptance perangkat iOS.

Integration berjalan pada AVD sementara Android 17/API 37, x86_64, page size
16.384 byte, layar 1080x2424/density 420. Kedua skenario menjalankan login
fixture, chat unavailable, notifikasi/read, kalender, absensi batal dan submit,
cuti, lalu logout A dan login B. Skenario kedua menolak submit absensi dan
memeriksa tidak ada sukses palsu. Tidak memakai akun atau transaksi server nyata.

Fixture mengganti repository; keberhasilannya tidak membuktikan kontrak live,
face match, geofence, push delivery, maupun isolasi dua tenant backend.

## Pemeriksaan manual demo aktual

Beranda, modal tim, Pengajuan, Absensi, Kalender dan Profil dibuka pada APK
`DEMO_MODE=true`, push/logging nonaktif, base URL `https://demo.invalid/api/v1`.
Screenshot diperiksa saat sesi berlangsung; data seluruhnya demo lokal.

- Avatar Beranda/Profil berbentuk lingkaran dan header berada di bawah status bar.
- Modal tim menutup floating action dan navigasi, tidak menempatkannya di atas modal.
- Pengajuan memakai capsule filter ringkas dan riwayat lokal, tetapi kehilangan
  navigasi bawah. Ini defect terbuka, bukan manual acceptance PASS menyeluruh.
- Navigasi tab Absensi, Kalender dan Profil tersedia. Tidak melakukan enrollment
  kamera atau submit absensi demo manual pada pemeriksaan ini.
- Pada sesi 20 Oktober dark mode dan restart demo belum dinyatakan lulus;
  pengujian aktual 21 Oktober dicatat terpisah di bawah.
- Pada sesi 20 Oktober APK non-demo belum dipasang/dibuka setelah build. Endpoint `ci.invalid` hanya
  untuk verifikasi konfigurasi; tidak dapat dipakai sebagai backend UAT.

## Defect QA04-UI-01: navigasi Pengajuan hilang

Prioritas: **P1**. Status defect: **FIXED** pada snapshot 21 Oktober;
QA-04 keseluruhan tetap IN_PROGRESS untuk exit gate yang masih tertunda.

Reproduksi: buka demo, dari Beranda pilih Pengajuan. Halaman memiliki header
dan filter, tetapi tidak memiliki navigasi bawah seperti referensi HTML.
Untuk keluar saat pengujian digunakan Back Android; tab tidak tersedia di layar.

Penyebab source yang dikonfirmasi 21 Oktober:

- `/requests` terdaftar di luar `StatefulShellRoute` pada `app_router.dart`.
- `MainShell` menyediakan navigasi hanya pada empat branch utamanya.
- `router_test.dart` bahkan mengharuskan navigasi hilang pada Requests. Assertion
  ini melindungi perilaku yang bertentangan dengan acuan, sehingga suite hijau
  tidak membuktikan kesesuaian design halaman tersebut.

Perbaikan disetujui dan diterapkan 21 Oktober: overview `/requests` menjadi
route dalam branch Beranda pada shell yang sama, tetap empat tombol dan URL
yang sudah ada. Tab Beranda membuka Beranda, bukan menganggap Pengajuan sebagai
reseleksi tab. Overview tidak menampilkan FAB Beranda atau menandai tab yang
salah. Form/detail tetap di navigator root dan fullscreen.

Sheet jenis pengajuan dan detail izin memakai navigator root agar barrier-nya
menutup navigasi. Menu jenis pengajuan dapat digulir pada ruang terbatas.
Repository, guard sesi, serta shortcut Approval manager tidak diubah.

## Verifikasi patch 21 Oktober

- RED: tes router gagal karena tidak menemukan `AppFloatingNavigation` pada
  Pengajuan. Setelah patch routing, kasus tersebut lulus.
- RED tambahan: alur fixture menemukan tombol Profil masih hit-testable saat
  modal tampil dan overflow menu 9,2 px. Patch navigator root/scroll menangani
  keduanya; delapan tes router/alur terkait kemudian PASS.
- Full suite dengan coverage: **653 PASS**, exit 0, 2 menit 10 detik.
- Coverage: **10.224 / 12.569 baris, 81,34%**, informasional.
- Analyzer: tidak ada issue. Format: 282 file, 0 perubahan. `git diff --check`
  bersih. Golden acuan tidak diperbarui.
- Regresi mencakup direct route `/requests`, perpindahan tab/aksi tengah,
  Back ke asal, form/detail fullscreen dan modal menutup hit testing navigasi.
- Review scoped patch: tidak ditemukan issue critical/important/minor yang
  memerlukan perubahan; tidak mensertifikasi perubahan API/Firebase lain.

Integration emulator snapshot patch: **2 PASS**, exit 0, 1 menit 25 detik
setelah install; assembleDebug 210,1 detik dan install 19,7 detik. Perintah:
`rtk flutter test integration_test/redesign_flow_test.dart -d emulator-5554`.
Pengujian memakai AVD sementara Android 17/API 37, x86_64, page size 16 KB.
Hanya emulator yang ditarget; perangkat lain yang terhubung tidak disentuh.
Ini APK integration fixture, bukan build demo aktual atau artifact distribusi.

Log suite dan integration tersedia sementara di
`/tmp/hris-qa04-20261021.N26EpB/full-tests.log` dan
`/tmp/hris-qa04-20261021.N26EpB/integration.log`.
Warning KGP `firebase_core` masih muncul pada build; task toolchain/release
terpisah belum ditutup. Tidak ada dependency baru atau perubahan lockfile.

AVD sempat gagal dibuat karena suite memakai ruang `/tmp` bersamaan dengan
pemeriksaan kapasitas partisi emulator. Setelah suite selesai, emulator berhasil
boot; tidak menghapus data atau melakukan wipe pada AVD asli.

## Acceptance APK aktual 21 Oktober

Pengujian lanjutan memakai `lib/main.dart`, bukan entrypoint integration dengan
repository fixture. Hanya emulator QA sementara yang ditarget. Tidak mengubah
kode aplikasi, menghapus data aplikasi, mengirim login/transaksi ke backend,
atau menyentuh real device yang juga terhubung.

| Pemeriksaan | Hasil dan batas bukti |
| --- | --- |
| Build APK demo aktual | PASS, assembleDebug 37,6 detik; development debug, push/logging disabled, `https://demo.invalid/api/v1` |
| Pengajuan demo light | PASS: header/filter/riwayat lokal, empat tujuan navigasi dan aksi tengah tampil; FAB Beranda tidak muncul |
| Modal Buat Pengajuan | PASS: sheet menutupi navigasi. Dump accessibility hanya memuat pilihan modal, bukan tombol tab; Back menutup modal |
| Perpindahan tema | PASS: toggle Profil mengaktifkan tema gelap; Beranda, Pengajuan, Absensi, Kalender dan pengaturan Profil dibuka/diperiksa |
| Force-stop/relaunch demo | PASS: kembali ke Beranda dengan sesi Karyawan Demo dan tema gelap. Bukan bukti penyimpanan record absensi baru atau template wajah |
| Build APK non-demo | PASS, assembleDebug 40,5 detik; production config pada debug APK, `https://ci.invalid/api/v1`, push/logging disabled |
| Install non-demo di atas demo | PASS: tanpa clear-data, membuka login tanpa banner DEMO/identitas demo. Preferensi dark mode tetap ada; preferensi tema bukan sesi bisnis |
| Force-stop/relaunch non-demo | PASS: tetap di login, tidak otomatis masuk sebagai akun demo |
| Bootstrap non-demo terautentikasi | PENDING: tidak diuji karena URL dummy bukan backend dan tidak memakai kredensial live |

Fingerprint APK saat selesai dibangun:

| Mode | Byte | SHA-256 |
| --- | --- | --- |
| Demo debug | 268491577 | 2c4fd8905f5858d4232b06c1db562211604512b2337d39e7788302b2c9d1db28 |
| Non-demo production-config debug | 268489409 | dccf65d928c2152994313bed86c62bb667675d51f5c776ac52c6b91870ce9d97 |

Output `build/app/outputs/flutter-apk/app-debug.apk` saat ini adalah non-demo
debug, bukan signed production. Salinan demo berada sementara di
`/tmp/hris-qa04-20261021.N26EpB/hris-demo-debug.apk`.
Log build, screenshot dan dump accessibility ada di direktori temporary yang
sama (`demo-build.log`, `non-demo-build.log`, `demo-*.png`,
`requests-modal-light.xml`, `non-demo-start.xml`, `non-demo-restart.xml`).
Screenshot/dump yang diperiksa tidak menggantikan matriks perangkat, UAT live,
atau pemeriksaan visual seluruh state. Tidak menjalankan ulang suite 653 test
setelah pemeriksaan manual ini; kode dan lockfile tidak diubah pada putaran ini.

## Tindak lanjut bootstrap non-demo 21 Oktober

Status defect **QA04-AUTH-01: FIXED lokal**, prioritas P1. Saat restore memakai
access token kedaluwarsa, refresh mempublikasikan identitas ke controller dan
request context sebelum retry `/auth/me` selesai. Akibatnya gate loading dapat
terbuka sebelum repository selesai memvalidasi identitas sesi.

Regresi loopback menahan respons retry `/me` dengan completer. Sebelum patch,
assertion controller masih loading gagal (`false`), bukan sekadar perbedaan
waktu menunggu tes. Patch menahan publikasi refresh ketika controller belum
memiliki sesi terverifikasi dan ketika request context belum tersedia.
Rotasi token tetap disimpan; repository kemudian memakai token terbaru untuk
menyelesaikan `/me`. Sesi aktif tetap menerima pembaruan otoritas dari refresh.

Tes baru: `test/features/authentication/non_demo_bootstrap_flow_test.dart`.
Empat skenario berikut lulus pada server HTTP loopback dengan port sementara:

1. Login A, bangun ulang container provider dengan storage yang sama, refresh
   token, tahan `/me`, lalu lanjutkan bootstrap dan muat Beranda. Selama `/me`
   tertahan controller tetap loading, context kosong, dan tidak ada request saldo.
   Setelah logout/login B, query saldo memakai employee ID dan bearer B;
   client fitur lama tidak dapat mengirim request baru.
2. `/me` mengembalikan 503 saat restore: tidak mempublikasikan identitas atau
   memuat saldo, token dipertahankan. Invalidation/retry setelah server pulih
   berhasil tanpa refresh yang tidak diperlukan.
3. Refresh berhasil tetapi retry `/me` gagal 503: controller berstatus error,
   context tetap kosong dan data Beranda tidak dimuat. Token baru dipertahankan.
4. Refresh ditolak 401: sesi dan kedua token dihapus, context kosong dan tidak
   memuat saldo akun sebelumnya.

Controller, repository autentikasi/Beranda, datasource, interceptor dan refresh
HTTP merupakan implementasi asli, tanpa override repository demo. Platform
secure storage memakai mock plugin dan pembersih artifact native di-stub.
HTTP hanya mengakses loopback dengan data sintetis, bukan kredensial server.
Ini pembuktian integrasi provider/network pada host, **bukan** startup proses
Android/iOS, persistensi keystore nyata, TLS, atau acceptance UI terautentikasi.

Perintah tes terfokus:

```bash
rtk flutter test --no-pub test/features/authentication/non_demo_bootstrap_flow_test.dart
```

Review terfokus tidak menemukan defect penghalang. Saran coverage minor yang
belum dijalankan: kasus token langsung kedaluwarsa setelah login, bukan restore.
Inspeksi menunjukkan kedua guard juga berlaku pada login; ini bukan bukti tes
kasus tersebut sudah tersedia. Review tidak mensertifikasi perubahan worktree
lain, UI, live backend, perangkat, iOS, atau remote CI.

### Verifikasi setelah patch bootstrap

| Pemeriksaan | Hasil terbaru |
| --- | --- |
| Empat skenario loopback baru | 4 PASS, exit 0 |
| Suite penuh `flutter test --no-pub --coverage` | 675 PASS, exit 0, 2 menit 26 detik |
| Coverage | 10.223 / 12.570 baris, 81,33%; informasional |
| Analyzer | Tidak ada issue |
| Format `lib test tool integration_test` | 285 file, 0 perubahan |
| Build APK non-demo | PASS, assembleDebug 79,3 detik |

APK validasi terbaru menggunakan `APP_ENV=production`,
`BASE_URL=https://ci.invalid/api/v1`, `ENABLE_LOGGING=false`, dan
`PUSH_MODE=disabled`. Path `build/app/outputs/flutter-apk/app-debug.apk` kini
berisi build ini: 268.491.712 byte, SHA-256
`4790e83699b2b2375b5be6975e25c8ce57d0a9ec48f7055fb38d03873d30177c`.
App ID development dan debug signing belum berubah. APK ini tidak dipasang atau
diuji manual pada putaran bootstrap; hasil emulator di bagian sebelumnya berasal
dari snapshot sebelumnya. Tidak mengklaim APK baru lulus acceptance perangkat.
Peringatan KGP `firebase_core` masih muncul; build berhasil, QA-02 belum ditutup.

Log suite/build terbaru ada sementara di
`/tmp/hris-qa04-bootstrap-20261021.6jfMiX/`. Tes penuh awal tertahan sandbox
karena cache SDK read-only; pengulangan dengan izin akses SDK selesai exit 0.
Tidak mengubah dependency, lockfile, golden, konfigurasi release, data perangkat,
atau mengirim transaksi live. Perubahan production pada putaran ini hanya dua
guard publikasi identitas; perubahan worktree lain tetap dipertahankan.

### Dependency HTTPS yang diperiksa

Probe HEAD tanpa kredensial pada
`https://srv540825.hstgr.cloud:8084/api/v1/auth/login` menghasilkan curl exit 35:
`TLS connect error: SSL routines::wrong version number` pada 21 Oktober.
Ini membuktikan port/alamat API yang diberikan belum melayani TLS yang dapat
dipakai probe tersebut, bukan bukti tidak ada URL HTTPS lain. URL staging HTTPS
alternatif belum diberikan. REL-01 tetap PENDING; tidak memakai `--insecure`,
menambah pengecualian cleartext production, atau mengirim password lewat HTTP.

## Bukti sementara dan kapasitas host

Pengujian AVD asli sempat tertahan disk host. Pengujian dilanjutkan pada AVD
terpisah di /tmp dengan opsi partition-size; tidak melakukan wipe-data AVD asli.
Saat build demo, ruang root turun sekitar 134 MB. Untuk menambah ruang tanpa
menghapus source/artifact final, tiga cache hasil build dipindahkan ke /tmp:

- `build/app/intermediates/merged_native_libs/release`
- `.dart_tool/flutter_build/66f34936ccbdc4bf620e36fe7f442ab3`
- `.dart_tool/flutter_build/885d46b8090ee541758bc57abac04170`

Pada 21 Oktober direktori temporary sesi tersebut sudah tidak tersedia dan
ruang root sekitar 5,8 GB. Cache generated dapat dibangun ulang; tidak ada source,
golden, kredensial, atau data AVD asli yang dihapus oleh pekerjaan ini.
Log dan screenshot yang sebelumnya di `/tmp/hris-qa04-20261020.zy4VDZ/` tidak
lagi menjadi bukti file yang dapat dibuka. Angka historis di atas berasal dari
output pengujian yang sudah diperiksa saat sesi, bukan pemeriksaan file saat ini.

Fingerprint APK saat selesai dibangun, sebelum path output ditimpa mode lain:

| Mode | Byte | SHA-256 |
| --- | --- | --- |
| Demo | 268491294 | 459398b4c651a3cf3e190aaf4c9350ea718d70c4a87e5d143d930ea3aa5066e2 |
| Non-demo, production config debug | 268491256 | 34a443d396a63afd06e85a3b3f77020fe00775ee5956e913a99428493c7c8c08 |

Keduanya memakai app ID development dan debug signing; bukan artifact distribusi.

## Sisa pekerjaan

1. Tuntaskan bootstrap UI akun non-demo terautentikasi pada backend HTTPS dan
   perangkat dengan akun attendance aktif. Jalur provider/network fixture sudah
   diuji, termasuk refresh/error/account switch; ini tidak menggantikan startup
   proses nyata, isolasi dua tenant backend, absensi live, payroll, atau push.
2. Ulang snapshot final setelah QA-02/toolchain dan konfigurasi release selesai.
3. Acceptance Android/iOS live dan remote CI tetap task terpisah; tidak ditutup
   dengan hasil fixture atau build debug di report ini.
4. Tambahkan coverage token langsung kedaluwarsa setelah login sebelum penutupan
   regresi final; kasus restore dengan refresh sudah dilindungi tes baru.
