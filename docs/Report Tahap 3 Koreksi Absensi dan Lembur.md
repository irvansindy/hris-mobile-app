# Report Tahap 3, Koreksi Absensi dan Lembur

Tanggal: 19 September 2026  
Scope: pengajuan koreksi absensi, riwayat dan detail koreksi, pengajuan lembur, estimasi bayaran server, serta integrasi approval manager  
Status tahap: PASS lokal, PARTIAL live, PENDING real device

## 1. Ringkasan hasil

Tahap 3 telah menyelesaikan implementasi lokal API-201 sampai API-205. Aplikasi sekarang menyediakan satu layar `Koreksi & lembur` yang dapat dibuka dari halaman Absensi, menu Pengajuan, atau quick action yang sesuai permission.

Hasil utama:

- employee membaca koreksi melalui route self-service `/attendance-corrections/my` dan detail `/attendance-corrections/my/:id`;
- koreksi dapat dibuat dari record riwayat absensi atau dari form kosong;
- koreksi mewajibkan minimal satu perubahan waktu, alasan minimal tiga karakter, dan waktu pulang setelah waktu masuk;
- submit koreksi tidak mengubah record absensi final secara lokal;
- daftar lembur selalu dibatasi memakai `companyId` dan `employeeId` dari session aktif;
- form lembur mendukung rentang lintas tengah malam dan mengirim durasi turunan sampai dua desimal;
- nominal lembur hanya berasal dari `GET /attendance/overtime/:id/pay` dan tidak memiliki fallback perhitungan lokal;
- mutation memakai `Idempotency-Key` dan tidak mengirim identity employee/company dari input UI;
- respons dari akun lama ditolak bila session berubah saat request masih berjalan;
- action manager untuk koreksi dan lembur memakai Approval Center generik dari Tahap 2. Route approve/reject khusus resource tidak dipasang sebagai jalur kedua.

## 2. Keputusan kontrak

### Koreksi absensi employee

Dokumen API yang diterima hanya menampilkan route koleksi umum. Pemeriksaan implementasi backend menemukan route self-service berikut dan keduanya telah dibuktikan live:

- `GET /attendance-corrections/my`;
- `GET /attendance-corrections/my/:id`.

Mobile memakai route tersebut untuk employee agar scope akun tidak bergantung pada filter identity dari client. Route umum `GET /attendance-corrections` tetap diperlakukan sebagai route approver dengan permission `attendance:read`.

### Action manager

Approval Center mengirim action ke `POST /workflow-engine/instances/:id/actions`. Backend saat ini meneruskan action untuk reference type `ATTENDANCE_CORRECTION` dan `OVERTIME_REQUEST` ke domain handler terkait. Karena itu mobile tidak mengaktifkan `approve`, `reject`, atau `workflow-action` khusus resource sebagai jalur mutation tambahan.

Keputusan ini mencegah dua request berbeda menghasilkan status yang saling bertentangan.

## 3. Endpoint dan status implementasi

| No. | Method | Path | Pemakaian mobile | Live 19 September 2026 |
|---:|---|---|---|---|
| 1 | GET | `/attendance-corrections/my` | Riwayat koreksi employee, filter status opsional | PASS 200, list kosong |
| 2 | GET | `/attendance-corrections/my/:id` | Detail dan timeline terbaru | Route terjangkau, 404 karena fixture belum tersedia |
| 3 | POST | `/attendance-corrections` | Membuat koreksi self-service | PASS negative validation 422; positive create belum dijalankan |
| 4 | GET | `/attendance-corrections` | Read-only list approver legacy | PASS 200 pada manager, list kosong |
| 5 | GET | `/attendance/overtime` | Riwayat lembur employee aktif | PASS 200, list kosong |
| 6 | POST | `/attendance/overtime` | Membuat pengajuan lembur | BLOCKED 403, akun employee tidak memiliki `attendance:create` |
| 7 | GET | `/attendance/overtime/:id/pay` | Estimasi nominal dari server | Route terjangkau, 404 karena fixture belum tersedia |
| 8 | POST | `/workflow-engine/instances/:id/actions` | Approve/reject manager untuk correction dan overtime | Terintegrasi lokal melalui Tahap 2; positive live BLOCKED permission/fixture manager |

Route resource-specific berikut sengaja tidak dipanggil oleh UI manager:

- `PUT /attendance-corrections/:id/approve`;
- `PUT /attendance-corrections/:id/reject`;
- `PATCH /attendance-corrections/:id/workflow-action`;
- `PATCH /attendance/overtime/:id/approve`;
- `PATCH /attendance/overtime/:id/reject`;
- `PATCH /attendance/overtime/:id/workflow-action`.

Backend boleh mempertahankannya untuk kompatibilitas, tetapi kontrak mobile memilih workflow engine sebagai jalur action tunggal.

## 4. Perubahan implementasi

### Domain dan data

- entity koreksi, lembur, status, command create, pay estimate, dan breakdown bayaran;
- datasource serta repository untuk list, detail, create, dan pay;
- validasi strict envelope, ID, status, tanggal, waktu, tenant, employee, dan permission;
- `Idempotency-Key` wajib pada kedua create mutation;
- identity employee/company tidak dapat diisi dari form;
- pay amount dan breakdown hanya diterima dari response server yang cocok dengan overtime terpilih.

### UI dan navigasi

- route `/attendance/requests` dengan tab Koreksi dan Lembur;
- filter Semua dan Menunggu;
- form koreksi dari kartu riwayat absensi melalui tombol `Ajukan koreksi`;
- detail koreksi selalu melakukan refresh ke endpoint detail server;
- form lembur dengan date-time mulai dan selesai, termasuk lintas hari;
- detail lembur menampilkan durasi server dan mengambil pay estimate secara terpisah;
- loading, empty, error, permission, detail, dan retry state;
- quick action `Klaim lembur` hanya tersedia bila session mempunyai `attendance:create`;
- menu Lembur di halaman Pengajuan juga mengikuti capability yang sama.

## 5. Hasil pengujian otomatis

| Gate | Hasil |
|---|---|
| Contract test koreksi dan lembur | 8 lulus |
| Widget/provider test Tahap 3 | 11 lulus |
| Seluruh test proyek | 333 lulus setelah final rerun |
| `flutter analyze` | Lulus, tidak ada issue |
| Golden test Koreksi/Lembur | 4 lulus dan telah diinspeksi visual |
| Layout 320dp, text scale 200%, light/dark | Lulus tanpa overflow |
| Pergantian akun saat response tertunda | Lulus, respons lama ditolak |
| Contrast check 9 pasangan warna | Seluruhnya lulus WCAG 4.5:1 untuk teks normal |
| `flutter build apk --debug` | Lulus setelah final rebuild |
| `git diff --check` | Lulus |

Golden image mencakup tab Koreksi dan Lembur pada tema terang dan gelap. Pemeriksaan visual tidak menemukan clipping, tumpang tindih status bar, kartu terpotong, atau status yang tidak terbaca.

APK pengujian:

- file: `build/app/outputs/flutter-apk/app-debug.apk`;
- ukuran: `204372754` byte;
- SHA-256: `eb478dc004f670727b1e56fdd927ef23271f04a6771cf819271d2e5e95f3f5d6`.

Build masih menampilkan warning bahwa `package_info_plus` menerapkan Kotlin Gradle Plugin. Warning tidak menggagalkan build, tetapi dependency perlu diperbarui sebelum Flutter menghentikan dukungan pola tersebut.

## 6. Hasil live probe

Probe dijalankan secara non-destruktif melalui base URL HTTP yang sebelumnya disetujui khusus untuk akun uji.

| Skenario | HTTP | Hasil |
|---|---:|---|
| Login employee | 200 | PASS |
| Login manager | 200 | PASS |
| Employee membaca daftar koreksi miliknya | 200 | PASS, list kosong |
| Employee membuka detail koreksi sentinel | 404 | PASS keterjangkauan route, fixture belum ada |
| Manager membaca list koreksi | 200 | PASS, list kosong |
| Employee mengirim koreksi kosong | 422 | PASS negative validation, tidak membuat data |
| Employee membaca lembur dengan identity session | 200 | PASS, list kosong |
| Employee membuka pay sentinel | 404 | PASS keterjangkauan route, fixture belum ada |
| Employee mengirim lembur kosong | 403 | BLOCKED oleh permission `attendance:create` sebelum validasi payload |
| Logout manager dan employee | 200 | PASS |

Ringkasan runner: 7 `PASS`, 2 `REACHABLE_PREREQUISITE_MISSING`, dan 2 `REACHABLE_EXPECTED_REJECTION`.

Artefak tersanitasi berada di `/tmp/hris-mobile-stage3-probe.json` dengan permission `600`. Scan artefak tidak menemukan access token, refresh token, password, cookie, email, atau authorization header. Tidak ada koreksi, lembur, absensi, atau approval nyata yang dibuat atau diubah.

## 7. Blocker backend untuk positive live test

Backend developer perlu menyiapkan:

1. permission `attendance:create` pada akun employee uji;
2. minimal satu record absensi milik employee yang aman untuk dikoreksi;
3. minimal satu correction fixture untuk verifikasi detail dan timeline;
4. minimal satu overtime fixture agar response `/pay` dapat divalidasi;
5. akun manager dengan `workflow:approve` dan pending workflow untuk `ATTENDANCE_CORRECTION` serta `OVERTIME_REQUEST`;
6. skenario reject yang menyimpan alasan dan skenario stale/duplicate action;
7. konfirmasi tertulis bahwa `/attendance-corrections/my` dan `/my/:id` menjadi bagian kontrak API publik mobile;
8. base URL HTTPS untuk penggunaan di luar pengujian sementara.

## 8. Checklist pengujian manual real device

### Koreksi absensi

- [ ] Buka Absensi, pilih record riwayat, lalu tekan `Ajukan koreksi`.
- [ ] Pastikan tanggal dan waktu awal mengikuti record yang dipilih.
- [ ] Kirim hanya koreksi check-in.
- [ ] Kirim hanya koreksi check-out.
- [ ] Kirim koreksi keduanya.
- [ ] Matikan kedua pilihan waktu. Harapan: submit ditolak lokal.
- [ ] Pilih waktu pulang sebelum waktu masuk. Harapan: submit ditolak lokal.
- [ ] Tekan submit berulang. Harapan: satu mutation idempotent dan sukses hanya muncul setelah response server.
- [ ] Buka detail koreksi. Harapan: status serta timeline cocok dengan endpoint detail, bukan snapshot lama.
- [ ] Coba akses atau submit record akun lain melalui request manual. Harapan: server menolak.

### Lembur

- [ ] Login akun dengan `attendance:create`; pastikan quick action dan menu Lembur muncul.
- [ ] Login akun tanpa permission tersebut; pastikan tombol create tidak muncul.
- [ ] Kirim lembur pada hari yang sama.
- [ ] Kirim lembur yang melewati tengah malam.
- [ ] Pilih waktu selesai sebelum waktu mulai. Harapan: submit ditolak.
- [ ] Uji duplicate submit dan konflik shift.
- [ ] Buka detail lembur dengan fixture valid dan cocokkan durasi server.
- [ ] Cocokkan nominal `/pay` dengan UI.
- [ ] Simulasikan `/pay` gagal. Harapan: UI menampilkan error tanpa angka contoh.

### Approval dan isolasi session

- [ ] Manager approve satu correction melalui Approval Center.
- [ ] Manager reject correction lain dengan alasan.
- [ ] Manager approve satu overtime dan reject lainnya.
- [ ] Employee melakukan refresh dan melihat status terbaru.
- [ ] Logout employee A saat request list/detail tertunda, lalu login employee B. Harapan: respons dan form A tidak muncul pada sesi B.
- [ ] Pastikan tidak ada draft koreksi atau lembur lama setelah pergantian akun.

## 9. Exit gate Tahap 3

Implementasi lokal API-201 sampai API-205 selesai. Tahap 3 belum dinyatakan DONE deployment sampai:

- positive create correction dan overtime lulus pada server uji;
- detail correction dan overtime pay lulus memakai fixture nyata;
- approval manager untuk kedua reference type lulus end-to-end;
- checklist real device selesai tanpa kebocoran antar akun;
- backend menyediakan HTTPS untuk penggunaan operasional.

Jangan memasukkan access token, refresh token, password, cookie, OTP, atau data pribadi karyawan ke report manual.
