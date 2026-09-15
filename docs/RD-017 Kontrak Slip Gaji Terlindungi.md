# RD-017: Kontrak slip gaji terlindungi

Status: BLOCKED untuk implementasi fitur. Verifikasi kontrak lokal dilakukan pada 15 September 2026; bukan verifikasi deployment.

## Kontrak yang tersedia

`mobile-api.md` bagian 4.12 menyediakan `GET /payroll/payslips` dan `GET /payroll/payslips/:id`, dengan permission `payroll:read`, self scope, dan run APPROVED/DISBURSED. Dokumen belum menentukan schema respons, list periode tanpa nominal, challenge PIN, verify, unlock expiry, PDF, maupun download/share.

Source backend lokal lama hanya menjadi bukti pendukung: `payroll.repository.ts` mengembalikan objek payslip beserta components; `payroll.service.ts` membentuk breakdown memakai baseSalary, totalEarnings, totalDeductions, dan netPay. Tidak ditemukan route PIN/unlock dalam modul payroll. Source ini bukan kontrak deployment final dan tidak dipakai untuk mengarang endpoint baru.

Menyembunyikan nominal di UI setelah menerima respons tidak memenuhi syarat RD-017: nominal tidak boleh diterima sebelum server unlock. Biometric/PIN lokal juga tidak dapat menggantikan verifikasi server.

## Yang perlu dikirim backend

Daftar berikut merupakan kebutuhan integrasi, bukan endpoint atau schema yang sudah disepakati:

1. Contoh respons tersanitasi list periode yang tidak memuat nominal/components, permission, dan scope employee/company dari sesi server.
2. Kontrak challenge/verify PIN atau reauthentication, pengaturan PIN, error PIN salah, lockout/rate limit, serta mekanisme biometric bila didukung server. PIN tidak disimpan atau dicatat client.
3. Bukti unlock yang terikat sesi, employee/company, masa berlaku, dan aturan revoke/relock pada logout, pergantian akun, background, atau sesi kedaluwarsa.
4. Kontrak detail hanya setelah unlock, lengkap dengan currency, periode, nilai desimal, komponen, THR, dan status run yang boleh dibaca.
5. Kontrak PDF berizin: content type, batas ukuran, expiry, aturan redirect/URL, dan kebijakan download/share. File sementara harus dibersihkan; share ke aplikasi luar harus dijelaskan sebagai ekspor yang tidak bisa ditarik kembali.
6. Fixture acceptance untuk identity mismatch, periode terlarang, unlock expired, PIN salah/lockout, respons/file gagal, dan akses akun lain yang ditolak server.

## Keputusan client saat kontrak belum lengkap

- Tidak memanggil kedua endpoint payroll pada bootstrap Beranda/Profil.
- Tidak membuat sheet PIN, biometric sukses lokal, nominal contoh, PDF contoh, atau tombol download/share yang belum bekerja.
- Profil mempertahankan keterangan dokumen belum tersedia. Salary dari respons employee tidak dipetakan ke state Profil.
- Screenshot protection dan cleanup file sensitif belum diklaim diterapkan untuk payroll; keduanya harus diuji pada Android/iOS setelah kontrak dan fitur tersedia.

## Bukti lokal

`test/features/profile/profile_api_contract_test.dart` memeriksa salary server tidak dipetakan. Test navigasi shell memeriksa tombol Slip gaji tidak dirilis. Regresi Tahap 5 mempertahankan guard ini, termasuk ketika sesi memiliki permission payroll:read. Akun uji/staging belum tersedia sesuai arahan pengguna sebelumnya.
