# Verifikasi Integrasi Pasca Migrasi API Oktober

Tanggal: 19 Oktober 2026.
Status: smoke development sebagian berhasil; acceptance release belum selesai.

## Lingkup dan batas pengujian

- Target memakai base URL development HTTP yang sebelumnya disetujui proyek.
  Ini bukan bukti HTTPS staging atau production siap.
- Kredensial dibaca dari file lokal yang diabaikan Git. Password, email, token,
  cookie, dan response berisi data HR tidak ditampilkan dalam laporan.
- Putaran awal melakukan satu login untuk setiap role. Setelah pengguna
  mengonfirmasi pembaruan file lokal, employee diuji satu kali lagi dan
  berhasil. Tidak ada percobaan password alternatif atau retry login otomatis.
- Setelah login manager, pengujian hanya melakukan GET resource dan logout.
  Tidak ada check-in/check-out, perubahan password, cuti, approval, mutasi
  payroll, atau registrasi token push backend.
- Hasil GET di bawah membuktikan akses/status dan bentuk data tingkat dasar,
  bukan kelengkapan schema, validasi semua field, ownership seluruh resource,
  ataupun pengujian UI dengan response server tersebut.

## 1. Hasil smoke backend

| Role | Operasi | Hasil | Catatan |
| --- | --- | --- | --- |
| Tanpa login | `GET /auth/me` | 401 | Host dapat dijangkau; akses tanpa sesi ditolak. |
| Employee | `POST /auth/login` | 401 `AUTHENTICATION_FAILED` | Pengujian fitur employee tertahan. Tidak menyimpulkan penyebabnya password salah atau akun nonaktif tanpa konfirmasi backend. |
| Manager | `POST /auth/login` | 200 | Bearer tersedia; `mustChangePassword:false` pada sesi uji. |
| Manager | `GET /auth/me` | 200 | Identitas employee/company terhubung; flag wajib ganti password false. |
| Manager | `GET /meta/endpoints` | 403 `FORBIDDEN` | Inventaris route live belum bisa dicocokkan memakai akun ini. |
| Manager | `GET /attendance/me/today` | 200 | Object tersedia; `canCheckIn:true`, `canCheckOut:false`. Belum mengirim absensi. |
| Manager | `GET /payroll/payslips` | 200 | List berisi 1 slip. Belum ada bukti beberapa slip dalam satu periode di server. |
| Manager | `GET /payroll/payslips/my` | 401 `PAYROLL_UNLOCK_REQUIRED` | Tidak menghasilkan daftar pada sesi ini; tidak diperlakukan sebagai endpoint daftar pengganti. |
| Manager | `GET /assets/my` | 200 | List kosong; positive fixture aset belum tersedia untuk akun ini. |
| Manager | `GET /leave` | 200 | List berisi 3 record; detail/create/cancel tidak diuji pada putaran ini. |
| Manager | `GET /notifications` | 200 | List berisi 4 record; read/read-all/delete tidak dilakukan. |
| Manager | `GET /workflow-engine/instances/my-approvals` | 200 | List kosong; belum membuktikan approve/reject/bulk. |
| Manager | `GET /leave/balances/employee` | 200 | List berisi 7 record; setidaknya satu membawa field carry-over. Query employee berasal dari sesi, tidak dicantumkan dalam laporan. |
| Manager | `POST /auth/logout` | 200 | Sesi uji ditutup setelah pemeriksaan GET. |

Jumlah record merupakan snapshot pengujian, bukan angka tetap atau kriteria
regresi yang harus selalu sama.

### Pembaruan setelah kredensial employee diperbarui

Pengguna mengonfirmasi pembaruan `tmp/hris-mobile-smoke.json`. Satu login
employee baru berhasil; hasil berikut menggantikan blocker login 401 pada
putaran awal, bukan menghapus riwayat pengujian tersebut. Akun manager tidak
diuji ulang pada putaran ini.

| Operasi employee | Hasil | Batas bukti |
| --- | --- | --- |
| `POST /auth/login` | 200 | Bearer tersedia; `mustChangePassword:false`. Bukan fixture wajib ganti password. |
| `GET /auth/me` | 200 | Employee/company terhubung; belum membuktikan pemisahan dua tenant. |
| `GET /meta/endpoints` | 403 `FORBIDDEN` | Inventaris route membutuhkan pemeriksaan backend berwenang. |
| `GET /attendance/me/today` | 200 | `canCheckIn:true`, `canCheckOut:false`; tidak mengirim punch. |
| `GET /payroll/payslips` | 200 | List 1 slip; belum membuktikan multi-slip satu periode. |
| `GET /payroll/payslips/my` | 401 `PAYROLL_UNLOCK_REQUIRED` | Bukan daftar sukses; endpoint canonical masih perlu konfirmasi. |
| `GET /assets/my` | 200 | List kosong. |
| `GET /leave` | 200 | List 3 record; tidak create/cancel. |
| `GET /notifications` | 200 | List 4 record; tidak mengubah status baca. |
| `GET /workflow-engine/instances/my-approvals` | 403 `FORBIDDEN` | Penolakan teramati; belum membuktikan permission tepat menurut matriks role atau konflik 409. |
| `GET /leave/balances/employee` | 200 | List 7 record; field carry-over tersedia. Semantik saldo belum terkonfirmasi. |
| `POST /auth/logout` | 200 | Sesi smoke ditutup. |

Role pada tabel mengikuti slot kredensial `employee`; tidak mengasumsikan
seluruh permission akun sudah benar hanya dari nama slot tersebut. Tidak ada
password/PIN, token, ID pegawai, atau payload HR mentah yang dicetak.

## 2. Dampak terhadap keputusan integrasi

### Smoke lanjutan poin 2, 3, dan 5

Putaran terpisah read-only menggunakan akun employee terbaru menghasilkan
login, `/auth/me`, tiga GET di bawah, dan logout 200. Tidak ada transaksi
bisnis yang diubah. Ini probe schema dasar, bukan pemakaian mapper Flutter
terhadap response live atau acceptance lintas tenant.

| Pemeriksaan | Hasil |
| --- | --- |
| `/employees/{ownEmployeeId}` | ID profil cocok dengan employee ID sesi; company cocok dengan sesi; employee number tersedia dan berbeda dari ID. Nilai identitas tidak dicetak. |
| `/payroll/payslips` | Satu record, ID unik pada snapshot; belum ada beberapa slip periode sama. |
| `/leave/balances/employee` | Tujuh record dengan carry-over numerik; tidak ada nilai pecahan dan tidak ada expiry berbentuk string. Belum membuktikan perilaku tanggal batas. |

UUID header berikut dikirim oleh probe untuk pencocokan backend. Ini bukan
token autentikasi dan bukan bukti server sudah merekam header tersebut.

| GET | X-Request-Id | X-Correlation-Id |
| --- | --- | --- |
| Profil sendiri | `1ef33b39-6bd5-4982-99fd-fff9bb0df282` | `c20cf511-456d-43b0-9b40-408b14498b41` |
| Daftar payslip | `fbea2eec-90c9-4d0e-bcda-1fd3fb4346e4` | `f9e5d281-105a-4de7-a5c5-2c20fb20601f` |
| Saldo cuti | `2a58150a-f9d0-463a-8d44-ad678b3860cb` | `67bb34eb-3ffc-428e-a5df-d8519ed027b1` |

Probe ini tidak melakukan retry. Identitas request per retry tetap baru
dibuktikan dengan tes lokal, bukan putaran live ini.

### Payslip

Client tetap memakai `GET /payroll/payslips`. Endpoint ini terbukti
mengembalikan list untuk akun uji manager. Path `/payroll/payslips/my`
memberikan error unlock, sehingga belum ada dasar untuk mengganti konfigurasi
atau menambahkan fallback otomatis.

Backend tetap perlu mengonfirmasi path canonical dan alias. Error unlock di
atas juga bukan bukti PIN atau izin list bermasalah pada path yang sudah benar.
Uji unlock/detail/PDF ditunda; tidak mencoba menebak atau mengatur PIN.

### Attendance

Today akun manager dan employee kini dapat diakses. Ini memperbarui bukti lama
mengenai ketidaksiapan kalender pada akun uji, tetapi tidak menutup gate
transaksi absensi atau membuktikan geofence, face match, dan shift malam.

### Fixture dan akses

- Blocker login employee sudah teratasi setelah pembaruan file lokal. Akun
  khusus password-required dan dua tenant masih dibutuhkan untuk acceptance.
- Dibutuhkan fixture aset, pending approval, dan beberapa payslip pada periode
  sama untuk positive live test yang belum tersedia pada snapshot ini.
- Untuk validasi `/meta/endpoints`, backend dapat menjalankan pemeriksaan dengan
  akun berwenang dan memberikan hasil yang disanitasi; mobile tidak perlu
  mendapat privilege admin hanya untuk melewati probe ini.
- Carry-over sudah muncul di response, tetapi semantik saldo, pecahan hari,
  nullability, dan timezone expiry tetap membutuhkan konfirmasi.

## 3. Pengujian Android virtual

Emulator `Pixel_10a` berhasil boot sebagai `sdk_gphone16k_x86_64`, Android 17,
dan Google Play services tersedia. Ruang disk sebelum boot sekitar 2,2 GB;
tidak ada file pengguna yang dihapus untuk menjalankannya.

Pengujian `integration_test/redesign_flow_test.dart` lulus 2 skenario pada
emulator: alur fixture absensi diterima dan ditolak, masing-masing dengan
logout akun A lalu masuk akun B. Perintah:

```bash
rtk flutter test --no-pub integration_test/redesign_flow_test.dart -d emulator-5554
```

Fixture tidak mengirim transaksi ke API HRIS live dan tidak menggantikan
acceptance perangkat fisik Android/iOS.

Smoke `integration_test/firebase_development_smoke_test.dart` juga lulus
1 tes pada emulator: izin authorized, token FCM diperoleh, lalu token dihapus.
Tidak ada token yang ditampilkan atau diregistrasikan ke backend HRIS.
Percobaan sebelumnya timeout saat menunggu dialog izin notifikasi Android;
pengulangan lulus setelah izin diberikan pada instalasi test yang baru.
Tidak ada perubahan kode aplikasi untuk melewati izin tersebut.

```bash
rtk flutter test --no-pub integration_test/firebase_development_smoke_test.dart -d emulator-5554 --dart-define=APP_ENV=development --dart-define=DEMO_MODE=false --dart-define=PUSH_MODE=firebase --dart-define=ENABLE_LOGGING=false
```

Log lokal: `/tmp/hris-oct-device-integration.log` dan
`/tmp/hris-oct-firebase-sdk-smoke.log`. Hasil SDK bukan bukti delivery pesan
Console, foreground/background/terminated, atau integrasi push backend.
Warning kompatibilitas KGP `firebase_core` tetap muncul saat build.

Pengguna telah mengonfirmasi pembaruan file akun lokal; smoke employee setelah
pembaruan dicatat pada bagian 1.

## 4. Gate yang belum ditutup

Pengguna menyetujui melewati task yang belum memiliki dependency dalam
development. Daftar yang dapat difilter, owner, dan kriteria penutupannya ada
di [Pending Task Migrasi Oktober](<Pending Task Migrasi API Oktober 2026.md>).
Gate tersebut tetap berlaku untuk release.

- [x] Login employee, GET resource dasar, dan logout setelah pembaruan kredensial.
- [ ] Positive live acceptance end-to-end sesuai permission role employee.
- [ ] Runtime password-required menggunakan akun khusus yang disiapkan backend.
- [ ] Check-in/check-out nyata, konsistensi today/history, restart, jaringan,
  face mismatch, geofence, replay, dan shift malam 36 jam.
- [ ] Uji dua company dengan nomor employee/kode aset/kode cuti yang sama.
- [ ] Multi-payslip, PIN/unlock/detail/PDF, dan proteksi layar native.
- [ ] Approval dengan fixture pending dan skenario 403/409/partial success.
- [ ] Delivery Firebase Console dan integrasi token push backend melalui HTTPS.
- [ ] HTTPS staging, iOS, signing, remote CI, serta UAT release candidate.

## 5. Eksekusi lanjutan sesuai urutan revisi

Bagian ini melanjutkan tujuh poin pada matriks Oktober, bukan tahap atau
roadmap baru. Implementasi yang sudah tersedia tidak diulang. Gate live tetap
terbuka sampai ada bukti server, meskipun regresi lokal lulus.

| Urutan revisi | Prasyarat dari Backend/QA | Langkah acceptance dan kriteria lulus |
| --- | --- | --- |
| 1. Wajib ganti password | Akun disposable dengan flag awal true, akun terpisah yang flag-nya dapat diaktifkan saat sesi berjalan, dan izin perubahan password pada akun uji. | Login tetap berhasil tetapi Home/deep link tertahan; runtime `403 PASSWORD_CHANGE_REQUIRED` membuka gate tanpa logout atau replay mutation. Setelah password diganti dan login kembali, akses pulih. Jangan mengubah password akun bersama. |
| 2. Identitas employee/company | Dua akun pada company berbeda dengan `employeeNumber` sama; setiap akun memiliki ID employee berbeda dan resource miliknya sendiri. | Profil menampilkan nomor yang sama tetapi request/cache memakai ID masing-masing. Logout/account switch/restart tidak menampilkan data akun sebelumnya. Uji penolakan akses resource company lain hanya pada fixture yang disetujui. |
| 3. Endpoint payslip/multi-slip | Konfirmasi tertulis path daftar canonical dan alias; minimal dua slip yang dapat dilihat akun sendiri pada periode sama, ID berbeda, serta nama/nomor run jika tersedia. | Semua slip tampil tanpa deduplikasi periode; pemilihan setiap slip membuka ID yang tepat. Detail/PDF memerlukan PIN uji melalui konfigurasi lokal aman dan HTTPS sebelum mengirim token unlock. Jangan menebak PIN atau membuat fallback path dari hasil 401. |
| 4. Permission/konflik approval | Akun manager tanpa permission, manager berwenang, fixture pending, dan fixture stale/sudah diproses; sediakan ID fixture lewat kanal lokal aman. | Penolakan 403 tidak memunculkan sukses atau fallback legacy. Konflik 409 tidak disubmit ulang otomatis; refresh menampilkan status server. Approval positif dilakukan hanya pada fixture disposable dengan izin mutasi. List kosong bukan bukti acceptance selesai. |
| 5. Carry-over/tracing/parser | Saldo tanpa carry-over, pecahan, belum/sudah expired; konfirmasi apakah remaining/quota mencakup carry-over dan timezone expiry. Backend menyediakan cuplikan log yang disanitasi. | Nilai ditampilkan tanpa menambah saldo lagi; field opsional/enum baru tidak menyebabkan crash. Request ID berbeda per percobaan, correlation ID tetap pada satu request logis/retry, dan keduanya cocok dengan log backend. Server tetap menentukan saldo otoritatif. |
| 6. Dokumentasi | Hasil dari setiap pengujian di atas. | Perbarui matriks dan rekap yang sudah ada dengan hasil, batas pengujian, dan blocker; jangan mencentang gate hanya dari status HTTP 200. |
| 7. Scope modul baru | Pengguna menyetujui penundaan pada 19 Oktober 2026. | DONE untuk keputusan scope. Helpdesk, Feed & Kudos, dan Timesheet DEFERRED dari rilis awal; implementasinya belum dilakukan. Adopsi berikutnya membutuhkan persetujuan scope baru dan schema lengkap. |

### Pengamanan pelaksanaan

- Login employee ulang hanya setelah pengguna mengonfirmasi pembaruan akun,
  seperti pada putaran terbaru. Jangan menjalankan retry terjadwal atau mencoba
  password alternatif.
- Pengujian hanya memakai akun milik fixture; jangan menyiapkan fixture dengan
  mengubah data pegawai nyata dari aplikasi.
- Pengujian yang tertahan tidak boleh diganti memakai akun berprivilege lebih
  tinggi lalu dinyatakan lulus untuk role employee.
- Bukti pengujian cukup berupa status, kode error, jumlah record, build dan
  skenario. Jangan menyimpan password, PIN, token, isi PDF gaji, selfie, atau
  response HR mentah pada laporan atau log yang masuk Git.

### Regresi prioritas lokal

Pengulangan regresi pada 19 Oktober menghasilkan **190 tes lulus**, exit code
0. Cakupan: refresh/gate password, authentication/router, kontrak Profil,
payroll termasuk multi-slip, approvals, kontrak ESS, carry-over dashboard,
dan parser request. Log lokal: `/tmp/hris-oct-priority-regression.log`.

```bash
rtk flutter test --no-pub test/core/auth_refresh_test.dart test/features/authentication test/app/router_test.dart test/features/profile/profile_api_contract_test.dart test/features/payroll test/features/approvals test/features/ess/ess_api_contract_test.dart test/features/dashboard/home_carryover_contract_test.dart test/features/self_service/request_api_contract_test.dart
```

Ini pengujian subset lokal, bukan pengulangan full CI atau acceptance live.
Tidak ada perubahan kode aplikasi pada putaran regresi lokal. Smoke employee
berikutnya merupakan putaran terpisah setelah pembaruan kredensial.

## Referensi

- [Matriks migrasi API Oktober](<Migrasi API Oktober 2026 - Matriks dan Report.md>)
- [Acceptance absensi](<Tahap 2 Acceptance Live Tertunda.md>)
- [Firebase development](<Firebase Android Development.md>)
- [Rekap kebutuhan backend](<Rekap Task Tertunda dan Kebutuhan Backend - 2026-10-18.md>)
