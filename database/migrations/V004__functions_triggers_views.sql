-- ============================================================================
-- MIGRATION: V004__functions_triggers_views.sql
-- DESKRIPSI: Fungsi pendukung, trigger audit & validasi, serta view analytical
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. FUNGSI & TRIGGER: updated_at OTOMATIS
-- ============================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Pasang trigger updated_at pada tabel yang memiliki kolom updated_at
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_guru_updated_at ON guru;
CREATE TRIGGER trg_guru_updated_at
  BEFORE UPDATE ON guru
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_kelas_updated_at ON kelas;
CREATE TRIGGER trg_kelas_updated_at
  BEFORE UPDATE ON kelas
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_siswa_updated_at ON siswa;
CREATE TRIGGER trg_siswa_updated_at
  BEFORE UPDATE ON siswa
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_mata_pelajaran_updated_at ON mata_pelajaran;
CREATE TRIGGER trg_mata_pelajaran_updated_at
  BEFORE UPDATE ON mata_pelajaran
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_nilai_updated_at ON nilai;
CREATE TRIGGER trg_nilai_updated_at
  BEFORE UPDATE ON nilai
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_kehadiran_updated_at ON kehadiran;
CREATE TRIGGER trg_kehadiran_updated_at
  BEFORE UPDATE ON kehadiran
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_prestasi_updated_at ON prestasi;
CREATE TRIGGER trg_prestasi_updated_at
  BEFORE UPDATE ON prestasi
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_catatan_perkembangan_updated_at ON catatan_perkembangan;
CREATE TRIGGER trg_catatan_perkembangan_updated_at
  BEFORE UPDATE ON catatan_perkembangan
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_pengaturan_sistem_updated_at ON pengaturan_sistem;
CREATE TRIGGER trg_pengaturan_sistem_updated_at
  BEFORE UPDATE ON pengaturan_sistem
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 2. TRIGGER STATUS PRESTASI: OTOMATIS ISIKAN diverifikasi_at KETIKA DIVERIFIKASI
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_prestasi_status_verifikasi()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status_verifikasi = 'DIVERIFIKASI' AND (OLD IS NULL OR OLD.status_verifikasi <> 'DIVERIFIKASI') THEN
    IF NEW.diverifikasi_at IS NULL THEN
      NEW.diverifikasi_at := now();
    END IF;
  ELSIF NEW.status_verifikasi <> 'DIVERIFIKASI' THEN
    -- Jika di-pending atau ditolak, reset tanggal verifikasi jika belum diset
    NEW.diverifikasi_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prestasi_verifikasi_sync ON prestasi;
CREATE TRIGGER trg_prestasi_verifikasi_sync
  BEFORE INSERT OR UPDATE OF status_verifikasi ON prestasi
  FOR EACH ROW
  EXECUTE FUNCTION trg_fn_prestasi_status_verifikasi();

-- ============================================================================
-- 3. TRIGGER AUDIT: CATAT AUDIT LOG PADA users, nilai, kehadiran, prestasi
-- ============================================================================
CREATE OR REPLACE FUNCTION catat_audit()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID := NULL;
  v_session_user_str TEXT;
  v_entitas_id UUID := NULL;
  v_data_sebelum JSONB := NULL;
  v_data_sesudah JSONB := NULL;
BEGIN
  -- Dapatkan user ID konteks dari session setting jika diset back-end via:
  -- SET LOCAL simpatik.current_user_id = 'uuid...';
  BEGIN
    v_session_user_str := current_setting('simpatik.current_user_id', true);
    IF v_session_user_str IS NOT NULL AND v_session_user_str ~ '^[0-9a-fA-F-]{36}$' THEN
      v_user_id := v_session_user_str::UUID;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    v_entitas_id := NEW.id;
    v_data_sesudah := to_jsonb(NEW);
    INSERT INTO audit_log (user_id, aksi, entitas, entitas_id, data_sebelum, data_sesudah, created_at)
    VALUES (v_user_id, 'CREATE', TG_TABLE_NAME, v_entitas_id, NULL, v_data_sesudah, now());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    v_entitas_id := NEW.id;
    v_data_sebelum := to_jsonb(OLD);
    v_data_sesudah := to_jsonb(NEW);
    INSERT INTO audit_log (user_id, aksi, entitas, entitas_id, data_sebelum, data_sesudah, created_at)
    VALUES (v_user_id, 'UPDATE', TG_TABLE_NAME, v_entitas_id, v_data_sebelum, v_data_sesudah, now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    v_entitas_id := OLD.id;
    v_data_sebelum := to_jsonb(OLD);
    INSERT INTO audit_log (user_id, aksi, entitas, entitas_id, data_sebelum, data_sesudah, created_at)
    VALUES (v_user_id, 'DELETE', TG_TABLE_NAME, v_entitas_id, v_data_sebelum, NULL, now());
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_users ON users;
CREATE TRIGGER trg_audit_users
  AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW
  EXECUTE FUNCTION catat_audit();

DROP TRIGGER IF EXISTS trg_audit_nilai ON nilai;
CREATE TRIGGER trg_audit_nilai
  AFTER INSERT OR UPDATE OR DELETE ON nilai
  FOR EACH ROW
  EXECUTE FUNCTION catat_audit();

DROP TRIGGER IF EXISTS trg_audit_kehadiran ON kehadiran;
CREATE TRIGGER trg_audit_kehadiran
  AFTER INSERT OR UPDATE OR DELETE ON kehadiran
  FOR EACH ROW
  EXECUTE FUNCTION catat_audit();

DROP TRIGGER IF EXISTS trg_audit_prestasi ON prestasi;
CREATE TRIGGER trg_audit_prestasi
  AFTER INSERT OR UPDATE OR DELETE ON prestasi
  FOR EACH ROW
  EXECUTE FUNCTION catat_audit();

-- ============================================================================
-- 4. TRIGGER VALIDASI KEPEMILIKAN PENUGASAN GURU (Pertahanan Tingkat Basis Data)
-- ============================================================================
CREATE OR REPLACE FUNCTION validasi_penugasan_guru()
RETURNS TRIGGER AS $$
DECLARE
  v_siswa_kelas_id UUID;
  v_ada_penugasan BOOLEAN;
BEGIN
  -- Dapatkan kelas siswa
  SELECT kelas_id INTO v_siswa_kelas_id
  FROM siswa
  WHERE id = NEW.siswa_id;

  IF v_siswa_kelas_id IS NULL THEN
    RAISE EXCEPTION 'Siswa % belum dimasukkan ke dalam kelas.', NEW.siswa_id;
  END IF;

  -- Cek apakah guru yang mencatat ditugaskan pada kelas dan mata pelajaran tersebut
  SELECT EXISTS (
    SELECT 1 FROM penugasan_guru
    WHERE guru_id = NEW.guru_id
      AND (kelas_id = v_siswa_kelas_id OR kelas_id IS NULL)
      AND mata_pelajaran_id = NEW.mata_pelajaran_id
  )
  OR EXISTS (
    SELECT 1 FROM kelas
    WHERE id = v_siswa_kelas_id
      AND wali_kelas_id = NEW.guru_id
  )
  INTO v_ada_penugasan;

  IF NOT v_ada_penugasan THEN
    RAISE EXCEPTION 'Pelanggaran Penugasan: Guru % tidak ditugaskan untuk mengajar mapel % di kelas siswa %',
      NEW.guru_id, NEW.mata_pelajaran_id, v_siswa_kelas_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validasi_nilai_penugasan ON nilai;
CREATE TRIGGER trg_validasi_nilai_penugasan
  BEFORE INSERT OR UPDATE OF siswa_id, mata_pelajaran_id, guru_id ON nilai
  FOR EACH ROW
  EXECUTE FUNCTION validasi_penugasan_guru();

DROP TRIGGER IF EXISTS trg_validasi_kehadiran_penugasan ON kehadiran;
CREATE TRIGGER trg_validasi_kehadiran_penugasan
  BEFORE INSERT OR UPDATE OF siswa_id, mata_pelajaran_id, guru_id ON kehadiran
  FOR EACH ROW
  EXECUTE FUNCTION validasi_penugasan_guru();

-- ============================================================================
-- 5. VIEWS UNTUK MONITORING & DASHBOARD
-- ============================================================================

-- View 5.1: v_siswa_aktif
-- Siswa aktif (deleted_at IS NULL), beserta kelas dan wali kelas
CREATE OR REPLACE VIEW v_siswa_aktif AS
SELECT
  s.id AS siswa_id,
  s.nis,
  s.nama AS nama_siswa,
  s.jenis_kelamin,
  s.tanggal_lahir,
  s.alamat,
  s.nama_orang_tua,
  s.no_telepon,
  k.id AS kelas_id,
  k.nama AS nama_kelas,
  k.tingkat AS tingkat_kelas,
  k.tahun_ajaran,
  g.id AS wali_kelas_id,
  g.nama AS nama_wali_kelas,
  g.nip AS nip_wali_kelas
FROM siswa s
LEFT JOIN kelas k ON s.kelas_id = k.id AND k.deleted_at IS NULL
LEFT JOIN guru g ON k.wali_kelas_id = g.id AND g.deleted_at IS NULL
WHERE s.deleted_at IS NULL;

-- View 5.2: v_rata_rata_nilai_siswa
-- Rata-rata nilai per siswa, per mapel, per periode (hanya siswa dan mapel aktif)
CREATE OR REPLACE VIEW v_rata_rata_nilai_siswa AS
SELECT
  n.siswa_id,
  s.nis,
  s.nama AS nama_siswa,
  n.mata_pelajaran_id,
  mp.kode AS kode_mapel,
  mp.nama AS nama_mapel,
  n.periode,
  ROUND(AVG(n.nilai), 2) AS rata_rata,
  COUNT(n.id) AS jumlah_komponen_nilai,
  MIN(n.nilai) AS nilai_terendah,
  MAX(n.nilai) AS nilai_tertinggi
FROM nilai n
JOIN siswa s ON n.siswa_id = s.id AND s.deleted_at IS NULL
JOIN mata_pelajaran mp ON n.mata_pelajaran_id = mp.id AND mp.deleted_at IS NULL
GROUP BY
  n.siswa_id,
  s.nis,
  s.nama,
  n.mata_pelajaran_id,
  mp.kode,
  mp.nama,
  n.periode;

-- View 5.3: v_persentase_kehadiran
-- Persentase kehadiran per siswa per mapel.
-- Berdasarkan ASUMSI.md: SAKIT/IZIN dihitung sebagai tidak hadir dalam persentase murni HADIR.
-- Rumus: ROUND(COUNT(*) FILTER (WHERE status = 'HADIR') * 100.0 / NULLIF(COUNT(*), 0), 2)
CREATE OR REPLACE VIEW v_persentase_kehadiran AS
SELECT
  kh.siswa_id,
  s.nis,
  s.nama AS nama_siswa,
  s.kelas_id,
  k.nama AS nama_kelas,
  kh.mata_pelajaran_id,
  mp.kode AS kode_mapel,
  mp.nama AS nama_mapel,
  COUNT(kh.id) AS total_pertemuan,
  COUNT(kh.id) FILTER (WHERE kh.status = 'HADIR') AS total_hadir,
  COUNT(kh.id) FILTER (WHERE kh.status = 'SAKIT') AS total_sakit,
  COUNT(kh.id) FILTER (WHERE kh.status = 'IZIN') AS total_izin,
  COUNT(kh.id) FILTER (WHERE kh.status = 'ALPA') AS total_alpa,
  ROUND(
    COUNT(kh.id) FILTER (WHERE kh.status = 'HADIR') * 100.0 / NULLIF(COUNT(kh.id), 0),
    2
  ) AS persentase_hadir
FROM kehadiran kh
JOIN siswa s ON kh.siswa_id = s.id AND s.deleted_at IS NULL
LEFT JOIN kelas k ON s.kelas_id = k.id AND k.deleted_at IS NULL
JOIN mata_pelajaran mp ON kh.mata_pelajaran_id = mp.id AND mp.deleted_at IS NULL
GROUP BY
  kh.siswa_id,
  s.nis,
  s.nama,
  s.kelas_id,
  k.nama,
  kh.mata_pelajaran_id,
  mp.kode,
  mp.nama;

-- View 5.4: v_siswa_kehadiran_rendah
-- Siswa dengan persentase kehadiran di bawah ambang batas ATTENDANCE_THRESHOLD pada tabel pengaturan_sistem
CREATE OR REPLACE VIEW v_siswa_kehadiran_rendah AS
WITH threshold AS (
  SELECT COALESCE(
    (SELECT NULLIF(nilai, '')::NUMERIC FROM pengaturan_sistem WHERE kunci = 'ATTENDANCE_THRESHOLD'),
    75.0
  ) AS val
)
SELECT
  pk.siswa_id,
  pk.nis,
  pk.nama_siswa,
  pk.kelas_id,
  pk.nama_kelas,
  pk.mata_pelajaran_id,
  pk.kode_mapel,
  pk.nama_mapel,
  pk.total_pertemuan,
  pk.total_hadir,
  pk.total_sakit,
  pk.total_izin,
  pk.total_alpa,
  pk.persentase_hadir,
  t.val AS attendance_threshold
FROM v_persentase_kehadiran pk
CROSS JOIN threshold t
WHERE pk.persentase_hadir < t.val;

-- View 5.5: v_ringkasan_prestasi
-- Jumlah prestasi dikelompokkan berdasarkan status verifikasi dan tingkat prestasi
CREATE OR REPLACE VIEW v_ringkasan_prestasi AS
SELECT
  p.status_verifikasi,
  p.tingkat,
  COUNT(p.id) AS total_prestasi,
  COUNT(DISTINCT p.siswa_id) AS total_siswa
FROM prestasi p
JOIN siswa s ON p.siswa_id = s.id AND s.deleted_at IS NULL
GROUP BY
  p.status_verifikasi,
  p.tingkat;

COMMIT;
