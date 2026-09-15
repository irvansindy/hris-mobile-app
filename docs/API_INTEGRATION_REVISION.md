# HRMS Mobile API Integration Revision

Tanggal penyesuaian awal: 12 September 2026. Pembaruan redesign: 15 September 2026.

## Sumber kontrak

Implementasi mobile mengikuti `mobile-api.md` berjudul **HRIS Mobile API
Reference (Final)** yang diterima dari backend developer. Baseline dokumen
tersebut adalah branch backend `main` per 12 September 2026.

Dokumen final menggantikan kontrak lama berbasis endpoint admin, query
`employeeId`/`companyId`, serta cookie auth pada native mobile. Source backend
lokal yang pernah diaudit masih mencerminkan kontrak lama, sehingga verifikasi
deployment dan fixture respons nyata tetap dibutuhkan sebelum acceptance.

## Perbandingan kontrak

| Area | Implementasi/revisi lama | Kontrak final | Penyesuaian mobile |
|---|---|---|---|
| Auth native | Cookie `at`/`rt`/`csrf` atau Bearer fallback | Bearer wajib | Native mengabaikan cookie respons login dan mensyaratkan access serta refresh token |
| Penanda client | Tidak ada | `X-Client-Type: mobile` pada login dan refresh | Header ditambahkan pada kedua request |
| CSRF native | Ikut cookie auth | Tidak diperlukan untuk Bearer-only | Native tidak mengirim Cookie atau `X-CSRF-Token`; dukungan browser tetap terpisah |
| Refresh | Cookie `rt` atau body fallback | Body `{refreshToken}`, token selalu dirotasi | Respons tanpa pasangan token baru ditolak |
| Logout | Cookie/CSRF atau body fallback | Body `{refreshToken}`, access token hidup tidak wajib | Snapshot refresh token dikirim setelah storage lokal dibersihkan |
| Ganti password | `{currentPassword,newPassword}` | `{oldPassword,newPassword}` | Payload diubah ke `oldPassword` |
| Status hari ini | `GET /attendance` dengan identity query | `GET /attendance/me/today` | Query identity dihapus |
| Context/policy | `GET /attendance/context` endpoint admin | Menjadi bagian `/attendance/me/today` | Context memakai identity dari sesi sebagai fallback parsing, bukan request parameter |
| Check-in | `POST /attendance` dengan employee, company, date, dan waktu device | `POST /attendance/me/check-in` | Identity dan waktu client dihapus dari payload |
| Check-out | `PATCH /attendance/:id/checkout` | `PATCH /attendance/me/check-out` | ID attendance dan waktu device tidak dikirim |
| Face payload | Selfie plus MIME/ukuran dalam object face | Hanya `faceRecognition.selfieImage` | Field tambahan dihapus; metadata live camera dikirim melalui `liveness` |
| GPS metadata | Accuracy, mock, altitude, bearing | `isMockLocation` dan `accuracyMeters` | Payload dibatasi ke field kontrak final |
| Dashboard attendance | Endpoint summary/list admin | Endpoint today self-service | Dashboard tidak lagi memanggil endpoint attendance admin |

## Implementasi autentikasi

Pada native mobile:

1. `POST /auth/login` mengirim `X-Client-Type: mobile` dan body
   `{email,password,totp?}`.
2. Respons wajib memiliki `data.user`, `data.tokens.accessToken`, dan
   `data.tokens.refreshToken`.
3. Kedua token disimpan di Keychain/Keystore melalui
   `flutter_secure_storage`.
4. Protected request mengirim `Authorization: Bearer <accessToken>`.
5. Satu operasi refresh melayani request 401 yang bersamaan.
6. Refresh mengirim `X-Client-Type: mobile` dan `{refreshToken}`.
7. Respons refresh tanpa access token atau refresh token hasil rotasi ditolak
   dan tidak menimpa kredensial sebelumnya.
8. Sesi cookie-only yang tersimpan dari versi native lama dihapus saat restore.
9. Logout membersihkan sesi lokal lebih dulu, kemudian mengirim refresh token
   snapshot tanpa access token.

Transport browser tetap memiliki adapter cookie/CSRF tersendiri. Jalur tersebut
tidak digunakan sebagai fallback native.

## Implementasi absensi self-service

Endpoint yang dipakai mobile:

- `GET /attendance/me/today` untuk record hari ini dan policy/metode;
- `POST /attendance/me/check-in` untuk check-in;
- `PATCH /attendance/me/check-out` untuk check-out hari ini.

Payload check-in tidak lagi mengirim `employeeId`, `companyId`, `date`,
`source`, atau `checkIn`. Server menurunkan identity dari Bearer token dan
mengisi waktu penerimaan. Payload hanya memuat method, koordinat, metadata GPS,
serta selfie/liveness ketika metode face recognition dipakai.

Payload face recognition dibatasi menjadi:

```json
{
  "faceRecognition": {
    "selfieImage": "data:image/jpeg;base64,..."
  },
  "liveness": {
    "isLiveCapture": true,
    "clientSource": "camera"
  }
}
```

Check-out memakai endpoint self-service tanpa mencari ID attendance melalui
endpoint admin. Waktu checkout juga tidak dikirim agar server menjadi sumber
waktu otoritatif.

Client tetap menolak posisi yang ditandai mock dan accuracy di atas 100 meter
sebagai umpan balik awal. Keputusan geofence, fake GPS, face match, liveness,
rate limit, dan review wajib tetap dilakukan server.

## Dashboard

Dashboard mengganti pemanggilan `/attendance/summary` dan `/attendance` dengan
`GET /attendance/me/today`. Persentase bulanan tidak dihitung dari record hari
ini karena itu akan menghasilkan statistik rekaan. Kartu ringkasan bulanan
tetap unavailable sampai response schema riwayat atau summary self-service
tersedia dan dipetakan.

## Penyesuaian redesign Tahap 3 dan 4

Riwayat `GET /attendance/me?month=YYYY-MM`, cuti `/leave` dan `/leave/types`,
serta izin `/permission-requests/my` dan `/permission-requests` sudah
diintegrasikan dalam Tahap 3. Bukti dan batas schema ada di laporan RD-009 sampai RD-012.

Tahap 4 menambahkan:

- `GET /work-calendars/me/resolved?year=YYYY&month=M`, tanpa query employee/company;
- `GET /notifications?limit=N` serta `GET /notifications/unread-count`;
- `PUT /notifications/read` dengan `{ids:[...]}` dan `PUT /notifications/read-all`;
- penguatan `GET /employees/:id`: permission `employee:read`, validasi identitas
  respons, error/retry terlihat, dan nominal gaji tidak diproyeksikan ke state Profil.

Resolved calendar dipetakan dari `employee`, `period`, dan `days` pada source
lokal sebagai fixture kontrak sementara. Tanggal `YYYY-MM-DD` tidak dikonversi
ke local timezone. Respons tersebut belum menyertakan timezone kantor, sehingga
Today saat ini berlabel perangkat. Cuti tim tidak disimpulkan dari cuti pribadi.

Notifications hanya menyediakan limit-only, bukan page/cursor/meta. Muat lebih
banyak mengambil ulang N notifikasi terbaru dengan limit yang ditambah. Filter
inbox berlaku pada daftar yang dimuat; unread badge memakai count server.
Routing resource dibatasi ke route mobile yang tersedia. Payload tidak boleh
menentukan URL bebas. State dan callback diikat ke lifecycle sesi aktif.

Kontrak chat, device/push registration, konfigurasi Firebase, dokumen profil,
dan relasi atasan masih belum tersedia untuk integrasi mobile penuh. Tidak ada
endpoint atau data pengganti yang dibuat. Bukti: [laporan Tahap 4](<RD-013-016 Kalender Notifikasi dan Profil.md>).

## Endpoint yang masih belum diintegrasikan

- koreksi: `/attendance-corrections`;
- kalender hari libur terpisah: `/work-calendars/holidays/list` (resolved calendar sudah dipakai);
- penghapusan notifikasi: `DELETE /notifications/:id` (tidak ada kontrol delete dalam handoff);
- approval: `/workflow-engine/instances/my-approvals` dan actions;
- payslip: `/payroll/payslips`;
- loan, EWA, daily activity, travel expense, dan modul ESS lanjutan.

Daftar endpoint saja belum cukup untuk membangun DTO yang stabil. Endpoint
yang belum memiliki contoh response `data` tetap memerlukan OpenAPI response
schema atau fixture sukses tersanitasi.

## Catatan keamanan dan deployment

- Base URL production pada dokumen backend masih HTTP. Build production mobile
  tetap menolak HTTP dan memerlukan URL HTTPS.
- Certificate pinning menunggu domain dan sertifikat final.
- Face recognition dan geofence dinyatakan server-authoritative oleh dokumen
  final, tetapi masih memerlukan pengujian live dengan payload termodifikasi.
- Kontrak final memakai `oldPassword`, sedangkan source backend lokal lama yang
  pernah diperiksa memakai `currentPassword`. Deployment harus dipastikan sudah
  mengikuti dokumen final.

## Quality gate

Test kontrak memverifikasi:

- header mobile pada login dan refresh;
- penyimpanan dan rotasi pasangan Bearer token;
- migrasi sesi native cookie-only;
- payload `oldPassword`;
- endpoint attendance self-service tanpa identity/timestamp client;
- pembatasan face payload dan metadata liveness;
- dashboard tidak lagi memakai endpoint attendance admin.
- kalender self-service hanya mengirim year/month dan menolak identitas/periode/tanggal tidak sesuai;
- notifikasi memakai metode PUT yang terdokumentasi serta tidak mengarang page/cursor;
- profil tidak menyembunyikan error dan tidak menerima data employee/company lain;
- badge, inbox, read, back navigation, account switch, metadata, dan persistensi tema.

Acceptance live tetap memerlukan akun employee/manager khusus uji, deployment
yang sesuai baseline dokumen, perangkat Android/iOS, dan fixture response yang
disanitasi.
