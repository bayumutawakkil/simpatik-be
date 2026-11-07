# SIMPATIK Backend (Sistem Manajemen Data Akademik Siswa)

Backend RESTful API SIMPATIK berbasis Node.js, Express, TypeScript, Prisma ORM, dan PostgreSQL.

---

## 1. Prasyarat & Lingkungan

- **Node.js:** Versi 18+ (direkomendasikan v20+)
- **PostgreSQL:** Versi 15 atau lebih baru
- **Ekstensi PostgreSQL:** `pgcrypto`, `citext`, `pg_trgm` (diinisialisasi otomatis via migrasi)
- **GUI Database:** pgAdmin 4

---

## 2. Konfigurasi Lingkungan (`.env`)

SIMPATIK menerapkan prinsip pemisahan hak akses ganda (*Dual Role Architecture*):
- **`DATABASE_URL`**: Digunakan oleh runtime aplikasi Express dengan role `simpatik_app` (hak DML terbatas, `audit_log` bersifat *append-only*).
- **`DIRECT_URL`**: Digunakan oleh Prisma CLI untuk migrasi DDL dengan role `simpatik_admin` (pemilik skema).

Salin template file `.env.example` ke `.env`:

```bash
cp .env.example .env
```

Sesuaikan nilai variabel:

```env
# Database PostgreSQL connection URLs
DATABASE_URL="postgresql://simpatik_app:GANTI_PASSWORD_APP@localhost:5432/simpatik_db?schema=public"
DIRECT_URL="postgresql://simpatik_admin:GANTI_PASSWORD_ADMIN@localhost:5432/simpatik_db?schema=public"

# Keamanan dan Autentikasi JWT
JWT_SECRET="ganti-dengan-secret-key-yang-kuat"
JWT_EXPIRES_IN="8h"
PORT=4000
CORS_ORIGIN="http://localhost:8443"

# Konfigurasi Berkas & Upload
UPLOAD_DIR="./uploads"
MAX_UPLOAD_MB=5

# Ambang Batas Logika Akademik
ATTENDANCE_THRESHOLD=75
NILAI_DROP_THRESHOLD=10

# Kredensial Awal untuk Seeding Akun
SEED_ADMIN_EMAIL="admin@simpatik.test"
SEED_ADMIN_PASSWORD="admin123"
SEED_GURU_PASSWORD="password123"
```

Akun seed kepala sekolah menggunakan `kepsek@simpatik.test` dengan password yang sama
dengan `SEED_GURU_PASSWORD`. Role `KEPSEK` bersifat read-only untuk data guru, siswa,
nilai, dan prestasi.

---

## 3. Langkah Instalasi & Menjalankan Back End

### Langkah 1: Persiapan Database PostgreSQL (Superuser)
Jalankan script setup awal role dan database menggunakan user superuser `postgres`:

```bash
psql -U postgres -f database/scripts/00_setup_role_dan_database.sql
```

### Langkah 2: Instalasi Dependensi & Generate Prisma Client
```bash
npm install
npx prisma generate
```

### Langkah 3: Menjalankan Migrasi Skema & Fitur Manual
```bash
# Menjalankan migrasi DDL Prisma ke PostgreSQL (menggunakan DIRECT_URL simpatik_admin)
npx prisma migrate dev
```

### Langkah 4: Seeding Data Dummy
```bash
# Seeding data via Prisma Client
npx prisma db seed
```

### Langkah 5: Menjalankan Server
```bash
# Mode pengembangan (hot-reload)
npm run dev

# Mode produksi
npm run build
npm start
```

---

## 4. Akun Contoh (Hasil Seeding)

| Peran | Nama | Email | Password | Keterangan |
|---|---|---|---|---|
| **Admin** | Administrator Utama | `admin@simpatik.test` | `admin123` | Akses penuh dashboard, kelola user/guru/kelas, verifikasi prestasi |
| **Guru** | Bambang Sudarmanto, M.Pd. | `bambang@simpatik.test` | `password123` | Wali Kelas X IPA 1 & Guru Matematika |
| **Guru** | Siti Rahmawati, S.Si. | `siti.rahmawati@simpatik.test` | `password123` | Wali Kelas X IPA 2 & Guru Fisika/Kimia |
| **Guru** | Ahmad Fauzi, S.Pd. | `ahmad.fauzi@simpatik.test` | `password123` | Wali Kelas X IPS 1 & Guru Bahasa Indonesia/Inggris |
| **Guru** | Dewi Lestari, M.Si. | `dewi.lestari@simpatik.test` | `password123` | Wali Kelas XI IPA 1 & Guru Biologi |
| **Guru** | Eko Prasetyo, S.Pd. | `eko.prasetyo@simpatik.test` | `password123` | Wali Kelas XI IPS 1 & Guru Sejarah/Ekonomi |

---

## 5. Perintah-perintah Prisma Penting

| Perintah | Fungsi |
|---|---|
| `npx prisma validate` | Memvalidasi sintaks dan relasi pada `schema.prisma` |
| `npx prisma format` | Merapikan format kode file schema |
| `npx prisma generate` | Menghasilkan kode `@prisma/client` terbaru |
| `npx prisma migrate dev` | Menjalankan migrasi dalam mode pengembangan |
| `npx prisma migrate deploy` | Menjalankan migrasi tertunda pada lingkungan produksi |
| `npx prisma migrate reset` | Mengosongkan database dan menjalankan migrasi serta seed dari nol (Development Only) |
| `npx prisma db seed` | Menjalankan script `prisma/seed.ts` |
| `npx prisma studio` | Membuka antarmuka GUI Prisma Studio di browser (`http://localhost:5555`) |

---

## 6. Verifikasi di pgAdmin 4 & Pengujian

1. **pgAdmin 4**: Buka pgAdmin, daftarkan server `localhost:5432` dengan database `simpatik_db`.
2. **Periksa Objek**: Pastikan 13 tabel dan 5 view terbentuk di schema `public`.
3. **Jalankan Verifikasi Data**:
   Buka **Query Tool** di pgAdmin dan jalankan file `be/database/scripts/verifikasi.sql`.
   Semua pemeriksaan (jumlah akun, rentang nilai 0–100, keunikan presensi, kepemilikan guru, dan status verifikasi) harus menunjukkan status **LULUS**.
4. **Jalankan Integration Test**:
   ```bash
   npm test
   ```
