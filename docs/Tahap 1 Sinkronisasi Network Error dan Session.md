# Tahap 1 — Sinkronisasi Network, Error, dan Session

Tanggal verifikasi: 6 Oktober 2026  
Status: **PASS untuk implementasi dan pengujian lokal**

## Hasil Implementasi

- `error.code` tetap nullable. Error tanpa kode tidak ditebak sebagai token
  kedaluwarsa dan tidak memicu refresh otomatis.
- Interceptor hanya menjalankan refresh untuk respons 401 dengan kode
  `TOKEN_EXPIRED` atau `AUTHENTICATION_FAILED`, maksimal satu kali per
  request dan single-flight untuk request paralel.
- `PAYROLL_UNLOCK_REQUIRED` dan `PAYROLL_REAUTH_FAILED` tidak memicu refresh,
  logout, atau pemetaan sebagai kegagalan sesi.
- Semua request mendapat `X-Correlation-Id`. Retry mempertahankan correlation
  ID request awal, sedangkan refresh menggunakan ID baru.
- `X-Client-Type: mobile` hanya dikirim pada login dan refresh.
- Refresh native mewajibkan pasangan token dan snapshot user yang lengkap.
  Token, user, role, permission, company scope, dan metadata sesi disimpan
  bersama sebelum state aplikasi dipublikasikan ulang. Menu ikut dievaluasi
  ulang melalui permission terbaru.
- Pergantian otoritas untuk user/company yang sama membangun ulang cache
  feature tanpa membatalkan retry HTTP yang sedang berjalan. Pergantian akun,
  company, atau revision tetap menolak respons lama.
- Logout tetap local-first: token dan session dibersihkan, provider/cache
  per-account diinvalidasi, data Face ID lokal dijadwalkan untuk dihapus, dan
  token FCM lokal dicabut bila Firebase aktif.

## Pengujian

- `rtk flutter analyze` — **PASS**, tidak ada issue.
- `rtk flutter test` — **PASS**, 444 test.
- Cakupan regresi baru: nullable code, dua payroll 401, single-flight lintas
  client, correlation ID, retry final 401, rotasi authority, publikasi state
  auth, logout artifact cleanup, dan late-response session isolation.

## Batas Tahap

- Registrasi serta penghapusan `installationId` melalui
  `/notifications/device-tokens` dikerjakan di Tahap 6 bersama konfigurasi
  Firebase Android/iOS.
- Verifikasi terhadap server staging belum dilakukan karena HTTPS staging dan
  akun acceptance belum tersedia. Hal ini tidak mengubah hasil test lokal.
