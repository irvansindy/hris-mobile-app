# HRIS-001 — Kontrak Autentikasi dan Identitas Employee/Company

> **Superseded untuk native mobile pada 12 September 2026.** Kontrak final dari
> backend menetapkan Bearer-only dengan `X-Client-Type: mobile`, token pada
> response body, tanpa CSRF, refresh token rotation, dan payload change-password
> `{oldPassword,newPassword}`. Dokumen ini dipertahankan sebagai catatan audit
> source backend lama. Acuan aktif ada di
> [API Integration Revision](<API_INTEGRATION_REVISION.md>).

Tanggal: 10 September 2026.

Status: **source backend terverifikasi; implementasi mapping dan pengujian lokal selesai.** Pengujian akun/server live ditunda sesuai instruksi pengguna karena akun khusus uji belum tersedia. Status ini tidak membuktikan bahwa deployment server sama dengan source lokal.

## 1. Sumber bukti dan batas pengujian

Backend ditemukan di `/home/ictsindy/Projects/node/hris-draft`, working tree bersih pada commit `fa1d33cab5b39b2956c400cca046d73915933706`.

| Sumber pada commit tersebut | Bukti kontrak |
|---|---|
| `backend/src/modules/auth/auth.routes.ts` | Route, middleware autentikasi, validator dan rate limiter |
| `backend/src/modules/auth/auth.controller.ts` | Respons HTTP, nama cookie, atribut cookie, sumber token dan body logout/refresh |
| `backend/src/modules/auth/auth.dto.ts` | Validasi email/password/TOTP/refresh/change-password |
| `backend/src/modules/auth/auth.service.ts` | `buildAuthContext`, login, MFA, lockout, refresh rotation, profile |
| `backend/src/modules/auth/auth.repository.ts` | Relasi user → employee → company, roles/company access, reset mustChangePassword |
| `backend/src/shared/middleware/Authenticate.ts` | Prioritas cookie `at`, kemudian Bearer |
| `backend/src/shared/middleware/CsrfProtection.ts` | Signed double-submit cookie, safe methods, cookie/header comparison |
| `backend/src/shared/middleware/RequestValidator.ts` dan `shared/exceptions/AppError.ts` | Envelope error, status HTTP dan field errors |
| `backend/src/app.ts` | Pemasangan cookie parser, CSRF dan auth routes pada prefix konfigurasi |
| `frontend/src/services/auth.service.ts` | Pembanding client web: cookie-only, body refresh/logout kosong |

Fixture di [auth_contract.json](../test/fixtures/auth/auth_contract.json) adalah **sintetis berdasarkan struktur source**, bukan rekaman respons akun nyata. Nama, ID, role/prioritas contoh dan token fixture bukan seed akun maupun kredensial valid. Pengujian HTTP menggunakan server fixture pada loopback; tidak menjalankan database, JWT verification, CSRF signature verification atau layanan autentikasi backend sebenarnya.

## 2. Kontrak HTTP

Path di bawah relatif terhadap prefix API, saat ini digunakan mobile sebagai `/api/v1`.

| Endpoint | Request | Respons source backend |
|---|---|---|
| `GET /auth/csrf` | Tanpa body | 200, `{success:true,message:"CSRF token issued",data:null}`; menerbitkan cookie `csrf` |
| `POST /auth/login` | `{email,password,totp?}` | 200, `{success:true,message:"Login successful",data:{user,tokens:{expiresIn}}}`; menerbitkan `at`, `rt`, `csrf` |
| `GET /auth/me` | Cookie `at` atau Bearer | 200, `data` langsung berisi user/context; bukan wajib `data.user`. Tambahan `companyName?`, `lastLoginAt` |
| `POST /auth/refresh` | Cookie `rt`; body boleh kosong. Fallback body `{refreshToken}` masih diterima | 200, `data:{user,tokens:{expiresIn}}`; merotasi cookie `at`, `rt`, `csrf` |
| `POST /auth/logout` | Protected; cookie `at`/Bearer, cookie `rt` atau fallback body `{refreshToken}` | 200, `data:null`; revoke refresh token jika ditemukan, hapus `at`, `rt`, `csrf` |
| `POST /auth/change-password` | Protected; `{currentPassword,newPassword}` dan CSRF bila memakai cookie auth | 200, `data:null`; set `mustChangePassword=false` dan revoke seluruh refresh token user |
| `GET /auth/sessions` | Protected | Daftar sesi user |
| `DELETE /auth/sessions/:id` | Protected, CSRF untuk cookie auth | Revoke sesi tertentu |
| `POST /auth/mfa/setup`, `/enable`, `/disable` | Protected; enable/disable menerima `{code}` | Setup MFA, enable beserta recovery codes, atau disable |

`forgotPasswordSchema` dan `resetPasswordSchema` ada di DTO, tetapi route `/auth/forgot-password` dan `/auth/reset-password` **tidak dipasang** pada `auth.routes.ts` yang diperiksa. Keberadaan schema atau halaman web tidak membuktikan endpoint tersebut tersedia.

### Validasi login dan ganti password

- Email login wajib berupa email valid, maksimal 255 karakter, ditransformasi lower-case dan trim oleh backend. Username bukan field login pada kontrak ini.
- Password login wajib, panjang 1–128 karakter.
- `totp` opsional pada schema, panjang 6–20 setelah trim; diperlukan oleh service jika MFA aktif. Service juga menerima recovery code lewat field yang sama.
- `currentPassword` wajib. `newPassword` panjang 8–128, memerlukan huruf besar, huruf kecil, angka dan karakter khusus yang diterima schema; service menolak password sama dengan sebelumnya.
- `mustChangePassword` dikirim sebagai flag. Source authenticate yang diperiksa tidak memasang guard flag tersebut; mobile belum memiliki form/gate-nya. Implementasi UX ada pada HRIS-008.
- Perubahan password merevoke refresh token; jangan mengasumsikan semua access token langsung tidak valid saat itu juga.

### Cookie dan CSRF

| Cookie | Nilai | Path | HttpOnly | SameSite | Secure | Masa berlaku cookie source |
|---|---|---|---|---|---|---|
| `at` | JWT access token | `/` | true | lax | true saat `config.app.env === production` | 15 menit |
| `rt` | JWT refresh token | `/api/v1/auth` | true | lax | true saat production | 7 hari |
| `csrf` | `nonce.signature` | `/` | false | lax | true saat production | Tidak diberi Max-Age oleh middleware |

Domain tidak diatur eksplisit oleh controller. TTL JWT berasal dari konfigurasi; `tokens.expiresIn` berisi durasi access JWT. TTL cookie controller ditetapkan terpisah, sehingga keselarasan konfigurasi TTL harus diperiksa pada deployment.

Aturan transport yang ditemukan:

1. Middleware authenticate membaca `at` terlebih dahulu; Bearer adalah fallback apabila `at` tidak ada.
2. Refresh memilih cookie `rt` sebelum field body `refreshToken`.
3. GET/HEAD/OPTIONS tidak memerlukan CSRF. Mutasi yang membawa `at` atau `rt` memerlukan cookie `csrf` dan header `X-CSRF-Token` dengan nilai yang cocok serta signature valid.
4. Bearer-only tanpa cookie auth dikecualikan dari pemeriksaan CSRF. Tetapi endpoint login/refresh source ini tetap mengeluarkan token melalui cookie, bukan body Bearer.
5. Login awal tanpa cookie auth tidak memerlukan bootstrap CSRF. Bila request login membawa cookie auth lama, middleware CSRF tetap berlaku.
6. Controller source tidak mengembalikan `data.csrfToken`. Mobile sekarang membaca cookie `csrf`; fallback field body dipertahankan untuk kompatibilitas dengan log deployment lama yang diberikan sebelumnya.

Pembatasan domain/path/expiry cookie dan adapter browser kemudian diselesaikan secara lokal pada [HRIS-004](<HRIS-004 Cookie dan CSRF.md>). Perubahan HRIS-001 sendiri hanya menyelaraskan pengenalan nama cookie dan pembacaan CSRF yang diperlukan kontrak ini.

## 3. Identitas user, employee dan company

`buildAuthContext` dipakai bersama oleh login, refresh dan `/me`.

| Field respons | Sumber backend | Perlakuan mobile |
|---|---|---|
| `id` | `user.id` | Identitas akun; wajib untuk respons login; tidak digunakan sebagai pengganti employee ID |
| `email` | `user.email` | Identitas login; fallback display name saja |
| `employeeId?` | `user.employeeId` | Dipertahankan bila ada; tidak dibuat dari role/nama/email |
| `name?` | `user.employee.fullName` | Nama tampilan; akun tanpa employee dapat tidak mengirimnya |
| `companyId?` | Company milik employee, fallback company pertama pada assignment user role | Company utama dari backend; bukan hasil menebak dari user ID |
| `companyScope` | Union company utama, company user roles, explicit company accesses; dapat diperluas ke company aktif dalam group untuk group-wide access | List scope dipertahankan; bukan daftar employee |
| `groupId?` | Employee company group, fallback company access/group dan role group | Nullable |
| `roles` | Kode role dari `userRoles` | Dipertahankan; role manager pada fixture hanya contoh |
| `permissions` | Gabungan unik `resource:action` dari role permissions | Format memakai titik dua, misalnya `attendance:read` |
| `hasGlobalRole` | Assignment scope GLOBAL atau role scope GLOBAL | Sekarang dipertahankan sampai entity, storage dan request context |
| `maxRolePriority` | `Math.max(0, ...priority role)` | Sekarang dipertahankan, tanpa mengubah atau menafsirkan ulang urutannya |
| `mustChangePassword` | Flag user | Dipertahankan; penegakan alur login merupakan task berikutnya |

Konsekuensi:

- Employee dan manager dapat memiliki employee/company, tetapi keanggotaannya ditentukan data backend, bukan nama role.
- Admin global tanpa employee dapat mengirim `companyScope:[]` serta tidak mengirim employee/company/group. Kondisi ini adalah sesi valid, bukan error parsing.
- Tidak perlu memanggil `/employees/:id` untuk menebak employee ID; `/auth/me` sudah mengirim referensi bila akun terhubung. Endpoint employee dipakai untuk detail setelah ID diketahui.
- Field opsional yang dihilangkan pada `/me` harus menghapus afiliasi lama dalam objek sesi. Penggabungan user sekarang memperlakukan profil `/me` sebagai snapshot penuh, bukan partial patch.
- Pemilihan company aktif dari scope dan akses layar ESS masih mengikuti controller yang ada; finalisasi kebijakan non-employee/company selection termasuk HRIS-008/022.
- Menyimpan role/global flag tidak memberikan otorisasi dengan sendirinya; server tetap memutuskan akses setiap endpoint.

## 4. Error yang harus dipertahankan

| HTTP | Code | Pemicu berdasarkan source |
|---|---|---|
| 401 | `AUTHENTICATION_FAILED` | Email/password salah, MFA salah, refresh invalid, atau token autentikasi tidak tersedia |
| 401 | `MFA_REQUIRED` | Password benar tetapi akun MFA belum menerima `totp` |
| 401 | `TOKEN_EXPIRED` | Token expired dari lapisan security/error terkait |
| 403 | `FORBIDDEN` | Akun inactive/suspended; CSRF tidak ada/tidak cocok/invalid |
| 422 | `VALIDATION_ERROR` | Body gagal schema; `errors:[{field,message}]` |
| 429 | `TOO_MANY_REQUESTS` | Rate limiter atau lockout account; ambang dari konfigurasi, bukan angka hardcode mobile |
| 409 | `CONFLICT` | Password baru sama dengan lama |

Mobile mempertahankan status/code/message/field errors di `ApiException` pada datasource. Login 401 sudah dikecualikan dari auto-refresh pada HRIS-003. UI MFA dan countdown lockout tetap masuk HRIS-008. Tidak ada endpoint unlock/forgot-password baru yang ditebak dalam perubahan ini.

## 5. Perubahan implementasi HRIS-001

- `cookieValue` membaca nama cookie secara tepat dan men-decode nilai untuk header CSRF; encoding rusak dianggap invalid.
- DTO login mensyaratkan user ID dan access credential (`at` untuk cookie mode, atau field Bearer lama). Cookie `csrf`/`rt` saja tidak cukup.
- CSRF cookie diutamakan daripada field body lama, termasuk ketika response interceptor menyimpan cookie dan ketika refresh merotasi token.
- `hasGlobalRole` dan `maxRolePriority` dipertahankan dalam DTO, domain entity, secure session JSON dan `RequestContext`.
- Snapshot `/me` mengganti field user sebelumnya sehingga employee/company yang sudah dilepas tidak tertinggal.
- Kompatibilitas respons Bearer sebelumnya tetap diuji; tidak ada perubahan role navigation, UI MFA, reset provider lintas akun, atau refactor refresh single-flight dalam tahap ini.

## 6. Pengujian lokal

Test utama: [auth_api_contract_test.dart](../test/features/authentication/auth_api_contract_test.dart), test helper [cookie_session_test.dart](../test/core/cookie_session_test.dart), dan regresi DTO/repository yang sudah ada.

| Skenario | Yang dibuktikan |
|---|---|
| Employee / manager / admin | Parsing DTO, persist metadata, dan pemetaan request context; admin tidak diberi employee/company fiktif |
| Scope company manager | Company dalam scope dapat dipilih, company di luar scope ditolak client |
| `/me` berupa objek user langsung | Shape sesuai controller dan penghapusan afiliasi employee lama |
| `at`, `rt`, `csrf` pada response login | Login tidak lagi memerlukan `data.csrfToken` |
| Cookie non-auth, `rt` tanpa `at`, cookie kosong | Tidak membentuk sesi login |
| Cookie login tanpa CSRF / user ID hilang | Respons ditolak sebagai format tidak lengkap |
| CSRF cookie vs body legacy | Nilai cookie terkini dipakai, percent-encoding ditangani |
| 401/403/422/429 | Code/message/status/field error dipertahankan oleh datasource, termasuk `MFA_REQUIRED` |
| HTTP 200 `success:false` | Tidak menghasilkan sesi login |
| HTTP loopback login → `/me` → 401 → refresh → retry `/me` → logout | Dio menerima header nyata dari server fixture, menyimpan dan mengirim cookie/CSRF hasil rotasi, body refresh/logout kosong, storage dibersihkan |

Perintah reproduksi:

```sh
flutter analyze
flutter test test/features/authentication/auth_api_contract_test.dart
flutter test
```

Test HTTP menggunakan port acak pada `127.0.0.1`, tidak memanggil host development/production, dan menggunakan secure-storage mock. Pengujian ini membuktikan kompatibilitas client dengan fixture kontrak; bukan pembuktian validasi signature, password, database, TTL atau permission server.

## 7. Penutupan tahap dan tindak lanjut

- Verifikasi source dan dokumentasi: selesai pada commit backend yang dicatat.
- Penyesuaian mobile dan fixture sintetis: tersedia untuk review.
- Akun employee A/B, manager dan admin live: belum tersedia; tidak dibuat dan tidak dicoba menebak kredensial.
- Uji backend deployment serta perangkat Android/iOS/web: belum dilakukan, ditunda sesuai pilihan pengguna.
- Bug lifecycle sesi/rotasi dan cookie scoping telah ditutup secara lokal pada HRIS-002 sampai HRIS-004. UI MFA/change-password dan task HRIS-005 sampai HRIS-008 tetap terbuka. Lulusnya test kontrak ini tidak menutup seluruh gate sesi atau membuktikan deployment live.

Untuk verifikasi live berikutnya, gunakan akun khusus uji pada environment yang disepakati, rekam hanya status/schema/nama-atribut cookie tanpa nilainya, dan pastikan versi deployment cocok. Jangan menjalankan percobaan password berulang untuk menguji lockout pada akun pengguna nyata.
