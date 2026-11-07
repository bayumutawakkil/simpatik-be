ALTER TABLE penugasan_guru
  ALTER COLUMN kelas_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION validasi_penugasan_guru()
RETURNS TRIGGER AS $$
DECLARE
  v_siswa_kelas_id UUID;
  v_ada_penugasan BOOLEAN;
BEGIN
  SELECT kelas_id INTO v_siswa_kelas_id
  FROM siswa
  WHERE id = NEW.siswa_id;

  IF v_siswa_kelas_id IS NULL THEN
    RAISE EXCEPTION 'Siswa % belum dimasukkan ke dalam kelas.', NEW.siswa_id;
  END IF;

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
