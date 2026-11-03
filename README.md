# MemoIn Desktop - Flutter + Supabase

Proyek desktop Windows untuk MemoIn. Struktur dibuat sederhana supaya mudah dipelajari pemula.

## Struktur folder

```text
lib/
├── main.dart                 # Titik awal aplikasi dan inisialisasi Supabase
├── core/
│   └── app_theme.dart        # Token desain (warna, font, radius) dan tema aplikasi
├── models/
│   ├── memo.dart             # Bentuk data memo + konversi JSON
│   └── meter_stok.dart       # Bentuk data stok meter
├── services/
│   ├── memo_service.dart     # CRUD memo dan pencarian pelanggan
│   └── meter_stok_service.dart # CRUD stok meter
├── screens/
│   ├── login_screen.dart     # Login Supabase Auth
│   ├── main_shell.dart       # Sidebar dan navigasi utama
│   ├── dashboard_screen.dart # Dashboard, pencarian, CRUD, Excel
│   ├── memo_selesai_screen.dart
│   ├── stok_meter_screen.dart
│   └── evaluasi_screen.dart  # Filter periode dan grafik
└── widgets/
    ├── app_widgets.dart     # Komponen UI yang dipakai berulang
    └── memo_form_dialog.dart # Form tambah/edit memo
```

## 1. Prasyarat

- Flutter SDK stable
- Visual Studio 2022 dengan workload **Desktop development with C++**
- Akun/proyek Supabase

Cek instalasi:

```powershell
flutter doctor
```

## 2. Siapkan Supabase

1. Buka Supabase Dashboard dan pilih proyek.
2. Buka **SQL Editor**.
3. Jalankan seluruh isi `supabase-schema.sql`.
4. Buka **Authentication > Users** dan buat akun admin menggunakan email + password.
5. Ambil **Project URL** dan **publishable key** (atau anon key lama) dari Project Settings > API.

> Jangan pernah memasukkan `service_role` key ke aplikasi desktop. Aplikasi desktop adalah aplikasi client dan key tersebut dapat diekstrak.

## 3. Buat project Windows runner

Buka terminal di folder `MemoIn-Flutter-Supabase`, lalu jalankan:

```powershell
flutter create --platforms=windows .
flutter pub get
```

Perintah pertama menghasilkan folder `windows/` yang diperlukan untuk membangun aplikasi desktop.

## 4. Jalankan aplikasi

Ganti nilai di bawah dengan URL dan publishable/anon key proyekmu:

```powershell
flutter run -d windows --dart-define=SUPABASE_URL=https://PROJECT-REF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Kalau mau menjalankan dari VS Code/Android Studio, masukkan dua `--dart-define` tersebut ke konfigurasi run. Jangan commit key pribadi; publishable/anon key memang dirancang untuk client, tetapi semua akses tetap harus dibatasi dengan RLS.

## 5. Build installer/release

```powershell
flutter build windows --release --dart-define=SUPABASE_URL=https://PROJECT-REF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Output aplikasi ada di `build/windows/x64/runner/Release/`. Folder itu berisi executable dan DLL pendamping, bukan selalu satu file `.exe` mandiri. Untuk membagikan ke PC lain, distribusikan seluruh folder release atau bungkus dengan installer.

## Fitur yang sudah dipindahkan

- Login menggunakan Supabase Auth.
- Dashboard memo belum selesai, statistik, pencarian, filter Meter/MCB.
- Tambah, edit, detail, dan hapus memo.
- Status otomatis berdasarkan tanggal pemasangan.
- Cari pelanggan berdasarkan ID pelanggan atau nomor meter.
- Import Data DIL dari Excel (kolom IDPEL, TARIF, DAYA, NO_METER_BARU).
- Export memo ke Excel dengan sheet Meter dan MCB.
- Daftar memo selesai dan edit memo.
- CRUD stok meter, pencarian dan filter jenis pelanggan.
- Evaluasi memo selesai berdasarkan rentang tanggal, distribusi gangguan/merk/tahun, dan simpan ringkasan selama sesi aplikasi aktif.

## Catatan migrasi

- Aplikasi memakai database Supabase baru. Data PostgreSQL lama tidak otomatis disalin. Export/import data lama sebelum penggunaan produksi.
- Login Laravel sebelumnya memakai username. Supabase Auth memakai email + password; buat akun pengguna di Supabase Auth.
- Simpan evaluasi pada versi awal ini masih di memori aplikasi, sama seperti contoh evaluasi lokal di frontend sebelumnya. Jika ingin tersimpan permanen lintas PC, buat tabel `evaluations` di Supabase.
- Beberapa detail responsif/visual dari web perlu penyesuaian manual setelah dijalankan pada ukuran layar target. Uji alur CRUD dan format file Excel sebelum dipakai operasional.
- RLS pada SQL ini mengizinkan semua pengguna yang berhasil login mengelola data bersama. Untuk penggunaan produksi, sesuaikan policy dengan role/ULP bila diperlukan.

## Sistem desain

Seluruh tampilan bersumber dari `lib/core/app_theme.dart`:

- **Font**: satu keluarga untuk seluruh aplikasi (`AppTheme.font`, default Segoe UI), hanya bobot Regular dan Semibold.
  Untuk memakai font bundel (mis. Inter): taruh file di `assets/fonts/`, daftarkan di `pubspec.yaml` bagian `fonts:`,
  lalu ubah nilai `AppTheme.font`. Semua teks, tabel, dialog, dan grafik ikut berubah.
- **Warna**: palet desain utama. Biru `AppTheme.sidebar` (#003A8C) untuk sidebar, header dialog memo, dan panel login;
  `AppTheme.primary` (#0B3D91) untuk tombol; kuning hanya sebagai penanda menu aktif. Warna hijau/oranye/merah hanya untuk status.
- **Logo**: `assets/Logo.svg` ditampilkan lewat `BrandMark` (paket `flutter_svg`). Ganti file itu untuk mengganti logo di seluruh aplikasi.
- **Ikon**: satu keluarga Material *outlined*; ikon menu berganti ke versi terisi saat aktif. Ikon statistik berwarna di petak lembut.
- **Bentuk**: permukaan datar bergaris tipis; radius kartu 12, kontrol 10, dialog 16; tinggi kontrol seragam 44.
- Tidak ada gradien atau bayangan dekoratif.
- Komponen bersama ada di `widgets/app_widgets.dart` dan `widgets/dialog_frame.dart`. Gunakan komponen ini
  (mis. `StatusChip`, `SectionPanel`, `DialogHeader`) untuk layar baru supaya tampilannya tetap seragam.
