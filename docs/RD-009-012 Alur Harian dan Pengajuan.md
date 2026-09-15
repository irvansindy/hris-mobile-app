# Laporan Tahap 3: RD-009 sampai RD-012

Tanggal verifikasi: 14 September 2026.

Status: selesai untuk implementasi dan pengujian lokal. Verifikasi terhadap server live menunggu akun uji employee dan manager.

Catatan koreksi high-fidelity: tampilan yang dilaporkan di dokumen ini kemudian diselaraskan ulang terhadap struktur lengkap `HRIS Mobile Redesign.html`, bukan hanya gaya visualnya. Bukti dan batas koreksi dicatat dalam [Laporan Koreksi High-Fidelity Sebelum Tahap 4](<Koreksi High-Fidelity Sebelum Tahap 4.md>).

## Hasil implementasi

### RD-009: alur absensi nyata

- `GET /attendance/me/today` sekarang menghasilkan satu snapshot berisi record dan policy. Controller mengambil snapshot terbaru lagi tepat sebelum memilih check-in atau check-out.
- Controller mengunci transaksi sebelum refresh terakhir, sehingga double tap tidak dapat memulai dua request. State hanya berubah setelah server mengembalikan transaksi sukses.
- Policy terbaru menentukan GPS atau selfie. Perubahan policy saat dialog terbuka ditangani sebelum transaksi dikirim.
- Alur menampilkan preview selfie, konfirmasi, batal, progress, pesan penolakan server, recovery pengaturan lokasi, dan retry.
- Mock location serta akurasi di atas 100 meter berhenti di perangkat. Server tetap menjadi penentu geofence, face recognition, liveness, dan status review.
- Dashboard dan layar Absensi membaca provider attendance yang sama. Dashboard tidak lagi memanggil endpoint attendance sendiri.

### RD-010: Dashboard berbasis server

- Dashboard memakai `SliverAppBar` pinned yang menyusut saat konten digulir.
- Jam masuk, jam pulang, dan durasi berasal dari snapshot attendance server yang sama dengan layar Absensi.
- Aksi Pengajuan, Kalender, dan Absensi memiliki route nyata.
- Saldo cuti berasal dari `GET /leave/balances/employee`. Pemilih jenis cuti dan indikator lingkaran memiliki semantic label berdasarkan nilai server.
- Pengumuman hanya memakai notification dengan type atau category yang mengandung `ANNOUNCEMENT`.
- Error saldo dan pengumuman dipertahankan sebagai error section dengan retry. Nilainya tidak diganti angka nol.
- Tim, shift, heatmap, payroll, message entry, dan notification button tidak ditampilkan karena sumber data atau route lengkap belum tersedia pada tahap ini.

### RD-011: layar Absensi dan riwayat

- `GET /attendance/me?month=YYYY-MM&page=N&limit=20` terhubung ke pilihan bulan dan pagination meta.
- Filter Hadir, Cuti, dan Telat memproyeksikan record halaman yang diterima dari server. API terbaru belum mendokumentasikan query status, sehingga aplikasi tidak mengirim query yang tidak terjamin.
- Ringkasan menyebut total server, halaman, dan jumlah yang cocok pada halaman aktif. Bar chart disembunyikan karena endpoint agregasi periode tidak tersedia.
- Record memetakan tanggal, jam, branch, office timezone, review, dan geofence bila server mengirim field tersebut.
- Geofence tampil sebagai `Belum diverifikasi` sebelum server memberikan hasil.
- Loading, empty, error, pull-to-refresh, bulan sebelumnya, dan pagination tersedia.

### RD-012: Pengajuan cuti dan izin

- Katalog cuti memakai `GET /leave/types`.
- List cuti memakai `GET /leave`; list izin memakai `GET /permission-requests/my`. Keduanya memakai pagination dan tidak mengirim employee atau company identity dari client.
- Detail cuti memakai `GET /leave/:id`. Detail izin memakai record self-list karena kontrak terbaru tidak menyediakan endpoint detail self untuk izin.
- Form cuti mengirim `POST /leave`; form izin mengirim `POST /permission-requests`.
- Form menyediakan type server, date range, alasan, estimasi hari kerja Senin sampai Jumat, attachment foto data URI, konfirmasi, submit state, dan validasi lampiran wajib sesuai leave type.
- Hari libur perusahaan dan total final tetap divalidasi server. Integrasi kalender resolved akan menggantikan estimasi lokal pada RD-013.
- Submit memakai satu idempotency key per percobaan form dan mengunci tombol selama request. Respons sukses menampilkan serta mempertahankan ID server melalui list setelah aplikasi dimulai ulang.
- Pembatalan pending request terhubung ke `PATCH /leave/:id/cancel` dan `PATCH /permission-requests/:id/cancel`.
- Approver preview disembunyikan karena dokumen API tidak menyediakan endpoint preview approver untuk employee.

## Perubahan utama

- `lib/features/attendance`: snapshot today terpadu, riwayat paginated, hardening controller, dan layar baru.
- `lib/features/dashboard`: datasource tanpa duplikasi attendance, partial section error, sticky dashboard, dan leave balance selector.
- `lib/features/self_service`: datasource remote, model list/detail, route, form cuti/izin, attachment, confirmation, submit, dan cancel.
- `lib/app/router`: adapter lintas fitur untuk sinkronisasi attendance dan top-level route form/detail tanpa bottom navigation.
- `test/features/attendance` dan `test/features/self_service`: contract serta interaction test untuk endpoint dan payload baru.

## Verifikasi

- `flutter analyze`: PASS, tidak ada issue.
- `flutter test`: PASS, 167 test.
- `flutter build apk --debug`: PASS, menghasilkan `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web --release`: PASS, menghasilkan `build/web`.
- Web build masih memberi peringatan Wasm dari `flutter_secure_storage_web` karena legacy `dart:html` dan `dart:js_util`. Build JavaScript release tetap berhasil.
- `git diff --check`: PASS.

## Click-through yang diuji

- Catat masuk -> dialog konfirmasi -> Batal menutup dialog tanpa request.
- Catat masuk -> dialog konfirmasi -> Kirim -> GPS diambil -> server sukses -> status menjadi Sedang bekerja.
- Catat masuk -> server menolak -> pesan server tampil -> jam dan status sebelumnya tetap.
- Ambil selfie -> preview tampil -> Kirim -> payload face recognition dan liveness terkirim.
- Lokasi diblokir permanen -> Buka pengaturan -> gateway membuka pengaturan aplikasi.
- Beranda -> Buka Kehadiran -> destination Absensi aktif tanpa toggle lokal.
- Beranda -> Pengajuan -> route `/requests` terbuka tanpa bottom navigation.
- Quick action Ajukan cuti -> route `/requests/leave/new` hanya tampil untuk permission `leave:create`.
- Tab Riwayat -> ganti bulan atau halaman -> request query mengikuti pilihan dan state empty/error dapat retry.
- Submit cuti/izin -> payload sesuai kontrak -> ID server dipakai sebagai identitas transaksi.
- Batalkan pengajuan -> dialog konfirmasi -> endpoint cancel sesuai jenis request.

## Batas verifikasi live

- Tidak tersedia akun uji, sehingga refresh token, permission role, rate limit face, geofence cabang, format attachment maksimum, dan variasi schema response belum diuji terhadap server live.
- Kontrak auth belum membawa nama company. Header tidak menampilkan UUID sebagai pengganti nama perusahaan.
- API tidak menyediakan approver preview self, detail self untuk izin, atau filter status attendance. UI memilih perilaku aman dan jujur untuk ketiga batasan tersebut.

## Antislop Delivery Gate

Design Read: Employee Self-Service untuk karyawan Indonesia, light surface dengan kartu lembut, absensi sebagai fokus utama, ENERGY 2, RHYTHM 2, MOTION 2.

### Hard Gate

- R-02 PASS: copy baru tidak memakai em dash.
- R-03 PASS: test 320dp pada text scale 1.0 dan 2.0 lulus untuk light dan dark tanpa overflow.
- R-17 PASS: seluruh jam, count, saldo, dan total berasal dari respons server atau diberi label estimasi.
- R-18 PASS: tidak ada testimonial, nama, atau jabatan rekaan.
- R-23 PASS: tidak ada aset visual baru; avatar tetap memakai identitas session.
- R-24 PASS: aksi yang terlihat memiliki route nyata; fitur tanpa route disembunyikan.
- R-25 PASS: komponen memakai semantic color theme yang sudah melewati test contrast RD-004.
- R-26 PASS: absensi, filter, pagination, attachment, submit, cancel, retry, dan navigasi memiliki handler nyata.
- R-27 PASS: attendance, history, dashboard section, leave type, dan request list memiliki loading, empty, serta error state.
- R-28 PASS: tidak ada FAQ.
- R-32 PASS: kontrol Material mendukung fokus keyboard; dialog dapat ditutup dengan Escape dan tombol Batal.
- R-33 PASS: seluruh perubahan ditulis pada source Flutter, tanpa patch runtime eksternal.
- R-34 PASS: test light dan dark pada 320dp serta text scale 200 persen lulus.
- R-35 PASS: analyze, 167 test, APK debug, web release, dan click-through di atas lulus.
- R-36 PASS: tidak ada klaim keamanan, performa, atau compliance yang dibuat-buat.
- R-37 PASS: arah desain dan tiga dial dinyatakan sebelum implementasi.
- R-38 PASS: section tanpa data nyata disembunyikan dan tidak diisi konten prototipe.

### Purpose Gate

- R-01 PASS: primary `#315B8C` berasal dari handoff dan dipakai untuk hirarki aksi utama.
- R-04 PASS: ikon attendance, calendar, request, attachment, dan cancel menjelaskan tindakan masing-masing.
- R-06 PASS: Plus Jakarta Sans mengikuti identitas desain dan tidak ada monospace dekoratif.
- R-07 PASS: tidak ada grid atau pattern latar dekoratif.
- R-08 PASS: chevron hanya menandai navigasi atau pilihan detail.
- R-09 PASS: status chip menyampaikan status server, bukan label promosi.
- R-10 PASS: tidak ada glassmorphism tambahan.
- R-12 PASS: shadow mengikuti token elevasi kartu dan navigation, bukan semua elemen.
- R-13 PASS: tidak ada glow.
- R-14 PASS: kartu berbeda mengikuti fungsi attendance, quick action, balance, dan list.
- R-19 PASS: motion memakai perilaku Material singkat dan tidak ada animasi dekoratif tanpa akhir.
- R-22 PASS: tidak ada ilustrasi generik.

### Liveliness

- Dials PASS: ENERGY 2, RHYTHM 2, MOTION 2 dinyatakan.
- Consistency PASS: visual tenang, jarak teratur, dan motion rendah sesuai ketiga dial.
- Focal point PASS: attendance menjadi fokus Dashboard dan Hari ini, sedangkan submit menjadi fokus form.
- Whitespace PASS: spacing memisahkan policy, record, filter, list, dan action.
- Accent PASS: primary dipusatkan pada action dan status utama.
- Identity motif PASS: kartu radius lembut, semantic status chip, dan primary action berulang konsisten.
- Design Read PASS: arah Employee Self-Service dinyatakan sebelum generation.

### Craftsmanship dan Quality Locks

- C-1 PASS: keputusan visual mengikuti handoff, capability matrix, atau kebutuhan transaksi.
- C-2 PASS: tidak ada kontrol mati yang terlihat.
- C-3 PASS: setiap section mendukung pekerjaan attendance, request, atau informasi server.
- C-4 PASS: test state, theme, 320dp, text scale 200 persen, dan navigation lulus.
- C-5 PASS: tidak ada statistik atau claim tanpa sumber.
- R-05 PASS: komposisi mengikuti keputusan pengguna, bukan template dashboard generik.
- R-11 PASS: radius bervariasi sesuai token card, small card, sheet, dan pill.
- R-15 PASS: CTA menyebut tindakan seperti Catat masuk, Pilih foto, Tinjau dan kirim, serta Batalkan pengajuan.
- R-16 PASS: copy bebas buzzword pemasaran.
- R-20 PASS: istilah dan flow spesifik untuk HRIS Employee Self-Service.
- R-21 PASS: light dan dark tersedia dari pilihan Profil yang sudah ada.
- R-29 PASS: palette memakai primary dan semantic tones dari design system.
- R-30 PASS: implementasi mengikuti handoff HRIS, bukan meniru produk lain.
- R-31 PASS: layout, typography, spacing, card, dan visibility memiliki alasan satu baris pada baseline atau laporan ini.

### Checklist skill tambahan

- UI PASS: sumber palette, accent, section composition, route, state, dan angka telah diaudit terhadap handoff dan API.
- Mobile PASS: bottom navigation, safe area, 44dp target, 320dp, dan text scale 200 persen telah diuji.
- Human PASS: semantics status/donut, live error, keyboard Material, contrast theme, dan resize text tersedia.
- Code comments PASS: file baru tidak menambah separator, narasi langkah, komentar kosong, atau TODO samar.
- Copywriting PASS: CTA spesifik, Bahasa Indonesia natural, tanpa data rekaan, buzzword, atau em dash.
