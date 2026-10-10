# Panduan API HRIS untuk Aplikasi Mobile

Dokumen ini untuk pengembang aplikasi mobile (Android/iOS) yang akan
mengonsumsi API HRIS. Pasangannya adalah **`openapi.yaml`** di folder yang
sama — spesifikasi OpenAPI 3.1 dari permukaan API mobile.

> **Dari mana isi dokumen ini?**
> Seluruh path, parameter, field request, status HTTP, dan kode error di sini
> dibaca langsung dari source code backend. Setiap klaim penting disertai
> nama file dan nomor baris supaya Anda bisa memverifikasinya sendiri.
> Permukaan API-nya dipatok oleh
> `backend/src/modules/mobile-routes.contract.test.ts` — sebuah test yang
> gagal kalau route mobile dihapus atau urutannya diubah.
>
> **Bentuk `data` tidak dijanjikan.** Backend tidak punya skema response per
> endpoint (payload dirakit di service/Prisma), jadi `openapi.yaml`
> memodelkan `data` sebagai objek/array terbuka kecuali untuk endpoint yang
> bentuknya memang tertulis eksplisit di source. Untuk contoh payload nyata,
> minta `docs/mobile-api-fixtures.json` dari repo backend — tapi perlakukan
> sebagai contoh, bukan kontrak.

---

## Daftar isi

1. [Base URL dan versi](#1-base-url-dan-versi)
2. [Autentikasi: mobile vs web](#2-autentikasi-mobile-vs-web)
3. [Invalidasi sesi (`sessionVersion`) — yang paling penting](#3-invalidasi-sesi-sessionversion--yang-paling-penting)
4. [Envelope response](#4-envelope-response)
5. [Kode error](#5-kode-error)
6. [Pagination, sort, dan search](#6-pagination-sort-dan-search)
7. [Permission dan 403](#7-permission-dan-403)
8. [Masking PII (NIK, NPWP, rekening, BPJS)](#8-masking-pii-nik-npwp-rekening-bpjs)
9. [Kerahasiaan slip gaji dan mekanisme unlock](#9-kerahasiaan-slip-gaji-dan-mekanisme-unlock)
10. [Header yang perlu Anda tahu](#10-header-yang-perlu-anda-tahu)
11. [Alur lengkap dengan `curl`](#11-alur-lengkap-dengan-curl)
12. [Catatan jebakan dan hal yang tidak bisa dipastikan](#12-catatan-jebakan-dan-hal-yang-tidak-bisa-dipastikan)

---

## 1. Base URL dan versi

Semua endpoint berada di bawah prefix API, defaultnya `/api/v1`:

```
https://<host><API_PREFIX>
contoh: https://hris.contoh.co.id/api/v1
```

Prefix berasal dari env `API_PREFIX` dengan default `/api/v1`
(`backend/src/config/index.ts:19`). Minta nilai persisnya ke tim DevOps
untuk environment Anda; jangan hardcode kalau bisa dikonfigurasi.

Health check (di luar prefix, tanpa auth):

```
GET /health/live    → { "success": true }
GET /health/ready   → status database/redis/rabbitmq/queue
```

`/health/ready` menjawab `503` kalau salah satu dependency yang aktif mati
(`backend/src/app.ts:193-207`). Berguna untuk layar "server sedang gangguan".

---

## 2. Autentikasi: mobile vs web

Backend ini mendukung **dua mode autentikasi dari endpoint yang sama**, dan
mode dipilih oleh satu header.

| | Web (browser) | **Mobile (Anda)** |
|---|---|---|
| Penanda | *(tanpa header)* | **`X-Client-Type: mobile`** saat login & refresh |
| Letak token | Cookie httpOnly `at` dan `rt` | **Body response** (`data.tokens`) |
| Cara kirim token | Otomatis oleh browser | `Authorization: Bearer <accessToken>` |
| CSRF | Wajib: cookie `csrf` + header `X-CSRF-Token` | **Tidak berlaku** |

Sumber: `backend/src/modules/auth/auth.controller.ts:63-71`
(fungsi `isMobileClient`), `96-126` (login), `167-197` (refresh).

Kenapa CSRF tidak berlaku: `csrfProtection` hanya memeriksa request yang
membawa cookie auth `at` atau `rt`; request tanpa cookie langsung dilewati
(`backend/src/shared/middleware/CsrfProtection.ts:71-75`). Komentar di
`CsrfProtection.ts:60-63` menyatakan ini sengaja, supaya integrasi native
tidak perlu semantik CSRF browser.

Cara server membaca token Anda
(`backend/src/shared/middleware/Authenticate.ts:23-34`):

```
1. Kalau ada cookie `at` → pakai itu.
2. Kalau tidak → baca header Authorization.
3. Header harus tepat dua bagian dipisah satu spasi,
   dengan skema `Bearer` (huruf B besar, case-sensitive).
```

`bearer <token>` huruf kecil **tidak diterima**.

### 2.1 Login

```
POST /api/v1/auth/login
X-Client-Type: mobile
Content-Type: application/json

{ "email": "...", "password": "...", "totp": "123456" }
```

- `email` maksimum 255 karakter, di-lowercase & di-trim server.
- `password` 1–128 karakter.
- `totp` hanya perlu kalau MFA akun aktif: kode TOTP 6 digit **atau**
  recovery code, 6–20 karakter. Kalau akun pakai MFA dan `totp` tidak
  dikirim, server menjawab `401` dengan `code: "MFA_REQUIRED"`
  (`backend/src/modules/auth/auth.service.ts:255`) — pakai itu sebagai
  sinyal untuk membuka layar kode, lalu kirim ulang login lengkap.

Skema: `backend/src/modules/auth/auth.dto.ts:3-16`.

Response mobile (`auth.controller.ts:96-111`):

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "...", "email": "...", "employeeId": "...", "name": "...",
      "roles": ["EMPLOYEE"],
      "permissions": ["leave:create", "leave:read", "payroll:read"],
      "companyId": "...", "companyScope": ["..."], "groupId": "...",
      "mustChangePassword": false
    },
    "tokens": {
      "accessToken": "eyJ...",
      "refreshToken": "eyJ...",
      "expiresIn": 900
    }
  }
}
```

Yang harus aplikasi lakukan setelah login:

1. Simpan `refreshToken` di **Keystore (Android) / Keychain (iOS)**, bukan
   SharedPreferences / UserDefaults biasa.
2. Simpan `accessToken` di memori, atau di penyimpanan aman kalau perlu
   bertahan antar cold start. Masa hidupnya pendek (default `15m`).
3. Simpan `employeeId` dan `companyId` — beberapa endpoint **mewajibkan**
   Anda mengirimnya di body (lihat §12).
4. Simpan `permissions` dan `roles` untuk menyembunyikan menu yang pasti
   dijawab 403.
5. Kalau `mustChangePassword` `true`, arahkan ke layar ganti password
   sebelum apa pun.
6. Daftarkan token push: `POST /api/v1/notifications/device-tokens`.

**Rate limit login.** Ada dua limiter sekaligus (`auth.routes.ts:56-79`):
per IP dan per alamat email, masing-masing `RATE_LIMIT_AUTH_MAX` per
`RATE_LIMIT_WINDOW_MS`. Keduanya memakai `skipSuccessfulRequests: true`,
jadi hanya kegagalan yang menghabiskan kuota — refresh yang berhasil dari
kantor ber-NAT tidak akan mengunci orang lain. Backstop terakhir adalah
lockout akun di database.

### 2.2 Refresh

```
POST /api/v1/auth/refresh
X-Client-Type: mobile
Content-Type: application/json

{ "refreshToken": "<refresh token terakhir>" }
```

Sumber: `auth.routes.ts:163`, `auth.controller.ts:154-201`.

- Refresh token diambil dari cookie `rt` **atau** body `refreshToken`
  (`auth.controller.ts:59-61`). Mobile pakai body.
- Tanpa keduanya, jawabannya `401 AUTHENTICATION_FAILED` dengan pesan
  `"No refresh token"` (`auth.controller.ts:164`).
- **Token dirotasi.** Response membawa `accessToken` **dan** `refreshToken`
  baru. Timpa keduanya di penyimpanan; refresh token lama jangan dipakai
  lagi.
- Refresh **tidak** memeriksa `sessionVersion` — ia membaca ulang baris user
  dan mencetak klaim baru (komentar
  `backend/src/shared/security/session-revocation.ts:5-12`). Inilah sebabnya
  refresh adalah jalan keluar yang benar dari penolakan di §3.

### 2.3 Logout

```
POST /api/v1/auth/logout
Content-Type: application/json

{ "refreshToken": "<refresh token terakhir>" }
```

Sumber: `auth.routes.ts:169`, `auth.controller.ts:136-148`.

Perhatikan: route ini **sengaja tidak memakai middleware `authenticate`**.
Komentar `auth.routes.ts:167-168`: logout harus tetap bekerja dengan access
token yang sudah kedaluwarsa, karena yang dibutuhkan hanyalah refresh token —
menolaknya akan meninggalkan refresh token 7 hari tetap hidup.

Jadi:

- Header `Authorization` **tidak wajib** di sini.
- Panggil logout bahkan ketika access token Anda sudah mati.
- Panggil juga `DELETE /api/v1/notifications/device-tokens` dengan
  `installationId` Anda, supaya push berhenti ke perangkat ini.
- Hapus token lokal **apa pun** hasil panggilan logout.

### 2.4 Ganti password mematikan sesi

`POST /api/v1/auth/change-password` berhasil → seluruh refresh token dicabut
**dan** `sessionVersion` dinaikkan (`auth.repository.ts:224`). Pesan server
sendiri: *"Password changed successfully. Please log in again."* Setelah 200,
paksa user login ulang; jangan coba refresh.

---

## 3. Invalidasi sesi (`sessionVersion`) — yang paling penting

Ini bagian yang menentukan apakah aplikasi Anda me-refresh token atau
melogout user. Tolong baca utuh.

### Apa yang terjadi

Roles, permissions, dan company scope **dibawa di dalam access token**. Kalau
admin mencabut role seseorang, perubahan itu tidak terasa sampai token
kedaluwarsa — artinya bisa ada jendela sampai 15 menit dengan otoritas basi.
Untuk menutupnya, setiap perubahan otoritas menaikkan kolom
`users.session_version`, dan middleware autentikasi menolak token yang
`sessionVersion`-nya tidak lagi sama.

Yang menaikkan `sessionVersion`
(`backend/src/shared/security/session-revocation.ts:17-35`):

- pemberian/pencabutan role pada satu user (`revokeSessionsForUser`);
- perubahan set permission sebuah role — **mengenai semua pemegang role itu**
  (`revokeSessionsForRole`);
- pemberian/pencabutan akses company;
- ganti password (`auth.repository.ts:224`) dan reset password
  (`auth.repository.ts:317`).

### Jawaban persisnya: status dan `code`

Pemeriksaannya ada di
**`backend/src/shared/middleware/Authenticate.ts:43-54`** (fungsi
`isCurrentSession`, perbandingan `user.sessionVersion === decoded.sessionVersion`
di **baris 52**). Kalau tidak cocok,
**`Authenticate.ts:90-91`** melempar:

```ts
if (!(await isCurrentSession(decoded))) {
  throw new AuthError('Access token session is no longer valid');
}
```

`AuthError` didefinisikan di
**`backend/src/shared/exceptions/AppError.ts:40-44`**:

```ts
export class AuthError extends AppError {
  constructor(message: string = 'Authentication failed') {
    super(message, 401, 'AUTHENTICATION_FAILED');
  }
}
```

Lalu `errorHandler` (`backend/src/shared/middleware/ErrorHandler.ts:45-82`)
mengirimnya dengan `res.status(err.statusCode).json({ success, code, message })`.

Jadi jawaban di kabel adalah:

```
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{
  "success": false,
  "code": "AUTHENTICATION_FAILED",
  "message": "Access token session is no longer valid"
}
```

**Status `401`, `code` `AUTHENTICATION_FAILED`.** Dipatok juga oleh
`backend/src/shared/core/api-contract.test.ts` (baris 19 dari daftar
`ERROR_CATALOGUE`: `[AuthError, 401, 'AUTHENTICATION_FAILED']`) dan oleh
`backend/src/shared/middleware/Authenticate.test.ts` yang memastikan
`statusCode: 401` saat `sessionVersion` berbeda.

### Yang penting: `AUTHENTICATION_FAILED` ≠ logout

Perhatikan bahwa `code`-nya **sama** dengan kode untuk "token sampah" atau
"tidak ada token". Aplikasi **tidak bisa** membedakan "otoritas berubah" dari
"token tidak valid" hanya dari `code`. Satu-satunya pembeda adalah `message`
(`"Access token session is no longer valid"`), dan `message` bukan sesuatu
yang aman dijadikan logika (`docs/api-contract.md` secara eksplisit
mengatakan demikian).

Maka **satu-satunya strategi yang benar** adalah:

```
Terima 401 (code apa pun: TOKEN_EXPIRED atau AUTHENTICATION_FAILED)
  └─ Sudah pernah coba refresh untuk request ini?
       ├─ Belum → panggil POST /auth/refresh satu kali,
       │           simpan pasangan token baru, ulangi request aslinya.
       └─ Sudah → LOGOUT: hapus token, tampilkan layar login.

Refresh gagal dengan 401 → LOGOUT.
```

Ini bekerja untuk kedua kasus:

- **Token kedaluwarsa** (`TOKEN_EXPIRED`, 401, dari
  `JWTHandler.ts:122-124` → `AppError.ts:46-50`) → refresh berhasil, request
  diulang, user tidak merasakan apa-apa.
- **`sessionVersion` naik** (`AUTHENTICATION_FAILED`, 401) → refresh
  **tetap berhasil**, karena `/auth/refresh` tidak melihat `sessionVersion`
  dan justru mencetak klaim baru. User tetap login, dengan otoritas yang
  sekarang benar-benar dia miliki — persis yang dimaksud komentar di
  `session-revocation.ts:10-12`.
- **Refresh token benar-benar mati** (user dinonaktifkan, password diganti,
  token sudah dicabut/dipakai ulang) → refresh dijawab 401, dan di situlah
  logout.

Konsekuensi UX yang harus ditangani: setelah refresh karena perubahan
otoritas, **`permissions` dan `roles` di response refresh bisa berbeda** dari
yang Anda simpan saat login. Timpa cache permission Anda dengan nilai baru
dan refresh menu — kalau tidak, user melihat menu yang kemudian menjawab 403.

Dua sumber penolakan lain yang ikut diperiksa di tempat yang sama
(`Authenticate.ts:48-53`) dan **juga** menghasilkan `401
AUTHENTICATION_FAILED`: akun di-soft-delete (`deletedAt` terisi), dan status
akun `INACTIVE` atau `SUSPENDED`. Untuk dua kasus ini refresh akan gagal
juga, sehingga alur di atas berakhir dengan logout — yang memang benar.

### Hal lain yang harus dihindari

Jangan mem-refresh secara paralel. Karena refresh **merotasi** refresh token,
dua panggilan refresh bersamaan dengan token yang sama akan membuat salah
satunya gagal. Pakai satu mutex/single-flight: request mana pun yang
mendapat 401 menunggu satu panggilan refresh yang sedang berjalan, lalu
mengulang dirinya.

---

## 4. Envelope response

Satu envelope untuk semua, dari `backend/src/shared/core/Result.ts` dan
dipatok oleh `backend/src/shared/core/api-contract.test.ts`.

### Sukses

```json
{ "success": true, "message": "Success", "data": { } }
```

- `message` **selalu ada dan tidak kosong**. Teks untuk operator, bukan untuk
  dijadikan cabang logika.
- `data` **selalu ada**; bernilai `null` untuk respons delete / no-content
  (`Result.ts:65-71`, `81-87`).
- **Tidak ada** field `code` pada respons sukses.

### Sukses ber-pagination

```json
{
  "success": true,
  "message": "Success",
  "data": [ ],
  "meta": {
    "page": 2, "limit": 10, "total": 25, "totalPages": 3,
    "hasNextPage": true, "hasPreviousPage": true
  }
}
```

Dari `Result.paginated` (`Result.ts:26-47`).

### Error

```json
{ "success": false, "code": "NOT_FOUND", "message": "Resource not found" }
```

Dengan `errors` hanya untuk kegagalan validasi:

```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "errors": [{ "field": "email", "message": "Invalid email format" }]
}
```

`field` adalah jalur Zod digabung titik, mis. `provider` atau
`stages.0.level` (`backend/src/shared/middleware/RequestValidator.ts:23-26`).

### Pengecualian yang perlu Anda tangani

Tiga tempat di permukaan mobile **tidak** mengikuti envelope error di atas.
Parser Anda harus tahan terhadap `code` yang tidak ada:

1. **`Result.error(message)` tanpa kode** (`Result.ts:49-55`) — body hanya
   `{ success: false, message }`. Terjadi pada:
   - `GET /payroll/payslips` saat akun tidak tertaut karyawan
     (`payroll.controller.ts:381`);
   - `GET /workflow-engine/instances/my-approvals` saat company tidak
     terbentuk (`workflow-engine.controller.ts:173`);
   - `GET /workflow-engine/instances/{id}` saat tidak ditemukan — **404 tanpa
     `code`** (`workflow-engine.controller.ts:189`).
2. **Body pesan rate limiter.** Limiter PIN slip gaji mengirim
   `{ success: false, message }` tanpa `code`
   (`payroll.routes.ts:332`). Limiter auth mengirim
   `{ success, code: "TOO_MANY_REQUESTS", message }` (`auth.routes.ts:50-54`)
   — yang ini lengkap.
3. **`GET /meta/endpoints` dan `GET /meta/openapi.json`** menulis body sendiri
   tanpa `message` (`app.ts:256`, `app.ts:267`).

### Response biner

`GET /payroll/payslips/my/{id}/pdf` dan unduhan file privat mengembalikan
**berkas itu sendiri**, bukan envelope JSON — dengan
`Content-Disposition: attachment`, `Content-Type: application/pdf`, dan
`Cache-Control: no-store, private`. Kegagalan pada route itu tetap memakai
envelope error JSON.

---

## 5. Kode error

Katalog resmi, dipatok oleh `api-contract.test.ts` (daftar `ERROR_CATALOGUE`)
dan didefinisikan di `backend/src/shared/exceptions/AppError.ts`:

| Status | `code` | Arti bagi aplikasi |
|---|---|---|
| 400 | `BAD_REQUEST` | Input salah atau aturan domain ditolak. Tampilkan `message`. Jangan retry otomatis. |
| 401 | `AUTHENTICATION_FAILED` | Autentikasi gagal — **termasuk `sessionVersion` naik**. Jalankan alur §3: refresh sekali, baru logout. |
| 401 | `TOKEN_EXPIRED` | Access token kedaluwarsa. Refresh, lalu ulangi request. |
| 403 | `FORBIDDEN` | Terautentikasi tapi tidak berhak. **Jangan retry.** |
| 404 | `NOT_FOUND` | Tidak ada, **atau** di luar tenant/data-scope Anda — sengaja tidak dapat dibedakan. |
| 409 | `CONFLICT` | Tabrakan state: duplikat, sudah disetujui, tanggal tumpang tindih, atau konflik `Idempotency-Key`. |
| 422 | `VALIDATION_ERROR` | Validasi skema gagal; `errors[]` menyebut field. Tandai field di form. |
| 429 | `TOO_MANY_REQUESTS` | Rate limit atau lockout. Backoff; jangan retry cepat. |
| 500 | `DATABASE_ERROR` | Kesalahan server. Boleh retry dengan backoff. |
| 503 | `SERVICE_UNAVAILABLE` | Dependency mati. Retry nanti. |

Dari app shell, bukan exception class:

| Status | `code` | Dari |
|---|---|---|
| 404 | `NOT_FOUND` | Route tidak dikenal (`app.ts:278-284`) — biasanya berarti path Anda salah tulis |
| 500 | `INTERNAL_ERROR` | Fallback error tak terduga (`ErrorHandler.ts:118-125`) |
| 400 | `UPLOAD_ERROR` | Kegagalan multer, mis. file melebihi batas (`ErrorHandler.ts:95-108`) |
| 409 | `CONFLICT` | Pelanggaran unique constraint database, dengan pesan Indonesia seperti *"NIK sudah terdaftar di perusahaan ini"* (`ErrorHandler.ts:10-17`, `85-93`) |

Kode domain yang muncul di permukaan mobile ini:

| Status | `code` | Kapan | Yang harus aplikasi lakukan |
|---|---|---|---|
| 401 | `MFA_REQUIRED` | Login tanpa `totp` pada akun MFA (`auth.service.ts:255`) | Buka layar kode, kirim ulang login dengan `totp` |
| 409 | `PAYSLIP_PIN_NOT_SET` | Unlock slip gaji tapi PIN belum diatur (`payslip-pin.service.ts:112`) | Arahkan ke layar atur PIN |
| 403 | `PAYSLIP_PIN_INVALID` | PIN salah (`payslip-pin.service.ts:128`) | "PIN salah", biarkan coba lagi. **Jangan logout** |
| 429 | `PAYSLIP_PIN_LOCKED` | 5 PIN salah → kunci 15 menit (`payslip-pin.service.ts:32-40`) | Tampilkan sisa waktu dari `message` |
| 403 | `PAYSLIP_PIN_REAUTH_FAILED` | Password salah saat set PIN (`payslip-pin.service.ts:77`) | "Kata sandi salah". **Jangan logout** |
| 403 | `PAYSLIP_UNLOCK_INVALID` | Header `X-Payslip-Unlock` tidak ada / kedaluwarsa / tidak cocok (`payslip-pin.service.ts:150-156`) | Minta PIN lagi |
| 413 | `PAYSLIP_PDF_TOO_LARGE` | PDF > 5 MB (`payroll.controller.ts:444`) | Tampilkan error; laporkan ke HR |
| 401 | `PAYROLL_UNLOCK_REQUIRED` | Endpoint payslip jalur permission tanpa grant (`payroll-unlock.service.ts:24`) | **Jangan logout** — ini bukan sesi mati. Lakukan unlock payroll, atau beralih ke jalur PIN |
| 401 | `PAYROLL_REAUTH_FAILED` | Password/TOTP salah saat unlock payroll (`payroll-unlock.service.ts:60`) | **Jangan logout** |
| 429 | `PAYROLL_UNLOCK_LOCKED` | Unlock payroll terkunci 15 menit (`payroll-unlock.service.ts:26-31`) | Backoff |
| 429 | `ACCOUNT_LOCKED` | Akun terkunci (`payroll-unlock.service.ts:91`) | Arahkan ke HR/IT |

> **Peringatan khusus.** `PAYROLL_UNLOCK_REQUIRED` dan `PAYROLL_REAUTH_FAILED`
> berstatus **401**, tapi **bukan** masalah sesi. Interceptor 401 Anda harus
> memeriksa `code` lebih dulu: hanya `TOKEN_EXPIRED` dan
> `AUTHENTICATION_FAILED` yang memicu alur refresh/logout. Kalau tidak,
> membuka slip gaji tanpa grant akan melogout user Anda.

### Correlation ID

Kirim `X-Correlation-Id` (atau `X-Request-Id`) pada setiap request. Kalau
ada, server menyertakannya kembali di body error sebagai `correlationId` dan
mencatatnya di log (`ErrorHandler.ts:25`, `56-58`). Ini yang membuat laporan
bug dari lapangan bisa ditelusuri.

---

## 6. Pagination, sort, dan search

### Pagination

Endpoint ber-pagination di permukaan mobile menerima `page` dan `limit`:

| Endpoint | `page` | `limit` | Sumber skema |
|---|---|---|---|
| `GET /attendance/me` | min 1, default 1 | min 1, **maks 100**, default 20 | `attendance.dto.ts:114-118` |
| `GET /notifications` | min 1, default 1 | min 1, maks 100, **default 50** | `notification.dto.ts:17-21` |
| `GET /announcements` | min 1, default 1 | min 1, maks 100, default 20 | `announcement.dto.ts:3-7` |
| `GET /assets/my` | min 1, default 1 | min 1, maks 100, default 20 | `asset.dto.ts:26-30` |
| `GET /workflow-engine/instances/my-approvals` | min 1, default 1 | min 1, maks 100, default 20 | `workflow-engine.dto.ts:56-59` |

Semuanya memakai `z.coerce.number().int()`, jadi mengirim `"2"` sebagai
string diterima. `limit` > 100 dijawab `422`.

Cara memutuskan memuat halaman berikutnya — **pakai `meta.hasNextPage`**,
jangan hitung sendiri:

```
page = 1
loop:
  GET ...?page=<page>&limit=20
  tampilkan data
  if (meta.hasNextPage) { page += 1; lanjut } else { berhenti }
```

Alasannya: `totalPages` adalah `0` untuk hasil kosong
(`Result.ts:33`, `ceil(0/20) = 0`), jadi perbandingan `page < totalPages`
yang Anda tulis sendiri bisa salah di tepi. `hasNextPage` sudah
memperhitungkan itu.

### Endpoint daftar yang TIDAK ber-pagination

Jangan kirim `page`/`limit` ke endpoint ini — tidak ada `meta` di
responsnya, dan jumlah barisnya ditentukan server:

- `GET /leave` — `Result.success`, bukan `paginated` (`leave.controller.ts:38`).
- `GET /leave/types`, `GET /leave/balances/employee`.
- `GET /payroll/payslips` — maksimum **20 baris terbaru**, hardcoded sebagai
  default parameter `limit = 20` di repository
  (`payroll.repository.ts:470`, `480`). Tidak ada cara menaikkannya dari
  klien. Kalau karyawan butuh riwayat lebih panjang, itu keterbatasan yang
  harus dilaporkan ke tim backend.
- `GET /attendance-corrections/my`, `GET /permission-requests/my`,
  `GET /employee-loans/my`, `GET /ewa/my`, `GET /daily-activities/my`.
- Semua endpoint work-calendar self-service.

### Sort

**Tidak ada parameter sort di permukaan mobile.** Ada middleware pagination
generik (`backend/src/shared/middleware/Pagination.ts:14-20`) yang mendukung
`sortBy` dan `sortOrder` (`asc`/`desc`, default `createdAt` `desc`), tetapi
`parsePagination` tidak dipasang pada route mana pun yang didokumentasikan di
sini. Mengirim `sortBy` ke endpoint mobile tidak berpengaruh.

Urutan tetap yang diketahui dari source:

- `GET /payroll/payslips`: `createdAt desc`, lalu `id asc`
  (`payroll.repository.ts:479`).

### Search

**Tidak ada parameter `search` di permukaan mobile.** `Pagination.ts:19`
mendefinisikan `search` opsional, tapi sekali lagi middleware itu tidak
terpasang di route mobile. Filter yang tersedia adalah parameter query
spesifik per endpoint, misalnya:

- `GET /attendance/me?month=2026-09` (pola `YYYY-MM`, divalidasi).
- `GET /attendance-corrections/my?status=PENDING`.
- `GET /notifications?unreadOnly=true` — **string literal**
  `"true"`/`"false"`, karena skemanya `z.enum(['true','false'])`, bukan
  boolean. Mengirim boolean JSON `true` akan gagal validasi.
- `GET /announcements?unreadOnly=true` — sama.
- `GET /assets/my?status=ACTIVE|RETURNED|ALL`.
- `GET /ewa/my?status=PENDING|APPROVED|PAID|DEDUCTED|REJECTED|CANCELLED`.
- `GET /work-calendars/me/next-shift?from=2026-10-04` — `YYYY-MM-DD`, dan
  divalidasi sebagai tanggal yang benar-benar ada, jadi `2026-02-30`
  dijawab `422` (`work-calendar.dto.ts:129-137`).

---

## 7. Permission dan 403

Setiap operasi di `openapi.yaml` menyebutkan permission yang diminta oleh
guard `authorize({ resource, action })` pada route-nya, di dalam
`description`. Kalau Anda mendapat 403, bandingkan dengan `data.permissions`
dari `GET /auth/me`.

Cara server mencocokkan (`backend/src/shared/middleware/Authorize.ts:26-62`):

1. Role `SUPER_ADMIN` melewati semua pemeriksaan permission.
2. Selain itu, permission cocok kalau salah satu dari ini ada di daftar user:
   - `resource:action` persis, mis. `leave:approve`;
   - wildcard `resource:*`, mis. `leave:*`;
   - alias legacy `aliasResource:action`;
   - wildcard alias `aliasResource:*`.
3. Alias legacy (`Authorize.ts:12-18`): `organization`→`org`,
   `attendance`→`att`, `recruitment`→`rec`, `dashboard`→`dash`,
   `travel-expense`→`travel`. **Hanya lima ini.** Resource lain tidak
   di-alias.

**Bentuk apa yang sebenarnya ada di `data.permissions`?** Token dibangun
sebagai `` `${permission.resource}:${permission.action}` ``
(`backend/src/modules/auth/auth.service.ts:60-68`), **bukan** kolom `code`
di tabel permission. Jadi `data.permissions` berisi `daily-activity:create`,
`attendance:read`, `travel-expense:create` — bukan `da:create`, `att:read`,
`travel:create`, walaupun itulah kolom `code` yang di-seed
(`backend/src/database/seeds/modules/01-permissions.seed.ts:143-149`).

Alias legacy di `authorize()` ada sebagai jaring pengaman untuk token lama
atau permission yang diisi manual; dalam alur normal Anda tidak akan
melihatnya. Tetap tulis helper yang mencoba keempat bentuk di daftar di atas,
supaya aplikasi tidak salah menyembunyikan menu kalau suatu saat ada token
yang membawa bentuk alias atau wildcard `resource:*`.

Pesan 403 dari permission **menyebutkan permission yang diminta**
(`Authorize.ts:53-57`):

```json
{ "success": false, "code": "FORBIDDEN",
  "message": "Insufficient permissions. Required: leave:approve" }
```

Dua sumber 403 lain yang perlu dibedakan di UI:

- **Company di luar scope** — `"You do not have access to this company data"`
  (`backend/src/shared/middleware/CompanyScope.ts:47-49`). Terjadi kalau Anda
  mengirim `companyId` yang tidak ada di `companyScope` sesi.
- **Aturan domain di service** — mis. membatalkan cuti milik orang lain
  (`leave.routes.ts:153-154`).

Route self-service tidak punya `authorize()` sama sekali — identitas karyawan
diambil dari sesi, dan layar untuknya tidak perlu disembunyikan berdasarkan
permission. Yang termasuk: `/attendance/me/*`, `/attendance-corrections/my*`,
`/payroll/payslips/pin*` dan `/payroll/payslips/my/*`, `/notifications/*`,
`/announcements` (sisi karyawan), `/employees/me/reporting-line`,
`/work-calendars/me/*` dan `/work-calendars/shift-swaps/*`
(kecuali route workflow), `/assets/my`, `/permission-requests/my` + create +
cancel, `/employee-loans/my` + create + cancel, `/ewa/my*`,
`/daily-activities/my`, dan delegasi workflow.

---

## 8. Masking PII (NIK, NPWP, rekening, BPJS)

Sumber: `backend/src/modules/employee/employee-pii.ts`.

Enam field data karyawan di-mask di response API kecuali pemanggil berhak
membacanya mentah. Daftar persisnya (`employee-pii.ts:10-17`):

| Field | Isi |
|---|---|
| `idNumber` | NIK |
| `taxId` | NPWP |
| `bankAccount` | Nomor rekening |
| `bankAccountHolder` | **Nama pemilik rekening** |
| `bpjsKetenagakerjaan` | Nomor BPJS Ketenagakerjaan |
| `bpjsKesehatan` | Nomor BPJS Kesehatan |

### Format mask, persis

Dari `employee-pii.ts:29-32`:

```ts
function last4(value: unknown): string {
  const s = String(value);
  return s.length <= 4 ? '****' : '*'.repeat(s.length - 4) + s.slice(-4);
}
```

Jadi:

| Nilai asli | Hasil mask |
|---|---|
| `3174010101900001` (16 karakter) | `************0001` |
| `09.254.294.1-407.000` (20 karakter) | `****************.000` |
| `1234567890` (10 karakter) | `******7890` |
| `Budi Santoso` (12 karakter) | `********toso` |
| `1234` (≤ 4 karakter) | `****` |
| `null` | tetap `null` — field `null` tidak di-mask (`employee-pii.ts:39`) |

Tiga hal yang harus aplikasi Anda ikuti:

1. **Panjang string dipertahankan.** Nilai ter-mask punya panjang yang sama
   dengan nilai asli. Jangan memakai panjang sebagai tanda bahwa nilainya
   asli, dan jangan menjalankan validasi format (mis. "NIK harus 16 digit
   angka") pada nilai dari API — `************0001` lolos cek panjang tapi
   bukan angka.
2. **Jangan render sebagai data asli, dan jangan kirim balik.** Kalau user
   melihat `************0001` di form edit lalu menyimpan, Anda akan
   menuliskan bintang ke database. Tandai field ini read-only di UI kalau
   pemanggil tidak berhak, atau kosongkan input dan minta user mengisi ulang.
3. **Nama pemilik rekening juga ter-mask.** `*********anto` adalah hasil
   masking, bukan data rusak. Jangan tampilkan sebagai nama.

### Siapa yang melihat nilai asli

Dari `canReadSensitiveEmployeeData()` (`employee-pii.ts:23-27`), nilai mentah
diberikan kalau **salah satu** benar:

- role pemanggil termasuk `SUPER_ADMIN`, `GROUP_ADMIN`, `COMPANY_ADMIN`,
  `HR_MANAGER`, atau `HR_STAFF` (`employee-pii.ts:21`);
- permission pemanggil memuat `employee:read-sensitive` **atau**
  `employee:*`.

Catatan dari komentar `employee-pii.ts:19-20`: fallback berbasis role itu
ada supaya alur HR tetap jalan di database yang belum di-seed permission
`employee:read-sensitive`. Artinya **jangan hanya memeriksa permission** di
aplikasi — periksa role juga, dengan logika yang sama, kalau Anda ingin
memprediksi apakah nilai akan ter-mask.

Cara aman untuk UI: ambil `roles` dan `permissions` dari `GET /auth/me`,
terapkan aturan di atas, dan kalau hasilnya "tidak berhak", tampilkan label
seperti *"Disamarkan — hubungi HR"* di sebelah nilainya.

Masking diterapkan untuk satu baris (`serializeEmployee`) maupun daftar
(`serializeEmployees`), jadi berlaku di detail karyawan dan di daftar.

---

## 9. Kerahasiaan slip gaji dan mekanisme unlock

Nominal slip gaji **tidak pernah** dikirim begitu saja. Ada **dua jalur
unlock yang berbeda**, dengan header berbeda, dan mobile harus memakai yang
pertama.

### 9.1 Jalur PIN (untuk aplikasi mobile karyawan) — header `X-Payslip-Unlock`

Empat endpoint, semuanya **tanpa** `authorize()` karena identitas selalu dari
sesi:

| Method | Path | Fungsi |
|---|---|---|
| `GET` | `/payroll/payslips/pin/status` | `{ pinSet, lockedUntil? }` |
| `PUT` | `/payroll/payslips/pin` | Atur/ubah PIN (butuh password akun) |
| `POST` | `/payroll/payslips/my/unlock` | Verifikasi PIN → `unlockToken` 15 menit |
| `GET` | `/payroll/payslips/my/{id}` | Detail + nominal (butuh `X-Payslip-Unlock`) |
| `GET` | `/payroll/payslips/my/{id}/pdf` | PDF (butuh `X-Payslip-Unlock`) |

Sumber: `backend/src/modules/payroll/payroll.routes.ts:336-367`,
`payroll.controller.ts:392-454`,
`backend/src/modules/payroll/payslip-pin.service.ts`,
`backend/src/shared/payroll/payslip-pin.ts`.

Daftar periodenya, `GET /payroll/payslips`, **tidak membawa nominal sama
sekali**. Query di repository hanya mengambil `id`, `status`, `createdAt`,
dan `payrollRun` (`payroll.repository.ts:470-482`), lalu controller
menambahkan `locked: true` ke setiap baris (`payroll.controller.ts:384`).
Jadi layar daftar slip gaji aman ditampilkan tanpa PIN; nominal baru muncul
setelah unlock.

Aturan PIN dan lockout (`backend/src/shared/payroll/payslip-pin.ts:17-20`):

```
PAYSLIP_PIN_LENGTH        = 6     → PIN tepat 6 digit angka
PAYSLIP_PIN_MAX_ATTEMPTS  = 5     → 5 PIN salah mengunci
PAYSLIP_PIN_LOCK_MINUTES  = 15    → lama kunci
PAYSLIP_UNLOCK_TTL_MINUTES = 15   → masa hidup unlockToken
```

Ditambah rate limiter 30 request / 15 menit per IP untuk route PIN
(`payroll.routes.ts:326-333`).

Sifat `unlockToken`: token HMAC-SHA256 **stateless** berisi
`{ userId, employeeId, companyId, expiresAt }` yang di-base64url lalu
ditandatangani (`shared/payroll/payslip-pin.ts:74-84`). Verifikasinya
mencocokkan tanda tangan, masa berlaku, **dan ketiga id** terhadap sesi
sekarang (`:91-117`). Jadi token tidak bisa dipakai oleh akun lain, dan ikut
mati kalau company aktif sesi berubah.

**Header yang benar adalah `X-Payslip-Unlock`** — dibaca dari
`req.headers['x-payslip-unlock']` di `payroll.controller.ts:30`. Bukan
`Authorization`, dan bukan `X-Payroll-Unlock-Token`.

Kenapa dua jalur dipisah, dari komentar
`shared/payroll/payslip-pin.ts:8-14`: `PayrollUnlockSession` adalah bukti
reautentikasi password(+TOTP) untuk jalur admin. Menerbitkan sesi yang sama
dari verifikasi PIN akan membuat PIN 6 digit diterima di jalur admin (sebuah
pelonggaran), dan unlock PIN akan mencabut sesi admin milik user yang sama.

### 9.2 Jalur password/TOTP (jalur admin & web) — header `X-Payroll-Unlock-Token`

| Method | Path | Permission |
|---|---|---|
| `POST` | `/payroll/payslips/unlock` | `payroll:read` |
| `POST` | `/payroll/payslips/lock` | `payroll:read` |
| `GET` | `/payroll/payslips/{id}` | `payroll:read` |
| `GET` | `/payroll/payslips/{id}/pdf` | `payroll:read` |

Unlock-nya meminta `{ password, totp? }` dan menghasilkan grant berumur
**5 menit** (`PAYROLL_UNLOCK_TTL_SECONDS = 300`,
`payroll-unlock.service.ts:7`, `108`, `128-134`). Grant baru mencabut grant
lama (`:53-56`). Lockout 15 menit.

Grant hanya diperiksa untuk pemanggil yang punya `employeeId` **dan tidak**
elevated — pemegang `payroll:process`, `payroll:approve`,
`payroll:disburse`, `payroll:*`, atau role `SUPER_ADMIN` dilewati
(`payroll.controller.ts:15-21`, `344-346`, `357-359`). Tanpa grant yang
diperlukan, jawabannya `401 PAYROLL_UNLOCK_REQUIRED` — dan ingat peringatan
di §5: **401 ini bukan sesi mati.**

### Mana yang dipakai aplikasi mobile

Pakai **jalur PIN**. Alasannya ada di source: jalur PIN dirancang khusus
self-service (tidak ada `authorize()`, identitas dari sesi, lockout di kolom
`users.payslip_pin_*`), masa berlakunya 15 menit alih-alih 5, dan tidak
meminta password akun setiap kali membuka slip gaji.

> **Perhatian untuk WebView.** `X-Payslip-Unlock` **tidak** terdaftar di
> `allowedHeaders` CORS (`backend/src/app.ts:108`, yang memuat
> `X-Payroll-Unlock-Token` tapi tidak `X-Payslip-Unlock` dan tidak
> `X-Client-Type`). Klien native tidak terkena CORS sehingga tidak masalah,
> tetapi kalau sebagian aplikasi Anda berjalan di WebView/browser, preflight
> akan memblokir header itu. Laporkan ke tim backend bila Anda butuh jalur
> WebView.

---

## 10. Header yang perlu Anda tahu

### Yang dikirim aplikasi

| Header | Kapan | Catatan |
|---|---|---|
| `Authorization: Bearer <accessToken>` | Hampir semua request | Skema `Bearer` case-sensitive (`Authenticate.ts:30`) |
| `X-Client-Type: mobile` | Login & refresh | Memilih mode token-di-body (`auth.controller.ts:70`) |
| `Content-Type: application/json` | Request dengan body JSON | |
| `X-Payslip-Unlock: <token>` | Detail/PDF slip gaji jalur PIN | 15 menit |
| `X-Payroll-Unlock-Token: <grant>` | Detail/PDF slip gaji jalur permission | 5 menit |
| `Idempotency-Key: <key>` | Mutasi yang di-retry | Lihat di bawah |
| `X-Correlation-Id: <uuid>` | Sebaiknya semua request | Dipantulkan ke body error dan dicatat di log |
| `X-CSRF-Token` | **Tidak perlu** untuk mobile | Hanya untuk klien cookie |

### `Idempotency-Key`

Sumber: `backend/src/shared/middleware/Idempotency.ts`.

- Format: **16–128 karakter ASCII tampak** (`!` sampai `~`), tanpa spasi —
  regex `^[!-~]{16,128}$` (`Idempotency.ts:93`). Format salah dijawab `422`
  dengan `errors[0].field = "Idempotency-Key"`.
- Scope kunci adalah `companyId : userId : method : path : key`
  (`Idempotency.ts:101`), jadi satu kunci boleh dipakai ulang untuk aksi
  berbeda tanpa bertabrakan.
- Respons sukses (2xx) disimpan **24 jam**. Pengulangan dengan kunci + payload
  sama mengembalikan respons tersimpan beserta header
  `Idempotency-Replayed: true` (`Idempotency.ts:78`).
- Kunci sama + payload **berbeda** → `409 CONFLICT`
  *"Idempotency-Key was already used with a different request payload"*.
- Kunci sedang diproses → `409 CONFLICT`
  *"A request with this Idempotency-Key is still in progress"*.
- **Hanya sukses yang disimpan.** Kegagalan validasi, permission, konflik,
  dan error server tetap bisa dicoba ulang dengan kunci yang **sama**
  (`Idempotency.ts:128-131`) — ini membuat retry setelah timeout jaringan
  aman.
- Urutan key JSON tidak mempengaruhi fingerprint (`Idempotency.ts:22-38`),
  jadi serializer yang mengurutkan key berbeda tidak akan memicu 409 palsu.

Endpoint yang mendukungnya di permukaan mobile: check-in, check-out,
pengajuan koreksi absensi, pengajuan cuti, pencairan cuti, overtime, daftar
& hapus device token, tandai pengumuman dibaca, pengajuan izin, pinjaman +
cancel, EWA + cancel, aktivitas harian + complete.

**Rekomendasi:** generate satu UUIDv4 (tanpa tanda hubung = 32 karakter, lolos
regex) per aksi yang dimulai user, dan pakai kunci yang sama untuk setiap
retry aksi itu.

### Yang dikirim server dan di-expose lewat CORS

`backend/src/app.ts:109` meng-expose: `X-RateLimit-Limit`,
`X-RateLimit-Remaining`, `X-Office-Timezone`, `X-Server-Date`,
`Idempotency-Replayed`.

| Header | Dari | Gunanya |
|---|---|---|
| `X-Office-Timezone` | `GET /attendance/me` (`attendance.controller.ts:23`) | Timezone kantor, mis. `Asia/Jakarta` |
| `X-Server-Date` | `GET /attendance/me` (`attendance.controller.ts:24`) | Tanggal kalender kantor menurut server |
| `Idempotency-Replayed: true` | Mutasi yang di-replay | Jangan hitung dua kali di UI |
| `X-RateLimit-*` | Limiter | Untuk backoff yang sopan |

**Soal waktu:** jangan pakai jam perangkat untuk menentukan "hari ini" dalam
konteks absensi. Server-lah yang menentukan tanggal kalender kantor dan
mengisi waktu check-in/check-out sendiri. Ambil `serverTime`, `serverDate`,
dan `timezone` dari `GET /attendance/me/today`
(`attendance.service.ts:442-450`).

---

## 11. Alur lengkap dengan `curl`

Variabel yang dipakai di seluruh contoh:

```bash
BASE="https://hris.contoh.co.id/api/v1"
```

### 11.1 Login

```bash
curl -i -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -H 'X-Client-Type: mobile' \
  -H "X-Correlation-Id: $(uuidgen)" \
  -d '{
        "email": "budi@contoh.co.id",
        "password": "RahasiaKuat1!"
      }'
```

Jawaban `200`:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "1111...", "email": "budi@contoh.co.id",
      "employeeId": "2222...", "companyId": "3333...",
      "companyScope": ["3333..."],
      "roles": ["EMPLOYEE"],
      "permissions": ["leave:create", "leave:read", "payroll:read"],
      "mustChangePassword": false
    },
    "tokens": {
      "accessToken": "eyJ...",
      "refreshToken": "eyJ...",
      "expiresIn": 900
    }
  }
}
```

Simpan untuk contoh berikutnya:

```bash
AT="eyJ..."     # data.tokens.accessToken
RT="eyJ..."     # data.tokens.refreshToken  → Keystore/Keychain
EMP="2222..."   # data.user.employeeId
CO="3333..."    # data.user.companyId
```

Kalau akun memakai MFA, jawabannya `401`:

```json
{ "success": false, "code": "MFA_REQUIRED", "message": "MFA code required" }
```

Kirim ulang login lengkap dengan `"totp": "123456"`.

### 11.2 Absensi — check-in dan check-out

**Langkah 1 — selalu tanya status hari ini lebih dulu.**

```bash
curl -s "$BASE/attendance/me/today" \
  -H "Authorization: Bearer $AT"
```

```json
{
  "success": true,
  "message": "Success",
  "data": {
    "serverTime": "2026-10-04T01:12:33.000Z",
    "serverDate": "2026-10-04",
    "timezone": "Asia/Jakarta",
    "record": null,
    "context": {
      "allowedMethods": ["MOBILE_GPS", "FACE_RECOGNITION"]
    },
    "canCheckIn": true,
    "canCheckOut": false
  }
}
```

Pakai `canCheckIn` / `canCheckOut` untuk menentukan tombol, dan
`context.allowedMethods` untuk menentukan metode yang boleh dikirim.
Mengirim metode di luar daftar itu dijawab `400 BAD_REQUEST` dengan pesan
*"Metode absensi ini tidak diizinkan untuk karyawan tersebut pada kebijakan
cabang yang berlaku"* (`attendance.service.ts:517-519`).

**Langkah 2 — check-in.**

```bash
curl -i -X POST "$BASE/attendance/me/check-in" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen | tr -d '-')" \
  -d '{
        "method": "MOBILE_GPS",
        "checkInLatitude": -6.200000,
        "checkInLongitude": 106.816666,
        "deviceGps": {
          "isMockLocation": false,
          "accuracyMeters": 12
        },
        "notes": "Masuk dari kantor pusat"
      }'
```

Sukses → `201` dengan envelope `Result.created`.

Perhatikan apa yang **tidak** Anda kirim: tidak ada `checkIn`, `date`,
`status`, `employeeId`, atau `companyId`. Semuanya diisi server
(`attendance.service.ts:453-464`) — `checkIn` dari jam server, `date` dari
tanggal kalender kantor, `status` dipaksa `PRESENT`, `source` dipaksa
`MOBILE_SELF_SERVICE`. Skema `selfCheckInSchema`
(`attendance.dto.ts:120-128`) memang hanya menerima `method`, `notes`,
koordinat check-in, `faceRecognition`, `liveness`, dan `deviceGps`.

Error yang mungkin:

- `400` *"Attendance record already exists for this date"* — sudah check-in.
- `400` metode tidak diizinkan (lihat di atas).
- `400` hari non-kerja tanpa izin kebijakan cabang.
- `409` konflik `Idempotency-Key` (payload berbeda, atau masih diproses).

**Langkah 3 — check-out.** Perhatikan method-nya `PATCH`, bukan `POST`.

```bash
curl -i -X PATCH "$BASE/attendance/me/check-out" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen | tr -d '-')" \
  -d '{
        "method": "MOBILE_GPS",
        "checkOutLatitude": -6.200000,
        "checkOutLongitude": 106.816666
      }'
```

Waktu checkout juga diisi server. Server mencari record absensi terbuka
terakhir dalam **36 jam** terakhir, supaya shift malam yang melewati batas
tanggal tetap bisa checkout (`attendance.service.ts:470-471`). Kalau tidak
ada record terbuka, jawabannya:

```json
{ "success": false, "code": "NOT_FOUND",
  "message": "No open attendance record found for checkout" }
```

Perbaikannya **bukan** retry — arahkan user mengajukan koreksi absensi:

```bash
curl -i -X POST "$BASE/attendance-corrections" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen | tr -d '-')" \
  -d '{
        "date": "2026-10-03T00:00:00.000Z",
        "requestedCheckOut": "2026-10-03T11:30:00.000Z",
        "reason": "Lupa clock-out karena rapat sampai malam"
      }'
```

Minimal satu dari `requestedCheckIn` / `requestedCheckOut` wajib ada;
kalau keduanya kosong, `422` dengan
`errors[0].field = "requestedCheckIn"` (`attendance-correction.dto.ts:9-12`).

Riwayat absensi sendiri:

```bash
curl -si "$BASE/attendance/me?month=2026-09&page=1&limit=20" \
  -H "Authorization: Bearer $AT"
```

Respons ini ber-`meta`, dan header `X-Office-Timezone` + `X-Server-Date` ikut
terkirim.

### 11.3 Ajukan cuti

**Langkah 1 — ambil daftar tipe cuti dan saldo.**

```bash
curl -s "$BASE/leave/types" -H "Authorization: Bearer $AT"
curl -s "$BASE/leave/balances/employee?employeeId=$EMP" -H "Authorization: Bearer $AT"
```

Keduanya butuh permission `leave:read` (`leave.routes.ts:59`, `137`).

**Langkah 2 — (kalau perlu) unggah lampiran.**

```bash
curl -s -X POST "$BASE/leave/attachments" \
  -H "Authorization: Bearer $AT" \
  -F 'attachment=@/path/surat-dokter.pdf'
```

→ `201` dengan `data.url`. Simpan URL itu. Isi file diperiksa magic-bytes,
jadi ekstensi palsu ditolak.

**Langkah 3 — ajukan.**

```bash
curl -i -X POST "$BASE/leave" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen | tr -d '-')" \
  -d "{
        \"employeeId\": \"$EMP\",
        \"companyId\": \"$CO\",
        \"leaveTypeId\": \"4444-...\",
        \"startDate\": \"2026-11-10T00:00:00.000Z\",
        \"endDate\": \"2026-11-12T00:00:00.000Z\",
        \"reason\": \"Acara keluarga di luar kota\"
      }"
```

Sukses → `201`.

**Tiga hal yang sering salah di sini:**

1. **`employeeId` dan `companyId` wajib dikirim**, walaupun server
   menimpanya. Penyebabnya urutan middleware: `validate(createLeaveRequestSchema)`
   berjalan sebelum controller, dan skema itu
   (`leave.dto.ts:14-22`) mewajibkan keduanya sebagai UUID. Tanpa mereka →
   `422`. Lalu `requireCompanyAccess()` menimpa `companyId` dengan company
   sesi (`CompanyScope.ts:143-150`) dan controller menimpa `employeeId`
   dengan `req.user.employeeId` (`leave.controller.ts:49`). Kirim nilai asli
   dari `GET /auth/me` dan semuanya cocok.
2. **`startDate`/`endDate` harus ISO 8601 lengkap**, bukan `YYYY-MM-DD` —
   skemanya `z.string().datetime()`. `"2026-11-10"` dijawab `422`.
3. **`companyId` di luar `companyScope` → `403`**, bukan `422`.

**Langkah 4 — pantau dan batalkan.**

```bash
# daftar pengajuan dalam data scope Anda (tanpa pagination)
curl -s "$BASE/leave?status=PENDING" -H "Authorization: Bearer $AT"

# batalkan punya sendiri — tidak butuh permission approve
curl -i -X PATCH "$BASE/leave/<leaveRequestId>/cancel" \
  -H "Authorization: Bearer $AT"
```

Jangan kirim `companyId` pada `GET /leave` — nilai Anda akan ditimpa
(`CompanyScope.ts:140-142`), dan nilai di luar scope dijawab `403`.

Untuk penyetuju (butuh `leave:approve`):

```bash
curl -i -X PATCH "$BASE/leave/<id>/approve" -H "Authorization: Bearer $AT"
curl -i -X PATCH "$BASE/leave/<id>/reject"  -H "Authorization: Bearer $AT"
```

### 11.4 Lihat slip gaji

**Langkah 1 — daftar periode (aman, tanpa nominal, tanpa PIN).**

```bash
curl -s "$BASE/payroll/payslips" -H "Authorization: Bearer $AT"
```

```json
{
  "success": true,
  "message": "Success",
  "data": [
    {
      "id": "ps-EMP001-2609",
      "status": "FINAL",
      "createdAt": "2026-09-25T02:00:00.000Z",
      "locked": true,
      "payrollRun": {
        "id": "...", "name": "Payroll September 2026",
        "runNumber": 1, "status": "DISBURSED",
        "period": {
          "id": "...", "name": "September 2026", "code": "2026-09",
          "frequency": "MONTHLY",
          "startDate": "2026-09-01T00:00:00.000Z",
          "endDate": "2026-09-30T00:00:00.000Z",
          "payDate": "2026-09-25T00:00:00.000Z"
        }
      }
    }
  ]
}
```

Tidak ada `netPay` di sini — itu memang desainnya. Perhatikan juga `id`
berbentuk `ps-EMP001-2609`: **id payslip belum tentu UUID**
(`payroll.validation.ts:24-29`), jadi jangan validasi sebagai UUID.

**Langkah 2 — cek status PIN.**

```bash
curl -s "$BASE/payroll/payslips/pin/status" -H "Authorization: Bearer $AT"
```

```json
{ "success": true, "message": "Success", "data": { "pinSet": false } }
```

`pinSet: false` → tampilkan layar atur PIN. Kalau ada `lockedUntil`, PIN
sedang terkunci sampai waktu itu (field ini **tidak muncul** kalau tidak
terkunci — jangan asumsikan `null`).

**Langkah 3 — atur PIN (sekali saja).**

```bash
curl -i -X PUT "$BASE/payroll/payslips/pin" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{ "currentPassword": "RahasiaKuat1!", "pin": "135791" }'
```

Sukses → `200`, `data: null`, pesan *"PIN slip gaji berhasil disimpan"*.
Password salah → `403 PAYSLIP_PIN_REAUTH_FAILED` *"Kata sandi salah"* —
**bukan** sesi mati, jangan logout.

**Langkah 4 — unlock dengan PIN.**

```bash
curl -s -X POST "$BASE/payroll/payslips/my/unlock" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{ "pin": "135791" }'
```

```json
{
  "success": true,
  "message": "Slip gaji terbuka",
  "data": {
    "unlockToken": "eyJ1c2VySWQiOi...fQ.Zm9vYmFyc2lnbmF0dXJl",
    "expiresAt": "2026-10-04T08:00:00.000Z"
  }
}
```

```bash
UNLOCK="eyJ1c2VySWQiOi...fQ.Zm9vYmFyc2lnbmF0dXJl"
```

Simpan **hanya di memori**. Masa hidup 15 menit.

Error yang mungkin:

- `409 PAYSLIP_PIN_NOT_SET` → kembali ke langkah 3.
- `403 PAYSLIP_PIN_INVALID` *"PIN salah"* → biarkan coba lagi.
- `429 PAYSLIP_PIN_LOCKED` → 5 kali salah, kunci 15 menit; `message`
  menyebut sisa menit.

**Langkah 5 — detail dengan nominal.**

```bash
curl -s "$BASE/payroll/payslips/my/ps-EMP001-2609" \
  -H "Authorization: Bearer $AT" \
  -H "X-Payslip-Unlock: $UNLOCK"
```

`data` membawa `baseSalary`, `totalEarnings`, `totalDeductions`, `netPay`,
`components[]` (dengan `salaryComponent { id, code, name, type }`), dan
`breakdown`. Hanya slip milik sendiri dari run `APPROVED`/`DISBURSED`
(`payslip-pin.service.ts:166-189`).

Kalau header hilang atau sudah kedaluwarsa:

```json
{ "success": false, "code": "PAYSLIP_UNLOCK_INVALID",
  "message": "Sesi buka slip gaji tidak valid atau sudah kedaluwarsa. Masukkan PIN kembali." }
```

→ minta PIN lagi (langkah 4). Status `403`, **bukan** 401 — jangan logout.

**Langkah 6 — unduh PDF.**

```bash
curl -s "$BASE/payroll/payslips/my/ps-EMP001-2609/pdf" \
  -H "Authorization: Bearer $AT" \
  -H "X-Payslip-Unlock: $UNLOCK" \
  -o slip-september.pdf
```

Berkas PDF langsung, bukan JSON. Batas 5 MB; di atasnya
`413 PAYSLIP_PDF_TOO_LARGE`.

### 11.5 Refresh ketika token ditolak

```bash
curl -i -X POST "$BASE/auth/refresh" \
  -H 'Content-Type: application/json' \
  -H 'X-Client-Type: mobile' \
  -d "{ \"refreshToken\": \"$RT\" }"
```

`200` → ambil `data.tokens.accessToken` **dan** `data.tokens.refreshToken`
yang baru (keduanya dirotasi), timpa yang lama, lalu ulangi request yang
tadi gagal. Timpa juga cache `permissions`/`roles` Anda dari
`data.user` — kalau penolakan tadi disebabkan perubahan otoritas, isinya
sudah berbeda.

`401` → logout.

### 11.6 Logout

```bash
curl -i -X DELETE "$BASE/notifications/device-tokens" \
  -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{ "installationId": "a1b2c3d4e5f6a7b8" }'

curl -i -X POST "$BASE/auth/logout" \
  -H 'Content-Type: application/json' \
  -d "{ \"refreshToken\": \"$RT\" }"
```

Lalu hapus token dari Keystore/Keychain apa pun hasil kedua panggilan itu.

---

## 12. Catatan jebakan dan hal yang tidak bisa dipastikan

### Jebakan yang terbaca jelas dari source

1. **Interceptor 401 yang terlalu rakus akan melogout user tanpa sebab.**
   `PAYROLL_UNLOCK_REQUIRED` dan `PAYROLL_REAUTH_FAILED` berstatus 401 tapi
   bukan masalah sesi. Periksa `code` sebelum memicu refresh/logout; hanya
   `TOKEN_EXPIRED` dan `AUTHENTICATION_FAILED` yang masuk alur §3.

2. **`companyId` hampir selalu tidak boleh Anda kirim di query.**
   `requireCompanyAccess()` menimpa `req.query.companyId` dengan company
   efektif sesi pada **setiap** request (`CompanyScope.ts:140-142`), dan
   nilai yang Anda kirim dicek lebih dulu — di luar scope → `403`. Karena
   middleware ini berjalan sebelum validasi, skema yang "mewajibkan"
   `companyId` (mis. `overtimeQuerySchema`, `attendance.dto.ts:155-161`)
   tetap lolos tanpa Anda mengirimnya. Satu pengecualian: `POST /leave`
   mewajibkannya **di body**, karena `CompanyScope` hanya menimpa
   `body.companyId` kalau key-nya sudah ada.

3. **`unreadOnly` adalah string, bukan boolean.** `z.enum(['true','false'])`
   pada `notification.dto.ts:18` dan `announcement.dto.ts:4`. Kirim
   `"true"`/`"false"`.

4. **`DELETE /notifications/device-tokens` butuh body JSON.** Beberapa HTTP
   client mobile tidak mengirim body pada DELETE secara default.

5. **Id payslip bukan UUID.** Charset `[A-Za-z0-9_-]`, panjang 1–36
   (`payroll.validation.ts:27-29`). Sebaliknya, `id` pada
   `/announcements/{id}` dan `/ewa/{id}/*` **divalidasi UUID** dan nilai lain
   dijawab `422`.

6. **`Decimal` Prisma.** Field nominal (`baseSalary`, `netPay`, dsb) berasal
   dari kolom Decimal. Diserialisasi sebagai string atau number tergantung
   driver. Parse ke tipe desimal, **jangan** ke `double`/`Float`.

7. **`employeeId` bisa kosong.** Akun admin tanpa data karyawan tidak
   memilikinya, dan seluruh route self-service akan menjawab
   `400 BAD_REQUEST` *"Akun ini tidak tertaut ke data karyawan..."*. Periksa
   `data.user.employeeId` setelah login sebelum menampilkan tab absensi/slip
   gaji.

8. **`GET /meta/endpoints` tidak bisa dipakai akun karyawan.** Butuh
   `rbac:read` (`app.ts:250`); komentar `app.ts:245-246` menyatakan peta
   permukaan API sengaja tidak publik. Minta tim backend mengekspornya untuk
   Anda, atau pakai `openapi.yaml` di folder ini.

9. **Satu refresh pada satu waktu.** Refresh merotasi refresh token; dua
   panggilan paralel akan membuat salah satunya gagal. Pakai single-flight.

### Di mana dokumen prosa lama bertentangan dengan source

Repo backend punya beberapa dokumen mobile lama. Di mana isinya berbeda dari
source, **source yang benar**. Yang saya temukan:

1. **`docs/mobile-api.md` §4.12 belum memuat jalur PIN sama sekali.** Dokumen
   itu menyebut slip gaji self-service dibuka lewat
   `POST /payroll/payslips/unlock` (password + TOTP) dan header
   `X-Payroll-Unlock-Token` dengan grant 5 menit, lalu dibaca di
   `GET /payroll/payslips/:id`. Di source sekarang ada lima route yang tidak
   disebut dokumen itu — `PUT /payroll/payslips/pin`,
   `GET /payroll/payslips/pin/status`, `POST /payroll/payslips/my/unlock`,
   `GET /payroll/payslips/my/:id`, `GET /payroll/payslips/my/:id/pdf`
   (`payroll.routes.ts:336-367`) — dengan header berbeda
   (`X-Payslip-Unlock`), TTL berbeda (15 menit), tanpa `authorize()`, dan
   dipatok oleh `mobile-routes.contract.test.ts`. **Untuk mobile, pakai jalur
   PIN**; §9 dokumen ini menjelaskannya.

2. **`docs/mobile-api.md` §4.12 menulis `GET /payroll/payslips` sebagai
   "periode payslip milik sendiri" dengan auth `payroll:read`** — itu benar,
   tetapi tidak menyebut bahwa setiap baris diberi `locked: true`
   (`payroll.controller.ts:384`) dan bahwa daftarnya **dibatasi 20 baris
   terbaru** oleh default `limit = 20` di `payroll.repository.ts:470`, tanpa
   parameter klien untuk menaikkannya.

3. **`docs/mobile-permission-matrix.md` memakai nama permission yang tidak
   akan Anda lihat di `GET /auth/me`.** Matriks itu menulis `att:read`,
   `da:create/read/update`, `travel:create/read`, `org:*` — itu kolom `code`
   di tabel permission (`01-permissions.seed.ts:143-149` untuk daily
   activity). Tetapi token dibangun dari
   `` `${permission.resource}:${permission.action}` ``
   (`auth.service.ts:60-68`), jadi `data.permissions` sebenarnya berisi
   `attendance:read`, `daily-activity:create`, `travel-expense:create`,
   `organization:read`. Guard `authorize()` juga meminta bentuk
   `resource:action` (`daily-activity.routes.ts:33`, `41`, `46`). Keduanya
   konsisten di server; yang menyesatkan hanyalah matriksnya. **Jangan
   mencocokkan string dari matriks itu dengan `data.permissions`** — pakai
   nama permission yang tertulis di `description` setiap operasi di
   `openapi.yaml`, yang dibaca dari guard-nya.

4. **`docs/mobile-permission-matrix.md` menyebut "Daily activity self" dan
   "EWA self" sebagai kapabilitas yang butuh permission**, padahal route
   `/my`-nya tidak memakai `authorize()` sama sekali
   (`ewa.routes.ts:31-40`, `daily-activity.routes.ts:27-30`), dengan komentar
   eksplisit bahwa permission `ewa:read` / `daily-activity:read` adalah untuk
   **membaca data orang lain**. Jadi membaca data sendiri tidak memerlukan
   permission apa pun. Sebaliknya, `POST /ewa` dan `POST /daily-activities`
   **memang** memakai `authorize()` (`ewa:create`, `daily-activity:create`),
   jadi mengirim data sendiri **bisa** 403 untuk role yang tidak diberi
   permission itu — asimetri yang tidak terlihat dari matriks tersebut.

5. **`docs/api-contract.md` menyatakan controller "never write an error body
   by hand"** dan bahwa setiap error membawa `code`. Itu benar untuk error
   yang dilempar sebagai `AppError`, tetapi tidak untuk `Result.error(...)`
   tanpa argumen kedua, yang memang dipakai di beberapa tempat
   (`payroll.controller.ts:381`, `workflow-engine.controller.ts:105`, `119`,
   `159`, `173`, `189`) dan menghasilkan body **tanpa `code`**. Parser Anda
   harus menoleransi `code` yang tidak ada. Lihat §4.

6. **`docs/api-contract.md` menyebut `docs/api-reference.md` sebagai daftar
   endpoint yang dibuat otomatis dari `GET /api/v1/meta/openapi.json`**, dan
   menandai tiga dokumen mobile lama (`mobile-api.md`,
   `mobile-api-documentation.md`, `mobile-api-screen-mapping.md`) sebagai
   "terakhir disentuh 8–21 September" — jadi dokumen-dokumen itu sendiri
   sudah ditandai berpotensi basi oleh repo. Konsisten dengan temuan nomor 1
   dan 2 di atas.

### Hal yang tidak dapat saya pastikan dari source

Ini bukan tebakan yang disamarkan — saya mencatatnya terbuka supaya Anda
mengonfirmasi ke tim backend:

1. **Format `shiftDate` pada `POST /work-calendars/shift-swaps`.** DTO-nya
   `z.string()` tanpa pola (`work-calendar.dto.ts:98`), dan saya tidak
   melacak ke dalam service-nya. Bisa `YYYY-MM-DD` atau ISO 8601 lengkap.

2. **Satuan `duration` pada `POST /permission-requests`.** DTO hanya
   menyebut `z.number().positive()` (`permission-request.dto.ts:7`) tanpa
   menyatakan jam atau hari.

3. **Format `startDate`/`endDate` pada `POST /permission-requests`.**
   `z.string()` tanpa pola — berbeda dari cuti yang memakai
   `z.string().datetime()`.

4. **Bentuk `data` untuk hampir semua endpoint.** Backend tidak punya skema
   response, jadi field di dalam `data` (kecuali yang ditandai di
   `openapi.yaml`) tidak dapat dijamin. `docs/mobile-api-fixtures.json` di
   repo berisi contoh payload; pakai itu untuk membentuk model Anda, lalu
   pastikan parser Anda toleran terhadap field tak dikenal dan field yang
   hilang.

5. **Nilai `config.upload.maxFileSize` dan `config.upload.allowedMimes`**
   untuk lampiran cuti — berasal dari env, jadi berbeda per environment.
   Minta nilainya ke DevOps.

6. **Field di dalam `context`** pada `GET /attendance/me/today` selain
   `allowedMethods` dan `policySnapshot`. Objek itu adalah hasil
   `attendanceContextService.resolve(...)` yang disebar; saya memverifikasi
   dua field yang ditambahkan (`attendance.service.ts:496-500`) tetapi tidak
   menelusuri seluruh isi `resolve()`.

7. **Skema `requestEncashmentSchema` dan `encashmentQuerySchema`**
   (`leave-encashment.dto.ts`) — saya mencatat keberadaan route-nya tetapi
   tidak memverifikasi field-nya, karena pencairan cuti bukan bagian dari
   empat alur utama mobile.

8. **Permission mana yang sebenarnya dipegang role `EMPLOYEE`** di database
   Anda. `docs/mobile-permission-matrix.md` menyebut `leave:create` +
   `leave:read` dan `payroll:read`. Saya memverifikasi bahwa
   `01-permissions.seed.ts` memang mendefinisikan permission-permission itu,
   tetapi **tidak** memverifikasi `03-role-permissions.seed.ts` (pemetaan
   role → permission), dan seed juga bisa berbeda dari data produksi.
   Verifikasi di lapangan dengan `GET /auth/me` memakai akun karyawan asli,
   lalu cocokkan dengan nama permission di `openapi.yaml`.

### Cara memverifikasi dokumen ini tetap akurat

Minta seseorang dengan permission `rbac:read` menjalankan:

```bash
curl -H "Authorization: Bearer $ADMIN_AT" \
  "$BASE/meta/openapi.json" > server-openapi.json
```

Dokumen itu dibuat dari router Express saat request, jadi tidak bisa
melenceng dari server (`app.ts:263-275`,
`backend/src/shared/openapi/generate.ts`). Bandingkan daftar path-nya dengan
`openapi.yaml` di folder ini setiap kali ada rilis backend.
