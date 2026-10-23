# Migrasi API Oktober 2026: Matriks dan Report Flutter

Tanggal: 18 Oktober 2026.
Lingkup: penyesuaian client Flutter terhadap perubahan backend Oktober,
bukan penerapan server atau persetujuan release.

## Dasar perubahan

Sumber: [checklist backend Oktober](api-for-mobile-apps/api-change-checklist-mobile-2026-10.md),
salinan dari `api-change-checklist-mobile-2026-10.md` yang dikirim backend.
Dokumen backend menyebut jendela commit `58aa2f4` sampai `30d9f37` dan tidak
ada endpoint yang dihapus. Riwayat dan deployment backend tersebut belum
diverifikasi langsung dalam pekerjaan Flutter ini.

Matriks ini merupakan addendum baseline Tahap 0. OpenAPI lama tidak diubah
untuk menebak endpoint atau schema baru yang belum lengkap.

## Matriks revisi

| Urutan | Perubahan backend | Penyesuaian Flutter | Status |
| --- | --- | --- | --- |
| 1 | Login `user.mustChangePassword`, runtime `403 PASSWORD_CHANGE_REQUIRED` | Gate login/router lama dipertahankan. Interceptor mengaktifkan gate sesi saat menerima kode spesifik; tidak refresh, logout, atau replay mutation. | Implementasi lokal tersedia; acceptance server tertunda. |
| 2 | `employeeNumber`, `assetCode`, `leaveType.code` unik per tenant | Profil memakai employee ID dari sesi/response yang sudah divalidasi. Nomor employee menjadi field tampilan terpisah. Asset assignment dan referensi cuti tetap memakai ID, bukan kode global. | Implementasi lokal tersedia. |
| 3 | Lebih dari satu payslip per periode | Daftar mempertahankan semua record, key dan navigasi memakai `payslip.id`. Nama dan nomor payroll run menjadi pembeda jika tersedia. | Implementasi lokal tersedia; path daftar perlu konfirmasi. |
| 4 | Permission admin aset/report/cuti diperketat; approval dapat 403/409 | App tetap memakai `/assets/my`; tidak menambahkan fitur admin. Workflow tetap lewat engine dan tidak mencoba endpoint approval legacy saat ditolak. | Cakupan mobile diperiksa; acceptance permission server tertunda. |
| 5 | `carryOverDays`, `carryOverExpiredAt` | Model dan mapper dashboard menyimpan metadata opsional, kartu saldo menampilkannya. Tidak menambahkan carry-over lagi ke saldo/quota utama. | Implementasi lokal tersedia. |
| 5 | Field/enum aditif dan kondisi aset string bebas | Field tambahan tidak mematahkan parser. Status request asing tetap `unknown`, bukan pending. Kondisi aset membaca `conditionAtAssign`, `conditionAtReturn`, dan alias lama. | Regresi lokal ditambahkan untuk modul yang dipakai. |
| 5 | `X-Request-Id`, `X-Correlation-Id` diizinkan | UUID request baru per percobaan HTTP, termasuk refresh. Correlation ID request logis dan idempotency key mutation tetap dipertahankan saat retry. | Implementasi lokal tersedia. |
| 6 | Dokumentasi integrasi terbaru | Addendum ini, tautan baseline, breakdown, dan rekap backend diperbarui. | Dokumentasi tersedia. |
| 7 | Helpdesk, engagement, timesheet, careers, custom fields | Helpdesk, Feed & Kudos, dan Timesheet ditunda dari rilis awal atas persetujuan pengguna. Careers/custom fields tetap tidak ditambahkan pada revisi ini. | DONE: keputusan scope tiga modul; implementasi DEFERRED setelah rilis awal. |

## Detail keamanan autentikasi

- Gate aktif sejak login/restore ketika flag password wajib tersedia.
- Respons 403 generik tidak dianggap kewajiban mengganti password.
- Respons lama setelah logout tidak memulihkan sesi atau mengaktifkan gate akun lain.
- Gate dilatch pada revision sesi aktif. Refresh yang sudah berjalan tidak
  boleh menimpanya dengan `mustChangePassword:false` dari snapshot lama.
- Jika baca/tulis secure storage gagal, gate di memori tetap berlaku tanpa
  exception async yang tidak tertangani. Persistensi best-effort; restore
  aplikasi berikutnya tetap memverifikasi sesi melalui server.
- Layar ganti password dan alur logout/login kembali yang sudah ada digunakan
  ulang; tidak menambahkan layar atau data source khusus demo.

## Konfirmasi yang masih dibutuhkan dari backend

### Path daftar payslip

Checklist Oktober menyebut `GET /payroll/payslips/my`, sementara OpenAPI lokal
dan integrasi sebelumnya memakai `GET /payroll/payslips`.

Path client sementara tetap `/payroll/payslips`. Tidak ada fallback otomatis
ke endpoint lain karena belum jelas apakah path lainnya memiliki scope atau
shape yang sama. Mohon backend mengonfirmasi path canonical, alias yang masih
didukung, serta contoh response self-service terkini.

### Pembeda jenis slip

`runType` belum diekspos pada self-service menurut checklist backend. UI hanya
menampilkan `payrollRun.name`/`runNumber` jika dikirim; tidak menyimpulkan
REGULAR/THR/SEVERANCE/CORRECTION dari teks nama. Tambahkan kontrak `runType`
jika label jenis yang terstruktur dibutuhkan Product.

### Semantik carry-over

Client menampilkan nilai dan tanggal dari server sebagai metadata. Mohon
konfirmasi apakah quota/remaining sudah termasuk carry-over, satuan pecahan
hari, nullability, dan timezone tanggal hangus. Client tidak melakukan accrue,
pengurangan akibat expiry, atau perhitungan saldo otoritatif sendiri.

## Scope modul baru

Keputusan pengguna 19 Oktober 2026: HR Helpdesk, Feed & Kudos, dan Timesheet
ditunda dari rilis awal. Fokus rilis tetap menutup kompatibilitas dan acceptance
modul yang sudah ada. Poin 7 selesai sebagai keputusan scope; ketiga fitur
belum diimplementasikan dan masuk backlog setelah rilis awal. Adopsi kembali
memerlukan persetujuan scope baru dan kontrak lengkap.

| Modul | Status adopsi | Kebutuhan sebelum implementasi |
| --- | --- | --- |
| HR Helpdesk | DEFERRED dari rilis awal (disetujui) | Untuk adopsi berikutnya: persetujuan scope baru, enum category, schema list/comment/close, error dan pagination cursor. |
| Feed & Kudos | DEFERRED dari rilis awal (disetujui) | Untuk adopsi berikutnya: persetujuan scope baru, enum badge, schema response, aturan hapus/moderasi, pagination `before`. |
| Timesheet | DEFERRED dari rilis awal (disetujui) | Untuk adopsi berikutnya: persetujuan scope employee/approver, schema proyek/entry, status/editability, pagination sesuai endpoint. |
| Careers publik | Tidak ditambahkan pada revisi ini | Konfirmasi kebutuhan mode publik dan tenant yang mengaktifkan fitur. |
| Custom fields employee sendiri | Menunggu kebutuhan dan endpoint | Backend belum menyediakan self-service khusus nilai milik sendiri. |
| Endpoint admin-only Oktober | Di luar scope ESS saat ini | Tidak membuat UI admin payroll/report/import/aset dari daftar endpoint baru. |

Cursor tidak dipaksakan pada modul lama yang memakai page/limit. Sebaliknya,
modul baru tidak boleh memakai model pagination page/limit secara otomatis.

## Pengujian dan review

Regresi yang direproduksi sebelum perbaikan:

- Runtime password-required belum mengaktifkan gate sesi.
- Mapper Profil memakai nomor employee sebagai ID.
- Slip satu periode belum menampilkan pembeda nama/nomor run.
- Carry-over belum dipetakan/ditampilkan dan request attempt belum memiliki ID.
- Refresh in-flight menimpa gate password dan kegagalan storage melepas error async.
- Kondisi aset `conditionAtAssign` belum terbaca.

Tes tambahan mencakup penolakan workflow 403/409 tanpa fallback, enum request
asing, optional carry-over invalid, pemilihan ID slip yang benar, serta Home
320 dp/text 200% light/dark. Informasi carry-over memakai tipografi dan warna
tema yang sudah ada, tanpa perubahan navigasi atau desain utama.

Review menemukan dua masalah penting pada gate password: race refresh dan
kegagalan storage. Keduanya memiliki reproduksi RED lalu pengujian GREEN.

Hasil verifikasi lokal:

- `rtk flutter test --no-pub --coverage`: 653 tes lulus.
- `rtk flutter analyze`: tanpa issue.
- Format `lib test tool integration_test`: 282 file, tanpa perubahan diperlukan.
- `git diff --check`: lulus.
- Build APK Android development: berhasil, artifact
  `build/app/outputs/flutter-apk/app-debug.apk`. Build memakai
  `APP_ENV=development`, `PUSH_MODE=disabled`, dan `ENABLE_LOGGING=false`.
- Warning KGP `firebase_core` masih menjadi backlog tooling, bukan ditutup oleh
  migrasi API ini.

Pengujian tersebut menggunakan fixture lokal, bukan acceptance server,
real-device, remote CI, atau bukti siap release. Tidak ada credential ataupun
mutation yang dikirim ke backend live selama pekerjaan ini.

## Acceptance manual berikutnya

Task yang belum dapat dijalankan ditandai `PENDING` pada
[daftar pending revisi 1–7](<Pending Task Migrasi API Oktober 2026.md>).
Pengguna menyetujui melanjutkan task berikutnya tanpa menutup gate tertahan.
Smoke lanjutan memverifikasi ID/company profil cocok dengan sesi dan nomor
employee terpisah; isolasi dua company tetap pending.

Pembaruan 19 Oktober: smoke GET backend berhasil untuk akun manager, sedangkan
login employee awal menerima 401. Setelah file kredensial diperbarui oleh
pengguna, satu login employee ulang berhasil 200, begitu pula GET today,
daftar payslip, cuti, saldo, dan notifikasi; logout berhasil. Daftar
`/payroll/payslips` mengembalikan 200 dan
`/payroll/payslips/my` mengembalikan `PAYROLL_UNLOCK_REQUIRED`. Tidak ada
pergantian path otomatis; konfirmasi canonical backend tetap diperlukan.
Fixture Android juga lulus 2 skenario pada emulator. Bukti serta batasannya
dicatat pada [Verifikasi Integrasi 19 Oktober](<Verifikasi Integrasi Pasca Migrasi API - 2026-10-19.md>).

Tindak lanjut prioritas tetap menggunakan urutan revisi 1–7 di atas. Regresi
terfokus terbaru lulus 190 tes. Prasyarat fixture dan kriteria acceptance
setiap poin telah dirinci pada bagian 5 laporan verifikasi tersebut. Login
employee sudah berhasil setelah pembaruan file kredensial; path payslip
tidak diubah sebelum backend mengonfirmasi kontrak canonical. Modul baru
poin 7 tetap ditunda, tanpa perubahan scope rilis.

- [ ] Login password awal, pastikan Home dan deep link tertahan di ganti password.
- [ ] Paksa flag dari server saat aplikasi sudah login; 403 harus membuka gate
  tanpa menghapus sesi atau mencoba ulang mutation.
- [ ] Ganti password, login kembali, dan pastikan akses pulih.
- [ ] Dua company memiliki nomor employee/kode aset/kode cuti sama tanpa cache silang.
- [ ] Tampilkan beberapa slip pada periode sama dan buka masing-masing ID yang tepat.
- [ ] Periksa carry-over null, pecahan, expired, dan tanggal batas pada akun nyata.
- [ ] Uji 403 permission dan 409 workflow, tanpa sukses palsu.
- [ ] Cocokkan request ID dan correlation ID di log backend yang disanitasi.

HTTPS, akun fixture, registrasi push backend, signing, UAT, serta gate rilis
sebelumnya tetap terbuka. Penyesuaian API ini tidak menutup blocker tersebut.
