# Report Tahap 5, ESS Lanjutan

Tanggal: 20 September 2026  
Status: **PASS lokal, PARTIAL live, PENDING real device**

## 1. Ringkasan hasil

Tahap 5 telah mengintegrasikan layanan employee berikut ke satu layar `Layanan Employee`:

- pinjaman karyawan;
- Earned Wage Access atau EWA;
- aktivitas harian berbasis branch dan GPS;
- perjalanan dinas dan klaim biaya;
- rincian cicilan, amortisasi, EWA, dan aktivitas sesuai permission server.

Semua data, status, limit, nominal, dan jadwal memakai response server. Aplikasi tidak mengirim `employeeId` atau `companyId` pada mutation. Khusus EWA, aplikasi juga tidak mengirim `earnedGross`, `periodStart`, `periodEnd`, atau nominal turunan lain yang menjadi tanggung jawab server.

Layar tersedia dari `Pengajuan > Layanan Employee` dan route `/ess`. Parameter `area` dapat membuka submodul `ewa`, `activity`, atau `travel` secara langsung.

## 2. Implementasi endpoint

| Submodul | Endpoint | Status mobile | Catatan |
|---|---|---|---|
| Loan | `GET /employee-loans/types` | DONE | `companyId` hanya berasal dari active company session karena backend masih mewajibkan query ini. |
| Loan | `GET /employee-loans/my` | DONE | Riwayat self-service. |
| Loan | `POST /employee-loans` | DONE lokal | Payload memakai `totalInstallments` dan `installmentAmount`. Nilai cicilan client hanya memenuhi schema; jadwal final tetap milik server. |
| Loan | `PATCH /employee-loans/:id/cancel` | DONE lokal | Hanya tampil untuk status `PENDING`. |
| Loan | `GET /employee-loans/:id/installments` | DONE lokal | Hanya tampil dengan `employee-loan:read`. |
| Loan | `GET /employee-loans/:id/amortization` | DONE lokal | Total dan row amortisasi tidak dihitung ulang oleh mobile. |
| EWA | `GET /ewa/my/limit` | DONE, live read PASS | `max`, `remaining`, approved, reserved, dan earned gross dibaca dari server. |
| EWA | `GET /ewa/my` | DONE, live read PASS | Riwayat self-service. |
| EWA | `GET /ewa/:id` | DONE lokal | Hanya tampil dengan `ewa:read`. |
| EWA | `POST /ewa` | DONE lokal, live 403 | Tombol hanya tampil dengan `ewa:create`. Akun live saat ini tidak memiliki izin tersebut. |
| EWA | `POST /ewa/:id/cancel` | DONE lokal | Hanya tampil dengan `ewa:update` dan status `PENDING`. |
| Daily activity | `GET /daily-activities/my` | DONE, live read PASS | Default menampilkan bulan berjalan. |
| Daily activity | `GET /daily-activities/:id` | DONE lokal | Hanya tampil dengan `daily-activity:read`. |
| Daily activity | `POST /daily-activities` | DONE lokal, live 403 | Branch dibaca dari profil server; GPS asli dan akurasi maksimal 100 meter diwajibkan mobile. |
| Daily activity | `PUT /daily-activities/:id` | DONE lokal | Hanya field update yang didukung schema server yang dikirim. |
| Daily activity | `DELETE /daily-activities/:id` | DONE lokal | Memerlukan konfirmasi dan `daily-activity:delete`. |
| Travel | `GET /travel-expenses/categories` | DONE, live PASS | Lima kategori server terbaca. |
| Travel | `GET /travel-expenses/trips/my` | DONE, live PASS | Riwayat perjalanan employee. |
| Travel | `POST /travel-expenses/trips` | DONE lokal | Identity berasal dari session server. |
| Travel | `GET /travel-expenses/claims/my` | DONE, live PASS | Riwayat klaim employee. |
| Travel | `POST /travel-expenses/claims/receipt-upload` | DONE lokal | Mobile menerima JPG/PNG maksimal 5 MB. |
| Travel | `POST /travel-expenses/claims` | DONE lokal | `ocrExtractedAmount` dan identity tidak dikirim mobile. |
| Approval | Workflow loan dan travel | DONE melalui Approval Center | Mobile tidak menambah jalur approve/reject domain kedua. |
| Approval | Workflow EWA | BLOCKED backend | EWA masih memakai action domain dan belum mempunyai workflow instance generik yang stabil. |

## 3. Isolasi sesi dan validasi kontrak

- Repository dan FutureProvider terikat `FeatureSession`.
- Response lama ditolak setelah akun atau company aktif berubah.
- Response yang membawa `employeeId` atau `companyId` lain ditolak sebagai error format.
- Semua ID path divalidasi sebelum request.
- HTTP 2xx tanpa envelope, object/list, ID, status, tanggal, atau nominal wajib diperlakukan sebagai error kontrak.
- Mutation tidak menampilkan sukses sebelum response server valid.
- Cache submodul hanya diinvalidasi setelah mutation dikonfirmasi server.

## 4. Hasil smoke test live non-destruktif

Target: `http://srv540825.hstgr.cloud:8084/api/v1`  
Metode: read endpoint dan payload kosong untuk membuktikan validation/permission guard tanpa membuat data.

| Hasil | Jumlah | Rincian |
|---|---:|---|
| PASS | 12 | Login employee/manager, delapan read ESS, dan logout employee/manager. |
| Expected rejection | 5 | Loan, EWA, activity, trip, dan claim create dengan payload kosong atau tanpa permission. |

Temuan live:

- tipe pinjaman dan riwayat pinjaman kosong;
- riwayat EWA kosong, tetapi object limit lengkap tersedia;
- aktivitas, perjalanan, dan klaim masih kosong;
- kategori klaim berisi 5 item;
- akun employee ditolak `403` untuk `ewa:create` dan `daily-activity:create`;
- endpoint create loan, trip, dan claim menolak payload kosong dengan `422`;
- tidak ada data nyata yang dibuat atau diubah oleh probe ini.

Artefak lokal tersanitasi: `/tmp/hris-mobile-stage5-probe.json`.

## 5. Hasil pengujian lokal

| Pemeriksaan | Hasil |
|---|---|
| Contract test ESS | 8 PASS |
| Widget, permission, click-through, dan logout isolation ESS | 11 PASS |
| Golden ESS, 4 area x light/dark, 320dp, text 200% | 8 PASS |
| Seluruh test proyek | **377 PASS** |
| `flutter analyze` | **PASS, no issues** |
| `flutter build apk --debug` | **PASS** |
| `git diff --check` | **PASS** |
| Contrast token utama | **PASS**, rasio minimum 4.51:1 |

Baseline visual ESS berada di `test/goldens/ess_stage5/`.

## 6. Gap backend dan batas rilis

Tahap 5 belum dapat dinyatakan PASS live penuh karena kondisi berikut:

1. akun uji tidak memiliki `ewa:create` dan `daily-activity:create`;
2. loan type kosong sehingga positive create loan tidak dapat diuji;
3. belum tersedia fixture loan, EWA, activity, trip, claim, installment, dan workflow untuk menguji detail/cancel/update/delete nyata;
4. `GET /employee-loans/types` masih meminta `companyId` dari query, bukan hanya tenant context server;
5. pembuatan aktivitas membutuhkan branch ID, tetapi belum ada endpoint self-context khusus yang menjamin employee dapat membaca branch tanpa permission `employee:read`;
6. detail trip dan claim pada backend hanya dapat diakses role approver. Employee menggunakan response daftar miliknya;
7. EWA belum terhubung ke Approval Center generik;
8. upload receipt tidak mempunyai endpoint rollback/delete bila upload berhasil tetapi create claim gagal;
9. UI attachment saat ini mendukung JPG/PNG. Dukungan PDF/GIF ditahan sampai pemilih dokumen dan lifecycle upload disepakati;
10. deployment masih HTTP cleartext. Konfigurasi ini hanya layak untuk pengujian akun khusus, bukan production.

## 7. Checklist pengujian manual real device

### Loan

- pastikan tipe pinjaman tersedia;
- ajukan nominal pada batas minimum dan maksimum;
- pastikan status tidak berubah sebelum server merespons;
- buka rincian cicilan dan amortisasi dengan permission baca;
- batalkan pinjaman `PENDING`, lalu coba batalkan kembali untuk menguji conflict.

### EWA

- pasang `ewa:create`, `ewa:read`, dan `ewa:update` pada akun uji;
- bandingkan sisa limit dengan response server;
- coba nominal nol, di atas limit, dan valid;
- buka detail lalu batalkan pengajuan `PENDING`;
- pastikan aplikasi tidak pernah mengirim earned gross atau periode payroll.

### Aktivitas harian

- pasang permission create/read/update/delete;
- pastikan profil employee memiliki branch dengan koordinat;
- uji GPS mati, izin ditolak, lokasi mock, akurasi di atas 100 meter, dan GPS valid;
- uji waktu selesai sebelum waktu mulai dan waktu yang overlap;
- buat, buka detail, ubah, dan hapus aktivitas;
- logout saat request berjalan lalu login akun lain untuk memastikan response lama ditolak.

### Travel dan claim

- buat perjalanan dengan tanggal valid dan tanggal akhir sebelum tanggal mulai;
- buat klaim tanpa perjalanan dan dengan perjalanan terkait;
- uji receipt JPG/PNG valid, file di atas 5 MB, dan koneksi putus setelah upload;
- manager memproses loan/travel dari Approval Center;
- employee memuat ulang dan memastikan status terbaru berasal dari server.

## 8. Exit gate

Status saat ini:

- lokal: **PASS**;
- live read dan negative probe: **PASS**;
- live positive mutation: **PENDING fixture/permission**;
- real device: **PENDING**;
- production readiness: **BLOCKED HTTPS dan gap backend pada bagian 6**.
