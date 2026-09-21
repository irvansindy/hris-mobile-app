# Report Tahap 1, Finalisasi Kontrak dan Smoke Test API

Tanggal: 18 September 2026  
Scope: 24 pasangan method/path yang sudah digunakan HRIS Mobile  
Status tahap: PASS lokal, REVIEW live deployment, PENDING real device

## 1. Ringkasan hasil

Tahap 1 telah menyelesaikan review implementasi, perbaikan contract validation, regression test, static analysis, dan build APK debug.

Hasil utama:

- 24 operasi API aktif mempunyai bukti test lokal;
- response HTTP 200 dengan `success:false` tidak lagi dianggap berhasil pada change-password, logout, dan section Dashboard;
- schema list yang rusak tidak lagi diubah menjadi empty state seolah response valid;
- response attendance ditolak bila ID kosong, employee berbeda, atau waktu wajib mutation tidak tersedia;
- response cuti/izin ditolak bila employee/company berbeda;
- ID detail dan cancel cuti/izin dibatasi ke identifier aman sebelum dimasukkan ke path;
- tidak ada data contoh yang ditambahkan sebagai fallback;
- smoke test live telah mencapai seluruh 24 pasangan method/path menggunakan akun uji melalui HTTP yang disetujui khusus untuk pengujian;
- 13 operasi lulus dengan response sukses, 7 mutation route menolak payload negatif sesuai kontrak, dan 2 route terbukti aktif tetapi belum dapat diuji sukses karena fixture kosong;
- 2 operasi gagal karena akun employee belum memiliki kalender kerja aktif atau formula shift;
- login employee dan manager mengembalikan Bearer access token serta refresh token. Error `Access token is missing` tidak muncul saat login memakai `X-Client-Type: mobile`.

## 2. Perubahan implementasi

### Authentication

- `POST /auth/change-password` sekarang memvalidasi envelope `success`.
- `POST /auth/logout` sekarang memvalidasi envelope `success` sebelum dianggap direvoke server.
- login, `/auth/me`, refresh rotation, retry satu kali, dan cleanup session tetap memakai contract gate yang sudah ada.

### Attendance

- list history harus berupa list object yang valid;
- record today, history, check-in, dan check-out harus sesuai employee aktif;
- mutation check-in wajib mengembalikan ID dan waktu check-in;
- mutation check-out wajib mengembalikan ID, waktu check-in, dan waktu check-out;
- response foreign employee, malformed list, dan `success:false` mempunyai regression test.

### Leave dan permission

- leave types, leave detail, permission history, dan permission cancel sekarang mempunyai test endpoint langsung;
- list tidak boleh berupa `null`, scalar, atau berisi item non-object;
- response dengan `employeeId` atau `companyId` berbeda ditolak;
- ID detail/cancel yang mengandung path traversal ditolak sebelum request dikirim.

### Dashboard

- saldo cuti dan notifikasi Dashboard hanya dinyatakan tersedia jika envelope sukses dan `data` berbentuk list/object;
- `success:false` menjadi section error, bukan empty success;
- query `employeeId` saldo cuti dan `limit=3` notifikasi diverifikasi oleh test.

## 3. Matriks 24 operasi

`PASS lokal` berarti method, path, payload/query utama, dan response minimum telah diuji dengan fixture lokal. Status ini tidak membuktikan endpoint deployment sudah aktif.

| No. | Method | Path | Bukti lokal | Live |
|---:|---|---|---|---|
| 1 | POST | `/auth/login` | PASS lokal | PASS employee + manager, token Bearer lengkap |
| 2 | POST | `/auth/refresh` | PASS lokal | PASS, access/refresh token dirotasi |
| 3 | POST | `/auth/logout` | PASS lokal | PASS employee + manager |
| 4 | GET | `/auth/me` | PASS lokal | PASS employee + manager |
| 5 | POST | `/auth/change-password` | PASS lokal | REACHABLE, negative probe 422; sukses belum diuji agar password tetap |
| 6 | GET | `/attendance/me/today` | PASS lokal | FAIL 400, kalender kerja aktif tidak ditemukan |
| 7 | GET | `/attendance/me?month=YYYY-MM` | PASS lokal | PASS, list kosong valid |
| 8 | POST | `/attendance/me/check-in` | PASS lokal | REACHABLE, payload invalid ditolak 422; success real device pending |
| 9 | PATCH | `/attendance/me/check-out` | PASS lokal | REACHABLE, payload invalid ditolak 422; success real device pending |
| 10 | GET | `/leave/types` | PASS lokal | PASS, list kosong valid |
| 11 | GET | `/leave/balances/employee` | PASS lokal | PASS, list kosong valid |
| 12 | GET | `/leave` | PASS lokal | PASS, list kosong valid |
| 13 | GET | `/leave/:id` | PASS lokal | REACHABLE 404, fixture leave belum tersedia |
| 14 | POST | `/leave` | PASS lokal | REACHABLE, payload kosong ditolak 422 |
| 15 | PATCH | `/leave/:id/cancel` | PASS lokal | REACHABLE, ID sentinel ditolak 404 |
| 16 | GET | `/permission-requests/my` | PASS lokal | PASS, satu record tersedia |
| 17 | POST | `/permission-requests` | PASS lokal | REACHABLE, payload kosong ditolak 422 |
| 18 | PATCH | `/permission-requests/:id/cancel` | PASS lokal | REACHABLE, ID sentinel ditolak 404 |
| 19 | GET | `/work-calendars/me/resolved` | PASS lokal | FAIL 400, kalender/formula shift belum tersedia |
| 20 | GET | `/notifications` | PASS lokal | PASS, list kosong valid |
| 21 | GET | `/notifications/unread-count` | PASS lokal | PASS |
| 22 | PUT | `/notifications/read` | PASS lokal | REACHABLE 422, fixture notifikasi belum tersedia |
| 23 | PUT | `/notifications/read-all` | PASS lokal | PASS |
| 24 | GET | `/employees/:id` | PASS lokal | PASS, identity sesuai session |

## 4. Hasil pengujian otomatis

| Gate | Hasil |
|---|---|
| Baseline sebelum perubahan | 283 test lulus |
| Contract test terarah setelah perbaikan | 41 test lulus |
| `flutter analyze` | Lulus, tidak ada issue |
| Seluruh regression test setelah perbaikan | 290 test lulus |
| `flutter build apk --debug` | Lulus |
| `git diff --check` | Lulus |

APK pengujian:

- file: `build/app/outputs/flutter-apk/app-debug.apk`;
- ukuran: 204372754 byte;
- SHA-256: `df5b9310f4512aa5abbc4c8199aa25772d42164391d3d8642b104e31e93305ef`.

Build menampilkan warning bahwa `package_info_plus` masih menerapkan Kotlin Gradle Plugin. Warning tidak menggagalkan APK, tetapi dependency perlu dipantau sebelum Flutter menghentikan dukungan pola tersebut.

### 4.1 Hasil smoke test live

Pengujian dijalankan pada 18 September 2026 menggunakan akun employee dan manager uji. Semua 24 operasi telah menerima response dari deployment. Ringkasan per operasi unik:

| Kategori | Jumlah | Arti |
|---|---:|---|
| PASS | 13 | Response 2xx, envelope sukses, dan field minimum tersedia. |
| REACHABLE, negative probe | 7 | Route serta validasi aktif; success mutation belum diuji. |
| REACHABLE, fixture belum tersedia | 2 | Route aktif, tetapi tidak ada leave/notifikasi untuk detail atau read-by-ID. |
| FAIL | 2 | Attendance today dan resolved calendar ditolak karena konfigurasi kalender akun belum lengkap. |

Runner menghasilkan 27 baris karena login, `/auth/me`, dan logout diverifikasi untuk kedua role. Artefak tersanitasi berada di `/tmp/hris-mobile-smoke-results.json` dengan permission `600`. Scan artefak tidak menemukan field token, password, cookie, atau email.

Mutation berikut sengaja memakai negative probe untuk mencegah perubahan data yang tidak dapat dipulihkan: change-password, check-in, check-out, submit/cancel leave, serta submit/cancel permission. `read-all` berhasil dijalankan dan hanya mengubah status notifikasi akun uji.

## 5. Checklist smoke test manual real device

Gunakan akun uji dan data staging. Jangan menjalankan mutation attendance, cuti, atau izin pada akun production karyawan nyata.

### Persiapan

- [ ] Pastikan perangkat dapat mengakses base URL API yang dipakai build debug.
- [ ] Instal APK dan catat versi Android, model perangkat, serta kondisi jaringan.
- [ ] Siapkan akun employee dan manager dari secret manager atau konfigurasi lokal.
- [ ] Siapkan shift, policy GPS/selfie, leave type, saldo, calendar, dan notifikasi pada akun uji.
- [ ] Aktifkan log debug hanya bila tidak mencetak token, cookie, password, selfie, atau payload sensitif.

### A. Authentication dan isolasi akun

- [ ] Login dengan password salah. Harapan: tetap di Login dan tidak membuat session.
- [ ] Login employee. Harapan: Beranda hanya terbuka setelah identity `/auth/me` lengkap.
- [ ] Tutup paksa lalu buka aplikasi. Harapan: session direstore tanpa flash data akun lain.
- [ ] Biarkan access token kedaluwarsa atau gunakan fixture expiry. Harapan: satu refresh dan request awal diulang satu kali.
- [ ] Uji refresh revoked/expired. Harapan: session dibersihkan dan kembali ke Login.
- [ ] Logout saat access token masih valid. Harapan: refresh token direvoke dan data lokal dibersihkan.
- [ ] Login akun manager sesudah employee. Harapan: tidak ada profil, pengajuan, notifikasi, atau draft employee sebelumnya.
- [ ] Bila tersedia, uji challenge TOTP. Harapan: kolom kode muncul hanya setelah `MFA_REQUIRED`.

### B. Attendance

- [ ] Buka Absensi sebelum check-in. Harapan: status server tampil, tidak ada record contoh.
- [ ] Uji izin lokasi ditolak. Harapan: check-in tidak diklaim sukses.
- [ ] Uji GPS di dalam dan di luar radius dengan skenario staging yang disiapkan backend.
- [ ] Uji policy selfie wajib, cancel kamera, serta capture valid.
- [ ] Tekan check-in berulang saat request berjalan. Harapan: tidak membuat record ganda.
- [ ] Refresh Today setelah check-in. Harapan: ID dan waktu sama dengan response server.
- [ ] Lakukan check-out. Harapan: waktu berasal dari server dan record yang sama diperbarui.
- [ ] Buka riwayat bulan kosong dan bulan berisi data. Harapan: empty state hanya untuk response list valid.
- [ ] Matikan jaringan ketika check-in/check-out. Harapan: tampil gagal dan status tidak berubah menjadi sukses.

### C. Leave dan permission

- [ ] Buka daftar tipe cuti. Harapan: nama, attachment requirement, dan batas hari berasal dari server.
- [ ] Buka saldo cuti di Beranda. Harapan: query memakai employee session dan nominal cocok dengan server.
- [ ] Buka daftar serta detail cuti. Harapan: status dan tanggal sesuai server.
- [ ] Buat cuti, lalu refresh daftar. Harapan: ID baru berasal dari server.
- [ ] Batalkan cuti yang masih boleh dibatalkan. Harapan: status berubah setelah response server.
- [ ] Buka riwayat izin, buat izin, lalu batalkan izin.
- [ ] Matikan jaringan saat submit/cancel. Harapan: form atau status tidak ditandai sukses.
- [ ] Uji tanggal tidak valid dan saldo tidak cukup. Harapan: error backend tampil tanpa membuat item lokal.

### D. Calendar, notification, dan profile

- [ ] Buka kalender bulan normal, Februari tahun kabisat, bulan sebelumnya, dan bulan berikutnya.
- [ ] Cocokkan seluruh tanggal, shift, holiday, dan absence dengan response server.
- [ ] Buka Notifikasi. Harapan: list dan unread count konsisten.
- [ ] Tandai satu notifikasi dibaca lalu gunakan read-all.
- [ ] Matikan jaringan saat read/read-all. Harapan: status visual tidak berubah permanen.
- [ ] Buka Profil employee dan manager. Harapan: ID/company sesuai session dan field sensitif tidak ditampilkan.
- [ ] Uji employee tanpa `employee:read`. Harapan: request detail tidak dikirim dan UI menampilkan state akses yang benar.

## 6. Format pencatatan hasil manual

Gunakan satu baris per skenario:

| ID | Perangkat/OS | Akun | Skenario | Hasil server | Hasil aplikasi | PASS/FAIL | Bukti |
|---|---|---|---|---|---|---|---|
| AUTH-01 |  | employee | Login valid |  |  |  |  |
| ATT-01 |  | employee | Today sebelum check-in |  |  |  |  |
| REQ-01 |  | employee | Buat dan cancel cuti |  |  |  |  |
| CAL-01 |  | employee | Kalender bulan berjalan |  |  |  |  |
| NOTIF-01 |  | employee | Read dan read-all |  |  |  |  |
| PROFILE-01 |  | manager | Profile identity |  |  |  |  |

Untuk kegagalan, lampirkan waktu pengujian, request ID dari server bila tersedia, HTTP status, error code, dan screenshot. Jangan memasukkan access token, refresh token, password, cookie, TOTP secret, atau selfie ke report.

## 7. Review akhir dan blocker live

### Live test 18 September 2026

- file kredensial ditemukan dengan permission `600` dan struktur field lengkap;
- file berada di dalam repository, sehingga `tmp/hris-mobile-smoke.json` ditambahkan ke `.gitignore` sebelum pengujian;
- probe `GET /auth/me` tanpa kredensial melalui base URL yang diberikan berhasil mencapai server dan menerima HTTP 401 dalam 1,587 detik;
- base URL memakai HTTP remote, bukan HTTPS atau loopback;
- probe HTTPS ke host dan port yang sama gagal pada TLS handshake dengan `wrong version number`;
- setelah persetujuan eksplisit untuk akun uji, login employee/manager dan authenticated smoke test dijalankan melalui base URL HTTP;
- login kedua role, refresh rotation, `/auth/me`, logout, dan profile berhasil;
- `/attendance/me/today` gagal HTTP 400 `BAD_REQUEST`: `No active work calendar found for the employee attendance context`;
- `/work-calendars/me/resolved` gagal HTTP 400 `BAD_REQUEST`: `Belum ada kalender kerja aktif atau formula shift untuk user ini`;
- leave types, saldo, leave list, dan notifications mengembalikan list kosong, sehingga success detail leave dan read notification by ID belum dapat dibuktikan;
- artefak final dan report tidak menyimpan password, token, cookie, OTP, email, atau identifier dinamis; path detail dinormalisasi menjadi `:id`.

Review lokal menyatakan implementasi layak masuk smoke test manual. Tahap 1 belum dapat dinyatakan DONE deployment karena:

1. backend perlu memasang active work calendar atau shift formula pada akun employee uji;
2. backend perlu menyediakan minimal satu leave request dan satu notifikasi untuk positive test detail/read;
3. mutation attendance GPS/selfie, create/cancel leave, create/cancel permission, dan change-password belum mempunyai bukti sukses;
4. base URL production/staging HTTPS belum tersedia;
5. pagination attendance/leave/notification belum dikonfirmasi final;
6. semantics `Idempotency-Key`, timezone kantor, tenant enforcement, geofence, fake GPS, dan liveness masih harus dibuktikan pada real device.

Setelah hasil manual diisi, setiap FAIL harus dijadikan regression test sebelum Tahap 1 ditutup dan Tahap 2 Approval Center dimulai.
