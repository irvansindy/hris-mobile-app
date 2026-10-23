# Tahap 6 Task 3: Lifecycle Push dan Isolasi Sesi

Tanggal: 10 Oktober 2026
Status pengujian lokal: PASS
Status Firebase/delivery OS: belum diaktifkan

## Implementasi

- Coordinator app-scoped menserialkan register/unregister. Callback memeriksa generation dan FeatureSession agar response akun/company lama tidak mengaktifkan sesi baru.
- Hook pada layer `app` mengikuti restore, login, logout, auth invalidation, dan perubahan company. Bind menunggu auth selesai, employee/company valid, dan mandatory password change terselesaikan. Push disabled tidak mengaktifkan coordinator.
- Setiap bind menangkap registry-nya sebelum cleanup berjalan. Cleanup A menggunakan registry A, kemudian token lokal dihapus sebelum registration B. ID instalasi tetap stabil; token B berbeda dari token A.
- Rotation selama registration tertunda direkonsiliasi ke token terbaru. Explicit retry mempertahankan command dan idempotency key saat token belum berubah; token baru mendapat key baru.
- Unbind segera menonaktifkan state/event, melepas subscriptions, dan mengosongkan command lokal. Cleanup memakai timeout konfigurasi sehingga kegagalan tidak menunggu tanpa batas.
- Jika penghapusan token gagal, registration baru ditahan sampai retry reset berhasil. Login/inbox tidak diblokir. Permission denied dan adapter/registry failure ditampilkan sebagai state coordinator, tanpa loop retry.
- Status memakai `simulated`, bukan klaim registration Firebase nyata. Registry tetap in-memory; tidak ada token dummy yang dikirim melalui Dio.

Tidak ada perubahan desain, key Firebase palsu, persistensi token/payload, atau logger baru. Artifact cleaner authentication yang lama tidak dijadikan pemilik push dummy; koordinasi berjalan dari bootstrap aplikasi.

## Regression yang Diperbaiki

Test membuktikan RED lalu GREEN untuk bootstrap yang belum melakukan bind, reuse token setelah delete gagal, serta status permission yang dicabut.

Integrasi juga memunculkan callback auth yang masih memanggil router setelah disposal. Riverpod mengiterasi snapshot listener; menutup subscription saja belum cukup jika callback sudah masuk snapshot tersebut. Router kini menutup subscription dan memeriksa flag lifecycle. Test integrasi restore/router dan demo app lulus setelah perbaikan.

Full suite pertama menemukan pelanggaran cross-feature import dan fixture navigasi yang belum mengatur push. Hook auth-to-push dipindah ke `lib/app/providers/push_lifecycle.dart` tanpa mengubah allowlist. Fixture offline menggunakan override push disabled, tanpa mengaktifkan network repository lain.

## Bukti Pengujian

- 14 test coordinator/integrasi: retry, rotation, register A tertunda, urutan unregister A sebelum B, logout offline, deadline register/cleanup, company switch, permission, kegagalan reset token, disposal, disabled mode, dan restore/logout/login melalui AuthController.
- Integrasi auth membuktikan mandatory password change serta akun tanpa employee tidak melakukan registration. ID instalasi bertahan pada pergantian akun, token diperbarui, dan Dio yang dilarang di fixture dummy tidak diakses.
- Suite notifikasi/auth/session/demo/router: 112 test lulus. Architecture guard dan fixture navigasi yang kemudian disesuaikan ikut lulus dalam full suite.
- `rtk flutter test`: 598 test lulus, termasuk golden, pada checkout aktif.
- `rtk flutter analyze`: 0 issue.
- `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`: 270 file, 0 perubahan.
- `rtk git diff --check`: tidak ada whitespace error.

## Batas dan Handoff

Timeout atau cancellation tidak membuktikan server membatalkan request yang sudah diterima. Cleanup offline, credential snapshot untuk adapter Firebase/Dio nyata, lock-screen privacy, delivery Android/iOS, dan konfigurasi partner tetap gate live. Future adapter nyata harus memakai coordinator ini; jangan menambahkan penghapusan token global dari cleaner tertunda yang dapat menyentuh akun berikutnya.

Task 4 belum selesai: lookup ID melalui inbox terpercaya, routing tap, pending intent saat auth restore/login, deduplication tap, serta status panel dan simulator UI. Tidak ada navigasi baru dari event push pada Task 3.

Build APK baru dan final review lintas-task masuk Task 5. Hasil lokal pada checkout aktif belum menjadi bukti remote CI atau clean checkout seluruh roadmap. Commit hanya mengambil file/hunk Task 3; perubahan tahap sebelumnya tetap dipertahankan.
