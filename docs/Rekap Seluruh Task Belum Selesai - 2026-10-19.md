# Rekap Seluruh Task Belum Selesai HRIS Mobile

Tanggal: 19 Oktober 2026.
Untuk: Mobile, Backend, QA, DevOps, Security/Legal, Product, dan partner aplikasi.

Dokumen ini menggabungkan sisa pekerjaan sampai go-live, bukan hanya migrasi
API Oktober. Nomor tahap tetap mengikuti [breakdown go-live](<Breakdown Task Go Live HRIS Mobile App.md>)
berbasis Tahap 0–10. Kolom revisi mengacu pada breakdown API Oktober 1–7.
ID dalam rekap ini hanya untuk pelacakan, bukan urutan tahap baru.

Ini rekap bukti yang sudah tersedia, bukan audit kode baru, hasil full CI baru,
atau persetujuan release. Pekerjaan dengan implementasi lokal selesai tetap
terbuka jika kontrak, pengujian live, atau bukti platform belum lengkap.

## 1. Status dan aturan prioritas

Snapshot setelah persetujuan publikasi QA-05: **50 task aktif belum selesai** (47 PENDING
dan 3 IN_PROGRESS), ditambah 1 DONE, 3 DEFERRED dan 2 CONDITIONAL. Delapan pending migrasi API sudah
termasuk dalam 50 task tersebut, bukan tambahan. Baris yang saling merujuk
memakai bukti acceptance bersama; jumlah baris bukan estimasi effort atau
jumlah bug.

- `TODO`: pekerjaan belum ditutup dan dapat disiapkan/dikerjakan lokal atau oleh owner.
- `IN_PROGRESS`: sudah dimulai, tetapi belum memenuhi seluruh kriteria penutupan.
- `PENDING`: menunggu kontrak, fixture, akses, perangkat, konfigurasi, atau bukti eksternal.
- `DONE`: kriteria task sudah diverifikasi; bukan otomatis persetujuan release.
- `DEFERRED`: disepakati di luar rilis awal; bukan blocker rilis ini.
- `CONDITIONAL`: pekerjaan opsional yang belum disetujui masuk scope; bukan otomatis blocker.

P0 wajib ditutup sebelum RC/go-live. P1 wajib ditutup jika fiturnya tetap masuk
rilis; pengecualian memerlukan keputusan Product dan pembatasan fitur yang jelas.
Prioritas bukan izin menjalankan mutasi data nyata atau memasang signing secrets.

## 2. Delapan pending migrasi API Oktober

Rincian fixture dan kriteria lengkap tetap di [Pending Task Migrasi API Oktober](<Pending Task Migrasi API Oktober 2026.md>).
Delapan baris ini adalah item yang sama, jangan dihitung sebagai backlog ganda.

| Status | ID | Revisi / tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| PENDING | API-01 | Revisi 1 / T1 | P0 | Acceptance wajib ganti password saat login dan runtime 403 | Backend + QA + Mobile; akun disposable berflag true dan izin ganti password | Home/deep link tertahan; tidak logout/replay mutation; akses pulih setelah ganti password dan login. |
| PENDING | API-02 | Revisi 2 / lintas tahap | P0 | Isolasi dua company dengan employee number sama | Backend + QA + Mobile; dua tenant dan resource fixture terpisah | Employee ID tetap unik; logout/account switch/restart tidak membawa cache atau resource tenant lain. |
| PENDING | API-03 | Revisi 3 / T5 | P1 | Konfirmasi path daftar payslip canonical dan alias | Backend + Mobile | Kontrak tertulis menyelesaikan perbedaan `/payroll/payslips` dan `/payroll/payslips/my`; client/test mengikuti keputusan, tanpa fallback spekulatif. |
| PENDING | API-04 | Revisi 3 / T5 | P1 | Acceptance multi-slip satu periode dan navigasi ID | Backend + QA + Mobile; minimal dua slip berbeda ID pada periode sama | Semua slip tampil dan masing-masing membuka ID tepat; detail/PDF mengikuti PAY-01. |
| PENDING | API-05 | Revisi 4 / T4 | P1 | Permission serta konflik approval 403/409 | Backend + QA + Mobile; matriks role, pending/stale fixture dan izin mutasi | Forbidden/conflict tidak sukses palsu, tidak fallback legacy; uji positive dan bulk partial success. |
| PENDING | API-06 | Revisi 5 / T3 | P1 | Semantik carry-over saldo cuti | Backend + Mobile | Konfirmasi quota/remaining, pecahan hari, nullability, dan timezone expiry; saldo tidak dihitung ganda. |
| PENDING | API-07 | Revisi 5 / T3 | P1 | Acceptance carry-over pecahan dan expiry | Backend + QA + Mobile; fixture edge case | Null, pecahan, belum/sudah expired dan tanggal batas ditampilkan sesuai kontrak. |
| PENDING | API-08 | Revisi 5 / T1 | P1 | Pencocokan request/correlation ID pada log backend | Backend + Mobile; log server disanitasi | UUID probe pada laporan ditemukan di log; hubungan request/retry dikonfirmasi tanpa data sensitif. |

Prioritas mengikuti daftar pending migrasi yang sudah disepakati. Kontrak
payroll dan saldo tetap harus ditutup bila fiturnya masuk rilis awal.

## 3. Kontrak dan implementasi fitur yang belum lengkap

| Status | ID | Tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| PENDING | CON-01 | T0/T3 | P0 | Finalisasi kontrak create izin dan upload | Backend; format/timezone start/end, satuan duration, multipart, referensi file, ukuran/format dan contoh error | OpenAPI/contoh request-response disepakati. Create production saat ini unavailable. |
| PENDING | CON-02 | T3 | P0 | Implementasi create izin production dan tes kontrak | Mobile; CON-01 | Form/data source memakai kontrak final; validation/permission/error teruji dan create tersedia tanpa data demo production. |
| PENDING | CON-03 | T0 | P0 | Tutup kontrak terbuka selain Oktober | Backend + Mobile; route ESS/aktivitas/travel/claim di luar baseline, error code nullable, identity create cuti, shiftDate, pagination/mutation dan batas upload | Matriks/OpenAPI sinkron dengan kontrak server dan contoh response yang disanitasi. |
| PENDING | CON-04 | T4 | P1 | Kontrak download attachment employee terotorisasi | Backend + Mobile | Endpoint atau document ID, ownership/company scope dan error disepakati; tidak membuka `/uploads/*` langsung. |
| PENDING | CON-05 | T4 | P1 | Integrasi dan acceptance download attachment | Mobile + QA; CON-04 | Download sesuai hak akses; empty/403/cross-tenant/account switch tidak membocorkan dokumen. |
| PENDING | CON-06 | T4 | P1 | Keputusan scope chat | Product + Backend | Kontrak disediakan untuk rencana implementasi terpisah, atau pengecualian rilis disetujui. Saat ini tetap unavailable, bukan chat production selesai. |
| PENDING | CON-07 | T5 | P1 | Kebijakan tampilan nominal pecahan dan label jenis slip | Product + Backend + Mobile | Putuskan precision rupiah serta kebutuhan runType self-service. Formatter saat ini membulatkan tampilan; mapping mempertahankan pecahan. Jika nama/nomor run cukup, catat keputusan tanpa menambah runType spekulatif. |

## 4. Acceptance fitur live Android/iOS

Pengujian GET 200 tidak menggantikan transaksi end-to-end. Gunakan akun dan
fixture disposable yang disetujui; jalur release memerlukan HTTPS. Semua
temuan acceptance perlu diperbaiki dan diregresikan sebelum gate ditutup.

| Status | ID | Tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| PENDING | ATT-01 | T2 | P0 | Kesiapan enrollment wajah dan kebijakan attendance server | Backend + QA; akun dengan shift, branch, geofence dan metode aktif | Backend mengenali enrollment production; fixture mismatch/rate-limit/geofence/shift malam tersedia. Today 200 belum membuktikan ini. |
| PENDING | ATT-02 | T2 | P0 | Check-in/check-out nyata Android/iOS | Mobile + QA + Backend; ATT-01 dan staging/perangkat | Satu record, today/history konsisten, restart mengikuti eligibility server; payload check-out tanpa wajah sesuai kontrak. |
| PENDING | ATT-03 | T2 | P0 | Failure/recovery dan shift malam | Mobile + QA + Backend | Pindah jaringan, timeout, double tap/replay tidak menggandakan record; face mismatch/rate-limit/fake GPS/geofence ditolak; open checkout 36 jam dan kamera/lokasi ditolak/5xx diuji. |
| PENDING | ESS-01 | T3 | P0 | Cuti end-to-end | Mobile + QA + Backend; saldo/leave fixture dan upload | Saldo/history/create/detail/cancel serta upload dan error live lulus; carry-over mengikuti API-06/07. |
| PENDING | ESS-02 | T3 | P0 | Izin end-to-end | Mobile + QA + Backend; CON-01/02 | Create/history/detail/cancel serta permission dan status conflict live lulus. |
| PENDING | ESS-03 | T3 | P1 | Koreksi absensi dan lembur | Mobile + QA + Backend | Create/detail/history/cancel sesuai fitur, koreksi checkout esok hari dan estimasi upah server diuji. |
| PENDING | ESS-04 | T3 | P1 | Kalender dan tukar shift | Mobile + QA + Backend | Holiday JL, next shift kosong/lintas bulan, create/cancel swap, permission dan konflik teruji. |
| PENDING | MGR-01 | T4 | P1 | Workflow manager lengkap selain API-05 | Mobile + QA + Backend; role workflow dan fixture | Queue/detail, reject wajib komentar, escalate, delegation, self-approval, branch context dan lintas tenant teruji; bukti API-05 dipakai ulang, bukan task duplikat. |
| PENDING | MGR-02 | T4 | P1 | ESS lanjutan live | Mobile + QA + Backend; positive/failure fixtures | Loan, EWA, daily activity, trip, claim/receipt, asset dan reporting line teruji. Receipt sudah memakai data.url; tidak mengulang fix filePath lama. |
| PENDING | PAY-01 | T5 | P1 | PIN/unlock/detail/PDF live | Mobile + QA/Security + Backend; HTTPS, akun payroll dan PIN uji aman | Set PIN, unlock/lockout, expiry, detail/PDF, background/resume, account switch dan jaringan buruk lulus. API-04 memakai bukti ini. |
| PENDING | PAY-02 | T5/T7 | P0 | Proteksi layar dan cache native payroll | QA/Security + Mobile; Android/iOS nyata | Screenshot/capture/recent-app preview dan cache PDF diperiksa. iOS privacy cover tidak diklaim memblokir semua screenshot. |

## 5. Firebase dan push end-to-end

| Status | ID | Tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| PENDING | PUSH-01 | T6 | P1 | Delivery Firebase Console Android development | Mobile + QA; token perangkat dan Console | Foreground/background/terminated benar-benar menerima pesan; permission denied/revoked/activation retry diuji. SDK token sudah lulus, jangan dihitung pending lagi. |
| PENDING | PUSH-02 | T6/T8 | P1 | Bootstrap Firebase resmi dan iOS/APNs | Mobile + DevOps + partner; config per environment/app ID dan APNs | Konfigurasi cocok dengan flavor; SDK/lifecycle/permission native Android/iOS terbukti, tanpa fallback dummy production. |
| PENDING | PUSH-03 | T6 | P1 | Aktivasi integrasi token nyata ke backend | Backend + Mobile + DevOps; HTTPS dan kontrak/konfigurasi siap | Register/delete, installation ID, token rotation/reinstall, idempotency, logout offline/online dan account/company scope teruji. Coordinator lokal tersedia, koneksi nyata belum ditutup. |
| PENDING | PUSH-04 | T6 | P1 | Delivery backend, deep link dan isolasi sesi | Backend + Mobile + QA; PUSH-02/03 dan resource fixture | Foreground/background/terminated, duplicate/stale events, resource hilang/403/cross-tenant, unread/read-all/delete/pagination dan account switch teruji. Payload memakai ID stabil, bukan URL arbitrer; lock screen aman. |

## 6. Quality, security, privacy, dan performance

| Status | ID | Tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| DONE | QA-01 | T7 | P0 | Review dan rapikan baseline integrasi | Mobile | Review/cleanup lokal selesai: 20 PNG diagnostik dikeluarkan dari staging atas persetujuan pengguna, 28 PNG lokal utuh, folder failure di-ignore, golden acuan tidak diubah. Full suite baseline 653 PASS; bukan merge/sign-off release. |
| PENDING | QA-02 | T7 | P0 | Tetapkan SDK release dan selesaikan warning KGP firebase_core | Mobile + DevOps | Kandidat stable 3.47.7: 653 test, analyzer dan format PASS; tiga matriks build Android gagal pada validasi built-in Kotlin 2.2.10. Pin CI/SDK utama dipertahankan. Tunggu verifikasi distribusi resmi kompatibel, build native dan iOS; lihat Report QA-02 Toolchain Release. Tidak menggunakan bypass atau edit SDK/cache. |
| IN_PROGRESS | QA-03 | T7 | P0 | Audit dependency native dan ulang audit lockfile final | Mobile + Security/DevOps | 20 Okt: JUnit profile diperbaiki; OSV 175 Maven+188 Pub tanpa advisory dalam cakupan query. 21 Okt: 24 ELF baseline dipetakan; unduhan PDFium Android/XCFramework cocok digest. Guard post-build cache/AAB tiga ABI sudah diterapkan sebelum upload CI; 23 tes terkait, 671 tes penuh dan AAB baru lulus lokal. Verifikasi sebelum ekstraksi hook, triage advisory native, iOS resolved/IPA, build tooling, remote CI dan artifact signed/toolchain final tetap PENDING. Lihat report QA-03 dependency, provenance dan guard. |
| IN_PROGRESS | QA-04 | T7 | P0 | Regresi final demo/production dan UI setelah perubahan terakhir | Mobile + QA | 21 Okt: QA04-UI-01 dan QA04-AUTH-01 FIXED lokal. Regresi terbaru: 675 tes PASS, coverage 81,33%, analyzer/format bersih, APK non-demo debug build PASS. Empat tes bootstrap loopback memakai controller/repository asli: refresh menunggu /me, recovery 503, refresh ditolak dan account switch. Bukti emulator sebelumnya: integration 2 PASS; demo dark/restart/modal/navigasi dan non-demo login setelah demo PASS. Bootstrap UI terautentikasi pada HTTPS/perangkat, coverage login langsung expired, snapshot final toolchain/release tetap PENDING. Remote CI terpisah QA-05; lihat Report QA-04. |
| IN_PROGRESS | QA-05 | T7 | P0 | Remote CI clean checkout | DevOps + Mobile; publikasi ke origin disetujui | Scope commit/branch/PR termasuk pelepasan tracking delapan PNG disetujui. Branch QA dibuat; verifikasi ulang 675 tes PASS, analyzer/format bersih. Origin tertinggal 35 commit baseline lokal. Masih perlu bukti run untuk commit publikasi: quality, Android build/guard/integration dan macOS iOS unsigned. HTTPS backend tidak diperlukan untuk fixture CI; hasil lokal bukan remote PASS. |
| PENDING | QA-06 | T7 | P0 | Build dan lifecycle iOS native | Mobile + QA; macOS/CI dan perangkat iOS | Dependency resolution/build, camera/location/push permission, restart/lifecycle serta sensitive screen teruji. Linux/emulator Android tidak menggantikan iOS. |
| PENDING | QA-07 | T7 | P0 | Android backup/transfer dan Keychain iOS | Mobile + QA/Security; perangkat/OEM dan identifier final | Cloud backup/transfer, kebijakan device-only/migrasi/reinstall/recovery terbukti. synchronizable:false saja tidak membuktikan no-migration. |
| PENDING | QA-08 | T7 | P1 | Performance perangkat target | Mobile + QA + Product; low/mid-range Android/iOS dan threshold | Startup/first frame, frame-time/jank, memori, APK/AAB/IPA, baterai kamera/GPS diukur dengan build/config tercatat. |
| PENDING | QA-09 | T7/T8 | P0 | Privacy dan siklus hidup data | Backend + Product + Security/Legal + Mobile | Consent biometrik/lokasi/selfie, retensi/penghapusan server, privacy policy, Data Safety dan App Privacy disepakati serta sesuai implementasi. |

### Preflight QA-05, 22 Oktober 2026

- `origin`: [run 36093545917](https://github.com/irvansindy/hris-mobile-app/actions/runs/36093545917),
  commit `3e9719e31dc5adef167240287177afbe76719133`, status failure.
  Log analyzer menyebut `assets/images/` tidak tersedia. File
  `assets/images/.gitkeep` kini sudah tracked pada HEAD lokal, diperkenalkan
  melalui commit `9e92230`; ini bukan bukti run remote baru sudah lulus.
- `draft`: [run 36093599189](https://github.com/solusidigitalkita1001-sudo/hris-mobile-draft/actions/runs/36093599189),
  commit yang sama, status failure pada langkah analyzer. Log penyebab spesifik
  hanya diperiksa untuk `origin`; kedua job Android/iOS masing-masing skipped.
- Pemeriksaan GitHub memakai daftar run repository, bukan menyimpulkan tidak ada
  run dari wrapper yang hanya memfilter event pull request. Tiga run terbaru pada
  setiap remote diperiksa; run paling baru yang dikembalikan bertanggal 25 September.
- `rtk flutter test --no-pub test/architecture/ci_workflow_test.dart`:
  **6 PASS**, exit 0. Tidak mengulang full suite atau build pada preflight ini;
  hasil 675 tes pada QA-04 tetap bukti snapshot 21 Oktober, bukan remote CI.
- Workflow baru dan patch aplikasi belum seluruhnya menjadi commit. Guard
  `tool/verify_native_pdfium.dart` serta tes bootstrap baru masih untracked.
  Rerun commit September tidak akan menguji perbaikan Oktober.
- Pengguna memilih `origin` (`irvansindy/hris-mobile-app`) pada 22 Oktober;
  `draft` tidak menjadi tujuan push untuk QA-05. Pengguna sudah menyetujui
  [scope commit/branch/PR](<QA-05 Scope Publikasi CI - 2026-10-22.md>), termasuk
  pelepasan tracking delapan PNG diagnostik pada baseline lama, dengan file lokal
  tetap disimpan. Eksekusi branch/verifikasi lokal berlanjut pada 23 Oktober;
  commit/push/PR dan pembuktian run dicatat dalam scope tersebut.
  File kredensial utama di-ignore dan tidak tracked; scan pola secret umum
  tidak menemukan kecocokan pada cakupan yang diperiksa, bukan security clearance.
  Jangan melakukan `git add .` atau push otomatis atas seluruh worktree.
  Pemeriksaan ini tidak mengubah index, HEAD, branch atau state GitHub.

## 7. Konfigurasi staging dan production

| Status | ID | Tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| PENDING | REL-01 | T8 | P0 | HTTPS staging/production dan pemisahan environment | Backend + DevOps | Sertifikat valid dan dapat diakses Android/iOS; release tidak membutuhkan pengecualian HTTP. Probe tanpa kredensial 21 Okt ke HTTPS pada host:8084 saat ini gagal curl35/wrong version number; URL HTTPS alternatif belum diberikan. HTTP development bukan staging siap. |
| PENDING | REL-02 | T8 | P0 | App ID/bundle ID final | Partner + Product + Mobile | Identifier Android/iOS tiap environment disepakati. com.example.hrm_app masih identifier development sementara. |
| PENDING | REL-03 | T8 | P0 | Flavor dan konfigurasi eksplisit demo/staging/production | Mobile + DevOps; REL-01/02 dan Firebase per environment | Setiap artifact memakai backend, repository dan Firebase yang tepat; tidak mencampur config personal ke production. |
| PENDING | REL-04 | T8 | P0 | Android dan Apple signing | Partner + DevOps + Mobile; upload/app key, Apple Team/certificate/profile/entitlement/APNs | Material aman di CI/secrets; signed build dapat diverifikasi. Jangan menyimpan private key/password di repo/chat. |
| PENDING | REL-05 | T8 | P0 | Identitas aplikasi dan metadata distribusi | Product + partner + Mobile | Nama, icon/splash, versioning, support contact, privacy URL dan permission purpose strings final; deklarasi mengikuti QA-09. |
| PENDING | REL-06 | T8 | P0 | Lengkapi release guards dan distribusi internal | Mobile + DevOps; REL-01–05, QA-05/06 | Guard menolak HTTP/example ID/debug signing/demo repository/Firebase salah; signed staging Android/iOS terpasang lewat distribusi internal. Guard parsial/debug APK bukan bukti selesai. |

## 8. Staging smoke, UAT, release candidate, dan rollout

| Status | ID | Tahap | Prioritas | Pekerjaan yang belum selesai | Owner dan dependency | Bukti penutupan |
| --- | --- | --- | --- | --- | --- | --- |
| PENDING | UAT-01 | T9 | P0 | Smoke endpoint dan sinkronisasi live route map | Backend + Mobile + QA; staging/fixture dan akses inventory berwenang | Smoke 0 failed/blocked; /meta/endpoints cocok dengan OpenAPI dan matriks. Akun employee/manager kini 403 pada inventory, bukan alasan menambah privilege mobile. |
| PENDING | UAT-02 | T9 | P0 | E2E lintas role/company | QA + Backend + Mobile; fixture siap | Auth, attendance, ESS, approval, payroll, push, logout/recovery diuji sesuai scope employee/manager/HR-admin. Gunakan bukti API-02 dan acceptance fitur; tidak menduplikasi eksekusi tanpa alasan. |
| PENDING | UAT-03 | T9 | P0 | Install/upgrade dan failure recovery | QA + Mobile + Backend; artifact staging | Fresh install, upgrade, reinstall, offline/poor network, session expiry, maintenance dan 5xx teruji tanpa data silang atau mutation ganda. |
| PENDING | UAT-04 | T9 | P0 | Sign-off dan freeze release candidate | Product + QA + Security + DevOps | Bukti UAT, build/commit, known limitations, rollback criteria dan persetujuan tercatat; RC identik artifact rilis, hanya blocker fix setelah freeze. |
| PENDING | LIVE-01 | T10 | P0 | Readiness operasional dan rollback | Backend + DevOps + Product + Mobile | Backup/migration diverifikasi; owner on-call, monitoring, kill switch/feature flag dan rollback aplikasi/server disiapkan serta diuji sesuai prosedur. |
| PENDING | LIVE-02 | T10 | P0 | Rollout bertahap dan hypercare | DevOps + Product + Backend + Mobile + QA | Internal/pilot/persentase bertahap berdasarkan crash/API latency/login/refresh/attendance/push/workflow; incident dan known issue ditangani hingga periode observasi disetujui. |

## 9. Di luar rilis awal dan backlog bersyarat

| Status | ID | Scope | Pekerjaan | Keputusan / syarat |
| --- | --- | --- | --- | --- |
| DEFERRED | POST-01 | Revisi 7 | HR Helpdesk | Pengguna menyetujui ditunda dari rilis awal pada 19 Oktober. Adopsi berikutnya memerlukan scope dan schema baru. |
| DEFERRED | POST-02 | Revisi 7 | Feed & Kudos | Keputusan sama; tidak menambah menu atau dependency pada rilis awal. |
| DEFERRED | POST-03 | Revisi 7 | Timesheet | Keputusan sama; kebutuhan employee/approver ditentukan saat adopsi berikutnya. |
| CONDITIONAL | OPT-01 | Face ID lokal | Embedding/on-device identity match dan liveness nyata | Belum disetujui sebagai tambahan scope production. Butuh model/lisensi, preprocessing/tensor/version, inference, kalibrasi similarity/dataset, threat model/liveness, blur/cahaya, secure template/migrasi/recovery dan kontrak device binding. Demo saat ini hanya metadata deteksi, bukan identitas/liveness. Production tetap menyerahkan face match ke backend. |
| CONDITIONAL | OPT-02 | Careers/custom fields | Adopsi halaman karier publik atau custom fields employee | Tidak termasuk revisi sekarang. Membutuhkan kebutuhan Product; custom fields self-service belum memiliki endpoint khusus. Bukan otomatis blocker go-live. |

Chat tidak termasuk keputusan penundaan tiga modul di atas. Pengecualian atau
adopsinya masih perlu keputusan tersendiri melalui CON-06.

## 10. Pekerjaan selesai yang tidak dihitung ulang

- Shared presentation demo/production tersedia; revalidasi final ada pada QA-04.
- Implementasi lokal revisi API 1–5 dan pembaruan dokumentasi poin 6 tersedia.
- Keputusan scope revisi 7 selesai; implementasi ketiga modul DEFERRED.
- Login employee terbaru, auth/me, GET today/payslip/cuti/saldo/notifikasi,
  profil sendiri dan logout berhasil pada smoke development.
- Profil live memakai employee ID yang cocok dengan sesi dan nomor terpisah;
  isolasi dua tenant tetap API-02.
- `/payroll/payslips` menghasilkan satu record; ini bukan multi-slip PASS.
- Regresi lokal terdahulu 653 tes, subset prioritas 190 tes; angka ini historis,
  bukan hasil pengujian ulang dalam penyusunan dokumen.
- Dua skenario fixture Android emulator lulus; bukan transaksi server nyata.
- Firebase SDK development memperoleh dan menghapus token nyata pada emulator;
  delivery Console dan registrasi HRIS tetap PUSH-01/03.
- Konflik cleanup token legacy/coordinator sudah diperbaiki dan diregresikan.
  Jangan mengulanginya sebagai task implementasi baru dari checklist lama.
- Receipt claim memakai data.url; tes live tetap bagian MGR-02.

## 11. Urutan eksekusi dan filtering

1. Selesaikan dependency P0: HTTPS, akun/fixture, kontrak izin/payslip/carry-over,
   identifier, privacy dan akses platform.
2. QA-01 selesai lokal; lanjutkan QA-02–04 sambil dependency eksternal dipenuhi.
3. Jalankan acceptance fitur dan push, perbaiki defect, lalu signed staging dan
   remote CI. Konfigurasi release bisa disiapkan paralel, tidak mengganti acceptance.
4. Tutup security/privacy/performance, jalankan UAT, sign-off dan freeze RC.
5. Rollout bertahap, monitoring dan hypercare. Jangan melewati gate release
   karena task PENDING sebelumnya diizinkan dilewati saat development.

```bash
rtk rg '^\| PENDING \|' 'docs/Rekap Seluruh Task Belum Selesai - 2026-10-19.md'
rtk rg '^\| TODO \|' 'docs/Rekap Seluruh Task Belum Selesai - 2026-10-19.md'
rtk rg '^\| IN_PROGRESS \|' 'docs/Rekap Seluruh Task Belum Selesai - 2026-10-19.md'
rtk rg '^\| (PENDING|TODO|IN_PROGRESS) \|.*\| P0 \|' 'docs/Rekap Seluruh Task Belum Selesai - 2026-10-19.md'
rtk rg '^\| (DEFERRED|CONDITIONAL) \|' 'docs/Rekap Seluruh Task Belum Selesai - 2026-10-19.md'
```

Untuk menutup baris: catat tanggal, owner, versi kontrak/commit/build,
platform/perangkat, hasil aktual dan bukti yang disanitasi. Ubah status menjadi
DONE setelah kriteria terbukti. Jangan mengirim password, PIN, token, private
key, selfie/template wajah, isi slip gaji, atau koordinat presisi dalam report.

## Referensi

- [Regresi demo/non-demo QA-04](<Report QA-04 Regresi Demo Production - 2026-10-21.md>)
- [Audit native QA-03](<Report QA-03 Audit Dependency Native - 2026-10-20.md>)
- [Provenance binary native QA-03](<Report QA-03 Provenance Binary Native - 2026-10-21.md>)
- [Guard integritas PDFium QA-03](<Report QA-03 Guard Integritas PDFium - 2026-10-21.md>)
- [Investigasi toolchain QA-02](<Report QA-02 Toolchain Release - 2026-10-19.md>)
- [Report eksekusi prioritas P0](<Report Eksekusi Prioritas P0 - 2026-10-19.md>)

- [Matriks migrasi Oktober](<Migrasi API Oktober 2026 - Matriks dan Report.md>)
- [Verifikasi integrasi terbaru](<Verifikasi Integrasi Pasca Migrasi API - 2026-10-19.md>)
- [Rekap backend sebelumnya](<Rekap Task Tertunda dan Kebutuhan Backend - 2026-10-18.md>)
- [Acceptance absensi](<Tahap 2 Acceptance Live Tertunda.md>)
- [ESS inti](<Tahap 3 Employee Self-Service Inti.md>)
- [Workflow dan ESS lanjutan](<Tahap 4 Workflow Manager dan ESS Lanjutan.md>)
- [Payroll](<Tahap 5 Payroll dan Payslip Aman.md>)
- [Acceptance push](<Tahap 6 Acceptance Push Live Tertunda.md>)
- [Firebase development](<Firebase Android Development.md>)
- [Release gate quality](<Tahap 7 Acceptance Release Gate Tertunda.md>)
- [Status Face ID lokal](face-id/implementation-status.md)

Jika checklist lama bertentangan dengan pembaruan di atas, gunakan bukti
bertanggal terbaru. Rekap ini mempertahankan ketidakpastian yang belum
diputuskan; bukan menyatakan semua task eksternal sudah gagal atau belum ada kode.
