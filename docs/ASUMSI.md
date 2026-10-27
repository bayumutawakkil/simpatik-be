# Catatan Asumsi & Keputusan Desain Basis Data & Integrasi Prisma SIMPATIK

Dokumen ini mencatat asumsi operasional, aturan bisnis, dan keputusan desain struktural basis data PostgreSQL serta integrasi Prisma ORM untuk Sistem Informasi Manajemen Data Akademik Siswa (SIMPATIK).

---

## 1. Lingkungan & Kompatibilitas DBMS
- **DBMS Target:** PostgreSQL versi 15 atau lebih baru (direkomendasikan versi 15 s.d. 18).
- **Versi Prisma:** Prisma CLI dan `@prisma/client` versi `^5.22.0`.
- **Ekstensi PostgreSQL Wajib:**
  - `pgcrypto` untuk pembuatan UUID v4 acak (`gen_random_uuid()`).
  - `citext` untuk penanganan teks *case-insensitive* pada kolom `users.email`.
  - `pg_trgm` untuk pengindeksan GIN trigram pada nama siswa dan guru (`ILIKE '%...%'`).
- **Skema:** Menggunakan skema `public` secara konsisten pada database `simpatik_db`.

---

## 2. Struktur Entitas & Keputusan Pemetaan Prisma Schema

### 2.1 Konvensi Nama Model & Kolom
- **Model Prisma:** PascalCase bahasa Indonesia/Inggris selaras (`User`, `Guru`, `Kelas`, `Siswa`, `MataPelajaran`, `PenugasanGuru`, `Nilai`, `Kehadiran`, `Prestasi`, `BuktiPrestasi`, `CatatanPerkembangan`, `PengaturanSistem`, `AuditLog`).
- **Field Model:** camelCase di TypeScript (`namaOrangTua`, `waliKelasId`, `mataPelajaranId`).
- **Tabel & Kolom Database:** snake_case di PostgreSQL menggunakan atribut `@@map("nama_tabel")` dan `@map("nama_kolom")`.
- **Primary Key:** `UUID` string (`String @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid`), kecuali `AuditLog` yang menggunakan `BigInt @id @default(autoincrement())` dan `PengaturanSistem` yang menggunakan kunci teks (`String @id @db.VarChar(50)`).

### 2.2 Tipe ENUM vs Tabel Referensi
- **Tipe ENUM yang Digunakan:**
  - `role_pengguna`: `ADMIN`, `GURU` (konstanta peran sistem).
  - `jenis_kelamin`: `LAKI_LAKI`, `PEREMPUAN`.
  - `jenis_nilai`: `HARIAN`, `TUGAS`, `UTS`, `UAS`.
  - `status_kehadiran`: `HADIR`, `SAKIT`, `IZIN`, `ALPA`.
  - `tingkat_prestasi`: `SEKOLAH`, `KECAMATAN`, `KABUPATEN`, `PROVINSI`, `NASIONAL`, `INTERNASIONAL`.
  - `status_verifikasi`: `PENDING`, `DIVERIFIKASI`, `DITOLAK`.
  - `aspek_perkembangan`: `AKADEMIK`, `SOSIAL`, `EMOSIONAL`, `KARAKTER`, `KETERAMPILAN`.
  - `status_perkembangan_siswa`: `BAIK`, `PERHATIAN`, `KRITIS`.
- **Bidang Prestasi (`bidang`):**
  - Menggunakan tipe `VARCHAR(50)` (bukan ENUM kaku) untuk menampung keberagaman bidang perlombaan yang sangat dinamis (seperti `SAINS`, `OLAHRAGA`, `SENI`, `TEKNOLOGI`, `BAHASA`, `ROBOTIKA`, dsb.) tanpa harus melakukan migrasi DDL berulang.

### 2.3 Kompatibilitas Preview Features pada Prisma 5.22.0
- Fitur `postgresqlExtensions` digunakan pada `generator client` dan `datasource db` untuk mendeklarasikan ekstensi PostgreSQL `[pgcrypto, citext, pg_trgm]`.
- Fitur `fullTextSearchPostgres` adalah fitur khusus Prisma 6; pada Prisma 5.22.0 digunakan `fullTextSearch` standar, sementara query pencarian cepat nama siswa/guru memanfaatkan index GIN trigram `pg_trgm` di PostgreSQL.

### 2.4 Penanganan Nilai Harian & Komponen Nilai
- Aturan keunikan nilai: `UNIQUE (siswa_id, mata_pelajaran_id, periode, jenis, pertemuan)`.
- Kolom `pertemuan` (SMALLINT DEFAULT 1) disediakan agar nilai jenis `HARIAN` atau `TUGAS` dapat dimasukkan beberapa kali (misal: Tugas 1, Tugas 2, UH 1, UH 2) tanpa melanggar constraint keunikan, sementara UTS dan UAS menggunakan pertemuan 1 secara baku.

### 2.5 Perhitungan Persentase Kehadiran (SAKIT & IZIN)
- Dalam penghitungan persentase murni kehadiran siswa pada view `v_persentase_kehadiran`, formula yang digunakan adalah:
  $$\text{Persentase Hadir} = \text{ROUND}\left(\frac{\text{COUNT(HADIR)} \times 100.0}{\text{COUNT(TOTAL PERTEMUAN)}}, 2\right)$$
- **Asumsi:** Status `SAKIT` dan `IZIN` dicatat dan ditampilkan secara transparan di kolom tersendiri (`total_sakit`, `total_izin`), namun dalam penghitungan kehadiran fisik di kelas diperlakukan sebagai tidak hadir secara fisik demi akurasi monitoring komitmen tatap muka.

---

## 3. Hak Akses & Keamanan Data (Dual Role Setup)
- **Role `simpatik_admin` (`DIRECT_URL`):**
  - Pemilik seluruh tabel, view, tipe, dan sequence.
  - Digunakan khusus oleh Prisma CLI untuk menjalankan migrasi DDL (`npx prisma migrate dev / deploy`).
- **Role `simpatik_app` (`DATABASE_URL`):**
  - Diberikan hak `SELECT`, `INSERT`, `UPDATE`, `DELETE` untuk operasi runtime aplikasi Express back-end.
  - **Pengecualian `audit_log`:** Hak `UPDATE` dan `DELETE` dicabut dari `simpatik_app` (`REVOKE UPDATE, DELETE ON audit_log FROM simpatik_app;`). Hal ini menjamin log audit bersifat *Append-Only* (tidak dapat dimanipulasi dari aplikasi).

---

## 4. Integritas Relasi & Perlindungan Data
- **Soft Deletion:**
  - Diterapkan pada entitas `siswa`, `guru`, `kelas`, dan `mata_pelajaran` dengan kolom `deleted_at TIMESTAMPTZ`.
  - Pada layer aplikasi, repository dan service secara konsisten menerapkan kondisi `{ deletedAt: null }`.
  - Semua view analytical (`v_siswa_aktif`, `v_rata_rata_nilai_siswa`, `v_persentase_kehadiran`, `v_ringkasan_prestasi`) secara otomatis menyaring baris di mana `deleted_at IS NULL`.
- **Aturan ON DELETE:**
  - `siswa.kelas_id` $\to$ `ON DELETE SET NULL`.
  - `guru.user_id` $\to$ `ON DELETE RESTRICT` (mencegah akun terhapus jika riwayat guru masih ada).
  - `penugasan_guru` $\to$ `ON DELETE CASCADE` terhadap guru, kelas, dan mapel.
  - `nilai` dan `kehadiran` $\to$ `ON DELETE RESTRICT` pada guru dan mapel untuk mencegah hilangnya riwayat nilai/kehadiran akademik yang penting.
- **Trigger Validasi Pertahanan:**
  - Trigger `validasi_penugasan_guru` memastikan guru hanya dapat mencatat nilai dan kehadiran untuk kelas dan mata pelajaran yang sah sesuai tabel `penugasan_guru`.

---

## 5. Fitur Database di Luar Dukungan Native Prisma
Prisma Schema tidak mendukung secara langsung beberapa fitur canggih PostgreSQL, sehingga fitur berikut disertakan via migrasi SQL manual ([`prisma/migrations/20261020000000_init/migration.sql`](file:///d:/Project/simpatik/be/prisma/migrations/20261020000000_init/migration.sql)):
1. **CHECK Constraints:**
   - Nilai 0–100 (`chk_nilai_rentang`)
   - Tingkat kelas 1–12 (`chk_kelas_tingkat`)
   - Format tahun ajaran regex `^\d{4}/\d{4}$` (`chk_kelas_tahun_ajaran`)
   - Tanggal lahir siswa tidak di masa depan (`chk_siswa_tanggal_lahir`)
   - Ukuran file berkas prestasi $\le$ 5 MB dan tipe MIME yang diizinkan (`chk_bukti_prestasi_ukuran`, `chk_bukti_prestasi_mime`)
   - Keterikatan verifikator pada status `DIVERIFIKASI` (`chk_prestasi_verifikasi`)
2. **Partial Indexes & GIN Trigram:**
   - Partial index: `idx_siswa_kelas_id_active` pada `siswa(kelas_id) WHERE deleted_at IS NULL`
   - GIN Trigram: `idx_siswa_nama_trgm` pada `siswa USING gin (nama gin_trgm_ops)` dan `idx_guru_nama_trgm` pada `guru USING gin (nama gin_trgm_ops)`
3. **Triggers & Stored Functions:**
   - `set_updated_at()` untuk update timestamp otomatis
   - `catat_audit()` untuk merekam audit log JSONB data sebelum & sesudah
   - `validasi_penugasan_guru()` sebagai layer keamanan database
   - `trg_fn_prestasi_status_verifikasi()` untuk otomatisasi timestamp verifikasi prestasi
4. **Analytical Views:**
   - `v_siswa_aktif`, `v_rata_rata_nilai_siswa`, `v_persentase_kehadiran`, `v_siswa_kehadiran_rendah`, `v_ringkasan_prestasi`
5. **Grants & Default Privileges:**
   - Konfigurasi izin role `simpatik_app` dan revokasi mutasi pada `audit_log`.
