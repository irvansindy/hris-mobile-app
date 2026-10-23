# Tahap 4, Workflow Manager dan ESS Lanjutan

Tanggal: 8 Oktober 2026  
Status: **PASS lokal, BLOCKED positive live fixture dan real device**

## Ringkasan

Tahap 4 menyelesaikan kontrak lokal Workflow Manager serta ESS lanjutan dengan presentation yang sama untuk demo dan production. Server tetap menjadi sumber kebenaran untuk status workflow, nominal, identity, tenant, reporting line, asset, dan metadata dokumen.

## Workflow Manager

- Antrean memakai `GET /workflow-engine/instances/my-approvals` dan menentukan halaman berikutnya dari `meta.hasNextPage`, termasuk ketika `totalPages` bernilai nol.
- Detail terbaru memakai `GET /workflow-engine/instances/{id}` dengan permission `workflow:read`, validasi instance ID, dan active company.
- Approve, reject, dan escalate tetap memakai endpoint action workflow. Reject wajib komentar sebelum request.
- Self-approval dihentikan di UI dan data source bila subject employee dari server sama dengan employee aktif. Backend tetap menjadi guard otoritatif.
- Bulk response 200 dibaca per item; item gagal tetap dipertahankan beserta error server.
- Delegation list/create/revoke tetap self-service dan terisolasi oleh user/company/session.
- Permission exact, wildcard, dan `SUPER_ADMIN` memakai `RequestContext.hasPermission`.

## ESS lanjutan

- Loan, EWA, daily activity, trip, dan claim dipertahankan pada repository production yang sama dengan presentation demo.
- Protected EWA, loan detail, dan daily activity kini berhenti sebelum network access bila permission tidak tersedia.
- Receipt tetap diunggah ke `POST /travel-expenses/claims/receipt-upload`, tetapi referensi klaim kini memakai `data.url` sesuai kontrak backend, bukan `data.filePath` yang sebelumnya menyebabkan 400.
- `GET /assets/my` terintegrasi dengan filter status, pagination `hasNextPage`, validasi identity, dan state loading/empty/error.
- `GET /employees/me/reporting-line` serta `GET /employees/{id}/attachments` terintegrasi ke Profil melalui repository terpisah yang dapat ditukar.
- Attachment hanya menampilkan metadata aman. `filePath` dan `url` mentah tidak diproyeksikan ke UI, serta tidak ada tombol download palsu.
- Chat tetap menampilkan pesan unavailable karena belum ada kontrak endpoint.

## Pengujian lokal

| Gate | Hasil |
|---|---|
| Contract dan widget approval | PASS |
| Contract dan widget ESS | PASS |
| Contract profile support | PASS |
| Permission, tenant, self-approval, late-session | PASS |
| Golden asset light/dark, 320dp, text 200% | PASS dan diinspeksi |
| Full Flutter test | 493 PASS |
| Flutter analyzer | PASS, 0 issue |
| Dart formatter | PASS |
| `git diff --check` | PASS |

## Blocker live dan backend

Tahap ini belum memenuhi exit gate live karena backend masih perlu menyediakan:

1. manager dengan `workflow:approve` dan `workflow:read`;
2. pending workflow untuk approve, reject, escalate, self-approval, stale conflict, dan bulk partial-success;
3. fixture loan, EWA, activity, trip, claim, asset, reporting line, serta attachment pada minimal dua company;
4. permission positif dan negatif yang dapat diuji untuk setiap fixture;
5. endpoint download terotorisasi khusus attachment employee, atau keputusan memakai document-management ID. OpenAPI saat ini hanya menyediakan metadata attachment;
6. HTTPS staging serta acceptance Android/iOS real device.

`/uploads/*` tidak boleh dibuka langsung. Receipt URL hanya dipakai sebagai referensi pada payload create claim, bukan sebagai URL publik untuk gambar atau WebView.

## Acceptance manual yang ditunda

- Workflow: refresh queue, detail terbaru, approve/reject/escalate, reject kosong, double tap, stale 404/409, bulk partial success, delegation, self-approval, dan pergantian akun/company.
- ESS: mutation loan/EWA/activity/travel/claim, receipt valid/tidak valid, asset pagination, reporting line tanpa supervisor, attachment kosong/403, dan isolasi account switch.
- Perangkat: Android dan iOS, light/dark, text scaling, restart aplikasi, pergantian jaringan, serta koneksi lambat/timeout.

## Delivery gate UI

- Tidak ada kontrol baru yang mati; attachment tidak diberi tombol download sebelum endpoint tersedia.
- Loading, empty, permission, dan error state tersedia.
- Asset light/dark pada 320dp dan text 200% tidak overflow horizontal.
- Visual memakai token aplikasi yang sudah disetujui, tanpa menambah dekorasi atau pola visual baru.
