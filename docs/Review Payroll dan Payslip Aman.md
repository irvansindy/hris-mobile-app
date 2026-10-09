# Review Payroll dan Payslip Aman

Tanggal: 9 Oktober 2026. Cakupan: final review implementasi payroll employee pada checkout aktif, bukan sertifikasi release production.

## Temuan dan Penyelesaian

| Temuan | Penyelesaian | Bukti |
| --- | --- | --- |
| Expiry tidak otomatis menyembunyikan rincian/PDF | Timer grant mengunci controller; response terlambat tidak dipublikasikan; byte PDF dibersihkan | Test expiry tanpa request baru dan PDF terlambat |
| PIN dan rincian belum dilindungi platform | `SensitiveScreen` melindungi seluruh flow; reference count menjaga proteksi saat route bertumpuk | Mock platform saat PIN/rincian dan nested screen test |
| Lifecycle hanya terpasang pada halaman daftar | Observer dimiliki provider; detail selalu memvalidasi grant saat dibuka | Background setelah keluar halaman payroll |
| Timestamp keamanan menerima tanggal overflow/tanpa timezone | Parser ketat untuk `expiresAt` dan `lockedUntil` | Contract test timestamp invalid |
| Lockout masih memungkinkan submit; PIN belum diset tidak dipulihkan | Tombol disabled selama lockout; `PIN_NOT_SET` kembali ke setup; pesan durasi memakai deadline | Widget lockout test dan golden light/dark |
| Error JSON pada request binary kehilangan kode | Decode error JSON terbatas 64 KiB sebelum mapper; envelope mengikuti top-level `code/message` OpenAPI | Contract test `PAYSLIP_UNLOCK_INVALID` dari PDF |
| Error PDF tidak terlihat jika detail tersedia | Error dan retry ditempatkan sebelum rincian | Widget PDF failure test |
| PDF demo hanya berisi header | Fixture PDF valid dengan halaman, font, xref, trailer | PDFium membuka dan merender satu halaman |
| Prefix MIME terlalu longgar | MIME essence harus tepat `application/pdf` | Test menolak `application/pdf-malicious` |

Regresi expiry, proteksi layar, error PDF, lockout, timestamp, dan renderer direproduksi sebelum perbaikan. Golden berubah hanya pada dua state lockout yang disengaja.

## Keputusan dan Batasan Review

- Checkout aktif dipertahankan karena payroll bergantung pada pekerjaan tahap sebelumnya yang belum di-commit. Hanya file payroll/proteksi terkait yang masuk commit. Biaya: clean checkout belum menjadi bukti integrasi seluruh roadmap.
- `RequestContext` tetap menjadi dependency domain vault yang diizinkan secara eksplisit. Jika boundary ini berubah, ekstrak session identity netral; import core lainnya tetap dibatasi.
- Tidak menambah hook payroll ke `AuthController`: invalidasi `featureSessionProvider` dan fingerprint user/employee/company menjadi batas isolasi. Jalur autentikasi baru yang tidak mengubah session harus menambah invalidasi.
- Dugaan kebocoran lintas akun melalui route PDF tidak diterima sebagai bug terpisah: router mengikuti session, provider diinvalidasi, viewer mengikuti state grant, dan byte lokal dibersihkan. Tetap perlu acceptance account switch di device.
- `pdfrx` memakai data memori tanpa file permanen aplikasi. Cache internal renderer tetap perlu pemeriksaan platform; tidak diklaim bebas cache OS.
- Pemblokiran semua screenshot iOS tidak dijanjikan. Privacy cover inactive/capture harus diverifikasi pada iOS native; Android `FLAG_SECURE` juga perlu acceptance device.
- Nominal pecahan masih ditampilkan bulat mengikuti formatter rupiah yang ada. Review minor ini ditunda sampai kontrak tampilan precision disepakati; mapping repository tetap mempertahankan nilai pecahan.
- Kepemilikan payslip dan kompatibilitas server belum divalidasi live tanpa HTTPS/akun/fixture. Tidak menandai gate tersebut PASS.
- Nama report mengikuti Tahap 5 pada roadmap berbasis Tahap 0; tahap berikutnya adalah push notification dan deep link.
- Ledger eksekusi dipertahankan selama prerequisite dan gate platform/live belum selesai agar jejak keputusan tidak hilang.

Hasil verifikasi final dan blocker release dicatat dalam [report tahap payroll](<Tahap 5 Payroll dan Payslip Aman.md>).
