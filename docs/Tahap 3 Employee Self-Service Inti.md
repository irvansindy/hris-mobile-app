# Tahap 3 — Employee Self-Service Inti

Tanggal verifikasi mobile otomatis: 7 Oktober 2026.

## Status

Implementasi dan pengujian otomatis sisi Flutter **PASS**. Exit gate Tahap 3
belum dinyatakan selesai karena create izin masih diblokir kontrak backend dan
positive live test belum memiliki fixture yang memadai.

## Hasil Implementasi

- Riwayat absensi memakai `meta.hasNextPage` server dan mempertahankan
  `totalPages: 0` untuk hasil kosong.
- Daftar cuti dan izin diperlakukan non-paginated. Create cuti mengunggah file
  multipart, memakai `data.url`, mengambil identity dari sesi, dan menunggu
  konfirmasi server sebelum menampilkan sukses.
- Koreksi absensi mendukung check-out hari berikutnya untuk shift malam,
  menolak waktu terbalik, menjaga ownership employee/company, dan memakai
  idempotency key. Lembur memvalidasi permission, waktu, ownership, serta
  breakdown estimasi upah dari server.
- Kalender mengenali `NH` dan `JL` sebagai hari libur, memuat next shift lintas
  bulan, daftar holiday, kandidat/request/approval shift swap, create, dan
  cancel melalui path `/{requestId}/cancel`.
- Profil menerima `employee:read` atau `employee:*`. Enam field sensitif tetap
  di luar entity presentation; nilai masked yang mengandung `*` tidak
  diproyeksikan sebagai kontak atau nilai mutation.

## Cakupan Endpoint

| Area | Endpoint | Status mobile |
|---|---|---|
| Absensi | `GET /attendance/me` | PASS otomatis |
| Koreksi | `GET /attendance-corrections/my`, detail, create | PASS otomatis |
| Lembur | list, create, `/{id}/pay` | PASS otomatis |
| Cuti | types, list, upload, create, detail, cancel | PASS otomatis |
| Izin | list, detail, cancel | PASS otomatis |
| Izin | upload dan create | BLOCKED kontrak backend |
| Kalender | resolved, next-shift, holidays | PASS otomatis |
| Tukar shift | mine, candidates, approvals, create, cancel | PASS otomatis |
| Profil | `GET /employees/{employeeId}` | PASS otomatis |

## Bukti Pengujian

- `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`:
  PASS, 233 file diperiksa dan tidak berubah.
- `rtk flutter analyze`: PASS, tidak ada issue.
- Attendance request contract/widget: PASS, 25 test.
- Calendar contract/repository/widget/parity: PASS, 23 test.
- Profile contract/repository: PASS, 16 test.
- `rtk flutter test`: PASS, 481 test termasuk contract, widget, parity, dan
  golden light/dark.
- Golden kalender light/dark diperbarui setelah inspeksi visual terhadap state
  next shift dan tukar shift; tidak ditemukan overflow.

## Blocker dan Acceptance Live

- OpenAPI mewajibkan `duration` untuk create izin, tetapi satuannya belum
  ditetapkan. Dokumen juga merujuk upload lampiran izin tanpa mendefinisikan
  operasinya. Form production sengaja menampilkan unavailable; history dan
  cancel tetap aktif.
- Positive live test masih dibutuhkan untuk cuti bersama, upload/create/cancel
  cuti, koreksi shift malam, lembur dan pay estimate, holiday `JL`, next shift
  nullable/lintas bulan, serta create/cancel shift swap.
- Fixture harus mencakup employee dan company lain untuk membuktikan isolasi,
  akun tanpa permission, akun dengan `employee:read-sensitive`, kandidat tukar
  shift kosong, dan request yang sudah diproses.
- Acceptance absensi real-device tetap dicatat terpisah di
  `docs/Tahap 2 Acceptance Live Tertunda.md` dan masih menjadi release blocker.

## Exit Gate

Status: **BLOCKED untuk live**, **PASS untuk implementasi dan regresi lokal**.
Tahap 4 boleh dimulai, tetapi release candidate tidak boleh dibuat sebelum
blocker kontrak izin dan seluruh positive live fixture di atas ditutup.
