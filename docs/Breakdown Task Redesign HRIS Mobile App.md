# Breakdown Task Redesign HRIS Mobile App

Tanggal baseline: 14 September 2026.

Dokumen ini memecah design handoff HRIS Mobile Redesign menjadi pekerjaan Flutter yang dapat dikerjakan dan diverifikasi satu per satu. Dokumen ini melengkapi, bukan menggantikan, [Breakdown Task HRIS Mobile App](<Breakdown Task HRIS Mobile App.md>) dan [API Integration Revision](<API_INTEGRATION_REVISION.md>).

Sumber desain eksternal:

- `HRIS Mobile App Redesign/design_handoff_hris_mobile/README.md`
- `HRIS Mobile App Redesign/design_handoff_hris_mobile/HRIS Mobile Redesign.html`
- `HRIS Mobile App Redesign/design_handoff_hris_mobile/support.js`

Klarifikasi high-fidelity, 14 September 2026: file HTML adalah sumber kebenaran untuk struktur, komposisi, ukuran, urutan section, navigasi, bentuk, warna, dan tipografi seluruh layar yang sudah tersedia. Referensi tersebut bukan sekadar arah gaya. Nilai contoh dalam prototipe tetap tidak boleh masuk ke aplikasi. `support.js` adalah runtime yang membuat prototipe HTML bekerja dan tidak menjadi dependency Flutter.

Bukti implementasi koreksi: [Laporan Koreksi High-Fidelity Sebelum Tahap 4](<Koreksi High-Fidelity Sebelum Tahap 4.md>).

Status awal seluruh task adalah `TODO`. Gunakan `IN PROGRESS`, `BLOCKED`, `REVIEW`, atau `DONE` setelah ada bukti implementasi dan verifikasi.

Pembagian pengerjaan yang disepakati:

| Tahap | Task | Gate |
|---|---|---|
| 1 | RD-001 sampai RD-004 | Laporan fondasi desain dan theme |
| 2 | RD-005 sampai RD-008 | Laporan komponen, router, auth presentation, dan navigation controls |
| 3 | RD-009 sampai RD-012 | Laporan absensi, Dashboard, riwayat, dan Pengajuan |
| 4 | RD-013 sampai RD-016 | Laporan Kalender, Notifikasi, Pesan, dan Profil |
| 5 | RD-017 sampai RD-020 | Laporan payroll terlindungi, hardening, motion, dan release gate |

Setiap tahap dimulai setelah laporan tahap sebelumnya disetujui.

## 1. Keputusan desain yang menjadi baseline

Design Read: aplikasi Employee Self-Service untuk karyawan Indonesia, memakai tampilan light surface dengan kartu lembut dan aksi absensi sebagai fokus utama. Dial desain: `ENERGY 2 / RHYTHM 2 / MOTION 2`.

| Keputusan | Baseline | Alasan |
|---|---|---|
| Warna utama | `#315B8C` | Menjadi identitas visual utama dan penanda aksi prioritas. |
| Tipografi | Plus Jakarta Sans, weight 300 sampai 700 | Mendukung karakter modern dan keterbacaan Bahasa Indonesia tanpa membuat UI terlalu berat. |
| Navigasi utama | Beranda, Absensi, FAB absensi, Kalender, Profil | Menempatkan aksi harian pada pusat navigasi dan mengurangi persaingan antarfitur. |
| Pengajuan | Dibuka dari quick action, dashboard, atau layar terkait | Pengajuan tetap mudah dijangkau tanpa menjadi tab utama. |
| Payroll | Hanya melalui Profil dan sheet terlindungi | Mengurangi paparan data sensitif di dashboard. |
| Tema | Light dan dark | Pengguna dapat memilih tema dari Profil. |
| Motion | Transisi singkat dan kontekstual | Memberi feedback tanpa menghambat tugas harian. |

## 2. Guardrail implementasi

- Semua nama, tanggal, status, statistik, pesan, dan nominal pada prototipe adalah data contoh. Jangan memindahkannya ke build pengguna.
- FAB absensi adalah pintu masuk ke alur absensi nyata, bukan toggle sukses lokal. GPS, selfie, permission, policy server, loading, error, dan hasil transaksi tetap wajib diproses.
- Sidik jari, Face ID, dan Scan QR hanya ditampilkan jika kontrak backend serta kemampuan perangkat sudah tersedia.
- PIN slip gaji harus diverifikasi server. Nominal dan rincian tidak boleh dikirim sebelum verifikasi berhasil.
- Kontrol yang belum memiliki perilaku nyata harus disembunyikan atau diberi status yang jujur. Jangan mengirim tombol mati.
- Setiap layar data wajib menangani loading, empty, error, offline, unauthorized, dan retry yang relevan.
- Layout 390 x 844 adalah referensi visual, bukan ukuran layar tetap. Implementasi harus aman pada Android kecil, perangkat besar, safe area, keyboard, dan text scaling.
- `support.js` hanya runtime prototipe. Jangan menyalin atau memasukkannya ke aplikasi Flutter.

## 3. Urutan prioritas

### Fase A: kontrak desain dan fondasi

#### RD-001 | P0 | Bekukan kontrak desain dan inventaris perubahan

**Status: DONE lokal, 14 September 2026.** Bukti: [laporan fondasi redesign](<RD-001-004 Fondasi Redesign.md>).

**Dependency:** tidak ada.  
**Ukuran:** S.  
**Area:** dokumentasi, theme, seluruh layar.

- [x] Catat token warna light/dark, typography, spacing, radius, shadow, dan motion dari handoff.
- [x] Petakan elemen prototipe ke widget Flutter yang sudah ada dan tandai widget yang perlu diganti.
- [x] Catat perbedaan antara handoff dengan source saat ini, termasuk `#2563EB` ke `#315B8C`, Inter ke Plus Jakarta Sans, dan perubahan navigasi.
- [x] Tentukan bagian yang harus sama secara visual dan bagian yang harus disesuaikan karena keamanan, API, atau platform.

**Selesai jika:** tersedia satu referensi token dan keputusan desain yang dipakai seluruh screen tanpa nilai visual baru yang tersebar inline.

#### RD-002 | P0 | Petakan setiap elemen desain ke data dan capability nyata

**Status: DONE untuk audit lokal, 14 September 2026.** Verifikasi capability live tetap mengikuti task API terkait. Bukti: [laporan fondasi redesign](<RD-001-004 Fondasi Redesign.md>).

**Dependency:** RD-001, HRIS-008, HRIS-016 sampai HRIS-023.  
**Ukuran:** M.  
**Area:** domain, API contract, presentation.

- [x] Buat matriks screen, section, sumber data, endpoint, permission, dan kondisi tampil.
- [x] Tandai dashboard heatmap, saldo cuti, pengumuman, tim, shift, notifikasi, chat, dan slip gaji sebagai `available`, `blocked`, atau `not supported`.
- [x] Tentukan data yang boleh di-cache dan data sensitif yang tidak boleh disimpan tanpa enkripsi.
- [x] Pastikan role dan company scope menentukan visibility menu dan request context.

**Selesai jika:** tidak ada section yang diimplementasikan memakai data contoh hanya karena endpoint atau capability belum tersedia.

#### RD-003 | P0 | Lengkapi spesifikasi state, responsivitas, dan aksesibilitas

**Status: DONE sebagai acceptance specification, 14 September 2026.** Implementasi per component/screen dilanjutkan mulai RD-005. Bukti: [laporan fondasi redesign](<RD-001-004 Fondasi Redesign.md>).

**Dependency:** RD-001.  
**Ukuran:** M.  
**Area:** seluruh presentation layer.

- [x] Tentukan layout untuk lebar kurang dari 360dp, 360 sampai 430dp, lebih dari 430dp, dan tablet.
- [x] Tentukan perilaku saat keyboard terbuka, orientation berubah, serta system text scale 1.0 sampai 2.0.
- [x] Definisikan loading, empty, error, offline, permission denied, disabled, submitting, dan success state per layar.
- [x] Tetapkan tap target minimal 44dp, semantics label, urutan fokus, dan contrast WCAG AA.
- [x] Definisikan safe area untuk status bar, gesture bar, bottom navigation, sheet, dan FAB.

**Selesai jika:** acceptance visual dapat diuji di luar ukuran referensi 390 x 844 dan setiap data screen memiliki state non-happy-path.

#### RD-004 | P0 | Implementasikan design token dan typography baru

**Status: DONE lokal, 14 September 2026.** Theme, font asset, lisensi, dan test token/contrast sudah ditambahkan. Bukti: [laporan fondasi redesign](<RD-001-004 Fondasi Redesign.md>).

**Dependency:** RD-001.  
**Ukuran:** M.  
**Area:** `core/theme`, assets font, shared styles.

- [x] Ganti warna utama menjadi `#315B8C` dan tambahkan seluruh semantic color light/dark.
- [x] Bundle Plus Jakarta Sans sebagai asset agar layout tidak bergantung pada unduhan runtime.
- [x] Buat token `AppSpacing`, `AppRadius`, `AppShadows`, dan durasi motion.
- [x] Perbarui `ThemeData`, `ColorScheme`, text theme, input, card, sheet, chip, button, dan navigation theme.
- [x] Hapus dependency font runtime dan nilai theme lama yang sudah digantikan token baru.

**Selesai jika:** light/dark theme memakai token yang sama, font tersedia saat offline, dan analyzer tidak menemukan referensi theme lama yang seharusnya sudah diganti.

#### RD-005 | P0 | Bangun komponen UI bersama dan state standar

**Status: DONE lokal, 14 September 2026.** Komponen bersama, state standar, dan widget test sudah ditambahkan. Bukti: [laporan shell dan autentikasi](<RD-005-008 Shell dan Autentikasi.md>).

**Dependency:** RD-003, RD-004, HRIS-015.  
**Ukuran:** L.  
**Area:** `core/widgets`.

- [x] Buat card, section header, status chip, avatar inisial, icon button dengan badge, segmented control, floating nav, dan bottom sheet shell.
- [x] Buat loading, empty, error, offline, permission, serta retry component yang menyebut konteks dan tindakan berikutnya.
- [x] Buat skeleton yang mengikuti bentuk konten tanpa menampilkan angka atau identitas palsu.
- [x] Tambahkan widget test untuk theme, text scaling, semantics, tap target, dan overflow.

**Selesai jika:** screen baru memakai komponen bersama untuk pola berulang dan tidak menduplikasi token atau state handling.

### Fase B: shell, autentikasi, dan alur harian

#### RD-006 | P0 | Refactor router dan main shell

**Status: DONE lokal, 14 September 2026.** Router deklaratif, shell empat branch, route tanpa navigation bar, back handling, dan isolasi state per session sudah diuji. Bukti: [laporan shell dan autentikasi](<RD-005-008 Shell dan Autentikasi.md>).

**Dependency:** RD-004, RD-005, HRIS-021, HRIS-022.  
**Ukuran:** L.  
**Area:** `main.dart`, router, shell navigation.

- [x] Pertahankan state tiap tab dengan router yang mendukung detail route dan deep link.
- [x] Ubah shell menjadi empat destination dengan FAB absensi di tengah.
- [x] Keluarkan Pengajuan dari tab utama dan sediakan route yang dapat dibuka dari quick action.
- [x] Sembunyikan navigation bar pada form, detail, camera, dan protected payroll flow melalui top-level route di luar shell.
- [x] Tangani Android back, tap tab aktif untuk scroll ke atas, safe area, dan perubahan role/capability.

**Selesai jika:** seluruh destination dan detail route dapat dibuka langsung, back navigation benar, serta pergantian akun tidak mempertahankan navigation state milik akun lama.

#### RD-007 | P1 | Implementasikan splash dan revisi tampilan login

**Status: DONE lokal, 14 September 2026.** Splash mengikuti restore session, login responsif menangani validasi dan failure state, serta overlay sukses menunggu bootstrap identity. Bukti: [laporan shell dan autentikasi](<RD-005-008 Shell dan Autentikasi.md>).

**Dependency:** RD-004, RD-005, kontrak auth HRIS-001 sampai HRIS-004.  
**Ukuran:** M.  
**Area:** authentication presentation.

- [x] Buat splash dengan durasi maksimum yang tidak memperlambat restore session.
- [x] Terapkan layout login, field, CTA, loading, validation, invalid credential, lockout, dan gangguan jaringan.
- [x] Tampilkan overlay berhasil hanya setelah login dan bootstrap employee/company berhasil.
- [x] Gunakan nama employee aktual pada success state, bukan nama dari prototipe.
- [x] Tampilkan biometric, QR, atau Face ID hanya bila capability nyata tersedia.
- [x] Jangan tampilkan lupa kata sandi jika route dan kontrak recovery belum tersedia.

**Selesai jika:** restore session tidak dipaksa melewati login, kegagalan bootstrap tidak ditampilkan sebagai sukses, dan semua metode login yang terlihat benar-benar bekerja.

#### RD-008 | P1 | Implementasikan floating navigation dan quick action

**Status: DONE lokal, 14 September 2026.** Floating navigation aktif, FAB membuka Absensi, dan registry shortcut memfilter endpoint, route, serta permission. Shortcut yang belum didukung tetap tersembunyi. Bukti: [laporan shell dan autentikasi](<RD-005-008 Shell dan Autentikasi.md>).

**Dependency:** RD-006, HRIS-012, HRIS-018, HRIS-021.  
**Ukuran:** M.  
**Area:** main shell.

- [x] Terapkan ukuran, inset, shadow, active state, dan label Bahasa Indonesia sesuai handoff.
- [x] Hubungkan FAB tengah ke layar attendance yang memakai orchestrator, bukan perubahan state lokal.
- [x] Buat registry shortcut FAB Dashboard untuk Ajukan cuti, Klaim lembur, Reimbursement, dan Slip gaji.
- [x] Filter shortcut berdasarkan endpoint, route, dan permission yang tersedia.
- [x] Tutup shortcut ketika tab berubah, scroll, session berubah, backdrop disentuh, atau tombol Escape ditekan.
- [x] Tambahkan haptic ringan melalui API platform.

**Selesai jika:** setiap destination dan shortcut memiliki route atau action nyata, tidak ada dead control, dan double tap tidak menghasilkan transaksi ganda.

#### RD-009 | P0 | Integrasikan FAB dengan alur absensi nyata

**Status: DONE lokal, perlu live API review, 14 September 2026.** Bukti: [laporan Tahap 3](<RD-009-012 Alur Harian dan Pengajuan.md>).

**Dependency:** RD-006, RD-008, HRIS-009 sampai HRIS-013.  
**Ukuran:** L.  
**Area:** attendance controller, location, selfie, confirmation UI.

- [x] Ambil attendance context dan record terbaru sebelum menentukan clock-in atau clock-out.
- [x] Jalankan location permission, service check, accuracy, mock-location handling, dan selfie sesuai policy server.
- [x] Tampilkan preview, konfirmasi, progress, cancel, server rejection, timeout, dan retry.
- [x] Nonaktifkan aksi selama request berjalan dan cegah double-submit.
- [x] Sinkronkan state Dashboard, FAB, dan Attendance screen dari respons server yang sama.
- [x] Jangan mengubah jam atau status jika transaksi gagal.

**Selesai jika:** clock-in/out hanya berubah setelah server menerima transaksi, seluruh failure state dapat dipulihkan, dan tidak ada toggle sukses lokal.

#### RD-010 | P1 | Redesign Dashboard memakai data server

**Status: DONE lokal sesuai capability tersedia, perlu live API review, 14 September 2026.** Bukti: [laporan Tahap 3](<RD-009-012 Alur Harian dan Pengajuan.md>).

**Dependency:** RD-002, RD-005, RD-006, RD-009, HRIS-012, HRIS-016 sampai HRIS-018.  
**Ukuran:** XL.  
**Area:** dashboard presentation dan mapping data.

- [x] Buat sticky header yang menyusut, identitas employee, company, notification badge, dan message entry sesuai capability.
- [x] Tampilkan jam masuk, jam pulang, dan durasi kerja dari attendance record server.
- [x] Hubungkan quick action Pengajuan dan Kalender.
- [x] Tampilkan pengumuman, tim hari ini, shift berikutnya, heatmap, dan saldo cuti hanya jika sumber data nyata tersedia.
- [x] Buat leave donut interaktif dengan semantic label dan nilai dari server.
- [x] Jangan tampilkan payroll atau nominal di Dashboard.
- [x] Sediakan refresh per section atau layar tanpa mengganti error menjadi angka nol.

**Selesai jika:** seluruh angka memiliki sumber server, section yang gagal dapat retry, data kosong tidak terlihat seperti error, dan Dashboard tidak memakai fallback demo.

#### RD-011 | P1 | Redesign layar Absensi dan riwayat

**Status: DONE lokal, perlu live API review untuk variasi schema, 14 September 2026.** Bukti: [laporan Tahap 3](<RD-009-012 Alur Harian dan Pengajuan.md>).

**Dependency:** RD-005, RD-009, HRIS-014.  
**Ukuran:** L.  
**Area:** attendance presentation.

- [x] Buat header, CTA Ajukan Cuti, ringkasan periode, geofence status, statistik, segmented filter, dan list riwayat.
- [x] Ganti bar chart prototipe dengan data periode server atau sembunyikan bila agregasi tidak tersedia.
- [x] Petakan status Hadir, Cuti, dan Telat dari kontrak server.
- [x] Dukung pagination, perubahan bulan, timezone kantor, pull-to-refresh, empty, dan error state.
- [x] Jangan menyatakan area kantor valid sebelum context/location check selesai.

**Selesai jika:** riwayat dan ringkasan konsisten dengan server, filter tidak memakai list lokal, dan status lokasi tidak bersifat prediktif.

### Fase C: fitur pendukung

#### RD-012 | P1 | Redesign Pengajuan dan form transaksi

**Status: DONE lokal untuk kontrak cuti dan izin, perlu live API review, 14 September 2026.** Bukti: [laporan Tahap 3](<RD-009-012 Alur Harian dan Pengajuan.md>).

**Dependency:** RD-005, RD-006, HRIS-018, HRIS-019.  
**Ukuran:** XL.  
**Area:** self-service request presentation.

- [x] Buat ringkasan aktif/selesai dan filter yang dihitung dari respons server.
- [x] Hubungkan list, detail, status timeline, pagination, dan retry.
- [x] Hubungkan Buat Pengajuan ke pilihan tipe yang benar-benar tersedia.
- [x] Lengkapi date range, perhitungan hari kerja, alasan, attachment, approver preview, konfirmasi, dan submit state.
- [x] Cegah duplikasi submit dan pertahankan ID transaksi server untuk recovery.

**Selesai jika:** seluruh kartu dan filter bekerja, status berasal dari server, dan transaksi tetap dapat ditemukan setelah aplikasi dimulai ulang.

#### RD-013 | P1 | Redesign Kalender

**Status: REVIEW lokal, 15 September 2026.** Kalender self-service sudah terintegrasi. Today zona kantor dan fixture deployment masih menunggu backend. Bukti: [laporan Tahap 4](<RD-013-016 Kalender Notifikasi dan Profil.md>).

**Dependency:** RD-005, RD-006, HRIS-017.  
**Ukuran:** L.  
**Area:** calendar presentation.

- [x] Implementasikan grid Senin-first untuk bulan dan tahun aktual.
- [x] Tampilkan jadwal kerja, cuti/izin pribadi, libur, shift, dan legend dari resolved calendar. Cuti tim disembunyikan karena kontrak team calendar belum tersedia.
- [x] Hubungkan pemilihan tanggal, perubahan bulan/tahun, Today perangkat berlabel jelas, serta list agenda.
- [x] Tangani date-only tanpa konversi timezone, loading, empty, error, offline, dan refresh.
- [ ] Today berdasarkan timezone kantor: respons belum menyertakan timezone/tanggal server.

**Selesai jika:** tidak ada tanggal/event hardcode dan kalender konsisten pada pergantian bulan, tahun, locale, serta zona waktu.

#### RD-014 | P1 | Implementasikan layar Notifikasi

**Status: REVIEW untuk inbox lokal; BLOCKED untuk push, 15 September 2026.** Bukti: [laporan Tahap 4](<RD-013-016 Kalender Notifikasi dan Profil.md>).

**Dependency:** RD-006, HRIS-023, HRIS-024.  
**Ukuran:** L.  
**Area:** notification presentation dan deep link.

- [x] Hubungkan unread count di header dengan inbox server.
- [x] Buat list bertahap memakai `limit`, read, read-all, empty, retry, dan pull-to-refresh sesuai kontrak server.
- [x] Petakan notification type ke icon/tone, serta resource ke allowlist route mobile. Resource belum didukung membuka isi notifikasi tanpa route rekaan.
- [ ] Pagination page/cursor: server hanya mendokumentasikan `limit`, tanpa metadata halaman/cursor.
- [ ] Pastikan push foreground/background/terminated membuka detail untuk akun aktif yang sesuai.

**Selesai jika:** badge sinkron setelah item dibaca, deep link aman terhadap session/company, dan tidak ada notifikasi contoh.

#### RD-015 | P2 | Putuskan dan implementasikan scope Pesan

**Status: DONE untuk keputusan scope, 15 September 2026.** Revisi pengguna meminta ikon chat tetap terlihat di header Beranda. Ikon membuka keterangan bahwa layanan belum tersedia, bukan percakapan contoh. API final belum menyediakan kontrak chat. Bukti: [laporan Tahap 4](<RD-013-016 Kalender Notifikasi dan Profil.md>).

**Dependency:** RD-002, RD-006, kontrak backend chat yang terverifikasi.  
**Ukuran:** M sampai XL.  
**Area:** messaging.

- [x] Verifikasi API final dan source lokal: tidak ada kontrak conversation, history, send, attachment, atau unread chat.
- [x] Sesuai revisi pengguna, tampilkan ikon chat dengan dialog unavailable yang dapat ditutup, tanpa badge contoh atau pengiriman pesan palsu.
- [x] Cabang implementasi chat tidak berlaku sampai kontrak tersedia; tidak dibuat endpoint atau conversation contoh.
- [x] Tidak ada cache pesan atau state chat yang dibuat sehingga tidak ada data chat lintas akun.

**Selesai jika:** keputusan scope jelas. Sesuai revisi pengguna, ikon tetap terlihat dengan keterangan unavailable; implementasi chat end-to-end tetap menunggu kontrak nyata.

#### RD-016 | P1 | Redesign Profil dan Pengaturan

**Status: REVIEW lokal untuk profil/pengaturan yang tersedia, 15 September 2026.** Dokumen dan atasan belum terintegrasi; push dan pemilihan bahasa tidak diaktifkan secara semu. Bukti: [laporan Tahap 4](<RD-013-016 Kalender Notifikasi dan Profil.md>).

**Dependency:** RD-004, RD-005, HRIS-008, HRIS-016.  
**Ukuran:** L.  
**Area:** profile presentation.

- [x] Tampilkan avatar inisial, identitas sesi, kontak, dan kepegawaian dari profil server; detail gagal/terbatas ditampilkan dengan state jujur serta retry.
- [ ] Dokumen dan atasan dari server: belum ada kontrak mobile memadai. Payroll terlindungi tetap scope RD-017.
- [x] Filter baris berdasarkan data dan `employee:read`, serta validasi employee/company respons.
- [x] Theme toggle di Profil memakai tema aktual dan preferensi yang tersimpan.
- [x] Push setting tidak ditampilkan; Bahasa Indonesia berupa informasi read-only, bukan pilihan bahasa yang belum diimplementasikan.
- [x] Ambil versi aplikasi dari package metadata, termasuk build number.
- [x] Pertahankan logout dan guard respons terlambat saat pergantian akun.

**Selesai jika:** tidak ada data identitas atau menu mati, theme preference pulih setelah restart, dan logout tidak meninggalkan data pengguna sebelumnya.

#### RD-017 | P0 keamanan, P2 fitur | Implementasikan slip gaji terlindungi

**Status: BLOCKED backend, 15 September 2026.** Audit kontrak selesai; list tanpa nominal, PIN/unlock expiry dan PDF belum dikontrakkan. Tidak dibuat unlock lokal atau endpoint rekaan. Bukti: [audit kontrak RD-017](<RD-017 Kontrak Slip Gaji Terlindungi.md>).

**Dependency:** RD-005, RD-006, RD-016, kontrak payroll/PIN backend, HRIS-029.  
**Ukuran:** XL.  
**Area:** payroll, secure screen, document handling.

- [x] Verifikasi ketersediaan kontrak: hanya list/detail payroll terdokumentasi; kontrak perlindungan yang diperlukan belum tersedia. Implementasi tetap BLOCKED.
- [ ] Buat sheet tiga tahap: riwayat terkunci, verifikasi PIN/biometric, dan detail.
- [ ] Jangan menyimpan PIN, nominal, atau PDF dalam log dan storage tidak terenkripsi.
- [ ] Terapkan screenshot protection pada layar/sheet sensitif sesuai dukungan platform.
- [ ] Hubungkan download dan share dengan file sementara serta cleanup.
- [ ] Tangani PIN salah, lockout, session expiry, jaringan gagal, file gagal, dan pembatalan biometric.

**Selesai jika:** nominal tidak pernah diterima sebelum server unlock, data sensitif terlindungi, dan file sementara dibersihkan setelah dipakai.

### Fase D: hardening visual dan verifikasi

#### RD-018 | P1 | Audit light/dark, locale, text scale, dan platform

**Status: REVIEW lokal, 15 September 2026.** Matriks widget 32 konfigurasi dan golden lulus; QA perangkat Android/iOS, keyboard native dan gesture tetap belum selesai. Bukti: [laporan Tahap 5](<RD-017-020 Hardening dan Release Gate.md>).

**Dependency:** RD-007 sampai RD-017 sesuai scope rilis.  
**Ukuran:** L.  
**Area:** seluruh UI.

- [x] Uji light/dark pada screen/state yang dirilis melalui matriks widget, golden, dan regresi fitur.
- [x] Aktifkan Material localization Indonesia dan uji string panjang serta tanggal/input tanggal; format waktu/durasi yang tersedia tetap dilindungi regresi.
- [ ] Format Rupiah payroll: belum berlaku sebelum kontrak RD-017 tersedia, bukan nominal contoh.
- [x] Uji text scale 1.0, 1.3, 1.5, dan 2.0 tanpa RenderFlex overflow; kontrol panjang dapat wrap/scroll.
- [x] Uji konfigurasi Android/iOS 320 x 568 dan 430 x 932, safe-area, simulasi keyboard dan system-back pada host widget test.
- [ ] Uji perangkat Android/iOS nyata, keyboard native dan gesture navigation.
- [x] Jalankan contrast checker dan regresi WCAG AA pada pasangan teks/control utama light/dark.

**Selesai jika:** golden/widget test utama lulus dan pemeriksaan manual tidak menemukan overflow, clipping, atau text contrast bermasalah.

#### RD-019 | P2 | Finalisasi motion, feedback, dan reduced motion

**Status: REVIEW lokal, 15 September 2026.** Reduced motion, sheet/dialog, FAB dan scroll diuji. Frame rendering perangkat kelas menengah belum diukur.

**Dependency:** RD-007 sampai RD-017.  
**Ukuran:** M.  
**Area:** animation dan haptic.

- [x] Audit motion yang tersedia: feedback login nonblocking, tab/scroll, FAB, donut berbasis nilai dan bottom sheet; tidak ditambahkan sticky header atau animasi dekoratif yang mengubah handoff.
- [x] Loading berulang hanya saat proses aktif; reduced motion memakai indikator statis dengan semantics, bukan progress palsu.
- [x] Hormati disable animations platform pada FAB, scroll, transisi halaman, theme, dialog/sheet dan feedback login.
- [x] Feedback login tidak menangkap tap; reduced motion tidak menunggu timer dan kembali ke atas melalui jumpTo. Restore/transaksi tidak menunggu feedback visual.
- [ ] Ukur frame rendering pada perangkat kelas menengah.

**Selesai jika:** motion memberi feedback yang jelas, tidak menyebabkan dropped frame yang mengganggu, dan aplikasi tetap dapat dipakai ketika animasi dinonaktifkan.

#### RD-020 | P0 release gate | Tambahkan verifikasi regresi redesign

**Status: REVIEW lokal, belum DONE release, 15 September 2026.** Regresi lokal dan baseline visual tersedia. Integration fixture perangkat, iOS/macOS CI, pengukuran performa dan smoke staging masih memerlukan bukti. Bukti: [laporan Tahap 5](<RD-017-020 Hardening dan Release Gate.md>).

**Dependency:** seluruh task dalam scope rilis.  
**Ukuran:** XL.  
**Area:** test, CI, QA perangkat.

- [x] Tambahkan matriks widget ukuran kecil/besar, light/dark, loading/empty/error dan 16 golden baru untuk teks 200%.
- [x] Tambahkan regresi navigasi lengkap dan account switch; pertahankan protected route/deep link serta quick action tests.
- [x] Siapkan integration fixture login, Beranda, absensi sukses/gagal, pengajuan, kalender, notifikasi dan logout A ke B; alur yang sama dijalankan sebagai host widget test.
- [ ] Jalankan integration fixture pada perangkat/emulator; payroll tetap BLOCKED, bukan integration sukses lokal.
- [x] Jalankan gate formatter/analyzer/unit/widget/golden dan validasi build Android lokal; CI quality/Android diperluas dengan build iOS macOS tanpa signing.
- [ ] Verifikasi hasil CI remote dan build iOS pada macOS; Linux lokal tidak dapat membuktikan build iOS.
- [x] Catat click-through lokal dan kontrol noninteraktif/unsupported; permission/file native tetap masuk QA perangkat.
- [ ] Jalankan smoke test dengan akun employee/manager dan server staging sebelum status DONE.

**Selesai jika:** CI lulus, bukti visual tersedia, alur kritis lulus pada perangkat, dan tidak ada data contoh atau sukses palsu pada build staging/release.

## 4. Milestone pengerjaan

| Milestone | Task | Hasil |
|---|---|---|
| M1: Fondasi visual | RD-001 sampai RD-005 | Token, typography, komponen, state, responsivitas, dan accessibility siap dipakai. |
| M2: Daily flow | RD-006 sampai RD-011 | Login, shell, Dashboard, dan absensi nyata memakai desain baru. |
| M3: ESS pendukung | RD-012 sampai RD-017 | Pengajuan, kalender, notifikasi, profil, serta fitur opsional tersedia sesuai kontrak. |
| M4: Release candidate | RD-018 sampai RD-020 | Light/dark, motion, accessibility, regresi, CI, dan perangkat tervalidasi. |

Critical path: `RD-001 -> RD-003/RD-004 -> RD-005 -> RD-006 -> RD-008 -> RD-009 -> RD-010/RD-011`. RD-002 berjalan setelah RD-001 dan harus selesai sebelum section Dashboard atau fitur baru dinyatakan siap.

## 5. Definition of Done per task

Sebuah task redesign berstatus `DONE` hanya jika:

- acceptance task terpenuhi dan tidak hanya cocok pada screenshot 390 x 844;
- data yang terlihat berasal dari server atau empty state yang jujur;
- tidak ada dead control, toggle sukses lokal, atau metode autentikasi semu;
- light/dark, loading, empty, error, retry, serta text scaling yang relevan diuji;
- widget/unit/integration test terkait lulus;
- analyzer dan formatter lulus;
- perubahan kontrak API atau navigation dicatat dalam dokumentasi;
- bukti uji perangkat atau staging disertakan untuk fitur yang memakai permission, kamera, lokasi, push, biometric, file, atau data sensitif.

## 6. Urutan mulai yang disarankan

| Urutan | Task | Fokus |
|---|---|---|
| 1 | RD-001 | Bekukan kontrak desain. |
| 2 | RD-002 dan RD-003 | Petakan data/capability dan lengkapi state/responsivitas. Keduanya dapat berjalan paralel. |
| 3 | RD-004 | Migrasikan theme dan font. |
| 4 | RD-005 | Bangun komponen bersama dan state standar. |
| 5 | RD-006 | Refactor router dan shell. |
| 6 | RD-007 dan RD-008 | Implementasikan auth presentation serta navigation controls. Keduanya dapat berjalan paralel setelah fondasi siap. |
| 7 | RD-009 | Amankan alur absensi melalui FAB. |
| 8 | RD-010 dan RD-011 | Redesign Dashboard serta layar Absensi memakai sumber state yang sama. |
| 9 | RD-012, RD-013, RD-014, dan RD-016 | Kerjakan fitur ESS pendukung sesuai kesiapan API. |
| 10 | RD-017 | Implementasikan slip gaji setelah kontrak unlock server tersedia. |
| 11 | RD-015 | Implementasikan Pesan hanya jika kontrak chat sudah terbukti. |
| 12 | RD-018, RD-019, dan RD-020 | Selesaikan hardening visual, motion, regresi, dan release gate. |

Vertical slice pertama berakhir pada RD-011. Pada titik itu login, shell, Dashboard, dan absensi sudah dapat diuji end-to-end memakai desain baru tanpa menunggu seluruh fitur pendukung.
