# API Contracts

Sumber utama: **HRIS Mobile API Reference (Final)** dari backend developer,
baseline branch `main` per 12 September 2026. Semua path di bawah relatif
terhadap base URL yang sudah berakhiran `/api/v1`.

Jika dokumen ini berbeda dengan response deployment, hentikan mapping dan minta
OpenAPI/fixture tersanitasi. Jangan kembali memakai endpoint admin untuk alur
self-service.

## 1. Autentikasi native mobile

- `POST /auth/login`
  - Header: `X-Client-Type: mobile`.
  - Body: `{email,password,totp?}`.
  - Respons: `data:{user,tokens:{accessToken,refreshToken,expiresIn}}`.
- `GET /auth/me`
  - Header: `Authorization: Bearer <accessToken>`.
  - Mengembalikan identity, employee/company, roles, dan permissions terkini.
- `POST /auth/refresh`
  - Header: `X-Client-Type: mobile`.
  - Body: `{refreshToken}`.
  - Access dan refresh token wajib diganti karena refresh token dirotasi.
- `POST /auth/logout`
  - Body: `{refreshToken}`.
  - Tidak memerlukan access token yang masih hidup.
- `POST /auth/change-password`
  - Bearer protected.
  - Body: `{oldPassword,newPassword}`.
- MFA: `/auth/mfa/setup`, `/auth/mfa/enable`, `/auth/mfa/disable`.
- Session management: `GET /auth/sessions`, `DELETE /auth/sessions/:id`.

Native memakai Bearer-only dan tidak mengirim cookie auth atau CSRF. Cookie
`at`/`rt`/`csrf` hanya merupakan kontrak browser/web.

## 2. Konvensi

- Sukses: `{success:true,message?,data,meta?}`.
- Error: `{success:false,code,message,errors?}`.
- `401`: refresh sekali, lalu logout jika tetap ditolak.
- `403`: permission/company scope ditolak.
- `404`: tidak ditemukan atau di luar tenant.
- `409`: conflict/stale/duplicate.
- `422`: validation error.
- `429`: rate limit.
- Endpoint `/me` dan `/my` mengambil employee/company dari token. Mobile tidak
  boleh mengirim identity sebagai sumber otorisasi.

## 3. Absensi self-service

- `GET /attendance/me/today`: record hari ini dan policy/metode.
- `GET /attendance/me?month=YYYY-MM`: riwayat sendiri.
- `POST /attendance/me/check-in`: check-in sendiri.
- `PATCH /attendance/me/check-out`: check-out hari ini.

Payload check-in:

```json
{
  "method": "MOBILE_GPS",
  "checkInLatitude": -6.2,
  "checkInLongitude": 106.816666,
  "deviceGps": {
    "isMockLocation": false,
    "accuracyMeters": 8
  }
}
```

Untuk `FACE_RECOGNITION`, tambahkan hanya foto mentah pada
`faceRecognition.selfieImage`, serta metadata live camera pada `liveness`.
Jangan mengirim vector, URL, similarity score, `isFaceMatch`, identity, atau
waktu device. Server menentukan waktu, geofence, liveness, dan face match.

Endpoint `/attendance`, `/attendance/context`, dan
`/attendance/:id/checkout` adalah endpoint admin/HR dan tidak dipakai alur
absensi employee.

## 4. Domain self-service lainnya

- Cuti: `/leave/types`, `/leave`, `/leave/:id`,
  `/leave/balances/employee`, `/leave/:id/cancel`.
- Izin: `/permission-requests/my`, `/permission-requests`, dan cancel.
- Kalender: `/work-calendars/me/resolved`,
  `/work-calendars/holidays/list`.
- Koreksi: `/attendance-corrections`.
- Lembur: `/attendance/overtime`.
- Pinjaman: `/employee-loans/types`, `/employee-loans/my`, installments, dan
  amortization.
- EWA: `/ewa/my`, `/ewa/my/limit`, `/ewa`.
- Daily activity: `/daily-activities/my`, `/daily-activities`.
- Travel/reimbursement: `/travel-expenses/trips/my`,
  `/travel-expenses/claims/my`, dan `/travel-expenses/categories`.
- Notifikasi: `/notifications`, `/notifications/unread-count`, PUT
  `/notifications/read`, PUT `/notifications/read-all`.
- Approval: `/workflow-engine/instances/my-approvals`, instance actions, dan
  bulk approve.
- Payslip: `/payroll/payslips`, `/payroll/payslips/:id`.
- Profil ringkas: `/auth/me`; detail employee `/employees/:id` memerlukan
  permission dan data sensitif dapat dimasking.

## 5. Batas integrasi

Dokumen final belum memberi contoh response `data` lengkap untuk sebagian besar
endpoint list. DTO baru hanya boleh ditambahkan setelah tersedia OpenAPI schema
respons atau fixture tersanitasi.

Production host yang diberikan backend masih HTTP. Mobile release tetap wajib
memakai HTTPS dan certificate pinning sebelum distribusi publik.
