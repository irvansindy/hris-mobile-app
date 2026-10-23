# Tahap 6 Task 1: Pagination dan Kontrak Registration

Tanggal: 9 Oktober 2026
Status pengujian lokal: PASS
Status push Firebase nyata: belum diaktifkan

## Hasil

- Inbox memakai `page` dan limit tetap 50. Load-more menambah halaman berikutnya, deduplicate ID, dan mempertahankan item/page lama saat gagal. Refresh kembali ke halaman pertama.
- Repository memvalidasi metadata pagination, data item, serta identitas akun/company. Read, read-all, delete, dan rollback tetap berjalan.
- Repository registration menyediakan POST `/notifications/device-tokens` dan DELETE dengan body JSON installation ID. Provider wire FCM; Android/iOS didukung oleh kontrak, bukan bukti delivery OS.
- Payload dibatasi sesuai OpenAPI. Header idempotency mengikuti 16 hingga 128 karakter ASCII terlihat dan dipertahankan untuk retry command yang sama.
- ID instalasi acak 32 karakter hex tersimpan per namespace environment, tanpa user ID atau hardware ID. Token push tidak dipersist.
- Demo dan fixture mengikuti interface page baru. Tidak ada perubahan desain atau golden yang diperlukan.

Repository registration belum dihubungkan ke bootstrap atau login. Seluruh pengujian HTTP memakai adapter mock, tanpa mengirim token contoh ke server. Adapter push dummy dan simulator merupakan task berikutnya.

## Bukti Pengujian

- Metadata rusak dan kenaikan limit berhasil direproduksi pada kondisi lama sebelum perbaikan.
- Test registration awal gagal karena interface belum tersedia; test tambahan memverifikasi validasi idempotency yang salah sebelum disesuaikan dengan kontrak.
- `rtk flutter test test/features/notifications test/features/secondary_presentation_parity_test.dart`: 35 test lulus.
- `rtk flutter test`: 574 test lulus, termasuk golden, pada checkout aktif.
- `rtk flutter analyze`: 0 issue.
- `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`: 264 file, 0 perubahan.
- `rtk git diff --check`: tidak ada whitespace error.

## Keputusan dan Batasan

`InstallationIdentity.getOrCreate()` mengembalikan `Future<String>` agar penyimpanan preferences ditunggu sebelum ID digunakan. Konsekuensinya, coordinator pada task berikutnya harus menggunakan await.

Pekerjaan tetap pada checkout aktif karena bergantung pada perubahan tahap sebelumnya yang belum di-commit. Fixture yang sudah tracked di-stage hanya pada hunk notification. Penyesuaian file demo/parity yang sebelumnya untracked dan satu test demo dalam hunk pekerjaan lama tetap ada di working tree; tidak digabungkan diam-diam ke commit Task 1. Hasil test ini belum menjadi bukti remote CI atau clean checkout seluruh roadmap.

Task 2 sampai 5 serta final review lintas-task belum selesai. Firebase/APNs config, delivery device, HTTPS, logout offline privacy, dan acceptance account switch tetap menjadi gate live.
