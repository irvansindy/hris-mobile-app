# Checklist Migrasi API untuk Tim Mobile

Dokumen ini merangkum perubahan API backend HRIS yang **harus ditindaklanjuti oleh
klien mobile**. Ditulis untuk dibaca sekali, lalu dikerjakan baris per baris dari
bagian [Checklist](#checklist) di bawah.

Setiap bagian menyebut **bukti** dalam dua bentuk: `path/file.ts:baris` pada kode
sumber yang berlaku di `main` hari ini, dan SHA commit bila perubahannya terlihat
di riwayat Git. Klaim yang tidak dapat ditemukan di kode dipindahkan ke bagian
[Belum terverifikasi](#belum-terverifikasi) — tidak dibiarkan berdiri sebagai
pernyataan.

## Jendela riwayat yang diperiksa

- `main` pada `f7a496e` (*test(security): fail the build when a mutating route has
  no guard (#38)*) sebagai HEAD, mundur sampai `51d37eb` (*Merge pull request #20*).
- **Catatan waktu:** verifikasi dokumen ini selesai saat `main` masih di
  `f7a496e`. Beberapa menit setelahnya, lima PR di-merge dan ter-deploy ke
  production (`5d9a99f` sekarang HEAD). Tiga di antaranya kelihatan ke klien
  dan **ditambahkan sebagai §20 di bawah** — jadi bagian "belum ter-merge" di
  draf tidak lagi berlaku, bukan karena analisisnya salah, tetapi karena
  keadaannya berubah.
- Verifikasi dilakukan dengan membaca `backend/src/**` dan `git show` secara
  langsung. Dokumen `docs/*.md` hanya dipakai sebagai petunjuk arah, bukan bukti.

## Ringkasan

Klasifikasi di kolom tengah adalah hasil **pembacaan kode**, bukan pembacaan
dokumen. Kolom "vs draf" mencatat ke mana penilaian berubah dibanding draf
sebelumnya. Dari 19 bagian, **9 bagian berklasifikasi BREAKING** (11 baris di
tabel ini, karena §1 dan §8 masing-masing memuat dua perubahan).

Definisi yang dipakai: **BREAKING** = field diganti nama / dihapus, envelope
berubah, header wajib baru, validasi lebih ketat, atau 4xx baru pada request yang
dulu diterima. **Additive** = field opsional baru atau endpoint baru.
**Perilaku** = bentuk sama, nilai atau waktunya berbeda.

| Endpoint / Area | Jenis | vs draf | Yang harus dilakukan klien mobile |
| --- | --- | --- | --- |
| Envelope **sukses**: EWA, daily-activity, employee, company-settings (§1) | **BREAKING** | sama | Satu parser `{ success, message, data, meta? }`. `message` selalu ada tapi nilainya **bukan** selalu `"Success"`. |
| Envelope **error**: `code` **masih belum** ada di 35 call site (§1) | **BREAKING** | **dibalik** — draf menyebutnya "additive/sudah selesai" | Decode `code` sebagai **opsional**; sediakan fallback ke HTTP status. Approval Center, work-calendar, loan, trip/claim, satu jalur payroll masih mengirim error tanpa `code`. |
| company-settings: field `code: "OK"` pada respons sukses (§2) | **BREAKING** | sama (payload "sebelum" dikoreksi) | Hapus pembacaan `code` pada respons sukses; `bulkUpsert`/`delete` sekarang mengirim `data: null`. |
| `sessionVersion` naik setiap perubahan otoritas (§3) | **perilaku** | sama, **pertanyaan terjawab** | `401` mendadak membawa **`AUTHENTICATION_FAILED`**, bukan `TOKEN_EXPIRED`. Tetap refresh dulu; logout **hanya** bila refresh gagal. |
| Header `X-Client-Type: mobile` (§4) | **konfigurasi wajib — bukan perubahan** | **diturunkan** dari "BREAKING jika belum dikirim" | Kirim nilai persis `mobile`; ambil token dari `data.tokens`. Matikan cookie jar (pembebasan CSRF berasal dari tidak adanya cookie, bukan dari header ini). |
| `companyId`/`employeeId` dari body/query (§5) | **BREAKING** | **dipersempit** | Hapus dari payload self-service. Tiga endpoint menjawab `403`; sisanya mengabaikannya tanpa suara. Beberapa endpoint admin **masih menuntut** `?companyId=`. |
| Field sensitif pegawai di-mask last-4 (§6) | **BREAKING** | sama, **nama field dikoreksi** | Nama field: `idNumber`, `taxId`, `bankAccount`, `bankAccountHolder`, `bpjsKetenagakerjaan`, `bpjsKesehatan`. Employee **tidak melihat nilai dirinya sendiri** secara penuh. |
| Payslip: daftar tanpa nominal + unlock (§7) | **BREAKING** | **dinaikkan cakupannya** | Jalur self-service memakai **PIN** dan header **`X-Payslip-Unlock`** (15 menit) lewat `/payslips/my/*`; `X-Payroll-Unlock-Token` (5 menit) adalah jalur admin. Draf mendokumentasikan jalur yang salah. |
| `POST /attendance/me/check-in`: payload biometrik (§8) | **BREAKING** | sama, **mekanisme dikoreksi** | Kirim hanya `faceRecognition.selfieImage`; field turunan → **`400 BAD_REQUEST`** dari service (bukan `422` dari schema). |
| Check-in/check-out: fake GPS & selfie policy (§8) | **BREAKING** | sama | Kirim `deviceGps` pada **kedua** jalur; tangani `400` fake-GPS/selfie dan `429` rate-limit face. Jangan kirim selfie pada check-out. |
| Absensi live-only, tanpa antrean offline (§9) | **perilaku** | **diturunkan** dari "BREAKING (perilaku)" | Hapus antrean offline. Field waktu dari klien **dibuang diam-diam**, tidak ada 4xx baru. Batas check-out 36 jam. |
| `Idempotency-Key` (§10) | **BREAKING** | sama | Satu key per percobaan kirim satu form; key sama + payload berbeda → `409`; format salah → `422`. |
| `/uploads/*`, `filePath`, signed URL (§11) | **BREAKING** | sama, **satu arah dibalik** | `/uploads/*` → `403`. Referensikan **`data.url`**, bukan `data.filePath`, sebagai `receiptFilePath`. |
| Reject wajib alasan + self-approval ditolak (§12) | **BREAKING** | sama, **kode status dikoreksi** | Reject tanpa alasan → **`400 BAD_REQUEST`** (bukan `422`). Self-approval → `403`, termasuk `SUPER_ADMIN`. |
| Approval Center lewat `workflow-engine` (§12) | **additive** | sama | Arahkan aksi ke `POST /workflow-engine/instances/:id/actions`; jangan campur dengan route domain. |
| Route yang tertangkap `/:id` (§13) | **additive** | **separuh ditarik** | Hapus workaround lembur. `GET /leave/balances/employee` **tidak pernah** tak terjangkau — jangan hapus workaround-nya tanpa diuji. |
| Endpoint baru: attendance self, koreksi, next-shift, shift-swap, announcement, reporting line, aset, device token, password recovery (§14) | **additive** | sama, **detail dikoreksi** | Pakai sesuai §14. Perhatikan `:requestId`, default `limit` yang berbeda, dan horizon `next-shift` yang tidak selalu 92 hari. |
| Riwayat cuti memuat cuti bersama (§15) | **perilaku** | sama, **satu klaim dilemahkan** | Terima baris `APPROVED` yang tidak diajukan user. `collectiveLeaveId` terkirim **insidental** dan tidak dipaku kontrak. |
| `employeeSalaries: []` pada profil (§16) | **perilaku** | sama, **nama field dikoreksi** | Array kosong = tidak berhak melihat, bukan "Rp 0". Endpoint gaji mandiri justru `404`/`403`, bukan `[]`. |
| SSO OIDC per company (§17) | **additive — web-only** | sama, **satu koreksi** | Jangan bangun tombol SSO. `/sso/start` yang gagal mengembalikan **JSON `404`**, bukan redirect. |
| `/health`, rate limit, MFA, logout, rotasi refresh (§18) | **perilaku** | sama — **semua angka benar** | `503` = server belum siap. `401 MFA_REQUIRED` → minta `totp`. `429` login bisa muncul walau password benar. |
| Hari libur kalender kerja (§19) | **perilaku** | **dipromosikan** dari "belum terverifikasi" | Hari kerja **berkurang**, hari libur **berhenti menghilang**, nilai `"JL"` mulai muncul. Tidak ada backfill — HR harus generate ulang. |
| Capability yang "sengaja tidak ada" | **koreksi dokumentasi** | **dibalik** | Training, Performance, Onboarding, MFA, daftar sesi, delete notifikasi **semuanya ada**. Hanya chat/messaging yang benar-benar belum ada. |

## 1. Satu envelope sukses — tapi envelope error **belum** seragam

**Status: BREAKING (envelope sukses), dengan catatan penting pada sisi error.**

**Yang berubah.** Empat controller — **EWA**, **daily-activity**, **employee**, dan
**company-settings** — dulu merakit envelope respons sendiri. Sejak
`d108458 refactor(api): one success envelope and one error-code catalogue`
(28 September 2026) semuanya melalui helper `Result` yang sama.

Isi commit message `d108458` menyebut persisnya: EWA, daily-activity dan employee
mengirim `{ success, data }` **tanpa `message`**, dan company-settings menambah
`code: "OK"`. Diff-nya menyentuh:

```
backend/src/modules/company-settings/company-settings.controller.ts  | 34 ++------
backend/src/modules/daily-activity/daily-activity.controller.ts      | 17 +--
backend/src/modules/employee/employee.controller.ts                  | 32 ++----
backend/src/modules/ewa/ewa.controller.ts                            | 25 ++---
backend/src/shared/core/api-contract.test.ts                         | 118 +++++
```

**Bentuk sukses yang berlaku sekarang** — `backend/src/shared/core/Result.ts:10-15`:

```ts
export interface ApiResponse<T = unknown> {
  success: boolean;
  message: string;
  data?: T;
  meta?: PaginationMeta;
}
```

- `message` **selalu ada dan tidak pernah kosong** (`Result.ts:18`, default
  `'Success'`; dipaku di `api-contract.test.ts:50-55`). **Tapi nilainya bukan
  selalu `"Success"`** — banyak endpoint mengirim teks sendiri, misalnya
  `'Company settings loaded'`, `'Setting saved'`
  (`company-settings.controller.ts`, hasil `d108458`). Teks ini **tidak boleh**
  dijadikan dasar percabangan.
- `data` ada pada setiap helper sukses; bernilai `null` untuk `Result.deleted()`
  dan `Result.noContent()` (`Result.ts:65-87`).
- `meta` **hanya** muncul dari `Result.paginated()` (`Result.ts:26-47`). Bentuknya:

```json
{
  "success": true,
  "message": "Success",
  "data": [],
  "meta": { "page": 2, "limit": 10, "total": 25, "totalPages": 3, "hasNextPage": true, "hasPreviousPage": true }
}
```

`totalPages = Math.ceil(total / limit)` (`Result.ts:33`), `hasNextPage = page <
totalPages`, `hasPreviousPage = page > 1` (`Result.ts:43-44`). Untuk hasil kosong
nilainya `totalPages: 0, hasNextPage: false, hasPreviousPage: false` — dipaku di
`api-contract.test.ts:67`. **Pakai `hasNextPage`/`hasPreviousPage`**, jangan
aritmetika sendiri.

**Bentuk gagal dari global error handler** —
`backend/src/shared/middleware/ErrorHandler.ts:45-82`:

```json
{ "success": false, "code": "NOT_FOUND", "message": "Resource not found" }
```

`errors` hanya pada kegagalan validasi (`ErrorHandler.ts:28-41` untuk `ZodError`,
`AppError.ts:29` untuk `ValidationError`):

```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "errors": [{ "field": "email", "message": "required" }]
}
```

Ada satu field tambahan yang **tidak disebut draf sebelumnya**: bila request
membawa `X-Correlation-Id` atau `X-Request-Id`, respons error menyertakan
`correlationId` (`ErrorHandler.ts:25`, `:39`, `:56-58`). Kirim header itu dan
catat nilainya — itu yang memudahkan backend menelusuri keluhan user.

**Katalog kode error** — sumbernya kelas exception di
`backend/src/shared/exceptions/AppError.ts`, dipaku di
`api-contract.test.ts:16-27`:

| Status | `code` | Kelas | Arti bagi klien |
|---|---|---|---|
| 400 | `BAD_REQUEST` | `AppError.ts:34-38` | Input salah bentuk/kontradiktif; perbaiki lalu ulangi. |
| 401 | `AUTHENTICATION_FAILED` | `AppError.ts:40-44` | Lihat §3 — **jangan langsung logout**, coba refresh dulu. |
| 401 | `TOKEN_EXPIRED` | `AppError.ts:46-50` | Access token kedaluwarsa; refresh lalu ulangi. |
| 403 | `FORBIDDEN` | `AppError.ts:52-56` | Terautentikasi tapi tidak berhak. **Jangan** retry. |
| 404 | `NOT_FOUND` | `AppError.ts:58-62` | Tidak ada, **atau** di luar tenant/scope. |
| 409 | `CONFLICT` | `AppError.ts:64-68` | Tabrakan state. |
| 422 | `VALIDATION_ERROR` | `AppError.ts:76-80` | Validasi schema gagal; `errors` menyebut field. |
| 429 | `TOO_MANY_REQUESTS` | `AppError.ts:70-74` | Rate limit atau akun terkunci; backoff. |
| 500 | `DATABASE_ERROR` | `AppError.ts:82-86` | Kesalahan server. |
| 503 | `SERVICE_UNAVAILABLE` | `AppError.ts:88-92` | Dependency mati; coba lagi nanti. |

Tiga kode lagi datang dari app shell / error handler, **bukan** dari kelas
exception, dan tidak ada di tabel draf sebelumnya:

| Status | `code` | Sumber |
|---|---|---|
| 400 | `UPLOAD_ERROR` | `ErrorHandler.ts:95-108` — `multer.MulterError`, termasuk `LIMIT_FILE_SIZE` |
| 409 | `CONFLICT` | `ErrorHandler.ts:85-93` — Prisma `P2002`, dengan `message` **berbahasa Indonesia** hasil `uniqueViolationMessage()` (`ErrorHandler.ts:10-17`), mis. `"NIK sudah terdaftar di perusahaan ini"` |
| 500 | `INTERNAL_ERROR` | `ErrorHandler.ts:118-125` — fallback untuk throw tak terduga |

### Koreksi besar terhadap draf: `code` **belum** ada di semua respons error

Draf sebelumnya menyatakan `code` dapat dijadikan "satu-satunya basis
percabangan error". **Itu tidak benar untuk kode yang berjalan sekarang.**

`Result.error(message, code?)` membuat `code` **opsional**
(`backend/src/shared/core/Result.ts:49-55`), dan **35 call site** di
`backend/src/modules/**` memanggilnya **tanpa** argumen `code` — sehingga
body-nya `{ success: false, message }` saja, **tanpa `code`**. Beberapa di
antaranya persis di jalur yang dipakai mobile:

| File:baris | Status | Body |
|---|---|---|
| `backend/src/modules/workflow-engine/workflow-engine.controller.ts:105,159,173` | 400 | `{ success:false, message:"companyId is required" }` |
| `backend/src/modules/workflow-engine/workflow-engine.controller.ts:119,189` | 404 | `"Workflow template not found"` / `"Workflow instance not found"` |
| `backend/src/modules/workflow-engine/workflow-engine.controller.ts:200,213` | 401 | `"Authentication required"` |
| `backend/src/modules/payroll/payroll.controller.ts:380` | 400 | `"Akun ini tidak tertaut ke data karyawan"` |
| `backend/src/modules/employee-loan/employee-loan.controller.ts:11,21,40` | 400 / 404 | `"companyId is required"` / `"Loan not found"` |
| `backend/src/modules/work-calendar/work-calendar.controller.ts:36,51,85,126,136,149,210` | 404 | `"Calendar not found"`, `"No calendar found for employee"`, … |
| `backend/src/modules/travel-expense/travel-expense.controller.ts:51,158,177,311` | 400 | `"companyId is required"` |
| `backend/src/modules/permission-request/permission-request.controller.ts:29,47,99,107,121` | 400 / 404 | `"Request not found or already processed"`, … |
| `backend/src/modules/document-management/document-management.controller.ts:31,45,59,…` | 401 | `"Authentication required"` |

Test penjaga di `api-contract.test.ts:105-112` hanya mencari literal
`res.json({ success: …` lewat regex — `Result.error('…')` **lolos** dari penjaga
itu, jadi celah ini tidak akan tertangkap CI. Konsekuensi untuk klien:

> **`code` boleh dipercaya kalau ada, tapi harus di-decode sebagai opsional, dan
> klien wajib punya fallback ke HTTP status ketika `code` tidak ada.** Model/DTO
> yang menandai `code` sebagai `required` pada respons error akan gagal parse di
> Approval Center, work-calendar, loan, trip/claim, dan satu jalur payroll
> self-service.

**Respons biner.** Ekspor CSV dan download file privat **tidak memakai envelope** —
body-nya file itu sendiri. Contoh: `employee.controller.ts:250-251` menyetel
`Content-Disposition: attachment; filename="employees.csv"` lalu `res.send(csv)`.
Kegagalan pada route tersebut tetap melalui `errorHandler` sehingga memakai
envelope error.

## 2. `code: "OK"` di company-settings dihapus — BREAKING

**Status: BREAKING (field hilang dari respons sukses).** Terkonfirmasi dengan
diff, bukan hanya dokumen.

**Bukti diff** (`git show d108458 -- backend/src/modules/company-settings/company-settings.controller.ts`):

```diff
-    res.json({
-      success: true,
-      code: 'OK',
-      message: 'Company settings loaded',
-      data: settings,
-    });
+    res.json(Result.success(settings, 'Company settings loaded'));
```

Lima handler berubah dengan pola yang sama: `findAll`, `findByKey`,
`upsertByKey`, `bulkUpsert`, `deleteByKey`.

**Koreksi terhadap draf.** Draf menulis bentuk "sebelum" sebagai
`{ "success": true, "code": "OK", "data": {} }` — **tanpa `message`**. Itu salah:
envelope lama company-settings **sudah punya `message`**. Yang hilang hanya
`code`. Bentuk yang benar:

```jsonc
// sebelum (d108458^)
{ "success": true, "code": "OK", "message": "Company settings loaded", "data": { } }

// sesudah
{ "success": true, "message": "Company settings loaded", "data": { } }
```

Ada perubahan kedua yang draf lewatkan sama sekali: `bulkUpsert` dan
`deleteByKey` dulu **tidak mengirim `data` sama sekali**; sekarang keduanya
mengirim `data: null` (`Result.noContent()` / `Result.deleted()`,
`Result.ts:65-87`). Untuk parser strict ini **penambahan** field, biasanya aman,
tapi parser yang menolak field tak dikenal akan terganggu.

**Path endpoint-nya** — draf tidak dapat menyebutnya; sekarang bisa:
`backend/src/modules/company-settings/company-settings.controller.ts` melayani
`findAll`, `findByKey(:key)`, `upsertByKey`, `bulkUpsert`, `deleteByKey`.
Perhatikan bahwa handler-handler ini **menerima `?companyId=`** sebagai pemilih
tenant eksplisit (`explicitCompanyId` dari `req.query.companyId`) — lihat §5.

Penjaga regresi: `api-contract.test.ts:114-117` gagal bila ada controller
memunculkan `code: 'OK'` lagi.

Konsekuensi konkret: model/DTO mobile yang menandai `code` sebagai field
**wajib** pada respons **sukses** company-settings akan gagal parse (Swift
`Codable` non-optional, Dart `json_serializable` dengan `required`). Ini error
runtime, bukan sekadar nilai kosong.

## 3. Perubahan otoritas mematikan access token — dan 401-nya bukan `TOKEN_EXPIRED`

**Status: perilaku (bentuk payload tidak berubah), tapi memunculkan 401 pada
request yang sebelumnya berhasil.**

**Commit:** `ff60ea2 fix(security): revoking a role takes effect on the next
request` (29 September 2026).

**Mekanismenya, dari kode.** `authenticate()` membandingkan `sessionVersion` di
klaim token dengan kolom `sessionVersion` di baris user:

`backend/src/shared/middleware/Authenticate.ts:43-54`
```ts
async function isCurrentSession(decoded: AccessTokenPayload): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: decoded.sub },
    select: { sessionVersion: true, status: true, deletedAt: true },
  });
  return Boolean(
    user && !user.deletedAt &&
    !['INACTIVE', 'SUSPENDED'].includes(user.status) &&
    user.sessionVersion === decoded.sessionVersion,
  );
}
```

`backend/src/shared/middleware/Authenticate.ts:90-92`
```ts
if (!(await isCurrentSession(decoded))) {
  throw new AuthError('Access token session is no longer valid');
}
```

### Jawaban atas pertanyaan terbuka: kode error-nya `AUTHENTICATION_FAILED`

`AuthError` adalah **`401` dengan `code: "AUTHENTICATION_FAILED"`**
(`backend/src/shared/exceptions/AppError.ts:40-44`), **bukan** `TOKEN_EXPIRED`.
`TOKEN_EXPIRED` hanya dipakai saat JWT-nya benar-benar kedaluwarsa menurut
`exp`: `backend/src/shared/security/JWTHandler.ts:122-124` memetakan
`jwt.TokenExpiredError` → `TokenExpiredError`. Semua penolakan lain dari
`verifyAccessToken` (tipe token salah, `sessionVersion` bukan integer ≥ 1,
signature salah) juga menjadi `AuthError` (`JWTHandler.ts:100-105`, `:125`).

> **Aturan klien yang mengikuti dari ini:** `401 AUTHENTICATION_FAILED` **tidak
> boleh** langsung memicu logout. Perlakukan **`AUTHENTICATION_FAILED` dan
> `TOKEN_EXPIRED` sama**: satu kali `POST /auth/refresh`, lalu satu kali retry.
> **Logout hanya kalau refresh-nya sendiri gagal.** Klien yang memetakan
> `AUTHENTICATION_FAILED` ke "kredensial salah → ke layar login" akan melogout
> user setiap kali HR mengubah role.

Alasan aturan itu aman ada di komentar implementasinya sendiri
(`backend/src/shared/security/session-revocation.ts:4-16`): `/auth/refresh`
membaca ulang baris user dan mencetak klaim baru **tanpa** memeriksa
`sessionVersion`, jadi refresh selalu berhasil setelah perubahan otoritas.
Sebaliknya, pada **ganti password / reset password** seluruh refresh token
keluarga sesi juga dicabut (`backend/src/modules/auth/auth.repository.ts:312-326`),
sehingga refresh akan gagal dan logout memang jawaban yang benar. Klien tidak
bisa membedakan kedua kasus dari `code`-nya — **maka urutannya harus "refresh
dulu, logout kalau refresh gagal"**, bukan sebaliknya.

**Apa saja yang menaikkan `sessionVersion`** (semua call site, terverifikasi):

| Pemicu | File:baris | `reason` yang dicatat |
|---|---|---|
| Assign role ke user | `backend/src/modules/rbac/rbac.service.ts:339` | `user-roles-assigned` |
| Ubah permission sebuah role (menyentuh **semua** pemegang role itu) | `backend/src/modules/rbac/rbac.repository.ts:90` | `role-permissions-changed` |
| Grant company access | `backend/src/modules/user/user.repository.ts:195` | `company-access-granted` |
| Ubah company access | `backend/src/modules/user/user.repository.ts:212` | `company-access-updated` |
| Revoke company access | `backend/src/modules/user/user.repository.ts:218` | `company-access-revoked` |
| Ganti password | `backend/src/modules/auth/auth.repository.ts:218-228` | — (`updatePassword`) |
| Reset password lewat token | `backend/src/modules/auth/auth.repository.ts:312-323` | — |

Draf menyebut tiga yang pertama; **`company-access-updated`** dan kedua jalur
password **juga** menaikkannya. Deaktivasi/suspensi user tidak perlu menaikkan
versi karena `status` dan `deletedAt` sudah diperiksa di request yang sama
(`Authenticate.ts:50-51`).

**Alur yang harus ada di aplikasi.**

1. Request biasa → `401` (`AUTHENTICATION_FAILED` **atau** `TOKEN_EXPIRED`).
2. Satu kali `POST /auth/refresh`. Antrekan request paralel selama refresh
   berjalan — **jangan** kirim dua refresh dengan refresh token yang sama
   (lihat §18: replay terdeteksi dan mencabut seluruh sesi).
3. Retry request semula **sekali**.
4. **Muat ulang `roles`/`permissions`** dari hasil refresh dan bangun ulang
   menu/guard — otoritas memang berubah, itu sebabnya 401-nya muncul. Cache
   permission lama tidak boleh dipakai lagi.
5. Kalau refresh juga gagal → logout.

Catatan kecil: `optionalAuthenticate` tidak melempar; ia hanya menurunkan
request menjadi anonim (`Authenticate.ts:126-129`). Jadi endpoint yang memakai
auth opsional bisa menjawab `200` dengan data anonim, bukan `401`.

## 4. Mode autentikasi mobile: `X-Client-Type: mobile`

**Status: bukan perubahan baru — konfigurasi wajib.** Draf menandainya
"**BREAKING** jika belum dikirim". Itu **diturunkan**: header ini diperkenalkan
`cfbbd01` pada **10 September 2026**, jauh sebelum jendela perubahan yang
didokumenkan di sini, dan **tidak ada klien yang pernah bekerja tanpanya** dalam
mode Bearer. Tidak ada field yang berganti nama atau hilang karena header ini.
Tetap dimuat di dokumen ini karena seluruh bagian lain mengasumsikan mode Bearer.

**Di mana header dibaca** — tepat satu tempat,
`backend/src/modules/auth/auth.controller.ts:69-71`:

```ts
function isMobileClient(req: Request): boolean {
  return (req.get('x-client-type') || '').toLowerCase() === 'mobile';
}
```

Dipakai hanya pada dua handler: login (`auth.controller.ts:96`) dan refresh
(`auth.controller.ts:167`). Route-nya `auth.routes.ts:162` (`POST /auth/login`)
dan `auth.routes.ts:163` (`POST /auth/refresh`). **Di luar dua handler itu header
ini tidak berpengaruh apa pun** — tidak pada middleware auth, tidak pada CSRF.

**Jebakan nilai header.** Perbandingannya **persamaan persis** dengan `'mobile'`
setelah `toLowerCase()`, dan **tanpa `trim()`**. Jadi:

| Nilai dikirim | Hasil |
|---|---|
| `mobile`, `Mobile`, `MOBILE` | mode Bearer ✅ |
| `android`, `ios`, `mobile-app`, `react-native` | **mode cookie** ❌ |
| `"mobile "` (ada spasi di belakang) | **mode cookie** ❌ |

Gagal di sini **tidak** memunculkan error — server hanya diam-diam memakai mode
web, dan `data.tokens.accessToken` tidak ada di body.

**Bentuk respons login/refresh (mode mobile)** —
`auth.controller.ts:96-108` dan `:167-179`:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "...", "email": "...", "employeeId": "...", "name": "...",
      "roles": ["EMPLOYEE"], "permissions": ["leave:create", "..."],
      "companyId": "...", "companyScope": ["..."], "groupId": "...",
      "mustChangePassword": false
    },
    "tokens": { "accessToken": "<JWT>", "refreshToken": "<opaque>", "expiresIn": 900 }
  }
}
```

Koreksi atas draf: daftar field `user` sebenarnya **lebih panjang** dari yang
ditulis draf — ada `name`, `companyScope`, `groupId`, dan
**`mustChangePassword`** (`backend/src/modules/auth/auth.dto.ts:83-96`,
`auth.service.ts:39-51`). `mustChangePassword: true` harus memaksa layar ganti
password; jangan diabaikan.

`expiresIn` bersatuan **detik** dan merupakan masa hidup **access token**, bukan
refresh token (`auth.service.ts:629-634`). Nilai di fixture test: `900`
(`backend/src/modules/auth/auth.csrf.routes.test.ts:30`).

**Bentuk respons mode web (tanpa header)** — tokennya **tidak ada di body sama
sekali**. `auth.controller.ts:110-124` menaruh `at`/`rt` sebagai cookie
`httpOnly`, lalu mengirim `data.tokens` yang **hanya** berisi `expiresIn`,
ditambah `data.csrfToken` yang tidak ada di mode mobile. Dipaku di
`auth.csrf.routes.test.ts:94`:

```ts
expect(login.body.data.tokens).toEqual({ expiresIn: 900 });
```

### Koreksi penting: pembebasan CSRF **tidak** ditentukan oleh header

Draf menjelaskan tabel mode dan menyebut mobile "tidak perlu CSRF". Benar
hasilnya, **salah sebabnya**. `backend/src/shared/middleware/CsrfProtection.ts:71-74`:

```ts
const usesAuthCookie = Boolean(req.cookies?.at || req.cookies?.rt);
if (!usesAuthCookie) { next(); return; }
```

Pembebasan datang dari **tidak adanya cookie `at`/`rt`**, bukan dari
`X-Client-Type`. Konsekuensi nyata untuk klien native:

> Klien yang memakai cookie jar HTTP bawaan (Android `CookieManager`,
> `URLSession` default, Dio tanpa konfigurasi) akan **ikut mengirim cookie
> `at`/`rt`** yang diterima dari respons login — walaupun ia juga mengirim
> `Authorization: Bearer`. Begitu cookie itu terkirim, seluruh mutasinya
> **ditolak `403 FORBIDDEN`** dengan message `'Invalid or missing CSRF token'`
> (`CsrfProtection.ts:90`). **Matikan cookie jar.**

Dipaku di `auth.csrf.routes.test.ts:120-127`. Middleware-nya global
(`backend/src/app.ts:135`). Method aman (`GET`/`HEAD`/`OPTIONS`) selalu bebas
(`CsrfProtection.ts:11`, `:66-69`).

Angka umur token CSRF yang disebut draf **benar**:
`CsrfProtection.ts:9` → `const TOKEN_TTL_MS = 2 * 60 * 60 * 1000;` dan
`CsrfProtection.ts:22-23` menolak nonce tanpa prefix epoch (`NaN`) **dan** nonce
bertanggal masa depan. Hanya relevan bila aplikasi memakai mode cookie.

`GET /auth/csrf` nyata ada (`auth.routes.ts:108`) dan **web-only** — mobile tidak
perlu memanggilnya.

## 5. `companyId`/`employeeId` diturunkan dari token — BREAKING, tapi tidak menyeluruh

**Status: BREAKING untuk endpoint self-service; klaimnya diperbaiki karena draf
menyatakannya terlalu luas.**

**Yang benar.** Endpoint `/me` dan `/my` memang memakai identitas pemanggil dari
token, dan field identitas dari klien tidak lagi berpengaruh:

| Endpoint | Dari mana identitasnya | File:baris |
|---|---|---|
| `GET /attendance/me` | `req.user.employeeId` + `req.user.companyId` | `backend/src/modules/attendance/attendance.controller.ts:10-25` |
| `GET /employee-loans/my` | `req.user?.employeeId` | `backend/src/modules/employee-loan/employee-loan.controller.ts:29` |
| `POST /employee-loans` | `req.user!.employeeId` / `companyId`, dengan **destructuring eksplisit** lima field body | `employee-loan.controller.ts:46-49` |
| `POST /travel-expenses/trips` dan `/claims` | `getEmployeeContext(req)`, di-override **setelah** spread body | `backend/src/modules/travel-expense/travel-expense.controller.ts:11-34`, `:82-94`, `:208-220` |
| `GET /ewa/my` | `getRequestContext()?.user.employeeId`, dicek ulang di service | `backend/src/modules/ewa/ewa.controller.ts:36-42`, `ewa.service.ts:140-143` |
| `GET /daily-activities/my` | idem | `backend/src/modules/daily-activity/daily-activity.controller.ts:34-40` |

**Koreksi: pernyataan "server tidak pernah menerima identitas dari klien" tidak
berlaku menyeluruh.** Beberapa endpoint **masih menuntut atau menerima
`?companyId=`** dari klien, dan satu di antaranya ada di jalur yang dipakai
mobile:

| Endpoint | Perilaku | File:baris |
|---|---|---|
| `GET /employee-loans` (daftar admin) | `?companyId=` **wajib**, tanpa fallback sesi — `400 "companyId is required"` bila tidak ada | `employee-loan.controller.ts:10-11`, `:19-21` |
| `GET /travel-expenses/trips`, `/claims` (daftar approver) | `req.query.companyId \|\| req.user?.companyId` | `travel-expense.controller.ts:47`, `:173` |
| `POST /travel-expenses/trips/:id/advance` | `req.body.companyId \|\| req.user?.companyId` | `travel-expense.controller.ts:156` |
| `GET /workflow-engine/instances/my-approvals` | `req.query.companyId \|\| req.user?.companyId` — **ini route ber-`/my`** | `backend/src/modules/workflow-engine/workflow-engine.controller.ts:171` |
| `company-settings` (semua handler) | `req.query.companyId` sebagai pemilih tenant eksplisit | `company-settings.controller.ts` |

Untuk mobile: jangan mengirim `companyId` pada endpoint `/me`/`/my` (tidak
berguna), **tetapi** siapkan diri bahwa `GET /employee-loans` versi admin
menuntutnya.

### Jawaban atas pertanyaan terbuka: `employeeId` asing — ditolak atau diabaikan?

**Jawabannya berbeda per endpoint. Tidak ada satu aturan.** Yang pasti: **tidak
pernah `422`**, karena tidak ada satu pun schema identitas yang memakai
`.strict()`. `backend/src/shared/middleware/RequestValidator.ts:17-19` memakai
`schema.parse()` biasa dan **menimpa** `req[target]` dengan hasil parse, sehingga
key yang tidak dikenal **dibuang diam-diam**:

```ts
const parsed = schema.parse(req[target]);
(req as any)[target] = parsed;
```

Di seluruh `backend/src` hanya ada **satu** pemakaian `.strict()`, dan itu tidak
berhubungan dengan identitas (`backend/src/modules/payroll/payroll-formula.dto.ts:13`).

| Endpoint | `employeeId` asing di body/query | `companyId` asing |
|---|---|---|
| `POST /attendance/me/check-in`, `PATCH /attendance/me/check-out` | **dibuang diam-diam** oleh Zod | dibuang diam-diam |
| `POST /attendance/overtime` | dibuang diam-diam | dibuang diam-diam |
| `GET /attendance/me`, `GET /attendance-corrections/my` | tidak ada di schema query → dibuang | dibuang |
| `POST /employee-loans`, `GET /employee-loans/my` | **diabaikan**, respons `200` dengan data sendiri | — |
| `POST /travel-expenses/trips`, `/claims` | dibuang diam-diam | ada di schema, **ditimpa** diam-diam |
| `GET /travel-expenses/trips/my`, `/claims/my` | diabaikan, `200` | — |
| `POST /attendance` (create versi admin) | **`403 FORBIDDEN`** — `"Anda tidak boleh clock-in atas nama karyawan lain"` | dipaksa dari sesi |
| `POST /ewa` | **`403 FORBIDDEN`** — `"EWA can only be requested for the authenticated employee"` | diabaikan |
| `POST /daily-activities` | **`403 FORBIDDEN`** `"Role EMPLOYEE tidak bisa input daily activity atas nama karyawan lain"` — **hanya** bila `roles` memuat literal `'EMPLOYEE'`; role kustom non-elevated lolos dan dibatasi hanya oleh pemeriksaan satu-company (`404` bila lintas company) | diabaikan |
| **key sampah apa pun** | **dibuang diam-diam, tidak pernah `422`** | — |

Bukti terkuatnya adalah contract test, bukan kode:

`backend/src/modules/attendance/attendance-mobile.contract.test.ts:16-32`
```ts
it('strips client-controlled identity and timestamps from self check-in', () => {
  const parsed = selfCheckInSchema.parse({
    method: 'MOBILE_GPS', checkInLatitude: -6.2, checkInLongitude: 106.8,
    employeeId: '00000000-0000-4000-8000-000000000001',
    companyId: '00000000-0000-4000-8000-000000000002',
    date: '2000-01-01T00:00:00.000Z', checkIn: '2000-01-01T00:00:00.000Z', status: 'PRESENT',
  });
  expect(parsed).toEqual({ method: 'MOBILE_GPS', checkInLatitude: -6.2, checkInLongitude: 106.8 });
});
```

`backend/src/modules/ewa/ewa.service.ts:155-159` (jalur yang **menolak**):
```ts
if (!onBehalf && employeeId !== access.actor.employeeId)
  throw new ForbiddenError('EWA can only be requested for the authenticated employee');
```

Contract test lain: `backend/src/modules/travel-expense/travel-expense.contract.test.ts:49-67`,
`backend/src/modules/employee-loan/employee-loan.contract.test.ts:12-23`,
dan integrasi lintas-company di
`backend/src/tests/integration/company-scope-sprint2-gaps.test.ts:157,168,191,223`.

> **Aturan praktis untuk klien:** jangan bergantung pada salah satu perilaku.
> **Hapus** field identitas dari payload. Kalau tertinggal, tiga endpoint akan
> menjawab `403` dan membuat fitur rusak di produksi, sementara sisanya akan
> "berhasil" tanpa memberi tahu bahwa field itu diabaikan — yang justru lebih
> berbahaya saat debugging.

**Satu kasus `422` yang perlu diketahui.** Pada `POST /ewa`, tiga field yang
dihitung server dilarang lewat `z.never()`
(`backend/src/modules/ewa/ewa.dto.ts:11`, `:20-22`):

```ts
earnedGross: z.never().optional(),
periodStart: z.never().optional(),
periodEnd: z.never().optional(),
```

Mengirim salah satunya → **`422 VALIDATION_ERROR`** dengan `errors[].field`
menyebut nama field itu, **bukan** `400`. Pemeriksaan `BadRequestError` di
controller (`ewa.controller.ts:68-74`) tidak pernah tercapai karena `validate()`
berjalan lebih dulu (`ewa.routes.ts:41-47`).

**Sebelum / sesudah.**

```http
# sebelum (konvensi lama mobile-api-documentation.md)
GET /api/v1/attendance?employeeId=<uuid-saya>&month=2026-09
POST /api/v1/employee-loans
{ "employeeId": "<uuid-saya>", "loanTypeId": "...", "amount": "1000000" }

# sesudah
GET /api/v1/attendance/me?month=2026-09&page=1&limit=20
Authorization: Bearer <accessToken>

POST /api/v1/employee-loans
{ "loanTypeId": "...", "amount": "1000000", "totalInstallments": 6,
  "installmentAmount": "166667", "reason": "..." }
```

Commit pengerasnya tersebar dan **subject-nya tidak dapat dicari**: `64c04c8`
(*test*) membalik `findMyLoans` dari `req.query.employeeId` ke
`req.user?.employeeId` dan menulis contract test loan + travel;
`0bc8b25` memperkenalkan `getEmployeeContext` travel;
`aa752d9 fix(#8 T3): enforce fine-grained data scope on by-path reads + positive attendance gate`
untuk attendance; `af7ced8` (*test*) untuk EWA; `abb6614` (*test*) untuk
daily-activity; `c2fbcea feat: implement mobile API gap coverage` menulis
`attendance-mobile.contract.test.ts` dan `mobile-routes.contract.test.ts`.

## 6. Field sensitif pegawai di-mask last-4 — BREAKING

**Status: BREAKING.** Nama field tidak berubah, tapi **nilainya** berubah menjadi
string mask, dan nama field yang dipakai draf sebelumnya **salah semua**.

**Commit:** `cfbbd01 feat: Phase 1 security hardening — tenant isolation, PII
masking, audit…` (satu-satunya commit yang menyentuh
`backend/src/modules/employee/employee-pii.ts`).

### Nama field yang benar

Draf menulis `nik`, `npwp`, `bankAccountNumber`. **Tidak ada satu pun yang
benar.** Daftar sebenarnya ada di
`backend/src/modules/employee/employee-pii.ts:11-18`:

```ts
const SENSITIVE_EMPLOYEE_FIELDS = [
  'idNumber',             // NIK
  'taxId',                // NPWP
  'bankAccount',
  'bankAccountHolder',    // ← nama pemilik rekening, bukan angka
  'bpjsKetenagakerjaan',
  'bpjsKesehatan',
] as const;
```

Perhatikan `bankAccountHolder`: itu **nama orang**, dan ikut di-mask. Jadi layar
yang menampilkan "nama pemilik rekening" akan menerima deretan bintang, bukan
nama.

### Bentuk mask yang persis

`backend/src/modules/employee/employee-pii.ts:29-32`:

```ts
function last4(value: unknown): string {
  const s = String(value);
  return s.length <= 4 ? '****' : '*'.repeat(s.length - 4) + s.slice(-4);
}
```

Jadi, menjawab pertanyaan yang draf gantung:

- Karakter mask: **`*`** (asterisk), bukan `•` atau `x`.
- Jumlahnya: **`panjang - 4`**, sehingga **panjang string hasil = panjang nilai
  aslinya**. Panjang nilai asli jadi bocor — itu konsekuensi desain, bukan bug.
- Separator **tidak dipertahankan**: fungsi ini tidak tahu format. Jika NPWP
  tersimpan dengan titik/strip, titik dan strip itu ikut diganti `*`.
- Nilai yang panjangnya **≤ 4 karakter** menjadi persis **`"****"`** (empat
  bintang), yang **lebih pendek** dari aslinya.
- `null`/`undefined` **dibiarkan apa adanya** (`employee-pii.ts:38` —
  `if (masked[field] != null)`), jadi jangan menebak "null berarti disensor".

Nilai persisnya dipaku test `backend/src/modules/employee/employee-pii.test.ts:20-29`:

```ts
expect(masked.idNumber).toBe('************0001');            // 16 digit NIK
expect(masked.taxId).toMatch(/^\*+1000$/);
expect(masked.bankAccount).toBe('******7890');               // 10 digit
expect(masked.bpjsKetenagakerjaan).toMatch(/^\*+4556$/);
expect(masked.bpjsKesehatan).toMatch(/^\*+7890$/);
expect(masked.email).toBe('budi@acme.co');                   // tidak di-mask
expect(masked.fullName).toBe('Budi Santoso');                // tidak di-mask
```

**Sebelum / sesudah yang benar** (untuk pemanggil tanpa hak baca PII):

```jsonc
// sebelum — nilai penuh
{
  "idNumber": "3174091201900001",
  "taxId": "012345678901000",
  "bankAccount": "1234567890",
  "bankAccountHolder": "Budi Santoso",
  "bpjsKetenagakerjaan": "11223344556",
  "bpjsKesehatan": "0001234567890"
}

// sesudah
{
  "idNumber": "************0001",
  "taxId": "***********1000",
  "bankAccount": "******7890",
  "bankAccountHolder": "*******sono",
  "bpjsKetenagakerjaan": "*******4556",
  "bpjsKesehatan": "*********7890"
}
```

### Siapa yang melihat nilai penuh

`employee-pii.ts:20-27`:

```ts
const SENSITIVE_READ_ROLES = new Set(['SUPER_ADMIN', 'GROUP_ADMIN', 'COMPANY_ADMIN', 'HR_MANAGER', 'HR_STAFF']);

export function canReadSensitiveEmployeeData(): boolean {
  if (getCurrentRoles().some((role) => SENSITIVE_READ_ROLES.has(role))) return true;
  const permissions = getCurrentUser()?.permissions ?? [];
  return permissions.includes('employee:read-sensitive') || permissions.includes('employee:*');
}
```

Draf hanya menyebut `employee:read-sensitive`. **`employee:*` juga membuka
mask** — itu wildcard yang perlu diperiksa klien bila ia memutuskan menampilkan
atau menyembunyikan field berdasarkan `permissions`.

### Endpoint yang kena mask

| Endpoint | File:baris |
|---|---|
| `GET /api/v1/employees` (list) | `backend/src/modules/employee/employee.controller.ts:93` |
| `GET /api/v1/employees/:id` (detail) | `employee.controller.ts:102` |
| `GET /api/v1/employees/:id/families` | `employee.controller.ts:264` — baris keluarga membawa NIK tanggungan, kebijakan mask-nya sama |
| `GET /api/v1/employees/export` (CSV) | `employee.controller.ts:248` → `employee.service.ts:893` |

### Temuan yang draf lewatkan sama sekali: **employee tidak melihat NIK-nya sendiri**

`backend/src/modules/employee/employee.routes.ts` **tidak punya**
`GET /employees/me`. Satu-satunya route `/me` di modul itu adalah
`/me/reporting-line` (`employee.routes.ts:52`). Jadi karyawan membaca profilnya
sendiri lewat `GET /employees/:id` dengan id dirinya
(`employee.routes.ts:85`) — dan `serializeEmployee()` **tidak punya pengecualian
"ini data saya sendiri"**. Role `EMPLOYEE` tidak ada di `SENSITIVE_READ_ROLES`
dan seed-nya tidak memberi `employee:read-sensitive`
(`backend/src/database/seeds/modules/03-role-permissions.seed.ts:142-157`).

> **Konsekuensinya: pada layar "Profil Saya", NIK, NPWP, nomor rekening, nama
> pemilik rekening, dan kedua nomor BPJS milik user sendiri tampil ter-mask.**
> Itu perilaku kode saat ini, bukan bug klien. Jangan membangun layar yang
> mengandalkan nilai itu (prefill form, verifikasi data, salin-tempel).

### Yang harus dilakukan klien

- **Jangan** memakai nilai hasil baca sebagai input ke mana pun — mengirimnya
  kembali pada `PUT /employees/:id` akan **menyimpan karakter bintang sebagai
  data**. Tidak ada penjaga di sisi server yang menolak string ber-`*`.
- **Jangan** memvalidasi panjang/format NIK atau NPWP pada nilai hasil baca.
  (Panjangnya memang sama, tapi isinya bukan digit.)
- Lebih baik **sembunyikan field** ketika `permissions` tidak memuat
  `employee:read-sensitive` atau `employee:*`, daripada menampilkan deretan
  bintang yang terlihat seperti data rusak.
- Untuk ekspor CSV, mask dipilih lewat `maskSensitive: !canReadSensitiveEmployeeData()`
  (`employee.controller.ts:248`) — file yang diunduh employee biasa juga
  ter-mask.

## 7. Payslip: daftar tanpa nominal + unlock wajib — BREAKING (dan lebih luas dari yang ditulis draf)

**Status: BREAKING, dengan cakupan yang dinaikkan.** Draf mendokumentasikan
**jalur yang salah**: tabelnya adalah jalur **admin/payroll-reader**, bukan jalur
self-service karyawan. Ada **dua mekanisme unlock dengan dua header berbeda**.

| | Jalur admin / pemegang `payroll:*` | **Jalur self-service karyawan** |
|---|---|---|
| Reautentikasi | `password` + `totp` (bila MFA aktif) | **PIN 6 digit** |
| Header grant | `X-Payroll-Unlock-Token` | **`X-Payslip-Unlock`** |
| Umur grant | **5 menit** | **15 menit** |
| Penyimpanan grant | tabel DB `payroll_unlock_sessions` | token HMAC stateless |

### Route sebenarnya — `backend/src/modules/payroll/payroll.routes.ts`

| Method | Path | Baris | Catatan |
|---|---|---|---|
| GET | `/payroll/payslips` | `:398-402` | Daftar periode sendiri **tanpa nominal** |
| POST | `/payroll/payslips/unlock` | `:369-374` | password + totp → grant 5 menit |
| POST | `/payroll/payslips/lock` | `:376-380` | cabut semua grant user itu |
| GET | `/payroll/payslips/:id` | `:390-396` | detail nominal |
| GET | `/payroll/payslips/:id/pdf` | `:382-388` | PDF privat |
| **PUT** | **`/payroll/payslips/pin`** | `:335-340` | **tidak ada di draf** — set/ubah PIN |
| **GET** | **`/payroll/payslips/pin/status`** | `:342-345` | **tidak ada di draf** |
| **POST** | **`/payroll/payslips/my/unlock`** | `:347-352` | **tidak ada di draf** — unlock pakai PIN |
| **GET** | **`/payroll/payslips/my/:id`** | `:361-366` | **tidak ada di draf** |
| **GET** | **`/payroll/payslips/my/:id/pdf`** | `:354-359` | **tidak ada di draf** |

Semua route `pin`/`my` didaftarkan **sebelum** `/payslips/:id` (`:334`) supaya
tidak tertangkap sebagai `:id`.

Header dibaca di `payroll.controller.ts:23-26` (`x-payroll-unlock-token`) dan
`payroll.controller.ts:29-32` (`x-payslip-unlock`); dipakai di `:345`, `:358`
(jalur admin) dan `:427`, `:439` (jalur `my`).

### Koreksi: header **tidak selalu** wajib pada `/payslips/:id`

`backend/src/modules/payroll/payroll.controller.ts:15-21`:

```ts
function requiresPayrollUnlock(req: AuthenticatedRequest): boolean {
  const permissions = req.user?.permissions ?? [];
  const elevated = req.user?.roles?.includes('SUPER_ADMIN') || permissions.some((permission) =>
    ['payroll:process', 'payroll:approve', 'payroll:disburse', 'payroll:*'].includes(permission),
  );
  return Boolean(req.user?.employeeId) && !elevated;
}
```

Jadi `SUPER_ADMIN`, pemegang `payroll:process|approve|disburse|*`, dan user yang
**tidak tertaut ke employee** melewati gerbang itu tanpa header. Route `my/*`
selalu menuntut header (`:427`, `:439`).

### Angka yang diverifikasi

`backend/src/modules/payroll/payroll-unlock.service.ts:7-9`:
```ts
export const PAYROLL_UNLOCK_TTL_SECONDS = 5 * 60;
export const PAYROLL_UNLOCK_MAX_ATTEMPTS = 5;
export const PAYROLL_UNLOCK_LOCK_MINUTES = 15;
```
`backend/src/shared/payroll/payslip-pin.ts:18-20`:
```ts
export const PAYSLIP_PIN_MAX_ATTEMPTS = 5;
export const PAYSLIP_PIN_LOCK_MINUTES = 15;
export const PAYSLIP_UNLOCK_TTL_MINUTES = 15;
```

Koreksi atas draf: jendela lockout adalah **sliding window atas kegagalan
terakhir**, bukan 15 menit sejak kegagalan pertama
(`payroll-unlock.service.ts:38-41`). Satu kegagalan setiap 14 menit **tidak
pernah** mereset penghitung dan akhirnya tetap terkunci.

### Kode error — semuanya spesifik dan tidak ada di draf

| Kondisi | Status + `code` | File:baris |
|---|---|---|
| Header hilang / grant kedaluwarsa / dicabut | **401 `PAYROLL_UNLOCK_REQUIRED`** | `payroll-unlock.service.ts:23-25`, `:137-152` |
| Password/TOTP salah | **401 `PAYROLL_REAUTH_FAILED`** | `payroll-unlock.service.ts:59` |
| 5 kegagalan → terkunci | **429 `PAYROLL_UNLOCK_LOCKED`** | `payroll-unlock.service.ts:53-57`, `:68-74` |
| Akun user terkunci | **429 `ACCOUNT_LOCKED`** | `payroll-unlock.service.ts:92` |
| PDF > 5 MB | **413 `PAYSLIP_PDF_TOO_LARGE`** | `payroll.controller.ts:362-364`, `:442-444` |
| Jalur `my`: grant tidak sah | **403 `PAYSLIP_UNLOCK_INVALID`** | `backend/src/modules/payroll/payslip-pin.service.ts:147-152` |
| Jalur `my`: PIN salah | **403 `PAYSLIP_PIN_INVALID`** | `payslip-pin.service.ts:134` |
| Jalur `my`: PIN terkunci | **429 `PAYSLIP_PIN_LOCKED`** | `payslip-pin.service.ts:31-39` |
| Jalur `my`: PIN belum di-set | **409 `PAYSLIP_PIN_NOT_SET`** | `payslip-pin.service.ts:115` |
| Jalur `my`: reauth PIN gagal | **403 `PAYSLIP_PIN_REAUTH_FAILED`** | `payslip-pin.service.ts:78` |

Perhatikan: jalur `my` memakai **403**, jalur admin memakai **401**, untuk
kondisi yang secara konsep sama. Jangan menyamakan keduanya di klien.

### Daftar tanpa nominal — benar, dengan batas yang tak disebut draf

`backend/src/modules/payroll/payroll.repository.ts:470-482` menyeleksi hanya
`id`, `status`, `createdAt`, dan `payrollRun` (`id, name, runNumber, status,
period{...}` — `payroll.repository.ts:15-18`). **Tidak ada** `netPay`,
`totalEarnings`, `totalDeductions`, `baseSalary`, atau `components`. Filter
`payrollRun: { status: { in: ['APPROVED', 'DISBURSED'] } }` benar.

Yang draf lewatkan:
- Setiap baris diberi flag **`locked: true`** oleh controller
  (`payroll.controller.ts:383`).
- Daftar ini **dibatasi keras 20 baris**, `orderBy createdAt desc`, dan
  **tidak punya parameter pagination** (`payroll.repository.ts:470`, `:479-480`).
- Route-nya tetap di belakang `authorize({ resource: 'payroll', action: 'read' })`
  (`payroll.routes.ts:400`) — karyawan butuh permission `payroll:read` untuk
  melihat daftar payslip-nya sendiri. Seed role `EMPLOYEE` memang memberikannya
  (`backend/src/database/seeds/modules/03-role-permissions.seed.ts:152`), tapi
  role kustom bisa tidak.

### Grant: terikat dan sekali pakai per sesi — benar

`payroll-unlock.service.ts:140-150` mencocokkan
`companyId + userId + employeeId + tokenHash + revokedAt: null + expiresAt > now`.
Token disimpan **hanya sebagai digest SHA-256** (`:121`); nilai mentahnya
dikembalikan sekali (`:107`, `:129-134`). Unlock baru mencabut grant lama di
transaksi yang sama (`:115-118`), jadi dua layar yang unlock sendiri-sendiri
memang saling membatalkan. `lock` mencabut semua grant user itu (`:156-162`).

`totp` **selalu opsional di schema** (`backend/src/modules/payroll/payroll.validation.ts:31-34`);
penegakan MFA ada di service (`payroll-unlock.service.ts:96-104`), jadi user MFA
yang lupa `totp` mendapat `401 PAYROLL_REAUTH_FAILED`, bukan `422`.

### PDF privat — benar

Dibangun di memori (`payroll.controller.ts:39-46`) dan dikirim dengan
`payroll.controller.ts:365-369`: `Cache-Control: no-store, private`,
`Content-Type: application/pdf`,
`Content-Disposition: attachment; filename="payslip-<id>.pdf"`. Tidak ada
`res.redirect`, tidak ada penulisan ke disk, tidak ada signed URL.

### Cacat yang ditemukan dan perlu dilaporkan ke tim backend

`backend/src/app.ts:108` — allowlist CORS:
```ts
allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token', 'X-Requested-With', 'Idempotency-Key', 'X-Payroll-Unlock-Token'],
```
**`X-Payslip-Unlock` tidak ada di daftar itu**, padahal frontend web
mengirimkannya (`frontend/src/services/payroll.service.ts:320`, `:329`). Klien
browser lintas-origin akan diblok di preflight. Klien native tidak terkena.

**Commit:** `c2fbcea feat: implement mobile API gap coverage` (18 September 2026)
untuk `payroll-unlock.service.ts` + migration
`20260918100000_payroll_unlock_sessions` (ada, berisi tabel
`payroll_unlock_sessions` dan `payroll_unlock_guards`);
`8f3bbc2 feat(payroll): PIN-protected self-service payslip amounts` untuk jalur
`my/*` + PIN (migration `20260927041124_payslip_pin`);
`d8a25a0 fix(payroll): payslip PIN unlock could never reveal amounts`.

## 8. Payload absensi: hanya foto mentah — BREAKING (mekanismenya dikoreksi)

**Status: BREAKING** — benar, tapi draf salah menjelaskan **di mana**
penolakannya terjadi, dan satu klaimnya terlalu kuat.

**Route** (`backend/src/modules/attendance/attendance.routes.ts`):
```
:28  router.post('/me/check-in',   validate(selfCheckInSchema),  idempotency(), ...)
:29  router.patch('/me/check-out', validate(selfCheckOutSchema), idempotency(), ...)
```
Keduanya memakai `idempotency()` — draf tidak menyebutkannya; lihat §10.

### Koreksi: yang menolak adalah **service**, bukan schema

Schema-nya **sengaja menerima** field turunan itu
(`backend/src/modules/attendance/attendance.dto.ts:26-45`, dengan komentar
penjelas di `:26-29`): "…remain in this DTO solely so the service can reject them
explicitly instead of silently stripping a dangerous payload." Tidak ada
`.strict()`, tidak ada `superRefine`.

Penolakannya di `backend/src/modules/attendance/attendance.service.ts:47-66`,
dipanggil dari `:585-590`:

```ts
const hasClientDerivedBiometric = Boolean(faceInput) && (
  faceInput.selfieUrl !== undefined || faceInput.selfieVector !== undefined ||
  faceInput.referenceVector !== undefined || faceInput.referencePhotoImage !== undefined ||
  faceInput.referencePhotoUrl !== undefined || faceInput.similarityScore !== undefined ||
  faceInput.isFaceMatch !== undefined
);
if (hasClientDerivedBiometric) {
  throw new BadRequestError('Vector, URL penyimpanan, data pembanding, dan hasil verifikasi wajah tidak boleh dikirim client; seluruh keputusan biometrik harus berasal dari server');
}
```

**Akibatnya untuk klien:** errornya **`400 BAD_REQUEST`** tanpa `errors[]` dan
tanpa nama field — **bukan** `422` dengan field-level error. Message-nya
berbahasa Indonesia. Jangan menulis handler yang mencari `errors[].field` di sini.

Dua catatan tambahan:
- `selfieFileSizeBytes` dan `selfieMimeType` **diterima** dan tidak pernah
  ditolak (dinyatakan "transport metadata only", `attendance.dto.ts:41`).
- Key yang **tidak dikenal** dibuang diam-diam (Zod non-strict +
  `backend/src/shared/middleware/RequestValidator.ts:18-20`), jadi tidak semua
  payload salah memberi umpan balik.
- Gerbang tambahan: mengirim `faceRecognition` dengan method non-face dan
  `requiresSelfie=false` → `400` `"Payload faceRecognition hanya boleh dipakai
  dengan method FACE_RECOGNITION"` (`attendance.service.ts:71-76`).

### Pagar lain pada jalur yang sama — semua angka draf benar

| Kondisi | Hasil | Bukti |
|---|---|---|
| Face tidak cocok, cosine `< 0.6` | `400 BAD_REQUEST` `"Wajah tidak cocok dengan profil karyawan yang terdaftar."` | ambang: `backend/src/shared/attendance/face-recognition.ts:1` (`DEFAULT_FACE_MATCH_THRESHOLD = 0.6`), perbandingan `score >= threshold` di `:79` (jadi tepat 0.6 **lolos**); throw di `attendance.service.ts:675-677` |
| 5 kegagalan face / 15 menit / karyawan | `429 TOO_MANY_REQUESTS` | `backend/src/shared/attendance/face-match-rate-limit.ts:7-8`, throw di `:101-103`, dipanggil `attendance.service.ts:602`. Sliding window atas baris `AttendanceFaceLog`, diserialisasi dengan advisory lock MySQL (`:36-74`) sehingga berlaku lintas instance. Efek samping: audit row `FACE_MATCH_RATE_LIMITED` (`:86-99`) dan notifikasi HR sekali (`:105-152`) |
| Mock location terkonfirmasi | `400` `"Lokasi terdeteksi palsu (Mock Location)…"`, **tidak ada baris absensi** | `attendance.service.ts:695-708`; insert satu-satunya ada di `:774-785` |
| `requiresSelfie=true` + `MOBILE_GPS` tanpa selfie | `400` `"Face recognition membutuhkan selfieImage dan profil wajah yang terdaftar"` | `attendance.service.ts:68-80`; `requiresSelfie` dipaksa aktif untuk policy `FACE_RECOGNITION`/`FACE_GPS` (`:191-193`, `:380`, `:589`); test `attendance.face-security.test.ts:48` |
| Profil wajah server belum ada | `400` `"Profil wajah karyawan belum terdaftar…"` | `attendance.service.ts:81-83`, `:598-600` |
| Di luar radius | `400` **atau** `requiresReview: true`, sesuai `outsideRadiusAction` | `attendance.service.ts:307-318` |
| GPS `SUSPICIOUS` (akurasi > 150 m, koordinat ≥ 24 jam basi) | **tidak** ditolak; `requiresReview: true` | `backend/src/shared/attendance/gps-mock.ts:113-121`, `attendance.service.ts:766-769` |

### Koreksi penting: "semua keputusan biometrik dihitung di server" **tidak benar untuk liveness**

Pencocokan **wajah** memang server-side (vektor diekstrak di
`attendance.service.ts:607`, referensi didekripsi di `:620`). Tapi **liveness
seluruhnya berasal dari metadata yang dideklarasikan klien**
(`backend/src/shared/attendance/liveness.ts:145-166`): `exifSoftware` cocok regex
→ `MANIPULATED`; `pixelVariance < 150` → `BLUR`; `clientSource` cocok
`/gallery|album|photo\s*library|files/i` → `STATIC`; `isLiveCapture === false`
→ `STATIC`. Header file-nya sendiri menyebutnya "MVP Level 1 — HEURISTIK EXIF +
BLUR" (`liveness.ts:14`). **Klien yang tidak mengirim `liveness` sama sekali
mendapat `NO_DATA` dan lolos** (`liveness.ts:115`; gerbangnya dilewati bila
`livenessAssess` falsy — `attendance.service.ts:682`).

Hal yang sama berlaku untuk fake GPS: verdict-nya diturunkan **sepenuhnya** dari
`deviceGps` yang dikirim klien (`attendance.dto.ts:3-10`). Tidak mengirim
`deviceGps` → `LIKELY_REAL` (`gps-mock.ts:104`). Jadi ini pagar kejujuran
perangkat, bukan deteksi server.

### Fake GPS **memang** diperiksa saat check-out — terkonfirmasi

`attendance.service.ts:831-843` (di dalam `checkOut`, dicapai dari
`checkOutSelf` di `:475`) menjalankan `assessGpsCompliance` atas
`checkOutLatitude`/`checkOutLongitude` + `data.deviceGps`, lalu:

```ts
if (gpsCompliance.mockVerdict === MockLocationVerdict.CONFIRMED_FAKE) {
  throw new BadRequestError(`Lokasi terdeteksi palsu (Mock Location). Matikan fake GPS app untuk clock-out.`);
}
```

Throw-nya terjadi **sebelum** `attendanceRepository.update` di `:868`, jadi baris
absensi yang terbuka tidak tersentuh. Geofence juga dievaluasi saat check-out
(`:818-829`, `phaseLabel: 'Check-out'`), termasuk cabang REJECT.

**Asimetri yang draf tidak sebut:** check-out **tidak melakukan verifikasi wajah
sama sekali** — tidak ada `enforceTrustedFaceRecognition`, tidak ada face match,
tidak ada liveness, tidak ada rate-limit face di seluruh `checkOut`
(`attendance.service.ts:798-915`), dan `selfCheckOutSchema` tidak punya field
`faceRecognition` (`attendance.dto.ts:130`). Jadi **jangan** mengirim selfie pada
check-out.

Catatan: commit `25a67cd` dan `45604f3 feat(attendance): fingerprint punches
that hardware actually attests` adalah jalur **mesin/device fingerprint**
(`POST /attendance-devices/punches`), bukan aplikasi mobile, dan route itu
**tidak** memakai `idempotency()`
(`backend/src/modules/attendance/attendance-device.routes.ts:29-34`, `:45-52`).
Tidak masuk checklist mobile.

**Commit:** `81c64cf feat: finalize mobile API stage 1 acceptance` (20 September
2026) — memperkenalkan `face-match-rate-limit.ts`,
`attendance.face-security.test.ts`, dan `enforceTrustedFaceRecognition` yang
berlaku sekarang; `c2fbcea` memperkenalkan `checkInSelf`/`checkOutSelf`.

## 9. Absensi live-only — **diturunkan dari BREAKING menjadi perilaku**

**Status: perilaku / aturan desain klien.** Draf menandainya "**BREAKING**
(perilaku)". **Diturunkan**, karena tidak ada field yang hilang, tidak ada
envelope yang berubah, dan **tidak ada 4xx baru**: field waktu dari klien
**dibuang diam-diam**, bukan ditolak. Yang berubah adalah apa yang harus
dilakukan aplikasi, bukan kontrak HTTP-nya.

**Waktu selalu dari server.**
`backend/src/modules/attendance/attendance.service.ts:453-464`:

```ts
async checkInSelf(employeeId: string, companyId: string, input: SelfCheckInDTO) {
  const clock = await this.selfClock(employeeId, companyId);
  return this.create({
    ...input,
    employeeId, companyId,
    date: clock.calendarDate.toISOString(),
    checkIn: clock.now.toISOString(),
    status: 'PRESENT',
    source: 'MOBILE_SELF_SERVICE',
  });
}
```

`clock.now` default `new Date()` saat request diterima
(`attendance.service.ts:397`). Nilai server ditaruh **setelah** `...input`, jadi
field selundupan pun tidak bisa menang. Hal yang sama di `checkOutSelf`
(`:466-476`).

**Field waktu dari klien: dibuang, tidak ditolak.** `selfCheckInSchema`
(`attendance.dto.ts:120-128`) hanya memilih `method, notes, checkInLatitude,
checkInLongitude, faceRecognition, liveness, deviceGps` — `date`, `checkIn`,
`checkOut` tidak ikut. Klien yang tetap mengirim `checkIn` **tidak mendapat
`422`**; field-nya hilang tanpa pesan. Jadi bug di klien bisa lolos tanpa
terdeteksi — itu alasan tambahan untuk membersihkannya sendiri.

Satu nuansa: `liveness.exifDateTimeOriginal` (`attendance.dto.ts:52`) **adalah**
timestamp capture dari klien, tetapi hanya dibaca sebagai sinyal liveness
(`liveness.ts:128`) dan tidak pernah memengaruhi waktu punch.

**Tidak ada antrean offline di sisi mana pun.** Pencarian
`offline.?(punch|queue)|pendingPunch|punchQueue` di `backend/src`, `frontend/src`
dan `docs` → nol hasil.

**Batas 36 jam yang tidak disebut draf.** `checkOutSelf` mencari baris absensi
terbuka hanya sampai 36 jam ke belakang
(`attendance.service.ts:470`: `clock.start.getTime() - 36 * 60 * 60 * 1000`);
di luar itu `404 NOT_FOUND` `"No open attendance record found for checkout"`.
**Itulah batas nyata** setelah mana punch yang terlewat harus jadi koreksi.

**`GET /attendance/me/today` — ketujuh field draf benar**
(`attendance.service.ts:436-451`): `serverTime` (ISO), `serverDate`, `timezone`,
`record`, `context`, `canCheckIn` (`!record`), `canCheckOut`
(`Boolean(record?.checkIn && !record?.checkOut)`). Dibungkus `Result.success`
(`attendance.controller.ts:34`), jadi klien membaca `data.serverTime`, bukan
top-level. Perhatikan `canCheckIn: !record` — baris yang sudah **ditutup** juga
memblokir check-in kedua pada hari itu.

**`GET /attendance/me`** (`attendance.routes.ts:27`): `limit` maksimum **100**,
default 20; `page` default 1; `month` wajib `YYYY-MM` atau `422`
(`attendance.dto.ts:114-118`). Respons `Result.paginated(...)` plus dua header
yang draf lewatkan (`attendance.controller.ts:24-26`):

```
X-Office-Timezone: <timezone kantor>
X-Server-Date: <YYYY-MM-DD menurut timezone kantor>
```

`timezone`/`serverDate` **tidak ada di body** pada endpoint ini — hanya di
header. Jadi untuk layar riwayat, bacalah header itu, atau ambil
`GET /attendance/me/today` sekali.

**Jalur koreksi** (`backend/src/modules/attendance/attendance-correction.routes.ts`):
`GET /my` (`:19`), `GET /my/:id` (`:20`), `GET /` (`:21`), `GET /:id` (`:22`),
`POST /` (`:23`, dengan `idempotency()`), `PUT /:id/approve` (`:24`),
`PUT /:id/reject` (`:25`), `PATCH /:id/workflow-action` (`:26`).

Di sinilah waktu dari klien **memang** diterima — dan hanya di sini
(`backend/src/modules/attendance/attendance-correction.dto.ts:3-12`):

```ts
export const createAttendanceCorrectionSchema = z.object({
  attendanceId: z.string().uuid().optional(),
  date: z.string().datetime(),
  requestedCheckIn: z.string().datetime().optional(),
  requestedCheckOut: z.string().datetime().optional(),
  reason: z.string().trim().min(3).max(2000),
}).refine((value) => value.requestedCheckIn || value.requestedCheckOut, {
  message: 'Minimal satu dari requestedCheckIn atau requestedCheckOut harus diisi', path: ['requestedCheckIn'],
});
```

`reason` **wajib**, minimal 3 karakter; minimal satu dari dua waktu harus ada.

## 10. `Idempotency-Key`: `409` untuk key yang dipakai ulang dengan payload berbeda — BREAKING

**Status: BREAKING** — benar. `409` pada request yang dulu diterima adalah 4xx
baru. Middleware-nya `backend/src/shared/middleware/Idempotency.ts`, satu factory
`idempotency(ttlSeconds = 24 * 60 * 60)` (`:88`).

| Klaim draf | Hasil verifikasi | Bukti |
|---|---|---|
| Header opsional | **benar** | `Idempotency.ts:91-92` — `if (!rawKey) return next();` |
| 16–128 karakter ASCII | **benar, dengan koreksi** | `Idempotency.ts:93` → `/^[!-~]{16,128}$/` = ASCII tampak `0x21`–`0x7E`, **spasi tidak boleh**. Pelanggaran → **`422 VALIDATION_ERROR`**, message `'Invalid Idempotency-Key'`, hint `'Use 16 to 128 visible ASCII characters without spaces'` (`:94-97`) — draf tidak menyebut kode ini |
| Disimpan 24 jam | **benar** | `:88` default `24*60*60`; semua call site memakai `idempotency()` tanpa argumen. Menyimpan respons **tidak memperpanjang** jendela (`:138` memakai ulang `pending.expiresAt`) |
| Scope company + user + method + path | **benar, tapi tidak lengkap** | `:100-102` — scope = `` `${companyId ?? 'none'}:${userId}:${method}:${baseUrl+path}:${rawKey}` ``, lalu `storageKey = 'idempotency:mobile:' + sha256(scope)`. Key mentahnya **ikut** masuk hash. Request tanpa auth tapi membawa key → **`422`** (`:98`) |
| Replay + header `Idempotency-Replayed: true` | **benar** | `:78-79`. Diizinkan di CORS expose (`backend/src/app.ts:109`); `Idempotency-Key` diizinkan di request (`app.ts:108`) |
| Payload berbeda, key sama → `409` | **benar** | `:72-74` — `ConflictError('Idempotency-Key was already used with a different request payload')` |
| Masih diproses → `409` | **benar** | `:75-77` dan `:118` — `ConflictError('A request with this Idempotency-Key is still in progress')` |
| Hanya `2xx` disimpan; error melepas reservasi | **benar** | `:132-140` — `statusCode >= 200 && < 300 ? save(...) : release(...)`. Respons ditahan sampai penyimpanan selesai (`:142-147`); `res.on('close')` melepas bila `!res.writableFinished` (`:150-152`) |
| Urutan key JSON tidak mengubah fingerprint | **benar** | `canonicalize` di `:27-38` mengurutkan key objek rekursif dan **membuang nilai `undefined`**; fingerprint = sha256 atas `{ body, query }` (`:103-106`). **Urutan elemen array tetap berpengaruh** |

**Koreksi riwayat.** Aturan "hanya `2xx` disimpan" **bukan** perilaku awal.
`c2fbcea feat: implement mobile API gap coverage` (18 September) menyimpan
`2xx`–`4xx` sehingga error pun ikut di-replay; `78b3845 feat: harden mobile auth
and mutation retries` (21 September) mempersempitnya ke `2xx`, menambahkan
`canonicalize`, dan menambahkan latch agar respons tidak terkirim dua kali.

**Penyimpanan.** Redis bila `config.redis.enabled` (`SET NX` lewat
`redisCache.setIfAbsent`, `:54-59`); **kalau tidak, `Map` lokal per proses**
(`:16`). Di mode in-memory tidak ada perlindungan lintas instance — relevan bila
backend di-scale horizontal.

### Cakupan nyata — daftar draf perlu dikoreksi di tiga titik

Route yang **benar-benar** memakai `idempotency()` (prefix `/api/v1`):

| Path | Method | File:baris |
|---|---|---|
| `/attendance/me/check-in` | POST | `attendance/attendance.routes.ts:28` |
| `/attendance/me/check-out` | PATCH | `attendance/attendance.routes.ts:29` |
| `/attendance/overtime` | POST | `attendance/attendance.routes.ts:34` |
| `/attendance-corrections` | POST | `attendance/attendance-correction.routes.ts:23` |
| `/leave` | POST | `leave/leave.routes.ts:141` |
| `/leave/encashment` | POST | `leave/leave.routes.ts:82` |
| `/leave/collective/:id/apply` | POST | `leave/leave.routes.ts:125` |
| `/employee-loans` | POST | `employee-loan/employee-loan.routes.ts:21` |
| `/employee-loans/:id/cancel\|approve\|reject` | PATCH | `employee-loan.routes.ts:24-26` |
| `/employee-loans/:id/workflow-action` | PATCH | `employee-loan.routes.ts:29` |
| `/ewa` | POST | `ewa/ewa.routes.ts:45` |
| `/ewa/:id/cancel\|approve\|reject\|mark-paid` | POST | `ewa/ewa.routes.ts:59,68,77,86` |
| `/daily-activities` | POST | `daily-activity/daily-activity.routes.ts:35` |
| `/daily-activities/:id` | PUT / DELETE | `daily-activity.routes.ts:48`, `:63` |
| `/daily-activities/:id/complete` | POST | `daily-activity.routes.ts:56` |
| `/travel-expenses/trips` | POST | `travel-expense/travel-expense.routes.ts:72` |
| `/travel-expenses/trips/:id/approve\|reject\|workflow-action\|advance` | PATCH/POST | `travel-expense.routes.ts:80,88,101,109` |
| `/travel-expenses/claims` | POST | `travel-expense.routes.ts:128` |
| `/travel-expenses/claims/:id/approve\|reject\|workflow-action\|reimburse` | PATCH/POST | `travel-expense.routes.ts:136,144,157,165` |
| `/notifications/device-tokens` | POST / DELETE | `notification/notification.routes.ts:14-15` |
| `/permission-requests` | POST | `permission-request/permission-request.routes.ts:59` |
| `/announcements/:id/read` | PUT | `announcement/announcement.routes.ts:74` |
| `/announcements/manage/:id/publish` | PATCH | `announcement/announcement.routes.ts:60` |

Koreksi atas daftar draf:

1. **"registrasi device" ambigu.** Push-token (`/notifications/device-tokens`)
   memang terlindungi. **Registrasi mesin absensi tidak**:
   `POST /attendance-devices` dan `POST /attendance-devices/punches`
   (`attendance/attendance-device.routes.ts:45-52`, `:29-34`) tidak memakai
   `idempotency()` — file-nya bahkan tidak meng-import-nya.
2. **"cuti" terlalu luas.** Hanya *pembuatan* cuti, encashment, dan
   collective-apply yang terlindungi. `PATCH /leave/:id/approve|reject|cancel|workflow-action`
   (`leave.routes.ts:151,152,155,159`) dan `PATCH /leave/encashment/:id/approve|reject`
   (`:85`, `:91`) **tidak**.
3. **"koreksi" sebagian.** Hanya `POST /attendance-corrections`; approve/reject/
   workflow-action di `:24-26` tidak.
4. **Dua grup yang draf lewatkan sama sekali:** announcement (publish,
   mark-read) dan permission-request.

### Mekanisme kedua yang draf tidak sebut: pembayaran payroll **mewajibkan** header

`backend/src/modules/payroll/payroll-payment.routes.ts:43-51` memakai helper
sendiri (`idempotencyKey(req)`) yang memvalidasi dengan
`paymentIdempotencyKeySchema`
(`backend/src/modules/payroll/payroll-payment.dto.ts:40-43`:
`z.string().min(16).max(128).regex(/^[\x21-\x7e]+$/)`) dan **melempar `422` bila
header tidak ada**. Kunci diteruskan ke service, **tanpa** replay di lapisan
HTTP dan **tanpa** header `Idempotency-Replayed`. Berlaku untuk
`POST /payroll/payment-batches` (`:63`), `POST …/:id/export` (`:82`),
`PATCH …/:id/transactions/:transactionId` (`:90`),
`POST …/:id/reconcile` (`:105`), `POST …/:id/cancel` (`:116`). Ini
**header wajib baru** — jadi BREAKING juga, tapi hanya untuk klien admin
payroll, bukan aplikasi karyawan.

**Pola yang benar:** satu key per **percobaan pengiriman satu form**, dibuat
ulang **hanya** ketika user mengubah isian. Satu key per layar atau per sesi akan
menghasilkan `409`.

## 11. File privat: `/uploads/*` ditutup — BREAKING

**Status: BREAKING** — benar, dengan empat koreksi dan satu jebakan baru yang
draf justru menyatakan terbalik.

**`/uploads/*` ditutup.** Tidak ada `express.static` di seluruh `backend/src`
(pencarian `express.static|serve-static|serveStatic` → nol hasil). Yang ada
adalah penolak menyeluruh, `backend/src/app.ts:137-141`:

```ts
// Private uploads are served exclusively through authorized resource controllers.
app.use('/uploads', (_req: Request, res: Response) => {
  res.setHeader('Cache-Control', 'no-store');
  res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'Use the authorized file download endpoint' });
});
```

**Koreksi 1: statusnya `403 FORBIDDEN`, bukan `404`**, dan berlaku untuk
**semua method**. Jangan menafsirkannya sebagai "file tidak ada".

**Endpoint download privat** — `backend/src/shared/storage/private-files.ts`,
dimount di `backend/src/app.ts:211` sebagai `/api/v1/private-files`, dengan
`authenticate` + `requireCompanyAccess()` di `:29`:

| Path | Baris | Guard |
|---|---|---|
| `GET /private-files/receipts/:id` | `:30` | `authorizeRole('GROUP_ADMIN','COMPANY_ADMIN','HR_MANAGER','HR_STAFF','MANAGER','EMPLOYEE')` |
| `GET /private-files/leave-attachments/:id` | `:56` | `authorize({ resource: 'leave', action: 'read' })` |
| `GET /private-files/permission-attachments/:id` | `:80` | `authorizeRole(...)` |
| `GET /private-files/performance-evidence/:id` | `:104` | `authorize({ resource: 'performance', action: 'read' })` |

**Koreksi 2:** parameternya literal **`:id`**, bukan `:claimId`/`:evidenceId`;
dan draf **melewatkan dua route** — `leave-attachments` dan
`permission-attachments`.

**Metadata dokumen tanpa `filePath` — benar.** Di-strip di tiga tempat
(`backend/src/modules/document-management/document-management.service.ts:80`
daftar, `:95` detail, `:167` respons create); nilainya tetap **disimpan** di DB
(`:162`), hanya tidak dikirim.

**Signed URL tetap menuntut sesi — benar.**
`GET /api/v1/documents/:id/signed-url`
(`backend/src/modules/document-management/document-management.routes.ts:88-92`)
berada di belakang `authenticate` (`:49`) + `requireCompanyAccess()` (`:50`) +
`authorize({ resource: 'document', action: 'read' })`. Formatnya
`${apiPrefix}/documents/${id}/file?expires=<ms>&sig=<hex>`, HMAC-SHA256 atas
`` `${id}.${expires}` ``, TTL **15 menit**
(`backend/src/shared/security/signed-url.ts:6`, `:15-25`). Route konsumennya
(`GET /documents/:id/file`, `document-management.routes.ts:51-52`) juga di
belakang `authenticate` + `document:read`, dan service-nya tegas
(`document-management.service.ts:186-191`):

```ts
// A signature supplements, but never replaces, current session authorization.
async getFileBySignature(id, expires, sig, user) {
  if (!verifyDocumentSignature(id, expires, sig)) throw new ForbiddenError('Invalid or expired document URL');
  return this.getDownloadPayload(id, user);   // ulang accessFilter + company/group check
}
```

Jadi link anonim yang dibagikan → `401` (tidak ada sesi). Commit:
`12fa098 feat(documents): HMAC signed URLs, block raw static document access (Task 1.3)`.

**Koreksi 3: header cache-nya bukan `no-store` polos.**
`backend/src/shared/storage/private-files.ts:23-26`:

```ts
res.set({ 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' });
res.download(file, name, error => { if (error) next(error); });
```

String yang sama di `document-management.controller.ts:93` dan `:124`.
`Content-Disposition: attachment` datang dari `res.download`. Jadi ada **tiga
nilai berbeda** di API ini: `no-store` (prefix payroll/EWA), `private, no-store`
(private-files + download dokumen), `no-store, private` (PDF payslip,
`payroll.controller.ts:365`). **Jangan mencocokkan string secara persis.**

### Koreksi 4 + jebakan: `receiptFilePath` opsional, dan **yang dikirim balik adalah `url`, bukan `filePath`**

Draf menyatakan klaim baru "**wajib** memakai referensi hasil upload baru". Itu
**overstated**: `backend/src/modules/travel-expense/travel-expense.dto.ts:31` →
`receiptFilePath: z.string().max(500).optional()`, dan pemeriksaannya kondisional
(`travel-expense.service.ts:253-255`). Klaim **boleh** dibuat tanpa lampiran.

Yang **tidak** draf sebut, dan ini yang akan merusak implementasi mobile:

Respons `POST /api/v1/travel-expenses/claims/receipt-upload` (**201**, multipart
field **`receipt`**, `travel-expense.routes.ts:116-123`) memang berisi
`fileName`, `originalName`, `mimeType`, `size`, `filePath`, `url`
(`travel-expense.controller.ts:222-245`), dengan

```ts
filePath: `${ownerDirectory}/${req.file.filename}`,     // "<companyId>/<employeeId>/<uuid>.<ext>"
url: `${config.app.url}/uploads/travel-expenses/receipts/${ownerDirectory}/${req.file.filename}`,
```

Tetapi `validateReceiptReference`
(`backend/src/shared/storage/receipt-reference.ts:11-21`) mem-resolve referensi
**sebagai URL** dan menuntut pathname-nya dimulai dengan
`/uploads/travel-expenses/receipts/<companyId>/<employeeId>/`. Mengirim nilai
`filePath` apa adanya menghasilkan pathname `/<companyId>/...` →
**`400 BAD_REQUEST`** `'Receipt does not belong to this employee'`.

> **Jadi: pada `POST /travel-expenses/claims`, isi `receiptFilePath` dengan
> `data.url` dari langkah upload, bukan `data.filePath`.** Draf menyuruh
> sebaliknya dan akan gagal `400`.

Ekstensi yang diterima referensi: `.png .jpg .jpeg .gif .pdf`, dengan basename
UUID (`receipt-reference.ts:19`).

Alur yang benar:

```
1. POST /api/v1/travel-expenses/claims/receipt-upload   (multipart, field "receipt")
   → 201, data.url  ← nilai inilah yang direferensikan
2. POST /api/v1/travel-expenses/claims
   { "category": "...", "amount": "...", "expenseDate": "...", "receiptFilePath": "<data.url langkah 1>" }
```

**Validasi upload diperketat — benar.**
`backend/src/shared/middleware/FileValidation.ts:100`
(`validateFileMagicBytes`), bagian intinya `:126-148`: allowlist signature
positif (JPEG/PNG/GIF/PDF/kontainer ZIP/OLE2, `:29-74`), jendela header 16 byte
(`:77`), lalu tiga pemeriksaan berurutan dengan **`400 BAD_REQUEST`** (bukan
`415`, bukan `422`) dan message yang perlu ditampilkan apa adanya:

- `Tipe file tidak diizinkan (terdeteksi <label>)`
- `File MIME does not match content`
- `File extension does not match content`

Pembersihan file gagal ada dua lapis: `unlink` langsung di dalam validator
(`:150-154`) dan `discardUploadOnFailure()` (`:166-181`) yang menghapus pada
`res.on('finish')` bila `statusCode >= 400`. Nama file diacak:
kuitansi `travel-expense.routes.ts:41-43`, evidence
`backend/src/modules/performance/performance.routes.ts:70-72`, dokumen
`document-management.routes.ts:37-41`. Field multipart: kuitansi `receipt`,
evidence `file` (`performance.routes.ts:189`), dokumen `file`
(`document-management.routes.ts:84`).

**Untuk menampilkan file:** panggil endpoint download dengan `Authorization` dan
render dari byte-nya. Jangan menyuapkan URL ke komponen gambar/WebView yang tidak
mengirim header auth.

**Commit.** `2d01312 fix(security): close the remaining file-upload gaps found by
the consumer audit` (28 September 2026) dan
`12fa098 feat(documents): HMAC signed URLs, block raw static document access`
bersih dan dapat dikutip. Untuk penutupan `/uploads/*` dan pembuatan router
`private-files`, **tidak ada commit yang bisa dikutip dengan bersih** — keduanya
berada di dalam commit ter-squash dengan subject `64c04c8 test`. Test pendukung:
`backend/src/shared/storage/private-files.test.ts` (`401` sebelum lookup DB
`:29-33`; `404` untuk luar scope `:35`; `403` untuk `companyId` palsu `:42`),
`backend/src/shared/middleware/FileValidation.test.ts`,
`backend/src/shared/storage/private-path.test.ts`,
`backend/src/modules/document-management/document-management.access.test.ts`.

## 12. Approval Center: `workflow-engine` jalur utama (additive) + aturan baru yang BREAKING

**Status: dua hal berbeda dalam satu bagian.**
Pemindahan jalur aksi ke `workflow-engine` → **additive**.
Kewajiban alasan pada reject dan penolakan self-approval → **BREAKING** (4xx baru
pada request yang dulu diterima).

**Route** — `backend/src/modules/workflow-engine/workflow-engine.routes.ts`,
dengan `authenticate` (`:19`) + `requireCompanyAccess()` (`:22`):

| Path | Baris | Guard |
|---|---|---|
| `GET /workflow-engine/instances/my-approvals` | `:31` | `workflow:approve`, `validate(myApprovalsQuerySchema,'query')` |
| `POST /workflow-engine/instances/:id/actions` | `:34` | `workflow:approve`, `validate(workflowActionSchema)` |
| `POST /workflow-engine/instances/bulk-approve` | `:35` | `workflow:approve` |

Route domain lama tetap ada: `PATCH /leave/:id/approve`
(`backend/src/modules/leave/leave.routes.ts:151`), `/:id/reject` (`:152`),
`/:id/workflow-action` (`:159`), semuanya `leave:approve`.

### Queue `my-approvals`

Pagination: `page` ≥ 1 default 1, `limit` 1–100 **default 20**
(`workflow-engine.dto.ts:57-60`). Controller mengirim
`Result.paginated(data.items, data.total, page, limit)`
(`workflow-engine.controller.ts:169-183`), jadi item berada **langsung pada
`data`** dengan `meta` standar — benar.

Bentuk item (`workflow-engine.repository.ts:414-459`): sebuah
`workflowInstanceStep` dengan `include: { instance: { include: { template:
{ select: { id, name, approvalType } } } } }`, filter `isCurrent: true,
status: 'PENDING'`. **Koreksi: setiap item juga membawa objek `summary`
top-level** (`:454-459`) — ringkasan kartu inbox. Draf melewatkannya; itu justru
yang paling berguna untuk UI daftar.

### Single action

`backend/src/modules/workflow-engine/workflow-engine.dto.ts:46-49`:

```ts
export const workflowActionSchema = z.object({
  action: z.enum(['APPROVE', 'REJECT', 'ESCALATE']),
  comment: z.string().max(2000).optional(),
});
```

Enum tepat tiga nilai; field-nya **`comment`** (tidak ada `reason` di schema ini).
`data` adalah hasil **domain handler**, didispatch menurut
`instance.referenceType` lewat `DOMAIN_HANDLERS`
(`workflow-engine.controller.ts:31-50`, sembilan reference type) — jadi bentuknya
memang berbeda per domain (mis. leave mengembalikan
`{ leaveRequest, workflowInstance }`, `leave.service.ts:430`). Reference type tak
dikenal jatuh ke transisi engine polos (`workflow-engine.controller.ts:63-66`).
Status sukses **200**, message `"Workflow action applied"`.

### Bulk approve

`workflow-engine.dto.ts:51-55`: `instanceIds: z.array(z.string().uuid()).min(1).max(100)`
— **1–100 benar**, dan setiap id **wajib UUID**. `action` memakai enum yang sama,
jadi bulk **juga menerima `REJECT` dan `ESCALATE`**, bukan hanya approve.

Respons (`workflow-engine.controller.ts:223-246`), **200** walau ada kegagalan:

```json
{ "success": true, "message": "...", "data": {
  "total": 3, "successful": 2, "failed": 1,
  "results": [ { "instanceId": "...", "success": true }, { "instanceId": "...", "success": false, "error": "..." } ] } }
```

`error` = `err.message` atau `'Unknown error'` (`:238`). Tangani `failed > 0`
sebagai hasil normal. (`workflowEngineRepository.bulkApplyAction` mendeklarasikan
field `status` tambahan di `workflow-engine.repository.ts:934`, tetapi itu **dead
code tanpa pemanggil** — route yang hidup tidak mengirimkannya.)

### Koreksi besar: reject tanpa alasan menghasilkan **`400`**, bukan `422`

Draf menebak "kemungkinan `422`". **Salah.** Aturannya ditegakkan di
repository, bukan di Zod (`comment` tetap opsional di schema), sehingga request
lolos validasi lalu ditolak di logika —
`backend/src/modules/workflow-engine/workflow-engine.repository.ts:703-705`:

```ts
if (action.action === 'REJECT' && !action.comment?.trim()) {
  throw new BadRequestError('A rejection reason is required');
}
```

→ **`400`, `code: "BAD_REQUEST"`, message `"A rejection reason is required"`**.
Hanya spasi juga ditolak (`.trim()`). Dipaku di
`backend/src/modules/workflow-engine/workflow-engine.concurrency.test.ts:57-59`.

**Urutan pemeriksaan penting:** cek status pending (`:700-702`) berjalan
**sebelum** cek alasan, jadi REJECT yang sudah basi **dan** tanpa alasan menjawab
**`409`**, bukan `400`.

**Koreksi kedua: route domain lama tidak setara.** `PATCH /leave/:id/reject`
(`leave.routes.ts:152`) **tidak punya validator body**, dan `rejectLeave`
mengisi default: `comment: reason ?? 'Legacy reject endpoint'`
(`backend/src/modules/leave/leave.service.ts:465`). Jadi **aturan "alasan wajib"
dapat dilewati** di route legacy itu. Jangan menganggap kedua jalur
berperilaku sama — ini alasan tambahan untuk tidak mencampurnya.

Nama field berbeda per endpoint: **`comment`** di `workflow-engine` dan
`PATCH /leave/:id/workflow-action`; **`reason`** di
`PATCH /leave/:id/reject` (`backend/src/modules/leave/leave.controller.ts:85`
membaca `req.body.reason`). EWA memakai nama lain lagi, `rejectReason`, minimal
3 karakter dan ditegakkan Zod → **`422`** (`backend/src/modules/ewa/ewa.dto.ts:28`).

### Self-approval ditolak, termasuk `SUPER_ADMIN` — benar, `403 FORBIDDEN`

`backend/src/modules/workflow-engine/workflow-engine.repository.ts:706-718`:

```ts
if (instance.requesterId === userId) {
  throw new ForbiddenError('Cannot approve/reject your own request via workflow');
}
// Subject-level self-approval: the employee the request is ABOUT cannot
// act on it, even when HR filed it on their behalf (requesterId differs).
...
if (actorEmployeeId && subjectEmployeeIds.includes(actorEmployeeId)) {
  throw new ForbiddenError('Cannot act on a workflow that concerns yourself');
}
```

Penjaga ini **tidak** dikecualikan per role, dan berjalan **sebelum** jalan
pintas `roles.includes('SUPER_ADMIN')` di `:738` — itulah sebabnya SUPER_ADMIN
juga ditolak. Dipaku eksplisit di `workflow-engine.concurrency.test.ts:48-51`.

Dua `403` lain di jalur yang sama: pemisahan tugas (`:720-722`,
`'Separation of duties: you already acted on an earlier step of this workflow'`)
dan bukan approver (`:744-746`). Leave punya penjaga domain tambahan untuk
APPROVE/REJECT (bukan ESCALATE) di `leave.service.ts:390-399`.

### Error lain

| Status | `code` | Contoh |
|---|---|---|
| 400 | `BAD_REQUEST` | `'No pending approval step found'` (`workflow-engine.repository.ts:729`) |
| 409 | `CONFLICT` | `'Workflow is no longer pending'` (`:701`), `'Workflow changed; reload before taking action'` setelah optimistic-lock miss (`:755`) |
| 422 | `VALIDATION_ERROR` | dari `RequestValidator.ts:22-28`, dengan `errors[]` |
| 400 / 404 / 401 | **tanpa `code`** | `Result.error(...)` di `workflow-engine.controller.ts:105,119,159,173,189,200,213` — lihat §1 |

**Commit.** `5d1ad3c feat: Phase 2 batch 1 — approval integrity & anti-double-apply guards`
(10 September 2026) untuk penjaga self-approval tingkat subjek;
`26dd007 uat phase 1` untuk `bulk-approve`;
`c2fbcea feat: implement mobile API gap coverage` untuk `my-approvals`. Baris
`'A rejection reason is required'` berada di commit ter-squash (`64c04c8 test`,
`041831e`), terakhir dipindahkan oleh `729c644`.

## 13. Route yang tertangkap `/:id` — **separuh klaim draf ditarik**

**Status: additive, dan separuhnya tidak pernah terjadi.**

| Route | Klaim draf | Hasil verifikasi |
|---|---|---|
| `GET /attendance/overtime` | dulu tertangkap `GET /attendance/:id` | **BENAR** |
| `GET /leave/balances/employee` | dulu tertangkap `GET /leave/:id` | **SALAH — tidak pernah tak-terjangkau** |

**`GET /attendance/overtime` memang pernah tertangkap.** Pada blob historis
`26dd007:backend/src/modules/attendance/attendance.routes.ts`, `GET /:id` berada
di baris **25** sementara `/overtime` di baris **32** — di belakangnya. Hal yang
sama di seluruh blob sebelumnya (`afc24f5`, `6f14895`, `0bc8b25`, `4fde9fe`,
`e47e1d2`, `26dd007`). `c2fbcea feat: implement mobile API gap coverage`
memindahkannya ke depan. Urutan sekarang:

```
backend/src/modules/attendance/attendance.routes.ts
:31-32  // Keep these routes before /:id so GET /overtime is not interpreted as
        // an attendance record whose id happens to be 'overtime'.
:33     router.get('/overtime', …)
:34     router.post('/overtime', …)
:46     router.get('/:id', …)
```

Catatan: hanya `GET /overtime` yang pernah tertangkap. `POST /overtime` tidak
punya `POST /:id` penyaing, dan route `/overtime/:id/*` berjumlah tiga segmen.

**`GET /leave/balances/employee` tidak pernah tak-terjangkau.** Express di
project ini `^4.21.1` (`backend/package.json:49`). Di Express 4
(path-to-regexp 0.1.x) pola `'/:id'` mencocokkan **tepat satu segmen path**.
`/leave/balances/employee` punya **dua** segmen setelah mount, jadi
`router.get('/:id')` tidak mungkin menangkapnya — dan tidak ada pola dua segmen
di file lama yang cocok (`/:id/approve|reject|cancel|workflow|workflow-action`
pada `6fc71c2:leave.routes.ts:23,24,27,30,31` semuanya menuntut segmen kedua
yang literal). Pemindahan urutannya (dilakukan di `c2fbcea` juga) bersifat
**defensif**, bukan perbaikan route mati.

Urutan sekarang: `GET /leave/balances/employee` di
`backend/src/modules/leave/leave.routes.ts:137`, `GET /leave/:id` di `:140`,
dengan komentar di `:136` ("Static balance routes must be declared before /:id.").
Kedua urutan dipaku `backend/src/modules/mobile-routes.contract.test.ts:24`
dan `:29`.

**Konsekuensi untuk tim mobile.** Workaround untuk **daftar lembur** memang bisa
dihapus. Workaround untuk **saldo cuti** — bila ada — dibuat untuk masalah lain
(kemungkinan besar `403` karena permission `leave:read`, lihat
[Belum terverifikasi](#belum-terverifikasi) butir 5), bukan karena route-nya mati.
Jangan hapus workaround itu tanpa menguji dengan akun employee nyata.

## 14. Endpoint baru (additive)

**Status: additive** — semuanya terverifikasi ada di source, tidak ada yang
mengubah bentuk endpoint lama. Prefix `/api/v1`
(`backend/src/config/index.ts:19`), mount di `backend/src/app.ts:213-243`.

### Absensi self-service — `backend/src/modules/attendance/attendance.routes.ts`
`GET /attendance/me/today` (`:26`), `GET /attendance/me` (`:27`),
`POST /attendance/me/check-in` (`:28`), `PATCH /attendance/me/check-out` (`:29`).
Detail respons di §9. Commit `c2fbcea`.

### Koreksi absensi — `attendance-correction.routes.ts`
`GET /attendance-corrections/my` (`:19`), `GET /attendance-corrections/my/:id`
(`:20`). Lihat §9 untuk daftar lengkap route modul ini. Commit `c2fbcea`.

### Shift berikutnya — `backend/src/modules/work-calendar/work-calendar.routes.ts:70`
`GET /work-calendars/me/next-shift?from=YYYY-MM-DD`. Parameter hanya `from`,
opsional (`work-calendar.dto.ts:129-137`).
- `from` **inklusif** — benar (`work-calendar.service.ts:38`: `day.date >= fromDate`).
- Default = tanggal server di timezone company — benar
  (`work-calendar.service.ts:49`; `work-calendar.repository.ts:446-450`, fallback
  `'Asia/Jakarta'`).
- `shift: null` bila tidak ada jadwal — benar (`work-calendar.service.ts:85`).
- **Koreksi: horizon 92 hari tidak selalu terpenuhi.** `work-calendar.service.ts:50-52`
  menghitung `through = from + 92 hari` (literal `92`, **bukan** konstanta
  `MAX_SHIFT_ASSIGNMENT_DAYS` di `:30` yang milik fitur lain), tetapi loop
  pengambilannya hanya **4 bulan kalender** (`:56`:
  `for (let index = 0; index < 4; index += 1)`). Untuk `from=2026-01-31`,
  `through` jatuh di `2026-05-03` tetapi Mei tidak pernah di-query. Jadi: 92 hari
  hanya terpenuhi bila `from` berada di awal bulannya. Commit `bdb28b1`.

### Tukar shift — `work-calendar.routes.ts`
`GET /work-calendars/shift-swaps/candidates/my` (`:71`),
`GET …/shift-swaps/my` (`:72`), `GET …/shift-swaps/approvals/my` (`:73`),
`POST /work-calendars/shift-swaps` (`:74`),
`PATCH …/shift-swaps/:requestId/cancel|approve|reject` (`:75-77`).
**Koreksi: parameternya `:requestId`, bukan `:id`.** Commit
`b650e96 feat: add shift swap self service workflow`. Catatan: grup ini **tidak**
dipaku contract test mana pun.

### Announcement — `backend/src/modules/announcement/announcement.routes.ts`
`GET /announcements` (`:71`), `GET /announcements/unread-count` (`:72`),
`GET /announcements/:id` (`:73`), `PUT /announcements/:id/read` (`:74`, dengan
`idempotency()`).
- ID di luar audience → **`404 NOT_FOUND`** — terverifikasi
  (`announcement.service.ts:62-71`); `markRead` melewati penjaga yang sama
  (`:113`), jadi ID di luar audience juga tidak bisa ditandai terbaca.
- Read-state **idempotent** — terverifikasi:
  `createMany({ … skipDuplicates: true })` dan increment `totalViews` hanya bila
  `created.count === 1` (`announcement.repository.ts:126-140`). PUT berulang
  tidak error dan tidak menghitung dua kali.
Commit `bdb28b1`, sisi tulis menyusul di `56a5b0b`.

### Reporting line — `backend/src/modules/employee/employee.routes.ts:52`
`GET /employees/me/reporting-line` (didaftarkan sebelum `/:id` di `:85`).
Diturunkan dari `Position.reportsTo` → `reportsToId`
(`employee.repository.ts:180-186`), ditandai `source: 'POSITION_REPORTS_TO'`
(`:214`); primary holder deterministik lewat
`orderBy: [{ employeeNumber: 'asc' }, { id: 'asc' }]` (`:209`) lalu
`primarySupervisor: supervisors[0] ?? null` (`:222`) dan
`alternateSupervisors: supervisors.slice(1)` (`:223`). Semua klaim draf benar.
Commit `bdb28b1`.

### Aset — `backend/src/modules/asset/asset.routes.ts:14`
`GET /assets/my?status=ACTIVE|RETURNED|ALL&page=&limit=` (sebelum `/:id` di `:16`).
Enum benar; `page` default 1, `limit` default 20 maksimum 100
(`asset.dto.ts:26-30`). Identitas tidak bisa dikirim klien
(`asset.controller.ts:18-22`), query `where: { companyId, employeeId, … }`
(`asset.repository.ts:13-16`). Nilai finansial tidak pernah dikembalikan —
`select` eksplisit di `asset.repository.ts:26-42` hanya memuat tanggal/kondisi
penugasan dan `asset: { id, assetCode, name, serialNumber, status, branchId }`.
(Depresiasi ada di endpoint lain, `GET /assets/:id/depreciation` `:17`, di
belakang `employee:read`.) Commit `cdea07c feat: add employee asset self service`.

### Push token — `backend/src/modules/notification/notification.routes.ts:14-15`
`POST /notifications/device-tokens` (**201**, `notification.controller.ts:16`),
`DELETE /notifications/device-tokens`.
Payload POST (`backend/src/modules/notification/mobile-device.dto.ts:3-13`):
`installationId` (8–200), `platform` `ANDROID|IOS`, `provider` `FCM|APNS`,
`token` (20–4096), `appVersion?` (≤50), `deviceModel?` (≤100).
**Koreksi: ada aturan lintas-field yang draf lewatkan** — `provider: 'APNS'`
menuntut `platform === 'IOS'` (`:10-13`), kalau tidak `422`.
Payload DELETE: hanya `{ installationId }` (`:15-17`) — perhatikan ini
**`DELETE` dengan body JSON**.
Token provider tidak pernah dikembalikan: `publicDeviceSelect`
(`mobile-device.repository.ts:7-18`) tidak memuat `token`/`tokenHash`; nilainya
disimpan sebagai `encryptSecret(data.token)` (`:23`) plus `tokenHash` sha256
(`:22`). Commit `c2fbcea`.

### Password recovery — `backend/src/modules/auth/auth.routes.ts:164-165`
`POST /auth/forgot-password`, `POST /auth/reset-password`.
- **`202` selalu — keraguan draf tidak berdasar, angkanya memang 202.**
  `backend/src/modules/auth/auth.controller.ts:207-210`:
  ```ts
  res.status(202).json(Result.success(null,
    'If the account is eligible, password reset instructions will be sent.'));
  ```
  Tidak bersyarat: `password-reset.service.ts:35` mengembalikan diam-diam untuk
  user yang tidak ada atau tidak eligible. (`POST /auth/reset-password`
  mengembalikan **200**, `auth.controller.ts:223`.)
- Berlaku **15 menit** — benar (`config/index.ts:99`
  `PASSWORD_RESET_TTL_MINUTES` default 15; dipakai di
  `password-reset.service.ts:47`).
- **Sekali pakai, atomik** — benar: di dalam transaksi,
  `updateMany({ where: { id, usedAt: null, expiresAt: { gt: now } }, data: { usedAt: now } })`
  lalu `if (claimed.count !== 1) return null`
  (`backend/src/modules/auth/auth.repository.ts:289-306`) → pemanggil melempar
  `PASSWORD_RESET_INVALID` **400** (`password-reset.service.ts:19-26`, `:84`).
- SMTP harus diaktifkan eksplisit — benar
  (`backend/src/shared/mail/MailService.ts:102`; `config/index.ts:84`
  `SMTP_ENABLED` default `'false'`). **Penting:** bila pengiriman mati, token yang
  baru dibuat **langsung dibakar** (`password-reset.service.ts:53-56`), jadi
  `202`-nya memang tidak menjanjikan apa pun soal pengiriman.
Commit `78b3845 feat: harden mobile auth and mutation retries`.

### Pagination yang ditambahkan
- `GET /notifications` — `notification.routes.ts:16`; `page` default 1,
  `limit` default **50** maksimum 100 (`notification.dto.ts:17-21`);
  `Result.paginated` di `notification.controller.ts:38`.
- `GET /workflow-engine/instances/my-approvals` — `limit` default **20**
  (`workflow-engine.dto.ts:57-60`).
- `GET /attendance/me` — `limit` default 20 maksimum 100.

**Koreksi: default `limit` berbeda per endpoint (50 vs 20 vs 20).** Jangan
mengasumsikan satu default.

### Migration — keenam-enamnya ada, nama persis
Di `backend/src/database/prisma/migrations/`:
`20260917120000_mobile_device_registrations`,
`20260918100000_payroll_unlock_sessions`,
`20260918110000_push_notification_deliveries`,
`20260918120000_mobile_permission_matrix`,
`20260920090000_password_reset_tokens`,
`20260920093000_auth_session_version`. Tidak ada yang hilang atau berganti nama.

Perlu diketahui: `20260918120000_mobile_permission_matrix` **memberi permission
baru ke role yang sudah ada**, dan untuk role `EMPLOYEE` hanya `leave:create`
dan `payroll:read` (`migration.sql:60-64`). Lihat
[Belum terverifikasi](#belum-terverifikasi) butir 5.

### Koreksi atas klaim "contract test memaku daftar route mobile"
`backend/src/modules/mobile-routes.contract.test.ts` **tidak** memaku daftar
route mobile. Ia hanya membaca `router.stack[].route.path` (`:12-15`), jadi yang
dijamin adalah **keberadaan path dan urutan pendaftarannya** — **bukan** HTTP
method, bukan mount prefix, bukan guard. Cakupannya: absensi self, koreksi,
announcement, reporting-line, next-shift (path saja), aset, device-token (path
saja), notifikasi/my-approvals (path saja). **Tidak** mencakup shift-swap, auth,
`/meta/*`, maupun `/health*`. Untuk kepastian route, pakai
`GET /api/v1/meta/endpoints`.

## 15. Riwayat cuti bisa memuat cuti yang tidak diajukan karyawan (perilaku)

**Status: perilaku** — benar. Bentuk payload tidak berubah; yang berubah adalah
**isi daftar**.

**Commit:** `54cd896 feat(leave): cuti bersama — deduct balance, fall to unpaid,
never below zero (GAP-08)` (30 September 2026, 12 file).

**Yang terverifikasi dari diff dan kode:**

| Klaim | Hasil |
|---|---|
| Satu `LeaveRequest` per karyawan terdampak | **benar** — `backend/src/modules/leave/collective-leave.service.ts:292-306`, satu `tx.leaveRequest.create` per entri rencana, di dalam satu `prisma.$transaction` (`:243`) |
| Statusnya `APPROVED` | **benar** — `collective-leave.service.ts:301`, plus `approvedBy`/`approvedAt` (`:302-303`) |
| Membawa `collectiveLeaveId` | **benar** — ditulis di `:304` (`collectiveLeaveId: declaration.id`) |
| Nama field di model | **benar** — `backend/src/database/prisma/schema.prisma:3507-3510`: `collectiveLeaveId String? @map("collective_leave_id") @db.VarChar(36)`, dengan `@@unique([collectiveLeaveId, employeeId])`. SQL: `migrations/20260930070000_collective_leave/migration.sql:36,39,57` |
| Alasan `Cuti bersama: <nama>` | **benar, persis** — `` reason: `Cuti bersama: ${declaration.name}` `` (`:300`) |
| Saldo tidak cukup → unpaid, tidak pernah minus | **benar, dan aman terhadap race** — `SELECT … FOR UPDATE` atas `leave_balances` (`:270-274`), lalu `if (balance && balance.remaining_days >= 1)` (`:276`); cabang `else` di `:283-287` berkomentar "Never a negative balance" |
| Pembalikan hari yang sudah diterapkan sengaja tidak ada | **benar** — `:333-337`: *"Only a declared collective leave can be cancelled… Reversing an applied day means restoring balances and removing leave, which is a separate decision."* |
| `DELETE` hanya menerima deklarasi yang belum diterapkan | **benar** — `DELETE /leave/collective/:id` (`backend/src/modules/leave/leave.routes.ts:129-134`) → penjaga di atas, plus `updateMany(... status: DECLARED)` dengan `count === 0` → `400` (`:339-343`) |

**Koreksi 1: bukan selalu "saldo cuti tahunan".** Tipe cuti yang dipotong adalah
**parameter deklarasi** (`leaveTypeId`), dan hanya divalidasi sebagai tipe
berbayar, aktif, milik company itu (`collective-leave.service.ts:44-58`). Baris
saldo dicocokkan pada `leave_type_id = declaration.leaveTypeId` (`:272`). Jadi
tipe mana yang berkurang bergantung pada apa yang HR pilih — jangan hardcode
"cuti tahunan" di UI.

**Koreksi 2: `collectiveLeaveId` muncul secara insidental, bukan kontraktual.**
Pencarian `collectiveLeave` di `backend/src/modules/**` tidak menghasilkan apa pun
di luar `collective-leave.*` — **tidak ada serializer atau `select` yang menyebut
field ini di jalur baca**. Ia terkirim hanya karena kedua query baca leave
memakai `include` tanpa `select`, sehingga Prisma mengembalikan semua skalar:

- daftar: `backend/src/modules/leave/leave.repository.ts:23-30` (`findAllLeaveRequests`)
- detail: `backend/src/modules/leave/leave.repository.ts:34-41` (`findLeaveRequestById`)

Artinya: penyempitan `select:` di masa depan akan **menghilangkannya tanpa suara**,
dan tidak ada test yang memakunya. **Jangan jadikan `collectiveLeaveId` satu-satunya
dasar logika UI.** Lebih aman memakai kombinasi `status === 'APPROVED'` dan
`reason` yang berawalan `"Cuti bersama: "`, atau meminta tim backend memakukan
field itu di kontrak.

**Penjaga tambahan yang draf lewatkan** (`collective-leave.service.ts`):
karyawan yang sudah punya cuti `PENDING`/`APPROVED` pada hari itu atau sudah ada
absensi aktual **dilewati** (`:114-132`, `:141-144`); mendeklarasikan maupun
menerapkan ditolak bila periode payroll sudah ditutup (`assertPayrollDateOpen`,
`:166` dan `:252`); apply bersyarat status `DECLARED` sehingga dua apply simultan
tidak bisa memotong dua kali (`:311-317`).

**Dampak untuk klien mobile.**

- Daftar `GET /leave` akan memuat baris yang **tidak dibuat user**, langsung
  `APPROVED`. UI yang mengasumsikan "setiap cuti di daftar saya pernah saya
  ajukan" perlu disesuaikan.
- **Jangan menawarkan cancel** untuk baris cuti bersama.
- Saldo di `GET /leave/balances/employee` bisa turun tanpa aksi user. Jangan
  cache saldo lintas sesi.

## 16. Bagian gaji pada profil pegawai bisa menjadi array kosong (perilaku)

**Status: perilaku** — benar, dengan nama field yang dikoreksi dan satu
pemisahan penting yang draf samarkan.

**Nama field-nya `employeeSalaries`**, bukan "bagian gaji". Dirakit di
`backend/src/modules/employee/employee.repository.ts:52-93` (`findById`), dengan
include bersyarat di `:61-67`:

```ts
employeeSalaries: {
  where: { isActive: true, deletedAt: null, AND: [await profileSalaryAccessWhere()] },
  include: { components: { … } },
  take: 1,
},
```

Penolakannya berupa **predikat database yang tidak mungkin cocok** —
`backend/src/shared/security/employee-data-scope.ts:54-69`:

```ts
/** Employee-profile access alone does not authorize the nested salary data. */
export async function profileSalaryAccessWhere(): Promise<Prisma.EmployeeSalaryWhereInput> {
  const actor = getCurrentUser();
  if (!actor && isSystemContext()) return {};
  const denied = { id: { in: [] as string[] } };
  if (!actor?.roles?.includes('SUPER_ADMIN') &&
      !actor?.permissions?.some(p => ['payroll:read', 'payroll:*'].includes(p))) {
    return denied;
  }
  …
}
```

`{ id: { in: [] } }` membuat relasi itu resolve menjadi `[]`, sehingga profilnya
tetap **`200`** dengan `employeeSalaries: []` — **bukan `403`, bukan `null`**.
Dipaku di `backend/src/modules/payroll/employee-salary-read.mysql.test.ts:119`
(`expect(hidden?.employeeSalaries).toEqual([])`) dan `:131,132,134,142`.

Dua detail tambahan: scope-nya memakai resource **`payroll`**, bukan `employee`
(`employee-data-scope.ts:62`), dan `take: 1` berarti ini **satu baris aktif**,
bukan riwayat.

**Koreksi: `[]` hanya berlaku untuk bagian bersarang di profil.** Endpoint gaji
mandiri **tidak** mengembalikan array kosong:

| Endpoint | Perilaku saat di luar scope | Bukti |
|---|---|---|
| `GET /payroll/employee-salaries` (list) | difilter di query | `backend/src/modules/payroll/employee-salary.service.ts:55-66` |
| `GET /payroll/employee-salaries/:id` | **`404`** `'Employee salary not found in the permitted payroll scope'` | `employee-salary.service.ts:55-66` |
| `?companyId=` lintas company | **`403`** `'Salary company must match the active company'` | `employee-salary.service.ts:57` |
| `GET /payroll/employees/:employeeId/thr` | **`404`** bila employee di luar scope | `employee-salary.service.ts:68-86`, `:75` |

**UUID/tanggal invalid ditolak `422 VALIDATION_ERROR`** — benar
(`backend/src/modules/payroll/payroll.validation.ts`): `idParamSchema` `:3-5`,
`employeeSalaryListQuerySchema` `:7-10` (juga memblokir filter terstruktur
seperti `employeeId[not]=…`), `employeeThrParamSchema` `:11`,
`calendarDateSchema` `:12-15` (regex **plus** round-trip `toISOString`, jadi
`2026-02-30` juga ditolak). Dipaku di
`backend/src/modules/payroll/employee-salary.routes.test.ts:104-112` dan `:119-122`.

**`no-store` termasuk pada respons error** — benar.
`backend/src/modules/payroll/payroll.routes.ts:33-36` memasang header untuk
prefix `/employee-salaries`, `/employees/:employeeId/thr`, `/runs`, `/periods`,
`/payslips`, `/arrears`, `/annual-tax-recap`, `/bpjs-report` **sebelum**
`authenticate`/`authorize`, sehingga header bertahan pada `401/403/404/422`.
Dipaku di `employee-salary.routes.test.ts:90-98` dan `:124-128`. EWA memakai
middleware router-level serupa (`backend/src/modules/ewa/ewa.routes.ts:21`).

**Koreksi: nilai header-nya tidak satu.** Ada **tiga** di API ini:
`no-store` (prefix payroll/EWA), `private, no-store` (private-files + download
dokumen), `no-store, private` (PDF payslip, `payroll.controller.ts:365`). Jangan
mencocokkan string secara persis — periksa keberadaan substring `no-store`.

**Dampak.** Untuk user mobile biasa, bagian gaji di layar profil akan **kosong**.
UI harus menampilkan state kosong yang masuk akal, dan **tidak** mengartikannya
sebagai "gaji Rp 0".

**Commit.** Tidak ada commit bersih yang bisa dikutip: `profileSalaryAccessWhere`
dan kedua middleware `no-store` berasal dari commit ter-squash
`af7ced8 test` (9 September 2026); `9b880a8 feat: Phase 4 — payroll lifecycle
remedies, snapshots, loan amortization` juga menyentuh `employeeSalaries`.

## 17. SSO OIDC per company: web-only (additive)

**Status: additive, web-only** — benar, dengan satu koreksi pada perilaku
kegagalan.

**Commit:** `d407bed feat(auth): single sign-on per company, OIDC (GAP-37)`
(30 September 2026, 15 file).

**Route** — `backend/src/modules/auth/auth.routes.ts:114-125`: dua-duanya
publik dan di belakang `authLimiter`:

```
GET /api/v1/auth/sso/start
GET /api/v1/auth/sso/callback
```

**Nama parameter query** — `backend/src/modules/auth/sso/sso.dto.ts:27-39`:

```ts
export const ssoStartQuerySchema = z.object({
  company: z.string().min(1).max(50),
  returnTo: z.string().max(300).optional(),
});
export const ssoCallbackQuerySchema = z.object({
  state: …, code: …optional(), error: …optional(), error_description: …optional(),
});
```

Draf menulis `company` dan `returnTo` — **keduanya benar**. (Parameter *fungsi*
di service bernama `companyCode` (`sso/sso.service.ts:126`), itu sumber
kebingungannya; di wire namanya `company`, dicocokkan dengan `Company.code` di
`sso.service.ts:128-130`.) `returnTo` divalidasi relatif-saja
(`sso.service.ts:155`: harus `startsWith('/')` dan bukan `//`). Callback juga
menerima `error` dan `error_description` — tidak disebut draf.

**Redirect ke penyedia** — `auth.controller.ts:336` (`res.redirect(302, authorizeUrl)`),
dengan parameter di `sso.service.ts:163-171`: `response_type=code`, `client_id`,
`redirect_uri`, `scope=openid email profile`, `state`, `nonce`,
`code_challenge`, `code_challenge_method=S256`.

**PKCE S256 benar-benar S256** — `sso/oidc-client.ts:174-178`:

```ts
const verifier = crypto.randomBytes(48).toString('base64url');
const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');
```

verifier diputar ulang saat exchange (`oidc-client.ts:199`).

**Callback memasang cookie lalu redirect** — `auth.controller.ts:369-380`:
`setAccessCookie` / `setRefreshCookie` / `issueCsrfToken`, lalu
`res.redirect(302, destination)` dengan `destination = identity.returnTo ?? '/dashboard'`
di-resolve terhadap `config.frontend.url` dan diperiksa same-origin lagi
(`:376-379`).

**Sesi identik dengan login password — benar.** Helper yang sama
(`auth.controller.ts:43-48`), nama cookie yang sama `at`/`rt`
(`auth.controller.ts:15-16`), keduanya `httpOnly` (`:28`, `:36`).
`loginWithVerifiedIdentity` (`backend/src/modules/auth/auth.service.ts:164-207`)
memakai ulang `buildAuthContext` + `generateTokens`, jadi tokennya identik secara
struktur. Satu beda yang perlu diketahui: cookie `rt` di-scope ke path
`${apiPrefix}/auth` (`:38`), dan flag MFA lokal (`twoFactorEnabled`) **sengaja
tidak diperiksa lagi**, hanya dicatat di log (`auth.service.ts:195-196`).

### Koreksi: kegagalan tidak selalu berupa redirect

Draf menyatakan kegagalan "mendarat di halaman login dengan `?sso=failed` atau
`?sso=denied`" dan "tidak mengembalikan JSON". **Itu hanya berlaku untuk
`/sso/callback`:**

| Jalur | Kegagalan | Hasil |
|---|---|---|
| `/sso/callback` | error dari penyedia atau `code` tidak ada | `302` ke `/login?sso=failed` (`auth.controller.ts:355-356`) |
| `/sso/callback` | `AppError` dengan `statusCode < 500` | `302` ke `/login?sso=denied` (`auth.controller.ts:384-387`) |
| `/sso/callback` | error 5xx | `next(error)` → **JSON** (`auth.controller.ts:389`) |
| **`/sso/start`** | kode company tidak dikenal, atau tidak ada provider aktif | **JSON `404`** — `auth.controller.ts:332-338` hanya punya `catch (error) { next(error); }`; throw-nya `NotFoundError` di `sso.service.ts:131`, `:137` |

**`X-Client-Type: mobile` tidak mengubah apa pun di sini — terverifikasi.**
Header itu dibaca hanya di `auth.controller.ts:69-71` dan dipanggil hanya dari
`login` (`:96`) dan `refresh` (`:167`). `ssoStart` (`:332`) dan `ssoCallback`
(`:348`) tidak pernah melihatnya, jadi klien mobile mendapat cookie + `302`,
bukan token di body.

**Yang harus dilakukan klien mobile: tidak ada**, selain tidak membangun tombol
SSO. Login mobile tetap `POST /auth/login`. Jangan membungkus alur redirect di
WebView lalu memanen cookie — mode cookie menuntut CSRF double-submit (§4) dan
tidak dirancang untuk klien native. Bila kelak tenant menuntut SSO di mobile,
itu **kontrak baru** yang harus diminta ke tim backend.

## 18. Catatan operasional (perilaku) — semua angka draf terverifikasi benar

| Hal | Hasil verifikasi | Bukti |
|---|---|---|
| Health check | `GET /health/live` handler terpisah, selalu `200` (`app.ts:171-174`). `GET /health` dan `GET /health/ready` **memakai handler yang sama** (`app.ts:176`) dan menjawab **`503`** bila ada check gagal (`app.ts:191-193`). `databaseHealthy` selalu dihitung (`:186`); redis/rabbit/queue hanya bila feature flag-nya aktif (`:187-189`). **Catatan: ketiganya tanpa prefix `/api/v1`.** Probe timeout 2 detik dihitung sebagai mati (`backend/src/shared/health/readiness.ts:2`, `:13`) | `backend/src/app.ts:171-193` |
| Rotasi refresh token + revoke keluarga saat replay | **benar**. `auth.service.ts:423-470`: token yang sudah di-revoke tetap **ditemukan** (`auth.repository.ts:137-141` adalah `findUnique` polos tanpa filter `isRevoked`), lalu `revokeRefreshTokenFamily(storedToken.family)` (`auth.repository.ts:150-159`) mencabut seluruh keluarga. Rotasi: `revokeRefreshToken(storedToken.id)` (`:456`) lalu `generateTokens(..., decoded.family)` (`:470`). **Tambahan yang draf lewatkan:** token yang kedaluwarsa karena **idle timeout** juga mencabut keluarga (`:445-453`); token yang sekadar expired hanya mencabut dirinya (`:437-440`) | `backend/src/modules/auth/auth.service.ts:423-470` |
| Logout tanpa access token hidup | **benar** — `auth.routes.ts:169` tidak memakai `authenticate`, dengan komentar eksplisit di `:167-168`. Token diambil dari cookie atau body (`auth.controller.ts:60-62`), lalu seluruh keluarga dicabut (`auth.service.ts:320-330`). **Catatan:** `csrfProtection` global tetap berlaku (`app.ts:135`) — klien cookie butuh header CSRF; klien Bearer tanpa cookie tidak | `auth.routes.ts:169`, `auth.service.ts:320-330` |
| Rate limit login 10 / 15 menit per IP **dan** per email | **benar**. `authLimiter` (`auth.routes.ts:56-66`) memakai `RATE_LIMIT_WINDOW_MS` default **900000** dan `AUTH_RATE_LIMIT_MAX` default **10** (`config/index.ts:76`, `:78`), `skipSuccessfulRequests: true`. `loginEmailLimiter` (`:69-78`) memakai window/max yang sama dengan `keyGenerator` berbasis email. Keduanya dipasang di `/login` (`:162`). Backed Redis bila Redis aktif (`:41-48`) | `backend/src/modules/auth/auth.routes.ts:56-78` |
| 5 kegagalan → akun terkunci 15 menit | **benar** — `MAX_LOGIN_ATTEMPTS` default **5**, `LOCKOUT_DURATION_MINUTES` default **15** (`config/index.ts:72-73`), ditegakkan di `auth.service.ts:658-671`. **Penting:** ada pemeriksaan kedua di jalur sukses (`auth.service.ts:264-275`), jadi **password yang benar setelah 5 kegagalan tetap `429`**, bukan sesi. Penolakannya `TooManyRequestsError` → **`429 TOO_MANY_REQUESTS`** (`auth.service.ts:234-236`), bukan 401/403 | `auth.service.ts:234-275`, `:658-671` |
| Forgot password: 5 / IP / 15 menit **dan** satu email / user / menit | **benar**. `passwordResetRequestLimiter` `max: 5`, window 900000 (`auth.routes.ts:86-93`, dipasang `:164`). Throttle per user: `REQUEST_THROTTLE_MS = 60_000` (`password-reset.service.ts:13`) dengan `findRecentPasswordResetToken` (`:37-41`) yang **no-op diam-diam** (tetap `202`). **Tambahan yang draf lewatkan:** `POST /auth/reset-password` punya limiter sendiri, **10 / 15 menit** (`auth.routes.ts:96-103`, dipasang `:165`) | `auth.routes.ts:86-103`, `password-reset.service.ts:13-41` |
| MFA: `401` dengan `MFA_REQUIRED`, retry dengan field `totp` | **benar, ketiga detailnya**. `auth.service.ts:253-262`: `throw new AppError('MFA code required', 401, 'MFA_REQUIRED', true)` — satu-satunya kemunculan string itu di repo. Field retry `totp`, `z.string().trim().min(6).max(20).optional()` (`backend/src/modules/auth/auth.dto.ts:14`) — `max(20)` karena **recovery code juga diterima**. **Hati-hati:** `totp` yang salah menghasilkan `401 AUTHENTICATION_FAILED` **dan menambah satu failed attempt** (`auth.service.ts:257-261`), sehingga bisa memicu lockout 5-kegagalan | `auth.service.ts:253-262` |
| Nilai uang sebagai decimal string | tidak dibantah; perlakukan sebagai string, jangan `double`/`Number()` | — |
| Sumber kebenaran route | **benar**, dengan satu tambahan: `GET /api/v1/meta/endpoints` (`app.ts:248-257`) **dan** `GET /api/v1/meta/openapi.json` (`app.ts:262-274`) keduanya menuntut `authenticate` **plus** `authorize({ resource: 'rbac', action: 'read' })` — draf hanya menempelkan permission itu pada `/endpoints`. Dokumen OpenAPI 3.1.0 di-generate dari router hidup saat request (`backend/src/shared/openapi/generate.ts:233`) | `backend/src/app.ts:248-274` |

**Satu endpoint yang keluar dari kontrak envelope** (relevan bila klien memakai
parser tunggal): `GET /api/v1/meta/endpoints` merakit envelope-nya sendiri,
`backend/src/app.ts:256` → `res.json({ success: true, data: { count, endpoints } })`
— **tanpa `message`**. Begitu juga handler health (`app.ts:173`, `:193-206`).
Ketiganya tidak terjaring `api-contract.test.ts` karena test itu hanya memindai
file `*.controller.ts` (`api-contract.test.ts:36`).

## 19. Hari libur kalender kerja: dua perbaikan yang mengubah **nilai** (perilaku)

**Status: perilaku — dipromosikan dari daftar "belum terverifikasi" draf menjadi
bagian penuh.** Draf menandainya "arah perubahan tidak dapat dipastikan"; sekarang
dapat.

Dua commit, keduanya di `main`, 1 Oktober 2026:

- `9b2b999 fix(work-calendar): generating a year must not erase its holidays (#34)`
- `70965d5 fix(work-calendar): derive a holiday's year from its date (#35)`

**Tidak ada field yang ditambah, dihapus, atau berubah tipe pada respons mana
pun.** Yang berubah: **nilai** `dayType`/`workStart`/`workEnd`/`name` pada payload
hari kalender, **nilai** `year` pada respons tulis hari libur, dan **status
4xx baru** di jalur tulis/baca hari libur.

**Endpoint yang terpengaruh** — `backend/src/modules/work-calendar/work-calendar.routes.ts`,
dimount di `backend/src/app.ts:232` sebagai `/api/v1/work-calendars`:

| Route | Baris | Relevansi mobile |
|---|---|---|
| `GET /work-calendars/holidays/list` | `:63` | register hari libur; **tanpa `authorize()`** — data referensi self-service |
| `POST /work-calendars/holidays` | `:64` | tulis (HR) |
| `PUT /work-calendars/holidays/:hid` | `:65` | tulis (HR) |
| `POST /work-calendars/:id/generate` | `:48` | generate setahun (HR) |
| `GET /work-calendars/:id/days` | `:46` | baris hari mentah |
| `GET /work-calendars/me/resolved?year=&month=` | `:69` | **kalender bulanan ter-resolve — grid harian di mobile**, tanpa `authorize()` |
| `GET /work-calendars/me/next-shift` | `:70` | lihat §14 |
| `GET /work-calendars/:id/working-days` | `:54-59` | mengembalikan `{ count }` hari kerja |

### #34 — generate setahun dulu menghapus hari liburnya

**Bug-nya.** `generateDefaultDays` membangun setahun **hanya** dari pola mingguan,
dan membuka dengan menghapus semua yang sudah ada:

```ts
await prisma.workCalendarDay.deleteMany({ where: { calendarId } });
return prisma.workCalendarDay.createMany({ data: days });
```

Akibatnya: **17 Agustus 2026 (Senin) keluar sebagai `dayType: 'WD'` dengan
`workStart: '08:00'`, `workEnd: '17:00'`, `name: null`**; 20–21 Maret 2026
(Idulfitri) jadi hari kerja biasa. Commit message-nya lugas: *"pressing 'generate'
in the UI silently turned Idulfitri into a working day."* Selain itu, setiap baris
`NH`/`JL`/`CH`/`RH` yang sudah tercatat **terhapus dan tidak dibuat ulang**, dan
karena delete + create bukan satu transaksi, kegagalan di tengah meninggalkan
**nol baris** — yang dibaca semua konsumen sebagai "tidak ada hari kerja sama
sekali". Ini bukan kosmetik: `backend/src/shared/payroll/attendance-calendar.ts:6-7`
mendefinisikan `workingTypes = new Set(['WD','WS','OT'])`, jadi `WD` vs `NH`
adalah bit yang dipakai payroll, absensi, dan cuti.

**Perbaikannya** — `backend/src/modules/work-calendar/work-calendar.repository.ts:549-608`:
hari libur company untuk tahun itu diambil dan diindeks per tanggal (`:557-566`),
hari libur **mengalahkan** pola mingguan (`:581-592`, `dayType` `'JL'` bila
`holiday.type === 'JL'`, kalau tidak `'NH'`, dengan `name` terisi dan
`workStart`/`workEnd` `null`), dan penggantian dilakukan **di dalam transaksi**
(`:604-607`).

**Arah efeknya:**

1. `GET /:id/days` dan `GET /me/resolved` — untuk setiap tanggal hari libur:
   `dayType` `"WD"` → `"NH"` (atau `"JL"`), `workStart`/`workEnd` `"08:00"`/`"17:00"`
   → `null`, `name` `null` → mis. `"Proklamasi Kemerdekaan RI"`. **Jumlah hari
   kerja BERKURANG, hari non-kerja BERTAMBAH.** 2026 turun dari 261 hari kerja
   menjadi 245 dengan 16 hari libur ter-seed.
2. `GET /:id/working-days` — **`count` TURUN** sebanyak hari libur yang jatuh di
   hari kerja pola.
3. `GET /me/next-shift` — bisa menunjuk tanggal **lebih jauh**.
4. Hari libur **berhenti menghilang** setelah generate — ini arah kedua yang
   terpisah.
5. `POST /:id/generate` sendiri tetap `Result.success({ count })` dengan `count`
   365/366 — bentuk **dan** nilainya tidak berubah.

**Risiko klien yang nyata: nilai `"JL"`.** `backend/src/modules/work-calendar/work-calendar.dto.ts:4`
sudah lama punya `z.enum(['WD','WS','WE','NH','JL','CH','RH','OT'])`, tapi klien
yang sebelumnya hanya pernah **melihat** `WD`/`WE`/`NH` dari kalender ter-generate
sekarang akan mulai menerima `"JL"`. **`switch` eksaustif atas `dayType` harus
menanganinya.**

**Batas yang jujur**, dari docstring-nya sendiri (`:546`): hari khusus yang
dimasukkan manual (`WS`, `OT`, `CH`, `RH`) **tetap hilang** saat regenerate —
hanya `NH`/`JL` yang didukung register nasional yang bertahan.

**Test pemaku** — `backend/src/modules/work-calendar/work-calendar.generate.test.ts`
(baru di commit ini): `:76-83` (`17 Agustus` → `NH`, `name` terisi, `workStart`
null), `:85-87` (`JL` tetap berbeda dari `NH`), `:107-110`
(`WE=104`, `NH=2`, `JL=1`, `WD = 365 - 104 - 3`), `:119-122` (penggantian di
dalam transaksi), `:124-129` (kalender tidak ada → `{ count: 0 }`, tanpa delete).

### #35 — `year` hari libur sekarang diturunkan dari `date`

**Bug-nya, empat lapis.** `NationalHoliday` punya kolom `date` **dan** `year`, dan
dulu keduanya diterima independen (`year` bahkan **wajib** di schema create).
`POST /work-calendars/holidays` dengan `{ date: "2026-08-17", year: 2027 }`
menyimpan baris bertanggal 2026 di bawah tahun 2027 — dan karena
`generateDefaultDays` menyeleksi `where: { companyId, year }`
(`work-calendar.repository.ts:558-561`), baris itu **tidak pernah mencapai
kalender mana pun**. `PUT` dengan hanya `{ date }` memindahkan tanggal dan
meninggalkan `year`. `'YYYY-MM-DD'` di-parse sebagai **UTC tengah malam**,
sehingga `getFullYear()` (lokal) di host sebelah barat UTC menjawab tahun
**sebelumnya** — `2026-01-01` di `America/Chicago` masuk sebagai tahun **2025**.
Dan `date` tak terbaca disimpan sebagai Date invalid, bukan ditolak.

**Perbaikannya** — `work-calendar.repository.ts:691-696` (create) dan `:699-710`
(update): `year: date.getUTCFullYear()`, `BadRequestError('date is not a valid
calendar date')` untuk `NaN`, dan pada update `delete updateData.year` bila `date`
tidak dikirim ("Nothing may set `year` on its own, or the two fields drift apart
again"). Schema: `date` wajib cocok `/^\d{4}-\d{2}-\d{2}/` dan `year` menjadi
**opsional dan diabaikan** (`work-calendar.dto.ts:56-63`). Daftar hari libur
mengambil tenant dari konteks, bukan dari `?companyId=`
(`work-calendar.controller.ts:151-172`).

**Arah efeknya:**

1. `GET /holidays/list` dengan `?companyId=` salah/basi → **LEBIH BANYAK** hari
   libur (dulu `[]`, sekarang daftar company pemanggil). `?companyId=` sekarang
   **diabaikan diam-diam** — mobile boleh berhenti mengirimnya.
2. `?year=N` menjadi dapat dipercaya **untuk baris yang baru ditulis**.
3. **Respons `POST`/`PUT /holidays` mengembalikan `year` yang bisa berbeda dari
   yang dikirim.** Kirim `{ date: "2026-08-17", year: 2027 }` → respons `year: 2026`.
   Klien yang menyimpan nilai optimistiknya sendiri akan berbeda dari server.
4. Status baru di jalur tulis: **`400 BAD_REQUEST`** untuk tanggal tak terbaca,
   `400` dari Zod untuk `date` yang tidak cocok regex, dan **`401 AUTHENTICATION_FAILED`**
   dari `GET /holidays/list` bila tidak ada active company (dulu `[]`).
5. **Pelonggaran request yang kompatibel ke belakang:** `year` dari wajib menjadi
   opsional pada create. Tidak ada klien yang rusak.
6. Nilai `type` pada baris ter-seed bisa berubah dari `"H"` menjadi `"NH"` —
   `"H"` bukan nilai yang diterima `createHolidaySchema`
   (`work-calendar.dto.ts:59`, `z.enum(['NH','JL'])`), jadi baris lama tidak bisa
   round-trip lewat `PUT`. Parser strict yang dulu tersedak `"H"` akan berhenti
   tersedak.

**Test pemaku** — `backend/src/modules/work-calendar/holiday-year.test.ts` (baru):
`:36-41` (`year: 2027` yang bertentangan diabaikan → `2026`), `:48-60` (kasus
timezone, benar-benar mengubah `process.env.TZ = 'America/Chicago'`), `:62-66`
(tahun ikut tanggal saat update), `:68-71` (`PUT { year: 2030 }` sendirian
ditolak), `:73-80` (`NaN` ditolak, `create` tidak dipanggil), `:82-88` (scope
company).

### Yang harus dilakukan — ini bagian terpentingnya

**Tidak satu pun dari dua commit ini memperbaiki data yang sudah tersimpan.**
Tidak ada migration, tidak ada backfill (tidak ada migration yang menyentuh
`NationalHoliday` setelah `20260626015109_add_work_calendar`).

1. Hari libur yang sudah **terhapus** dari `work_calendar_days` oleh generate
   lama **tidak kembali sendiri**. Harus ada yang memanggil
   `POST /api/v1/work-calendars/:id/generate` lagi.
2. Baris register yang `year`-nya sudah salah **tetap salah**. Perbaikannya
   manual per baris: `PUT /api/v1/work-calendars/holidays/:hid` dengan `date`
   yang benar di body (`PUT { year: X }` sendirian **tidak** memperbaiki).
3. Setelah register diperbaiki, **generate harus dijalankan ulang** atau hari
   libur yang baru terlihat tetap tidak masuk `work_calendar_days`.

> **Untuk tim mobile:** sampai HR menjalankan ulang generate pada setiap kalender
> kerja, **kalender apa pun yang di-generate sebelum deploy ini masih menampilkan
> hari libur nasional sebagai hari kerja biasa.** Jangan laporkan itu sebagai bug
> klien; verifikasi dulu bahwa kalender tahun berjalan sudah di-generate ulang di
> environment uji.

**Pemeriksaan bentuk.** `git log --oneline -40 -- backend/src/modules/work-calendar`:
tidak ada commit di riwayat terkini yang mengubah **bentuk** respons
work-calendar. Dua hal yang terlihat klien keduanya **additive**:
`4e3836a feat(work-calendar): HR can assign a shift to one employee directly`
menambah tiga route baru (`POST/GET/DELETE /work-calendars/employees/:employeeId/shift-assignments`,
`work-calendar.routes.ts:85-107`), dan `bdb28b1` / `c2fbcea` menambah endpoint,
bukan mengubah yang lama.

## Capability yang "sengaja tidak ada" — koreksi besar

Draf menyatakan tujuh hal **di luar scope** dan "tidak ada endpoint-nya":
chat/messaging, Training/LMS, Performance, onboarding/offboarding, pengelolaan
MFA, daftar/revoke sesi, dan delete notifikasi.

**Enam dari tujuh itu sebenarnya ADA dan sudah ter-mount di API:**

| Capability | Status sebenarnya | Bukti |
|---|---|---|
| Chat / messaging | **benar-benar tidak ada** — tidak ada modulnya | tidak ada `backend/src/modules/*chat*` / `*messaging*` |
| Training / LMS | **ada** | `backend/src/app.ts:220` → `app.use('/api/v1/training', trainingRoutes)` |
| Performance | **ada** | `backend/src/app.ts:219` → `/api/v1/performance` |
| Onboarding | **ada** (offboarding tidak) | `backend/src/app.ts:228` → `/api/v1/onboarding` |
| Pengelolaan MFA | **ada** — `POST /auth/mfa/setup`, `/auth/mfa/enable`, `/auth/mfa/disable` | `backend/src/modules/auth/auth.routes.ts:171-173` |
| Daftar / revoke sesi | **ada** — `GET /auth/sessions`, `DELETE /auth/sessions/:id` | `auth.routes.ts:175-176` |
| Delete notifikasi | **ada** — `DELETE /notifications/:id` | `backend/src/modules/notification/notification.routes.ts:20` |

Jadi yang benar untuk dikatakan: **ini keputusan scope rilis mobile, bukan
ketiadaan endpoint.** Klien tetap boleh menampilkan state "belum tersedia" bila
rilis pertama memang tidak memuatnya, tapi **jangan** menyimpulkan bahwa
endpoint-nya harus diminta ke tim backend — sebagian besar sudah ada dan dapat
diperiksa lewat `GET /api/v1/meta/endpoints`. Yang memang perlu kontrak baru
hanyalah **chat/messaging**.

## Checklist

### BREAKING — kerjakan dulu

- [ ] **Ganti parser respons sukses jadi satu envelope bersama**
      (`{ success, message, data, meta? }`). Hapus parser khusus EWA,
      daily-activity, employee, company-settings. Verifikasi: panggil satu
      endpoint dari masing-masing keempat modul dan pastikan semuanya di-decode
      oleh satu tipe `ApiResponse<T>`. (§1)
- [ ] **Jadikan `code` pada respons error OPSIONAL, dan siapkan fallback ke HTTP
      status.** 35 call site masih mengirim `{ success:false, message }` tanpa
      `code` — termasuk Approval Center, work-calendar, loan, trip/claim, dan satu
      jalur payroll self-service. Verifikasi: panggil
      `GET /workflow-engine/instances/my-approvals` tanpa active company →
      body `400` tanpa field `code`; pastikan aplikasi tidak crash. (§1)
- [ ] **Hapus pembacaan `code` dari respons SUKSES company-settings.** Jadikan
      field itu tidak ada, bukan optional. Verifikasi: decode respons
      `GET /api/v1/company-settings` dengan model tanpa `code`; grep kode klien
      untuk `"OK"` dan pastikan nol hasil pada jalur sukses. (§2)
- [ ] **Petakan sepuluh `code` dari tabel §1 plus `INTERNAL_ERROR`, `UPLOAD_ERROR`,
      dan `correlationId`.** Verifikasi: paksa satu `422` (payload kosong) dan satu
      `404` (UUID acak), dan pastikan percabangan diambil dari `code` bila ada.
      Jangan pernah mencabang dari `message` — beberapa message berbahasa Indonesia
      dan dihasilkan dari constraint DB. (§1)
- [ ] **Perbaiki nama field PII: `idNumber`, `taxId`, `bankAccount`,
      `bankAccountHolder`, `bpjsKetenagakerjaan`, `bpjsKesehatan`** — bukan `nik`,
      `npwp`, `bankAccountNumber`. Verifikasi: grep model klien untuk tiga nama
      lama; harus nol. (§6)
- [ ] **Berhenti memakai nilai PII sebagai data.** Mask-nya
      `'*'.repeat(len-4) + last4`, atau `"****"` bila panjangnya ≤ 4; separator
      tidak dipertahankan. Sembunyikan field bila `permissions` tidak memuat
      `employee:read-sensitive` **atau** `employee:*`. Verifikasi: login sebagai
      employee biasa, buka profil sendiri — **nilai sendiri pun ter-mask**;
      pastikan tidak ada validasi format yang gagal dan tidak ada nilai ber-`*`
      yang dikirim balik pada `PUT /employees/:id`. (§6)
- [ ] **Hapus semua `employeeId`/`companyId` dari body dan query endpoint
      self-service.** Tiga endpoint menjawab `403` bila tertinggal
      (`POST /ewa`, `POST /daily-activities`, `POST /attendance`), sisanya
      mengabaikannya tanpa suara. Verifikasi: grep klien untuk `employeeId=` dan
      `"employeeId":` pada pemanggilan `/me`, `/my`, dan create
      loan/EWA/daily-activity/trip/claim — harus nol. (§5)
- [ ] **Jangan kirim `earnedGross`, `periodStart`, `periodEnd` pada `POST /ewa`** —
      `z.never()` → `422 VALIDATION_ERROR`. (§5)
- [ ] **Implementasikan alur unlock payslip yang BENAR.** Untuk karyawan: PIN →
      `POST /payroll/payslips/my/unlock` → header **`X-Payslip-Unlock`** (grant
      **15 menit**) → `GET /payroll/payslips/my/:id` dan `/my/:id/pdf`. Jalur
      `X-Payroll-Unlock-Token` (grant 5 menit) adalah jalur admin. Verifikasi:
      panggil `my/:id` tanpa header → `403 PAYSLIP_UNLOCK_INVALID`; dengan header
      → berhasil; tunggu > 15 menit → gagal lagi. (§7)
- [ ] **Sediakan layar set/ubah PIN payslip** (`PUT /payroll/payslips/pin`,
      `GET /payroll/payslips/pin/status`) dan tangani
      `409 PAYSLIP_PIN_NOT_SET` sebagai "PIN belum dibuat", bukan error. (§7)
- [ ] **Tangani lockout unlock tanpa melogout user.** `429 PAYSLIP_PIN_LOCKED` /
      `429 PAYROLL_UNLOCK_LOCKED` setelah 5 kegagalan, **jendela sliding** atas
      kegagalan terakhir. Verifikasi: lima unlock dengan PIN salah, lalu pastikan
      `GET /auth/me` masih `200`. (§7)
- [ ] **Tangani `413 PAYSLIP_PDF_TOO_LARGE`** sebagai "PDF terlalu besar, hubungi
      HR", bukan kegagalan jaringan. (§7)
- [ ] **Buang semua field biometrik turunan dari payload check-in.** Kirim
      **hanya** `faceRecognition.selfieImage`. Verifikasi: grep klien untuk
      `similarityScore`, `isFaceMatch`, `selfieVector`, `referenceVector`,
      `selfieUrl`, `referencePhotoUrl`, `referencePhotoImage` pada payload absensi
      — harus nol; lalu kirim satu payload yang sengaja memuat `isFaceMatch` dan
      pastikan server menjawab **`400 BAD_REQUEST`** (bukan `422`, dan **tanpa**
      `errors[]`). (§8)
- [ ] **Jangan kirim `faceRecognition` pada check-out** — `selfCheckOutSchema`
      tidak punya field itu dan check-out tidak melakukan verifikasi wajah. (§8)
- [ ] **Kirim `deviceGps` pada check-in DAN check-out, dan tangani `400`
      fake-GPS di kedua jalur.** Verifikasi: dengan mock location aktif, check-in
      **dan** check-out keduanya `400`, dan tidak ada baris absensi / jam keluar
      baru. (§8)
- [ ] **Satu `Idempotency-Key` per percobaan pengiriman satu form**, dibuat ulang
      hanya saat isian berubah. Format: 16–128 karakter ASCII tampak **tanpa
      spasi**; salah format → `422`. Verifikasi: kirim form yang sama dua kali
      dengan key sama → respons identik + header `Idempotency-Replayed: true`,
      satu baris di server; lalu ubah satu field dan kirim dengan key yang sama
      → `409`. (§10)
- [ ] **Hentikan pemakaian URL `/uploads/*`** — sekarang `403 FORBIDDEN` untuk
      semua method. Unduh lewat endpoint ber-ID dengan header `Authorization`.
      Verifikasi: grep klien untuk `/uploads/` — harus nol. (§11)
- [ ] **Referensikan `data.url`, BUKAN `data.filePath`, sebagai `receiptFilePath`.**
      Verifikasi: upload satu kuitansi, lalu buat klaim dengan `receiptFilePath =
      data.url` → `201`; ulangi dengan `data.filePath` → harus `400`
      `'Receipt does not belong to this employee'` (buktinya pagar aktif). (§11)
- [ ] **Jangan merender file privat lewat komponen yang tidak mengirim header
      auth.** Verifikasi: tampilkan satu dokumen employee di UI dan pastikan
      request-nya membawa `Authorization`. (§11)
- [ ] **Pastikan ekstensi, MIME, dan isi file upload konsisten.** Verifikasi:
      unggah JPEG yang di-rename `.pdf` → `400 BAD_REQUEST` dengan message
      `'File extension does not match content'`; pastikan aplikasi menampilkan
      pesan yang bisa dipahami, bukan crash. (§11)
- [ ] **Wajibkan alasan pada aksi Reject di Approval Center, dan tangani
      `400 BAD_REQUEST` (bukan `422`).** Verifikasi: kirim
      `{ "action": "REJECT" }` tanpa `comment` → `400` dengan message
      `"A rejection reason is required"`; dengan `comment` → `200`. (§12)
- [ ] **Sembunyikan tombol approve/reject pada baris milik sendiri.**
      Self-approval → `403 FORBIDDEN`, termasuk untuk `SUPER_ADMIN`, dan termasuk
      bila HR yang mengajukan atas nama user. (§12)

### Perilaku — harus ditangani, bentuk payload tidak berubah

- [ ] **Perlakukan `401 AUTHENTICATION_FAILED` sama dengan `401 TOKEN_EXPIRED`:
      satu kali refresh, satu kali retry, logout HANYA kalau refresh gagal.**
      Ini keputusan paling penting di dokumen ini — perubahan otoritas
      mengembalikan `AUTHENTICATION_FAILED`, dan klien yang memetakannya ke
      "kredensial salah → layar login" akan melogout user setiap kali HR mengubah
      role. Verifikasi: jalankan tiga request bersamaan setelah HR mengubah role
      akun uji — hanya **satu** `POST /auth/refresh` boleh terkirim, ketiga
      request harus berhasil, dan user tidak boleh terlempar ke layar login. (§3)
- [ ] **Muat ulang `roles`/`permissions` dan bangun ulang menu/guard setelah
      refresh.** Verifikasi: cabut satu permission akun uji, picu satu request, dan
      pastikan menu terkait hilang tanpa perlu logout. (§3)
- [ ] **Tangani `mustChangePassword: true` dari `data.user`** dengan memaksa layar
      ganti password. (§4)
- [ ] **Matikan cookie jar pada HTTP client.** Pembebasan CSRF berasal dari
      **tidak adanya cookie `at`/`rt`**, bukan dari `X-Client-Type`. Verifikasi:
      inspeksi request kedua setelah login — tidak boleh ada header `Cookie`
      berisi `at`/`rt`; bila ada, mutasi ditolak `403 FORBIDDEN`. (§4)
- [ ] **Kirim `X-Client-Type: mobile` dengan nilai persis `mobile`** (tanpa spasi,
      bukan `android`/`ios`) pada `POST /auth/login` dan `POST /auth/refresh`, lalu
      ambil token dari `data.tokens`. Verifikasi: login tanpa header → `data.tokens`
      hanya berisi `expiresIn`; dengan header → `accessToken`, `refreshToken`,
      `expiresIn` ada. (§4)
- [ ] **Jangan pernah mengirim refresh token yang sudah dipakai.** Simpan hasil
      rotasi secara atomik dan antrekan refresh paralel — replay mencabut
      **seluruh keluarga** refresh token sesi itu. (§3, §18)
- [ ] **Hapus antrean punch offline; arahkan punch yang gagal ke koreksi absensi.**
      Perhatikan batas **36 jam**: di luar itu `checkOutSelf` menjawab
      `404 'No open attendance record found for checkout'`. Verifikasi: matikan
      jaringan, lakukan check-in, nyalakan jaringan — aplikasi tidak boleh
      mengirim punch dengan timestamp lama dan harus menawarkan
      `POST /attendance-corrections` (dengan `reason` minimal 3 karakter). (§9)
- [ ] **Pakai `serverTime`/`serverDate`/`timezone` dari
      `GET /attendance/me/today`** (atau header `X-Office-Timezone` /
      `X-Server-Date` pada `GET /attendance/me`) untuk seluruh tampilan tanggal
      absensi. Verifikasi: ubah timezone perangkat, check-in di sekitar tengah
      malam, pastikan tanggal mengikuti timezone kantor. (§9)
- [ ] **Terima baris cuti `APPROVED` yang tidak diajukan user, dan sembunyikan
      tombol cancel untuknya.** Jangan bergantung hanya pada `collectiveLeaveId`
      — field itu terkirim secara insidental dan tidak dipaku test apa pun;
      pakai juga `reason` yang berawalan `"Cuti bersama: "`. Verifikasi: minta HR
      menerapkan satu deklarasi cuti bersama di environment uji. (§15)
- [ ] **Jangan cache saldo cuti lintas sesi.** (§15)
- [ ] **Tampilkan state kosong yang benar untuk `employeeSalaries: []`** — berarti
      "tidak berhak melihat", bukan "Rp 0". (§16)
- [ ] **Jangan simpan respons EWA/payslip/salary/THR di cache disk.** Periksa
      **substring** `no-store`, bukan string persis — ada tiga varian:
      `no-store`, `private, no-store`, `no-store, private`. (§16, §11)
- [ ] **Tangani `"JL"` pada `dayType` kalender kerja.** Verifikasi: `switch` atas
      `dayType` harus punya cabang untuk `WD WS WE NH JL CH RH OT`. (§19)
- [ ] **Verifikasi bahwa HR sudah menjalankan ulang generate kalender** sebelum
      melaporkan hari libur yang muncul sebagai hari kerja sebagai bug klien. (§19)
- [ ] **Tangani `503` dari `/health` dan `/health/ready` sebagai "server belum
      siap", bukan error autentikasi.** Keduanya **tanpa** prefix `/api/v1`;
      `/health/live` terpisah dan selalu `200`. (§18)
- [ ] **Tangani `401 MFA_REQUIRED` dengan meminta `totp`** (6–20 karakter,
      recovery code juga diterima), bukan dengan menampilkan "password salah".
      Ingat: `totp` salah menambah satu failed attempt dan bisa memicu lockout. (§18)
- [ ] **Tangani `429` saat login sebagai lockout 15 menit**, termasuk ketika
      password-nya benar. (§18)
- [ ] **Perlakukan semua nilai uang sebagai decimal string.** Verifikasi: grep
      klien untuk parsing `double`/`Number()` pada field uang. (§18)

### Additive — manfaatkan, tidak merusak apa pun

- [ ] **Hapus workaround untuk `GET /attendance/overtime`** — route-nya memang
      dulu tak terjangkau dan sekarang bekerja. **Jangan** hapus workaround saldo
      cuti tanpa diuji: `GET /leave/balances/employee` tidak pernah tak
      terjangkau, jadi masalahnya kemungkinan `403` permission. (§13)
- [ ] **Pakai `GET /attendance/me/today` sebagai sumber policy absensi**
      (`context`, `canCheckIn`, `canCheckOut`) daripada menebak di klien. (§14)
- [ ] **Pasang pagination standar** pada notifikasi (`limit` default **50**),
      antrean approval (default **20**), dan riwayat absensi (default 20, maks
      100). Jangan mengasumsikan satu default. (§14)
- [ ] **Register/unregister push token** lewat `POST`/`DELETE
      /notifications/device-tokens` dengan `installationId` stabil per instalasi;
      unregister saat logout. `provider: 'APNS'` **wajib** berpasangan dengan
      `platform: 'IOS'`. `DELETE` membawa body JSON `{ installationId }`. (§14)
- [ ] **Tambahkan layar announcement** dan tangani `404` untuk ID di luar
      audience sebagai "tidak tersedia", bukan error. `PUT /:id/read` idempotent.
      (§14)
- [ ] **Tambahkan reporting line, next-shift, shift-swap (`:requestId`), dan inbox
      aset** sesuai §14. Jangan mengandalkan horizon 92 hari pada `next-shift`
      bila `from` berada di akhir bulan. (§14)
- [ ] **Tambahkan alur forgot/reset password.** `POST /auth/forgot-password`
      selalu **`202`** — jangan menyimpulkan apakah email terdaftar, dan jangan
      menjanjikan bahwa email terkirim (SMTP bisa dimatikan). `POST
      /auth/reset-password` mengembalikan `200`, dan punya limiter 10/15 menit. (§14)
- [ ] **Arahkan aksi approval ke `POST /workflow-engine/instances/:id/actions`**
      dan jangan mencampur jalur domain; refresh queue setelah sukses; tangani
      sukses parsial pada bulk-approve (`instanceIds` 1–100, wajib UUID); pakai
      objek `summary` per item untuk kartu inbox. (§12)
- [ ] **Jangan membangun tombol SSO.** Bila perlu diagnostik: `/sso/start` yang
      gagal mengembalikan **JSON `404`**, bukan redirect. (§17)
- [ ] **Jangan menyimpulkan bahwa Training, Performance, Onboarding, pengelolaan
      MFA, daftar sesi, dan delete notifikasi tidak punya endpoint** — semuanya
      ada. Hanya chat/messaging yang benar-benar belum ada. (lihat
      *Capability yang "sengaja tidak ada"*)

### Verifikasi akhir

- [ ] **Jalankan smoke runner mobile** terhadap target staging:
      `node scripts/mobile-api-smoke.mjs` dengan `MOBILE_API_BASE_URL` HTTPS,
      `MOBILE_EMPLOYEE_EMAIL`, `MOBILE_EMPLOYEE_PASSWORD`
      (`scripts/mobile-api-smoke.mjs:5`). Gate lulus hanya bila
      **`0 failed, 0 blocked`** — exit code-nya memang
      `process.exit(failed || blocked ? 1 : 0)` (`scripts/mobile-api-smoke.mjs:282`).
- [ ] **Pastikan base URL sudah HTTPS** — runner sengaja menolak target HTTP
      non-localhost (`scripts/mobile-api-smoke.mjs:14-16`).
- [ ] **Rekam tabel acceptance perangkat manual** (geofence, fake GPS, liveness,
      idempotent retry, changed replay, tenant isolation, timezone boundary,
      push delivery, invalid push token, payslip locked/unlock/lockout).
- [ ] **Bandingkan daftar route aplikasi dengan `GET /api/v1/meta/endpoints`**
      (butuh `authenticate` + `rbac:read`) sebagai pemeriksaan terakhir.
      `mobile-routes.contract.test.ts` **tidak** cukup — ia hanya memaku path dan
      urutannya, bukan method, prefix, atau guard. (§14, §18)

## Belum terverifikasi

Dokumen ini **tidak eksahustif**. Berbeda dari draf sebelumnya, seluruh klaim di
bagian §1–§19 sudah dibaca langsung dari `backend/src` dan dari `git show`. Yang
di bawah ini adalah sisa yang **tetap tidak dapat dipastikan dari kode saja**.

1. **Tidak ada satu pun klaim di dokumen ini yang diverifikasi dengan
   menjalankan test atau server.** `tsc`, `jest`, `eslint`, dan `npm` tidak
   dijalankan. Bukti yang dipakai adalah **isi** kode dan isi test (termasuk
   assertion-nya), bukan hasil eksekusinya. Angka-angka seperti "863 test lulus"
   dari `docs/*.md` **tidak** diverifikasi ulang dan tidak dikutip di sini.
2. **Perilaku runtime terhadap server yang berjalan belum dicoba.** Beberapa
   kesimpulan di §5 (field diabaikan vs ditolak) diambil dari schema Zod dan
   contract test, bukan dari respons HTTP nyata. Tiga `403` yang disebut di §5
   **wajib** dikonfirmasi dengan satu kali percobaan sebelum logika klien dikunci.
3. **Perilaku `/sso/start` bagi klien mobile belum dicoba end-to-end.** Yang
   terverifikasi adalah bahwa `X-Client-Type` tidak dibaca di route itu; apakah
   WebView tertentu akan tetap menyimpan cookie-nya tidak dapat dijawab dari kode.
4. **Daftar `/my` yang belum paginated — risiko BREAKING di masa depan, bukan
   perubahan sekarang.** `GET /employee-loans/my`, `GET /ewa/my`,
   `GET /daily-activities/my`, `GET /travel-expenses/trips/my`,
   `GET /travel-expenses/claims/my`, dan `GET /attendance-corrections/my`
   mengembalikan **array polos pada `data` tanpa `meta`**
   (`employee-loan.controller.ts:33`, `ewa.controller.ts:41`,
   `daily-activity.controller.ts:41`, `travel-expense.controller.ts:66` dan
   `:192`, `attendance-correction.controller.ts:17`), sementara
   `GET /attendance/me`, `GET /assets/my`,
   `GET /workflow-engine/instances/my-approvals`, dan inbox announcement sudah
   memakai `Result.paginated`. Bila pagination kelak ditambahkan ke grup pertama,
   `data` **tetap** array dan hanya `meta` yang muncul — jadi dampaknya kecil,
   tapi belum ada keputusan tertulis di mana pun. Catatan: `GET /ewa/my` dan
   `GET /daily-activities/my` mengembalikan `data: []` (bukan error) bila akun
   tidak tertaut ke employee (`ewa.controller.ts:40`,
   `daily-activity.controller.ts:37`).
5. **Apakah employee biasa benar-benar mendapat `403` pada endpoint cuti dan EWA
   miliknya sendiri — bergantung pada data role, bukan pada kode.** Yang pasti
   dari kode: `GET /leave` (`leave.routes.ts:135`),
   `GET /leave/balances/employee` (`:137`), `GET /leave/types` (`:59`) menuntut
   `leave:read`; `POST /leave` (`:141`) menuntut `leave:create`; `POST /ewa`
   (`ewa.routes.ts:43`) menuntut `ewa:create`; `POST /ewa/:id/cancel`
   (`:57`) menuntut `ewa:update`. Sebaliknya `GET /ewa/my` dan `/ewa/my/limit`
   (`:31`, `:36`) serta `PATCH /leave/:id/cancel` (`:155`) **tidak** menuntut
   permission apa pun. Seed standar memberi role `EMPLOYEE` semua permission yang
   dibutuhkan (`backend/src/database/seeds/modules/03-role-permissions.seed.ts:142-157`:
   `leave:create`, `leave:read`, `ewa:create`, `ewa:read`, `ewa:update`,
   `payroll:read`, `da:*`, `travel:*`, `document:*`), **tetapi** migration
   `20260918120000_mobile_permission_matrix:60-64` hanya menambahkan
   `leave:create` dan `payroll:read` ke `EMPLOYEE`. Jadi pada tenant yang
   role-nya **tidak** berasal dari seed itu — atau yang memakai role kustom —
   `403` memang mungkin. **Uji dengan akun employee nyata di tenant tujuan.**
6. **Riwayat Git sebagian tidak dapat diatribusikan.** Untuk empat hal berikut
   **tidak ada commit yang bisa dikutip dengan bersih**, karena perubahannya
   berada di dalam commit ter-squash bersubject `test` (`64c04c8`, `af7ced8`),
   `uat phase 1` (`26dd007`), `??` (`fa1d33c`), atau `hmmm` (`a720863`):
   penutupan `/uploads/*`, pembuatan router `private-files`, predikat
   `profileSalaryAccessWhere`, dan middleware `no-store` payroll/EWA. Yang
   dikutip di dokumen ini adalah commit tempat kode itu **muncul**, bukan selalu
   commit yang **dimaksudkan** sebagai perubahannya.
7. **`collectiveLeaveId` belum dipaku kontrak.** Lihat §15: tidak ada serializer,
   `select`, maupun test yang menjaminnya tetap ada di respons leave. Mintalah
   tim backend memakukannya sebelum UI bergantung padanya.
8. **Cacat yang ditemukan tapi belum diputuskan oleh tim backend** — bukan
   perubahan yang harus ditindaklanjuti klien, tetapi perlu dilaporkan:
   (a) `X-Payslip-Unlock` tidak ada di allowlist CORS (`backend/src/app.ts:108`),
   sehingga klien browser lintas-origin terblokir di preflight — klien native
   tidak terkena; (b) `PATCH /leave/:id/reject` tidak punya validator body dan
   mengisi alasan default `'Legacy reject endpoint'`
   (`backend/src/modules/leave/leave.service.ts:465`), jadi aturan "alasan wajib"
   bisa dilewati di jalur legacy; (c) `POST /daily-activities` hanya menolak
   `employeeId` asing bila `roles` memuat literal `'EMPLOYEE'`
   (`daily-activity.service.ts:77-84`), sementara jalur absensi yang setara
   memakai allowlist role (`attendance.controller.ts:84-94`);
   (d) horizon `next-shift` diiklankan 92 hari tapi dibatasi 4 bulan kalender
   (`work-calendar.service.ts:50-56`).
9. **Pekerjaan yang ter-merge setelah verifikasi selesai.** Saat bagian ini
   ditulis, `feat/tenant-onboarding` belum ada di `main`, sehingga dikeluarkan —
   checklist migrasi tidak boleh memuat kode yang belum ter-merge. Branch itu
   kini **sudah** di `main` (`9d92e4c`), bersama gross-up (`46d6786`) dan
   perbaikan basis pajak (`5d9a99f`). Ketiganya dibahas di **§20**, yang tidak
   melewati proses verifikasi `file:line` yang sama ketatnya dengan §1–§19 —
   isinya berasal dari sesi yang menulis perubahan itu sendiri.
10. **Commit yang terlihat klien tetapi di luar permukaan mobile.**
    `516a671 feat(webhook): outbound events for external systems (GAP-38)` adalah
    integrasi keluar ke sistem eksternal, bukan endpoint yang dipanggil mobile.
    `56a5b0b feat(announcement): the write side`,
    `3a88a5c feat(performance): goal hierarchy as a free reference, cycles refused (GAP-26)`,
    dan `07cf60a feat(recruitment): headcount requisition, required only where it
    means something (GAP-22)` menambah permukaan admin/web; tidak ada di antaranya
    yang mengubah bentuk endpoint `/me`/`/my`. Tidak diperiksa lebih dalam karena
    tidak ada layar mobile yang memakainya pada rilis pertama.

### Satu klaim draf yang dihapus seluruhnya

**"Daftar `/my` pernah mengembalikan `data.items`."** Draf mencurigai bentuk lama
pernah `data.items` karena dokumen menegaskan "bukan `data.items`".
**Itu tidak pernah terjadi.** `data.items` tidak ada di source saat ini
(`rtk proxy grep -rn "data: { items" backend/src` → nol), dan tidak pernah ada di
riwayat: `git log -S"items" --all` atas
`backend/src/modules/{employee-loan,ewa,daily-activity,travel-expense}` kosong —
keempat modul itu **belum pernah memuat token `items` sama sekali**. Setiap list
controller memakai `Result.paginated(x.items, …)` sejak commit pertamanya, dan
`Result.paginated` (`backend/src/shared/core/Result.ts:26-47`) menaruh array di
`data` dan penghitungnya di `meta` — `data` secara struktur tidak mungkin menjadi
`{ items }`. **Jadi ini bukan perubahan, dan tidak ada yang perlu dikerjakan.**


---

## §20 — Tiga perubahan yang ter-merge dan live setelah dokumen ini diverifikasi

Ditambahkan belakangan, di luar jalur verifikasi §1–§19. Ketiganya sudah
ter-deploy ke production (`Health HTTP 200`, `prisma migrate deploy` bersih).

| Area | Jenis | Yang harus dilakukan klien mobile |
|---|---|---|
| Komponen slip gaji | **BREAKING kalau peta komponen di-hardcode** | jangan asumsikan daftar kode komponen tetap |
| Nominal PPh 21 di slip | perilaku | tidak ada perubahan bentuk; angkanya naik |
| Katalog cuti perusahaan baru | additive | `GET /leave/types` perusahaan baru tidak lagi kosong |

### §20.1 — Kode komponen baru `TAX_ALLOWANCE_AUTO` bisa muncul di slip gaji

`46d6786` (#42) menambahkan metode **gross-up PPh 21**: bila perusahaan
menyalakan setting `pph21_gross_up_enabled`, payroll run menambahkan satu baris
penghasilan berkode `TAX_ALLOWANCE_AUTO` (*"Tunjangan Pajak (Gross-Up)"*,
`type: ALLOWANCE`, kena pajak) senilai PPh 21 yang dipotong, sehingga
take-home karyawan tidak bergerak oleh pajak.

**Kenapa ini bisa breaking:** bentuk respons tidak berubah, tetapi **isi array
komponen bertambah satu kode yang sebelumnya tidak pernah ada**. Klien yang
memetakan kode komponen ke label lewat map/`switch` yang tertutup akan
menampilkan baris kosong, `undefined`, atau malah crash.

```diff
  "components": [
    { "code": "GP",       "type": "ALLOWANCE", "amount": 20000000 },
+   { "code": "TAX_ALLOWANCE_AUTO", "type": "ALLOWANCE", "amount": 2274175 },
    { "code": "PPH21",    "type": "DEDUCTION", "amount": 2274175 }
  ]
```

Default setting ini **mati**, jadi baris itu hanya muncul pada perusahaan yang
sengaja menyalakannya. Perlakukan kode komponen tak dikenal sebagai
"tampilkan `name` dari server", bukan sebagai kasus yang tidak mungkin terjadi.

### §20.2 — Nominal PPh 21 naik untuk karyawan yang lembur

`5d9a99f` (#45). Lembur, rapel, dan pencairan cuti sudah ditandai kena pajak
oleh payroll run, tetapi tidak pernah masuk basis perhitungan PPh 21. Sekarang
masuk. **Bentuk respons tidak berubah sama sekali** — hanya nilainya.

Dampak ke klien: tidak ada pekerjaan kode. Tapi kalau aplikasi punya layar
perbandingan slip antar-bulan atau cache slip lama, angka bulan berjalan akan
melompat dibanding bulan sebelumnya untuk karyawan yang lembur. Itu benar, bukan
bug, dan sebaiknya tidak dilaporkan sebagai anomali.

### §20.3 — Perusahaan baru lahir dengan katalog cuti dan komponen gaji

`9d92e4c` (#43). Sebelumnya perusahaan yang baru dibuat tidak punya jenis cuti
maupun komponen gaji sama sekali, sehingga `GET /leave/types` mengembalikan
array kosong dan tidak ada karyawan yang bisa mengajukan cuti. Sekarang tujuh
jenis cuti (`ANNUAL`, `SICK`, `MATERNITY`, `PATERNITY`, `MARRIAGE`,
`BEREAVEMENT`, `UNPAID`) dan empat komponen gaji dibuat otomatis.

Additive murni untuk klien. Yang berubah: **array kosong bukan lagi keadaan
normal** untuk perusahaan baru, jadi empty-state "belum ada jenis cuti" praktis
tidak akan terlihat lagi. Kode `ANNUAL` dan kawan-kawannya juga kini unique
**per perusahaan**, bukan global — relevan kalau klien pernah meng-cache jenis
cuti berdasarkan kode tanpa menyertakan perusahaan aktif.
