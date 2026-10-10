# HRIS Mobile App Go-Live Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyelesaikan sinkronisasi kontrak API, validasi fitur, konfigurasi production, UAT, dan rollout HRIS Mobile App sampai siap go-live.

**Architecture:** Demo dan production memakai presentation/controller yang sama. Perbedaannya hanya repository dan data source yang dipilih saat bootstrap. Server tetap menjadi sumber kebenaran untuk identitas, permission, waktu, status workflow, dan data transaksi.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, secure storage, ML Kit/camera, Firebase Messaging, Android, iOS, GitHub Actions.

**Spec:** `docs/api-for-mobile-apps/README.md`, `docs/api-for-mobile-apps/openapi.yaml`, dan `docs/api-for-mobile-apps/checklist-perubahan-api.md`.

## Global Constraints

- Production wajib memakai HTTPS; HTTP hanya boleh untuk development environment yang disetujui.
- Tidak ada secret, credential, signing material, atau URL environment di source control.
- Demo repository tidak boleh dapat terpilih pada build production.
- Mutation tidak boleh menampilkan status sukses sebelum server mengonfirmasi.
- Absensi tidak memiliki offline queue.
- Setiap tahap wajib lulus format, analyzer, test terkait, dan review perubahan.

## Status Awal

- Shared presentation demo/production dan baseline UI sudah diterapkan, tetapi harus diregresikan setelah penyesuaian kontrak terbaru.
- CI, golden, dan virtual-device acceptance sebelumnya telah dikerjakan; hasilnya bukan bukti release setelah perubahan berikutnya.
- HTTPS staging, application ID final, Firebase project, signing Android, dan Apple signing masih menjadi dependency eksternal.
- Positive live test sejumlah endpoint masih tertahan permission atau fixture backend.

---

## Tahap 0 — Bekukan Baseline dan Matriks Kontrak (P0)

**Owner:** Mobile + Backend
**Tujuan:** Membuat satu sumber status sebelum implementasi baru dimulai.

**Status 5 Oktober 2026:** Selesai lokal; keputusan backend masih pending. Lihat `docs/Tahap 0 Baseline dan Matriks Kontrak API Mobile.md`.

- [x] Simpan dan review seluruh perubahan working tree yang sedang berjalan; jangan mencampur perubahan lama dengan penyesuaian kontrak baru.
- [x] Buat matriks seluruh path/method OpenAPI terhadap data source, repository, controller, layar, dan test Flutter.
- [x] Klasifikasikan setiap endpoint: implemented, partial, untested-live, blocked-backend, atau not-required-mobile.
- [x] Dokumentasikan permintaan backend untuk memperbaiki `ErrorEnvelope`: field `code` tidak boleh `required` bila runtime dapat menghilangkannya.
- [x] Catat ketidakpastian `shiftDate`, permission-request dates/duration, upload limit, dan response schema yang belum ketat.
- [x] Validasi sintaks OpenAPI dan bekukan versi/commit dokumen yang menjadi baseline.

**Exit gate:** Tidak ada endpoint mobile tanpa status dan owner; semua kontradiksi dokumentasi memiliki keputusan tertulis.

## Tahap 1 — Sinkronisasi Network, Error, dan Session (P0)

**Owner:** Mobile
**Area:** `lib/core/`, authentication, session lifecycle.

- [x] Jadikan `error.code` nullable dan sediakan fallback aman berdasarkan HTTP status.
- [x] Refresh hanya untuk `TOKEN_EXPIRED` atau `AUTHENTICATION_FAILED`, satu kali dan single-flight.
- [x] Pastikan error payroll 401 tidak memicu refresh atau logout.
- [x] Terapkan `X-Client-Type: mobile` hanya pada login dan refresh.
- [x] Terapkan `X-Correlation-Id`, redacted logging, timeout, retry aman, dan idempotency key pada mutation yang didukung.
- [x] Setelah refresh, ganti access/refresh token serta user, role, permission, menu, company, dan session version secara atomik.
- [x] Pastikan logout membersihkan token, cache per-user/per-company, device token, dan data Face ID lokal.
- [x] Tambahkan contract, repository, concurrency, dan session-isolation tests.

Status mobile lokal: selesai 6 Oktober 2026. Penghapusan registration device
di server tetap berada pada Tahap 6 karena bergantung pada implementasi
registrasi `installationId` dan Firebase per environment.

**Exit gate:** Seluruh test auth/session lulus; tidak ada retry loop, stale identity, atau logout palsu.

## Tahap 2 — Absensi dan Face Recognition Production Path (P0)

**Owner:** Mobile + Backend + QA
**Dependency:** Akun employee dengan kalender, lokasi, dan metode absensi aktif.

- [x] Gunakan `/attendance/me/today` untuk menentukan tombol, metode, server date/time/timezone, dan eligibility.
- [x] Check-in mengirim `deviceGps` dan hanya `faceRecognition.selfieImage`; hapus derived face fields dari payload.
- [x] Check-out mengirim GPS tetapi tidak mengirim face-recognition payload.
- [x] Pertahankan local multi-angle enrollment hanya untuk demo; production mengikuti kontrak enrollment/verifikasi backend yang disepakati.
- [x] Tangani fake GPS, wajah tidak cocok, permission kamera/lokasi, timeout, duplicate submit, dan open checkout maksimal 36 jam.
- [x] Arahkan kegagalan yang tidak dapat dipulihkan ke koreksi absensi, tanpa offline punch queue.
- [ ] Uji masuk dan pulang pada Android/iOS real device, termasuk app restart dan pergantian jaringan.

**Exit gate:** Check-in dan check-out nyata tercatat satu kali di server dan muncul konsisten pada today/history.

Status mobile otomatis: selesai 6 Oktober 2026. Contract, controller, widget,
parity, analyzer, format, dan full test suite lulus. Exit gate live tetap menunggu
akun attendance yang siap serta acceptance Android/iOS terhadap server staging.
Checklist acceptance yang ditunda dicatat terpisah di
`docs/Tahap 2 Acceptance Live Tertunda.md` dan tetap menjadi release blocker.

## Tahap 3 — Employee Self-Service Inti (P0/P1)

**Owner:** Mobile + Backend

Rencana implementasi terperinci:
`docs/superpowers/plans/2026-10-07-stage-3-employee-self-service-core.md`.

- [ ] Finalisasi attendance history, correction, overtime, leave balance/history/create/detail/cancel, dan permission request. Semua area lulus otomatis kecuali create izin yang masih diblokir kontrak backend.
- [x] Pertahankan `employeeId`/`companyId` pada create leave selama backend masih mewajibkannya, tetapi ambil nilainya dari session aktif.
- [x] Implementasikan pagination berdasarkan `meta.hasNextPage`; jangan mengasumsikan `totalPages >= 1`.
- [x] Dukung kalender day type `JL`, next shift, holiday, dan shift swap dengan state kosong/error yang jujur.
- [x] Pastikan PII bertopeng tidak divalidasi atau dikirim kembali sebagai nilai asli.
- [ ] Lengkapi positive live fixtures dan manual acceptance untuk leave, izin, terlambat, koreksi, dan lembur.

Status mobile otomatis 7 Oktober 2026: PASS, 481 test dan analyzer hijau.
Detail implementasi, bukti, blocker create izin, dan acceptance yang belum
dijalankan tersedia di `docs/Tahap 3 Employee Self-Service Inti.md`.

**Exit gate:** Seluruh alur employee P0 lulus contract test dan positive live test.

## Tahap 4 — Workflow Manager dan ESS Lanjutan (P1)

**Owner:** Mobile + Backend + QA

- [x] Finalisasi queue, detail, approve, reject wajib komentar, bulk partial-success, dan delegation melalui workflow engine.
- [x] Uji larangan self-approval dan 403 karena permission/company scope secara otomatis lokal.
- [x] Finalisasi loan, EWA, daily activity, travel, claim, asset, reporting line, dan attachment privat secara lokal.
- [ ] Gunakan URL upload yang benar untuk receipt dan endpoint terotorisasi untuk download; jangan memakai `/uploads/*` langsung.
- [ ] Backend menyediakan permission manager, pending workflow, branch context, dan fixture positif yang diperlukan.
- [x] Nyatakan chat unavailable sampai kontrak endpoint tersedia; jangan membuat data production palsu.

Status mobile lokal 8 Oktober 2026: implementasi dan seluruh gate otomatis
selesai. Detail bukti serta blocker live tersedia di
`docs/Tahap 4 Workflow Manager dan ESS Lanjutan.md`. Positive live fixture,
download attachment employee yang terotorisasi, dan real-device acceptance
tetap menjadi blocker exit gate.

**Exit gate:** Semua modul yang masuk release scope memiliki happy path, failure path, permission test, dan fixture live.

## Tahap 5 — Payroll dan Payslip Aman (P1)

**Owner:** Mobile + Backend + Security

- [x] Terapkan employee PIN flow: status, set PIN, unlock, detail, dan PDF dengan `X-Payslip-Unlock`.
- [x] Simpan unlock token hanya di memory dan hapus saat timeout, background policy, logout, atau pergantian akun.
- [x] Tangani lockout, attempt limit, unknown payroll component code, dan binary PDF.
- [x] Pastikan daftar payslip terkunci tidak membocorkan nominal.
- [x] Pisahkan tegas employee unlock dari admin payroll unlock.

Status mobile lokal 9 Oktober 2026: implementasi dan seluruh gate otomatis
selesai. Analyzer bersih, 556 test lulus, 12 golden payroll telah diinspeksi,
dan Android debug build berhasil. Detail bukti dan blocker live tersedia di
`docs/Tahap 5 Payroll dan Payslip Aman.md`. Exit gate live masih menunggu
staging HTTPS, akun employee payroll aktif, review security pada perangkat,
serta acceptance Android/iOS.

**Exit gate:** Security review dan device acceptance memastikan tidak ada token/PIN/nominal sensitif di log, cache, atau screenshot state yang tidak semestinya.

## Tahap 6 — Push Notification dan Deep Link (P1)

**Owner:** Mobile + Backend + DevOps

- [ ] Sediakan Firebase Android/iOS untuk setiap environment.
- [ ] Registrasikan installation ID, platform, provider, dan token melalui `/notifications/device-tokens` setelah login/refresh token FCM.
- [ ] Hapus registration saat logout dan tangani token rotation/reinstall.
- [x] Implementasikan list, unread count, read, read-all, delete, serta deep link hanya ke route yang diizinkan (verifikasi lokal; acceptance live terpisah).
- [ ] Uji foreground, background, terminated, duplicate notification, dan account switch.

**Exit gate:** Push staging diterima pada Android/iOS dan tidak membuka data tenant/account lain.

Task 1 sampai 5 selesai untuk scope dummy/local: 619 test lulus, analyzer
0 issue, format bersih, APK debug berhasil, dan simulator diuji pada emulator.
Login emulator non-demo mendapat 401 sehingga inbox server terautentikasi
belum diterima. Firebase/APNs dan exit gate OS live tetap tertunda, bukan PASS.
Lihat `docs/Tahap 6 Push Notification dan Deep Link.md` dan
`docs/Tahap 6 Acceptance Push Live Tertunda.md` untuk bukti dan checklist lanjut.

## Tahap 7 — Quality, Security, Privacy, dan Performance Gate (P0)

**Owner:** Mobile + QA + Security

- [ ] Jalankan format, analyzer, seluruh unit/widget/contract/golden/integration test dan Android build di CI.
- [ ] Tambahkan macOS CI untuk build iOS tanpa signing dan validasi CocoaPods.
- [ ] Jalankan regression demo dan production repository pada light/dark, text scaling, locale, empty/loading/error, dan reduced motion.
- [ ] Audit secure storage, TLS, cleartext policy, PII masking, screenshot/log exposure, dependency vulnerability, dan privacy disclosure.
- [ ] Ukur startup, jank, memory, ukuran APK/IPA, serta camera/location battery impact pada perangkat kelas target.
- [ ] Tutup warning plugin/Kotlin yang mengancam build Flutter berikutnya.

**Exit gate:** Full CI hijau dari checkout bersih; tidak ada defect P0/P1 atau temuan security kritis/tinggi.

## Tahap 8 — Konfigurasi Staging dan Production (P0, External Gate)

**Owner:** Backend + DevOps + Mobile

- [ ] Sediakan HTTPS staging dan production base URL dengan sertifikat valid.
- [ ] Tetapkan application ID/package name dan iOS bundle identifier final per flavor.
- [ ] Buat flavor `demo`, `staging`, dan `production` dengan entry configuration yang eksplisit.
- [ ] Sediakan Firebase config per flavor tanpa memasukkan secret sensitif ke repository publik.
- [ ] Sediakan Android upload/app-signing key melalui CI secrets.
- [ ] Sediakan Apple Team ID, certificates, provisioning profiles, entitlements, dan APNs capability.
- [ ] Finalisasi app name, versioning, icon/splash, privacy policy URL, data-safety declarations, permission purpose strings, dan support contact.
- [ ] Tambahkan release guards yang menolak HTTP, example app ID, debug signing, demo repository, atau konfigurasi Firebase yang salah.

**Exit gate:** Signed staging build terpasang melalui jalur distribusi internal Android dan iOS.

## Tahap 9 — Staging Smoke, UAT, dan Release Candidate (P0)

**Owner:** QA + Product + Backend + Mobile

- [ ] Jalankan backend `scripts/mobile-api-smoke.mjs` dengan hasil 0 failed dan 0 blocked.
- [ ] Bandingkan live route map `/meta/endpoints` dengan OpenAPI dan matriks client.
- [ ] Uji role employee, manager, HR/admin serta minimal dua company untuk isolasi tenant.
- [ ] Jalankan end-to-end auth, attendance, ESS, approval, payroll, notification, logout, account switch, dan recovery.
- [ ] Uji upgrade dari versi sebelumnya, fresh install, reinstall, offline/poor network, session expiry, dan maintenance/5xx.
- [ ] Catat bukti UAT, screenshot/video, build number, known limitations, rollback criteria, dan persetujuan Product/QA/Security.
- [ ] Bekukan release candidate; hanya blocker fixes yang boleh masuk setelah freeze.

**Exit gate:** UAT ditandatangani, 0 blocker, dan release candidate yang disetujui identik dengan artifact yang akan dirilis.

## Tahap 10 — Go-Live dan Hypercare

**Owner:** DevOps + Product + Mobile + Backend

- [ ] Backup dan verifikasi migration/backend readiness sebelum window rilis.
- [ ] Rilis bertahap: internal, pilot users, persentase kecil, lalu peningkatan bertahap berdasarkan telemetry.
- [ ] Pantau login/refresh failure, crash-free users, API 4xx/5xx, latency, attendance failure, push delivery, dan workflow failure.
- [ ] Siapkan feature flag/kill switch dan prosedur rollback untuk build serta backend.
- [ ] Triage incident dengan correlation ID tanpa meminta token, password, selfie, atau PII pengguna.
- [ ] Setelah periode hypercare disetujui, tutup known issues, dokumentasikan post-release review, dan pindahkan backlog non-release.

**Exit gate:** Rollout 100% stabil selama periode observasi yang disepakati, tanpa insiden P0/P1 terbuka.

## Urutan Eksekusi

`Tahap 0 → 1 → 2 → 3 → 4/5/6 → 7 → 8 → 9 → 10`

Tahap 4, 5, dan 6 dapat berjalan paralel setelah fondasi tahap 1 stabil. Tahap 8 dapat dipersiapkan lebih awal oleh Backend/DevOps, tetapi release tidak boleh melewati tahap 7 dan 9.

## Review Focus

- Response error tanpa `code` tetap menghasilkan pesan dan aksi recovery yang aman.
- Dua request 401 bersamaan hanya menjalankan satu refresh dan masing-masing diretry maksimal sekali.
- Account/company switch tidak membawa cache, push token, Face ID, payslip unlock, atau data pengguna sebelumnya.
- Mutation yang timeout tidak menghasilkan duplicate record ketika user mencoba ulang.
- Build production tidak dapat memakai HTTP, debug signing, example app ID, atau demo data source.
