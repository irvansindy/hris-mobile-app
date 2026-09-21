# Report Tahap 4, Keamanan Akun dan Endpoint Pendukung

Tanggal: 19 September 2026  
Status: PASS lokal, PARTIAL live, PENDING real device

## 1. Ringkasan hasil

Tahap 4 mengimplementasikan keamanan akun dan penghapusan notifikasi tanpa menebak informasi yang belum diberikan server.

- menu `Keamanan akun` tersedia dari halaman Profil;
- setup, enable, dan disable MFA memakai endpoint resmi;
- QR secret dan recovery codes tidak disimpan ke provider, secure storage, cache, atau log jaringan;
- daftar sesi aktif dan revoke sesi sudah tersedia;
- logout lokal setelah revoke hanya berjalan bila server secara eksplisit menandai sesi sebagai current;
- notifikasi mempunyai aksi hapus dengan konfirmasi, optimistic removal, dan rollback visual saat request gagal;
- endpoint holiday belum dipakai sebagai fallback karena resolved calendar sudah lengkap dan tenant contract holiday backend belum aman;
- seluruh regresi lokal, analysis, golden, dan build APK debug lulus.

## 2. Implementasi

### API-301, MFA

Client memvalidasi kontrak berikut:

| Operasi | Kontrak response minimum |
|---|---|
| `POST /auth/mfa/setup` | `secret` non-kosong dan `qrDataUrl` PNG base64 valid, maksimum 2 MiB |
| `POST /auth/mfa/enable` | body `{code}` 6 sampai 20 karakter dan `recoveryCodes` non-kosong/unik |
| `POST /auth/mfa/disable` | body `{code}` 6 sampai 20 karakter dan envelope sukses |

Perlindungan data sensitif:

- repository tidak menulis secret atau recovery code ke storage;
- provider MFA hanya menyimpan status runtime `unknown`, `enabled`, atau `disabled`, busy state, dan pesan error;
- secret hanya berada pada object lokal layar setup sampai bottom sheet ditutup;
- recovery codes hanya berada pada dialog satu kali dan dialog tidak dapat ditutup sebelum pengguna mengonfirmasi sudah menyimpannya;
- input OTP dibersihkan setelah submit dan ketika dialog/sheet dibuang;
- network logger proyek hanya mencatat method, status, durasi, dan sequence ID, tanpa path, body, response, token, secret, atau kode;
- status MFA awal ditampilkan `Status belum tersedia` karena `/auth/me`, login, dan refresh belum mengirim field status MFA.

### API-302, sesi aktif

`GET /auth/sessions` dipetakan secara strict ke:

- `id` unik;
- `userAgent` dan `ipAddress` opsional;
- `createdAt` dan `expiresAt` wajib valid;
- `current` atau `isCurrent` hanya diterima bila berupa boolean.

Revoke memakai `DELETE /auth/sessions/:id`, confirmation dialog, busy state per row, serta refresh state berdasarkan hasil server. Aplikasi tidak menandai sesi terbaru sebagai current karena urutan waktu bukan bukti identitas perangkat.

Jika backend kelak mengirim `current: true` atau `isCurrent: true`, revoke sukses pada row tersebut langsung menjalankan cleanup auth lokal dan kembali ke login. Deployment sekarang tidak mengirim field itu, sehingga acceptance revoke current session masih BLOCKED backend.

### API-303, hari libur

Layar Kalender tetap memakai `GET /work-calendars/me/resolved` sebagai satu-satunya sumber agenda. Response tersebut sudah mewajibkan setiap hari pada bulan terkait dan sudah memetakan `dayType: HOLIDAY`, label, serta catatan. Menambahkan holiday list akan menduplikasi event.

`GET /work-calendars/holidays/list` berhasil dijangkau live dengan `companyId` dari session dan menghasilkan list kosong. Namun source backend saat ini memanggil repository menggunakan `req.query.companyId`, bukan company dari authenticated session. Karena client tidak boleh menentukan tenant target, endpoint ini tidak dihubungkan ke UI sampai backend:

1. mengambil `companyId` dari `req.user.companyId` atau middleware tenant resmi;
2. mengabaikan atau menolak query company di luar scope;
3. menyediakan fixture hari libur untuk batas bulan;
4. menjelaskan kapan holiday list harus melengkapi resolved calendar.

Keputusan ini menjaga kalender dari data lintas tenant dan duplikasi event.

### API-304, hapus notifikasi

Repository dan UI kini memakai `DELETE /notifications/:id` dengan ID terenkode dan tervalidasi. Alur:

1. pengguna menekan ikon hapus 44x44;
2. dialog menyebut judul notifikasi yang akan dihapus;
3. setelah konfirmasi, item dihapus secara optimistis dan mutation tunggal dikunci;
4. sukses mempertahankan item terhapus dan me-refresh unread badge;
5. kegagalan memulihkan snapshot list, menampilkan live error, dan me-refresh badge dari server;
6. hasil request lama diabaikan setelah logout atau pergantian akun.

## 3. Hasil test lokal

| Gate | Hasil |
|---|---|
| Contract test keamanan akun | PASS, method/path, QR PNG, recovery codes, schema sesi, malformed response |
| State test MFA | PASS, secret dan recovery code tidak masuk state provider |
| Session isolation | PASS, hasil request akun lama tidak mencemari akun baru |
| Current-session callback | PASS bila dan hanya bila response menandai current secara eksplisit |
| Notification delete rollback | PASS, item pulih pada failure dan hilang pada success |
| Layout 320dp, text scale 200% | PASS, light dan dark tanpa overflow |
| Golden 390x844 | PASS, security light/dark dan inbox light/dark |
| Seluruh test proyek | PASS, 350 test |
| `flutter analyze` | PASS, no issues found |
| `flutter build apk --debug` | PASS |
| `git diff --check` | PASS |

APK debug:

- path: `build/app/outputs/flutter-apk/app-debug.apk`;
- ukuran: `204372754` byte;
- SHA-256: `0ff5f4de028ae6fb5cd5fffd9057bc32a968fbd94b906c86a373b7f5793ed00b`.

Build masih menampilkan warning migrasi Built-in Kotlin dari `package_info_plus`. Warning tidak menggagalkan build, tetapi dependency perlu diperbarui sebelum Flutter menghentikan dukungan pola KGP lama.

## 4. Hasil smoke probe live

Probe memakai akun uji dan transport HTTP yang sebelumnya disetujui. Tidak ada setup MFA, enable/disable valid, revoke sesi nyata, atau delete notifikasi nyata yang dijalankan.

| Skenario | HTTP | Hasil |
|---|---:|---|
| Login employee | 200 | PASS |
| Login manager | 200 | PASS |
| Daftar sesi employee | 200 | PASS, 5 sesi, tetapi tidak ada field current |
| Revoke session sentinel | 500 | ROUTE REACHABLE, defect backend: ID tidak ditemukan seharusnya 404 |
| Enable MFA dengan kode 3 karakter | 422 | PASS negative validation, tidak mengubah MFA |
| Disable MFA dengan kode 3 karakter | 422 | PASS negative validation, tidak mengubah MFA |
| Holiday list tenant/year akun | 200 | PASS route, list kosong |
| Delete notification sentinel | 404 | PASS route/not-found, tidak menghapus data |
| Logout manager | 200 | PASS |
| Logout employee | 200 | PASS |

Ringkasan runner: 6 `PASS`, 2 `REACHABLE_EXPECTED_REJECTION`, dan 2 `REACHABLE_PREREQUISITE_MISSING`.

Artefak tersanitasi berada di `/tmp/hris-mobile-stage4-probe.json`, permission `600`. Scan tidak menemukan access token, refresh token, authorization, password, cookie, email, MFA secret, QR data, atau recovery codes.

## 5. Temuan yang perlu diperbaiki backend

1. Tambahkan boolean status MFA pada login, refresh, dan `/auth/me` agar client dapat menampilkan status setelah restart.
2. Tambahkan `current: true` pada tepat satu sesi atau kembalikan `sessionId` pada login/refresh agar revoke current session dapat diverifikasi.
3. Ubah revoke ID yang tidak ada dari HTTP 500 `INTERNAL_ERROR` menjadi 404 idempotent/not-found yang terdokumentasi.
4. Ambil tenant holiday dari authenticated session, bukan `req.query.companyId`.
5. Sediakan fixture notifikasi khusus yang aman dihapus dan fixture hari libur pada batas bulan.
6. Sediakan akun khusus untuk positive MFA flow. Setup menghasilkan secret baru dan tidak boleh diuji tanpa koordinasi karena dapat memengaruhi login akun.
7. Sediakan base URL HTTPS sebelum pengujian di luar akun/environment uji sementara.

## 6. Checklist pengujian manual real device

### MFA

- [ ] Profil lalu `Keamanan akun` terbuka dengan status awal yang jujur.
- [ ] Tekan `Siapkan MFA`, pindai QR pada authenticator, dan masukkan kode salah.
- [ ] Pastikan error server tampil dan layar tidak mengklaim MFA aktif.
- [ ] Masukkan kode benar, simpan recovery codes, lalu tutup dialog.
- [ ] Logout dan login dengan TOTP.
- [ ] Nonaktifkan dengan kode salah, TOTP benar, lalu recovery code sesuai skenario backend.
- [ ] Pastikan secret, OTP, dan recovery code tidak muncul pada log perangkat.

### Sesi

- [ ] Bandingkan daftar sesi dengan dua perangkat uji.
- [ ] Revoke perangkat lain dan pastikan perangkat tersebut gagal refresh.
- [ ] Setelah backend memberi marker current, revoke perangkat ini dan pastikan cache/token dibersihkan serta login tampil.
- [ ] Matikan koneksi saat revoke dan pastikan row tidak hilang permanen.

### Notifikasi

- [ ] Hapus notifikasi read dan unread, lalu cek list serta badge.
- [ ] Batalkan confirmation dan pastikan tidak ada request.
- [ ] Putus jaringan setelah confirmation dan pastikan item kembali dengan error.
- [ ] Refresh setelah gagal dan cocokkan dengan server.
- [ ] Logout akun A, login akun B, dan pastikan rollback/request lama tidak masuk inbox B.

### Kalender

- [ ] Setelah tenant contract diperbaiki, bandingkan resolved calendar dan holiday list pada akhir/beginning bulan.
- [ ] Pastikan satu hari libur tampil satu kali.
- [ ] Uji tenant berbeda dan pastikan holiday akun lain tidak dapat diminta lewat query.

## 7. Click-through dan delivery gate UI

Click-through yang diverifikasi:

- Profil -> Keamanan akun -> kembali ke Profil;
- Siapkan MFA -> QR/secret -> kode -> recovery codes;
- Nonaktifkan MFA -> kode -> hasil server;
- Sesi aktif -> konfirmasi -> revoke atau error;
- Notifikasi -> hapus -> batal/sukses/rollback;
- refresh, empty, offline, malformed response, dan pergantian akun.

Antislop delivery gate:

- PASS Visual: bahasa visual redesign, Plus Jakarta Sans, radius/token, dan primary `#315B8C` konsisten; tidak ada gradient/dekorasi baru.
- PASS Layout: 320dp dengan text scale 200% serta 390x844 light/dark tidak overflow; SafeArea menjaga header dari status bar.
- PASS Human: target hapus/revoke minimal 44px, confirmation tersedia, error memakai live region, secret diberi konteks dan tidak disimpan.
- PASS Contrast: seluruh pasangan kritis yang dipakai layar diverifikasi dengan checker; rasio minimum normal text yang diuji 4.51:1.
- PASS Motion: sheet/dialog memakai kebijakan reduced-motion aplikasi, tanpa loop atau progress fiktif.
- PASS States: loading, empty, offline/error, busy, success server, invalid code, rollback, dan session change tercakup.
- PASS Copy: tidak ada em dash dan tidak ada klaim current/MFA/holiday yang belum dibuktikan server.
- PASS Golden/build: golden light/dark, 350 test, analysis, APK debug, dan diff check lulus.
- FAIL/BLOCKED server: status MFA persisten, marker current session, revoke sentinel 404, tenant-safe holiday, dan positive live mutation belum tersedia.

Tahap 4 dapat dinyatakan selesai untuk implementasi lokal. Acceptance deployment tetap partial sampai blocker backend dan checklist real device di atas selesai.
