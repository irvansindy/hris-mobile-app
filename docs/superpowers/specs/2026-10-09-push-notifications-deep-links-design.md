# Tahap 6: Push Notification dan Deep Link

Tanggal: 9 Oktober 2026
Status: rancangan teknis untuk review, belum diimplementasikan

## Tujuan dan Cakupan

Employee dan manager menerima pemberitahuan, melihat inbox terbaru, dan membuka resource yang tersedia di aplikasi melalui sesi akun aktif. Push tidak boleh melewati login, batas company/account, permission, atau PIN payslip. Demo dan production tetap menggunakan tampilan notifikasi yang sama.

Rancangan melanjutkan roadmap `docs/Breakdown Task Go Live HRIS Mobile App.md`. Persetujuan rancangan diberikan dalam percakapan; dokumen ini menjadi dasar review sebelum rencana implementasi.

Tahap ini mencakup registrasi perangkat, lifecycle Firebase Messaging, pagination inbox, routing dari tap notifikasi, isolasi sesi, dan test otomatis. Konfigurasi project Firebase nyata, APNs, signing, serta acceptance Android/iOS menjadi gate eksternal. Tidak ada redesign UI, scheduler background, polling berkala, local notification plugin, atau public app/universal link baru.

## Kondisi Repository

- `firebase_core` dan `firebase_messaging` sudah terpasang, tetapi `main.dart` belum menginisialisasi Firebase.
- Repository/controller inbox sudah menyediakan list, unread count, read, read-all, dan delete.
- `notificationResourceLocation` memetakan resource terbatas. Routing inbox sudah mengikuti `featureSessionProvider`.
- Cleaner logout hanya menghapus token FCM lokal. Belum ada registrasi/unregister ke endpoint backend.
- Inbox menaikkan `limit` ketika muat lagi. Kontrak terbaru membatasi `limit` maksimal 100 dan menyediakan `page`.
- `AppConfig` baru membedakan development/production. Tahap ini tidak mengarang app ID, Firebase project, atau flavor staging.

## Kontrak Backend

Sumber: `docs/api-for-mobile-apps/openapi.yaml`, README, dan checklist perubahan API pada folder yang sama.

| Operasi | Kontrak |
| --- | --- |
| Register | `POST /notifications/device-tokens`, sukses 201 |
| Unregister | `DELETE /notifications/device-tokens`, body JSON `{installationId}`, sukses 200 |
| Inbox | `GET /notifications?page=&limit=`, paginated envelope; default limit 50, maksimum 100 |
| Unread | `GET /notifications/unread-count`, `data.count` |
| Read | `PUT /notifications/read`, body `{ids}` |
| Read all | `PUT /notifications/read-all` |
| Delete | `DELETE /notifications/{id}` |

Register mengirim `installationId` sepanjang 8 hingga 200 karakter, platform `ANDROID`/`IOS`, provider `FCM`, dan token sepanjang 20 hingga 4096 karakter. Firebase Messaging mengembalikan token FCM pada kedua platform; token APNs tidak dikirim sebagai FCM. `appVersion` opsional maksimal 50 karakter. `deviceModel` tidak dikumpulkan pada implementasi awal karena opsional dan tidak diperlukan untuk delivery.

Gunakan mekanisme idempotency mutation yang sudah ada. Retry satu operasi memakai key dan payload yang sama; token rotation merupakan operasi baru. Jangan mengirim user/company dari klien untuk menetapkan kepemilikan registration.

Kontrak yang tersedia belum menetapkan format `RemoteMessage.data` dan tidak menyediakan `GET /notifications/{id}`. Nama `notificationId` adalah usulan kontrak mobile, bukan fakta server. Field tersebut hanya menjadi petunjuk pencarian, bukan bukti kepemilikan atau URL yang dipercaya.

## Komponen dan Batas Dependency

1. Adapter push membungkus Firebase initialization, permission, token, token refresh, foreground messages, opened messages, initial message, dan penghapusan token. Fake adapter digunakan dalam test; demo memakai adapter nonaktif. Adapter tidak mengenal router atau repository ESS.
2. Repository device registration memakai authenticated network yang sudah ada, memvalidasi payload, dan memetakan error dengan mapper bersama. Repository inbox tetap terpisah dari SDK Firebase.
3. Coordinator app-scoped menangani state push dan antrean registration. Ia mengambil snapshot session/revision dan membuang callback lama. Coordinator mengikuti perubahan sesi tanpa bergantung pada apakah halaman inbox sedang terbuka.
4. Router memakai pemetaan resource yang sudah ada; tap push terlebih dahulu memperoleh item dari inbox server akun aktif. Screen/controller fitur tujuan tetap memeriksa aksesnya sendiri.

Lokasi perubahan utama: `lib/features/notifications/`, `lib/app/router/notification_route.dart`, bootstrap aplikasi, serta batas logout pada authentication. Gunakan Riverpod, SharedPreferences, session lifecycle, dan dependency Firebase yang sudah terpasang. Jangan menambah event bus atau persistent message queue.

## Bootstrap, Permission, dan Identitas Instalasi

Tambahkan opt-in `ENABLE_PUSH`, default false sampai konfigurasi Firebase tersedia. Demo selalu menonaktifkan Firebase meskipun flag true. Jika enabled, bootstrap menggunakan konfigurasi Firebase resmi untuk environment yang dipilih. Kegagalan initialization tidak menggagalkan login atau inbox, tetapi status push harus menampilkan bahwa push belum aktif.

Minta permission setelah sesi login siap, bukan ketika splash/login terbuka. Permission denied tidak diminta berulang pada setiap refresh. Tampilkan status ringkas di inbox beserta aksi mencoba aktivasi kembali setelah pengguna mengubah izin. Gunakan provisional/authorized sesuai status SDK; jangan menyatakan registration aktif sebelum backend menerima POST.

Buat installation ID acak dengan sumber random aman, simpan pada preferences lokal menggunakan key bernamespace environment. ID tidak memuat identitas akun atau hardware. Pertahankan pada restart dan logout. Uninstall/data clear membentuk instalasi baru; acceptance mencakup kemungkinan OS memulihkan preferences dari backup, sehingga ID tidak diklaim sebagai hardware identifier atau pasti berubah pada setiap reinstall.

Token FCM tidak disalin ke preferences, secure storage, analytics, atau log. Hanya token aktif dan status registration disimpan sementara dalam coordinator.

## Registration, Rotation, dan Logout

Sesudah login/restore selesai, permission tersedia, dan token ada, register perangkat. Refresh token FCM memicu registration baru. Refresh access token tidak selalu memicu POST jika identitas dan registration tidak berubah; network memakai refresh auth yang sudah tersedia.

Coordinator menserialkan operasi register/unregister agar response akun lama tidak menimpa state akun baru. Setiap completion harus memeriksa revision, user, dan company yang ditangkap. Token berubah ketika operasi berjalan akan direkonsiliasi memakai token paling baru, tanpa membuat retry loop.

Saat logout:

1. Hentikan penerimaan tap/event untuk akun lama dan kosongkan pending intent serta state sensitif lokal.
2. Tangkap konteks autentikasi lama untuk cleanup. Unregister harus memakai kredensial akun lama, bukan mengambil Dio milik akun baru.
3. Selesaikan/batalkan registration lama sesuai timeout network, lakukan unregister dengan body JSON, lalu hapus token Firebase lokal.
4. Bersihkan token autentikasi dan selesaikan logout walaupun cleanup jaringan/platform gagal. Akun baru tidak menunggu retry tanpa batas.

Urutan ini harus terintegrasi dengan invalidasi sesi lokal yang sudah ada: logout segera menutup akses UI, sementara cleanup lama memakai snapshot terbatas yang tidak dipersist. Account switch tidak boleh mendaftarkan token baru bersamaan dengan cleanup lama; pending operasi lama harus dibatalkan/drain sebelum registration baru.

Jika jaringan putus, klien tidak dapat menjamin server menghapus registration. Cancellation juga tidak membuktikan server membatalkan commit request. Catat kegagalan tanpa token/PII, regenerasikan token lokal sebelum binding akun baru, dan verifikasi perilaku server saat acceptance. Perlindungan UI tetap memerlukan lookup inbox sesi aktif. Isi OS notification untuk akun lama harus dicegah juga oleh cleanup/delivery backend; ini gate privacy release, bukan klaim yang bisa dibuktikan test fake.

## Inbox dan Routing

Ubah load-more ke `page` dengan limit tetap 50. Repository mengembalikan page metadata dari envelope. Refresh mengganti halaman pertama; load-more menambah halaman berikutnya dan deduplicate berdasarkan ID. Kegagalan load-more mempertahankan item lama dengan retry. Pergantian akun/company mengosongkan seluruh halaman dan error lama. Mutation read/delete mempertahankan rollback dan isolasi sesi yang sudah ada.

Foreground message hanya menginvalidasi/refetch unread count dan inbox yang sedang aktif. Tidak otomatis membuka route dan tidak menyalin judul/body payload ke banner lokal.

Tap dari background atau terminated menunggu auth restore selesai. Bila belum login, tampilkan login dan simpan satu petunjuk ID sementara dalam memori. Setelah login, lakukan lookup baru dalam inbox akun yang baru; jangan memulihkan item/payload akun sebelumnya. Logout atau pergantian identitas menghapus pending intent.

Lookup awal memakai halaman pertama inbox dengan limit 50. Bila ID tidak ada, hilang, tidak valid, atau payload tidak memiliki ID, buka `/notifications` dan biarkan pengguna memilih dari inbox. Tidak mencari seluruh riwayat dan tidak membuat endpoint lookup yang belum tersedia. Konsekuensinya: push lama mungkin hanya membuka inbox; backend dapat menyediakan lookup per-ID di tahap berikutnya.

Item yang ditemukan dipetakan melalui allowlist resource yang sudah ada: attendance, leave/leave_request, permission_request, dan work_calendar. Resource baru hanya ditambahkan jika route dan permission guard tersedia. URL, path, title, action, referenceId, dan company dari payload push tidak dipakai sebagai tujuan langsung. Payslip/approval belum masuk allowlist push awal; fallback inbox tetap tersedia. Detail payslip tetap membutuhkan PIN.

Deduplicate tap memakai message ID atau notification ID dalam himpunan memori terbatas, bernamespace session. Callback background tidak melakukan navigasi, fetch akun, atau menyimpan isi notifikasi. Coordinator menangani `onMessageOpenedApp` dan `getInitialMessage` setelah bootstrap siap; duplicate event tidak membuat dua navigasi atau dua read mutation.

## Error dan Privacy

Permission denied, token belum tersedia, atau Firebase disabled membuat inbox tetap dapat dipakai. Registration gagal menampilkan status dengan retry pengguna; retry otomatis hanya pada login baru, token rotation, atau resume yang memang memerlukan rekonsiliasi, tanpa polling.

Error auth mengikuti mekanisme refresh yang sudah ada. Stale callbacks tidak memperbarui badge, membuka route, atau melogout akun baru. Jangan mencatat token push, bearer token, ID instalasi lengkap, payload, atau isi notifikasi.

Payload OS notification yang dibuat backend sebaiknya generik, tanpa nominal payroll atau data sensitif. Firebase service-account key/APNs private key hanya di server/CI secret store dan tidak masuk repository atau APK. Config klien Firebase harus sesuai app ID dan environment nyata; dokumen ini tidak memasok nilai palsu.

## Pengujian dan Exit Gate

Test otomatis wajib mencakup:

- POST/DELETE contract, batas payload, JSON body DELETE, mapping error, dan idempotency.
- Installation ID stabil pada restart/logout dan terpisah per environment.
- Demo/disabled tidak memanggil Firebase; initialization failure tidak memblokir inbox/login.
- Login/restore, permission denied, token rotation, duplicate event, dan registration failure/retry.
- Race register/logout/login akun lain, callback lama, pending intent, dan company switch.
- Inbox page 1/2, limit tetap 50, metadata, dedup, retry load-more, read/delete rollback.
- Tap foreground/background/terminated dengan adapter fake; auth restore, resource allowlist, ID tidak ditemukan, payload URL berbahaya, dan PIN payslip tidak dilewati.
- Format, analyzer, full suite, golden/resilience yang terdampak, dan build Android debug.

Fake tests membuktikan coordinator/routing, bukan delivery FCM atau perilaku OS. Gate live memerlukan Firebase tiap environment, app ID, APNs/iOS capabilities, HTTPS, akun employee/manager, serta device Android/iOS. Uji push nyata pada foreground/background/terminated, izin ditolak, reinstall/token rotation, logout offline, account switch, dan recent-app/lock-screen privacy. Gate live belum boleh diberi PASS sebelum bukti tersebut tersedia.

## Urutan Implementasi Setelah Review

1. Kontrak repository registration, installation identity, dan pagination inbox.
2. Adapter Firebase/fake serta bootstrap opt-in tanpa mengubah demo.
3. Coordinator session-aware, rotation, dan cleanup logout terurut.
4. Tap resolver terverifikasi dan integrasi routing/inbox status.
5. Regression, review, build, report otomatis, dan checklist acceptance live terpisah.

Dokumen ini menetapkan desain. Rencana implementasi rinci disusun setelah pengguna menyetujui spesifikasi tertulis ini.
