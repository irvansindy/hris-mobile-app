# Pending Task Migrasi API Oktober 2026

Pembaruan: 19 Oktober 2026.
Untuk: Backend, Mobile, QA, dan Product.

Dokumen ini memfilter pekerjaan tertahan dari breakdown revisi **1–7** yang
sudah disepakati. Bukan roadmap baru dan tidak menggantikan gate go-live.
Status implementasi lokal dipisahkan dari acceptance server. Semua baris
`PENDING` di bawah belum boleh dicentang selesai hanya berdasarkan tes lokal.

## Daftar pending menurut prioritas

| Status | Poin breakdown | Prioritas | Task tertahan | Owner dependency | Yang perlu disiapkan / kriteria penutupan |
| --- | --- | --- | --- | --- | --- |
| PENDING | 1 | P0 | Acceptance wajib ganti password saat login dan saat sesi berjalan | Backend + QA | Akun disposable dengan `mustChangePassword:true`, mekanisme mengaktifkan flag saat sesi berjalan, dan izin mengganti password akun uji. Mobile menguji gate Home/deep link, runtime 403 tanpa logout/replay mutation, lalu akses pulih setelah ganti password/login. Akun saat ini flag-nya false. |
| PENDING | 2 | P0 | Acceptance isolasi dua company dengan nomor employee sama | Backend + QA | Dua akun company berbeda, `employeeNumber` sama tetapi employee ID berbeda, serta resource fixture milik masing-masing. Mobile menguji logout, account switch, restart, dan tidak ada cache/data silang. Jangan menaikkan privilege akun employee hanya untuk tes ini. |
| PENDING | 3 | P1 | Konfirmasi endpoint daftar payslip canonical | Backend | Konfirmasi tertulis path daftar dan alias yang didukung beserta response self-service. OpenAPI lokal memakai `/payroll/payslips`; checklist Oktober menyebut `/payroll/payslips/my`. Hasil live berturut-turut 200 list dan 401 `PAYROLL_UNLOCK_REQUIRED`; mobile belum mengganti path atau menambah fallback. |
| PENDING | 3 | P1 | Acceptance multi-slip dan pembukaan ID yang tepat | Backend + QA | Minimal dua payslip untuk employee yang sama, periode sama, ID berbeda, nama/nomor run bila tersedia. Snapshot live hanya satu slip. Untuk detail/PDF sediakan HTTPS serta PIN uji melalui kanal lokal aman; jangan kirim PIN di laporan. Tidak mengasumsikan `runType` tersedia. |
| PENDING | 4 | P1 | Acceptance permission dan konflik workflow | Backend + QA | Matriks permission role, manager berwenang/tidak berwenang, fixture pending dan stale/sudah diproses, serta persetujuan mutasi fixture disposable. Uji 403, 409, approve/reject/bulk partial success tanpa fallback legacy atau sukses palsu. Employee mendapat 403; queue manager pada putaran sebelumnya kosong. |
| PENDING | 5 | P1 | Konfirmasi semantik carry-over | Backend | Pastikan apakah quota/remaining sudah termasuk carry-over, satuan pecahan hari, nullability, dan timezone expiry. Client tidak menghitung atau menambah carry-over ke saldo otoritatif. |
| PENDING | 5 | P1 | Acceptance carry-over pecahan dan batas expiry | Backend + QA | Fixture tanpa carry-over, pecahan, belum expired, expired, dan tepat tanggal batas. Snapshot live memiliki tujuh nilai numerik tetapi tidak ada pecahan atau expiry berbentuk string, sehingga belum mencakup edge case tersebut. |
| PENDING | 5 | P1 | Pencocokan tracing dengan log backend | Backend + Mobile | Backend mencari UUID pada tabel tracing di laporan verifikasi dan mengembalikan cuplikan log yang disanitasi. Header terkirim belum membuktikan server menyimpan/menggunakan ID tersebut; retry/correlation live juga belum dibuktikan. |

Tersisa **8 item PENDING** dalam poin 1–5. Keputusan poin 7 sudah selesai;
implementasi modulnya berstatus `DEFERRED`, bukan blocker rilis awal.

## Keputusan scope yang sudah disetujui

Pengguna menyetujui pada 19 Oktober 2026 bahwa HR Helpdesk, Feed & Kudos,
dan Timesheet ditunda dari rilis awal. Poin 7 berstatus `DONE` untuk keputusan
scope, bukan berarti fitur sudah diimplementasikan.

| Status | Poin breakdown | Backlog setelah rilis awal | Prasyarat jika diaktifkan kembali |
| --- | --- | --- | --- |
| DEFERRED | 7 | HR Helpdesk | Persetujuan scope baru, schema tiket/comment/close, enum, permission, dan pagination. |
| DEFERRED | 7 | Feed & Kudos | Persetujuan scope baru, schema post/kudos, enum badge, ownership/moderasi, dan pagination. |
| DEFERRED | 7 | Timesheet | Persetujuan scope employee/approver, schema proyek/entry, status/editability, permission, dan pagination. |

Jangan menambah menu, endpoint, dependency, atau placeholder production untuk
ketiga modul tersebut dalam rilis awal. Keputusan ini tidak menunda atau
menutup gate acceptance/security modul yang sudah masuk rilis.

## Pekerjaan yang tidak lagi pending

- Login employee setelah pembaruan file lokal: 200; logout: 200.
- GET profil milik employee: 200; ID dan company cocok dengan sesi,
  employee number tersedia dan berbeda dari ID. Ini bukan bukti dua tenant.
- Implementasi lokal poin 1–5 sudah tersedia; regresi terfokus sebelumnya
  lulus 190 tes. Angka tersebut bukan pengujian ulang pada putaran smoke ini.
- Poin 6: matriks, laporan, dan rekap diperbarui dengan hasil serta dependency.

## Cara memfilter dan menindaklanjuti

```bash
rtk rg '^\| PENDING \|' 'docs/Pending Task Migrasi API Oktober 2026.md'
```

Backend/Product dapat menjawab tiap baris dengan nomor poin breakdown, owner,
status, dan lokasi fixture/kontrak aman. Jangan menyertakan password, token,
PIN, selfie, isi slip gaji, atau data pegawai dalam dokumen ini.

Jika dependency sudah tersedia, Mobile menjalankan acceptance lalu mencatat
bukti pada laporan. Ubah status menjadi `DONE` hanya jika kriteria baris itu
terbukti; ketersediaan fixture saja belum menutup task. Pekerjaan yang pending
boleh dilewati dalam development sesuai persetujuan pengguna, tetapi gate
release yang terkait tetap berlaku.

## Referensi

- [Matriks revisi 1–7](<Migrasi API Oktober 2026 - Matriks dan Report.md>)
- [Hasil smoke dan acceptance](<Verifikasi Integrasi Pasca Migrasi API - 2026-10-19.md>)
- [Rekap kebutuhan backend dan go-live](<Rekap Task Tertunda dan Kebutuhan Backend - 2026-10-18.md>)
