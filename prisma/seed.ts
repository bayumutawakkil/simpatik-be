import { PrismaClient, RolePengguna, JenisKelamin, JenisNilai, StatusKehadiran, TingkatPrestasi, StatusVerifikasi } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  console.log("Memulai proses seeding basis data SIMPATIK...");

  // 1. Pengaturan Sistem
  await prisma.pengaturanSistem.upsert({
    where: { kunci: "ATTENDANCE_THRESHOLD" },
    update: {},
    create: { kunci: "ATTENDANCE_THRESHOLD", nilai: "75", keterangan: "Ambang batas minimum persentase kehadiran (%)" },
  });
  await prisma.pengaturanSistem.upsert({
    where: { kunci: "NILAI_DROP_THRESHOLD" },
    update: {},
    create: { kunci: "NILAI_DROP_THRESHOLD", nilai: "10", keterangan: "Ambang batas penurunan nilai rata-rata poin" },
  });

  // 2. Users
  const pwAdmin = await bcrypt.hash("admin123", 10);
  const pwGuru = await bcrypt.hash("password123", 10);

  const adminTest = await prisma.user.upsert({
    where: { email: "admin@simpatik.test" },
    update: { passwordHash: pwAdmin, isActive: true },
    create: { name: "Administrator Utama", email: "admin@simpatik.test", passwordHash: pwAdmin, role: RolePengguna.ADMIN, isActive: true },
  });

  await prisma.user.upsert({
    where: { email: "admin@simpatik.local" },
    update: { passwordHash: pwAdmin, isActive: true },
    create: { name: "Administrator Lokal", email: "admin@simpatik.local", passwordHash: pwAdmin, role: RolePengguna.ADMIN, isActive: true },
  });

  const guruBambang = await prisma.user.upsert({
    where: { email: "bambang@simpatik.test" },
    update: { passwordHash: pwGuru, isActive: true },
    create: { name: "Bambang Sudarmanto, M.Pd.", email: "bambang@simpatik.test", passwordHash: pwGuru, role: RolePengguna.GURU, isActive: true },
  });

  const guruSiti = await prisma.user.upsert({
    where: { email: "siti.rahmawati@simpatik.test" },
    update: { passwordHash: pwGuru, isActive: true },
    create: { name: "Siti Rahmawati, S.Si.", email: "siti.rahmawati@simpatik.test", passwordHash: pwGuru, role: RolePengguna.GURU, isActive: true },
  });

  // 3. Guru Profil
  const profilBambang = await prisma.guru.upsert({
    where: { nip: "198001012005011001" },
    update: { userId: guruBambang.id },
    create: {
      userId: guruBambang.id,
      nip: "198001012005011001",
      nama: "Bambang Sudarmanto, M.Pd.",
      noTelepon: "081234567890",
      alamat: "Jl. Pendidikan No. 10, Padang",
    },
  });

  const profilSiti = await prisma.guru.upsert({
    where: { nip: "198502022008012002" },
    update: { userId: guruSiti.id },
    create: {
      userId: guruSiti.id,
      nip: "198502022008012002",
      nama: "Siti Rahmawati, S.Si.",
      noTelepon: "081298765432",
      alamat: "Jl. Merdeka No. 45, Padang",
    },
  });

  // 4. Kelas
  const kelasXIPA1 = await prisma.kelas.upsert({
    where: { nama_tahunAjaran: { nama: "X IPA 1", tahunAjaran: "2024/2025" } },
    update: { waliKelasId: profilBambang.id },
    create: { nama: "X IPA 1", tingkat: 10, tahunAjaran: "2024/2025", waliKelasId: profilBambang.id },
  });

  const kelasXIPA2 = await prisma.kelas.upsert({
    where: { nama_tahunAjaran: { nama: "X IPA 2", tahunAjaran: "2024/2025" } },
    update: { waliKelasId: profilSiti.id },
    create: { nama: "X IPA 2", tingkat: 10, tahunAjaran: "2024/2025", waliKelasId: profilSiti.id },
  });

  const kelasXIPS1 = await prisma.kelas.upsert({
    where: { nama_tahunAjaran: { nama: "X IPS 1", tahunAjaran: "2024/2025" } },
    update: {},
    create: { nama: "X IPS 1", tingkat: 10, tahunAjaran: "2024/2025" },
  });

  // 5. Mata Pelajaran
  const mapelMTK = await prisma.mataPelajaran.upsert({
    where: { kode: "MTK" },
    update: {},
    create: { kode: "MTK", nama: "Matematika" },
  });

  const mapelIPA = await prisma.mataPelajaran.upsert({
    where: { kode: "IPA" },
    update: {},
    create: { kode: "IPA", nama: "Ilmu Pengetahuan Alam" },
  });

  const mapelIND = await prisma.mataPelajaran.upsert({
    where: { kode: "IND" },
    update: {},
    create: { kode: "IND", nama: "Bahasa Indonesia" },
  });

  // 6. Penugasan Guru
  await prisma.penugasanGuru.upsert({
    where: { guruId_kelasId_mataPelajaranId: { guruId: profilBambang.id, kelasId: kelasXIPA1.id, mataPelajaranId: mapelMTK.id } },
    update: {},
    create: { guruId: profilBambang.id, kelasId: kelasXIPA1.id, mataPelajaranId: mapelMTK.id },
  });

  await prisma.penugasanGuru.upsert({
    where: { guruId_kelasId_mataPelajaranId: { guruId: profilBambang.id, kelasId: kelasXIPA2.id, mataPelajaranId: mapelMTK.id } },
    update: {},
    create: { guruId: profilBambang.id, kelasId: kelasXIPA2.id, mataPelajaranId: mapelMTK.id },
  });

  await prisma.penugasanGuru.upsert({
    where: { guruId_kelasId_mataPelajaranId: { guruId: profilSiti.id, kelasId: kelasXIPA1.id, mataPelajaranId: mapelIPA.id } },
    update: {},
    create: { guruId: profilSiti.id, kelasId: kelasXIPA1.id, mataPelajaranId: mapelIPA.id },
  });

  // 7. Siswa
  const siswaData = [
    { nis: "2024001", nama: "Aulia Rahma", jk: JenisKelamin.PEREMPUAN, tgl: new Date("2008-04-12"), kelasId: kelasXIPA1.id },
    { nis: "2024002", nama: "Fikri Ramadhan", jk: JenisKelamin.LAKI_LAKI, tgl: new Date("2008-08-20"), kelasId: kelasXIPA1.id },
    { nis: "2024003", nama: "Nabila Putri", jk: JenisKelamin.PEREMPUAN, tgl: new Date("2008-01-15"), kelasId: kelasXIPA1.id },
    { nis: "2024004", nama: "Rizky Maulana", jk: JenisKelamin.LAKI_LAKI, tgl: new Date("2008-06-03"), kelasId: kelasXIPA2.id },
    { nis: "2024005", nama: "Siti Khadijah", jk: JenisKelamin.PEREMPUAN, tgl: new Date("2008-11-25"), kelasId: kelasXIPA2.id },
    { nis: "2024006", nama: "Daffa Alfarizi", jk: JenisKelamin.LAKI_LAKI, tgl: new Date("2008-09-09"), kelasId: kelasXIPS1.id },
  ];

  const siswaList = [];
  for (const s of siswaData) {
    const record = await prisma.siswa.upsert({
      where: { nis: s.nis },
      update: { nama: s.nama, kelasId: s.kelasId },
      create: {
        nis: s.nis,
        nama: s.nama,
        jenisKelamin: s.jk,
        tanggalLahir: s.tgl,
        kelasId: s.kelasId,
        alamat: "Kota Sawahlunto",
      },
    });
    siswaList.push(record);
  }

  // 8. Prestasi Awal
  const sAulia = siswaList[0];
  if (sAulia) {
    const existing = await prisma.prestasi.findFirst({ where: { siswaId: sAulia.id, judul: "Juara 1 Tahfiz Al-Qur'an" } });
    if (!existing) {
      await prisma.prestasi.create({
        data: {
          siswaId: sAulia.id,
          judul: "Juara 1 Tahfiz Al-Qur'an",
          bidang: "KEAGAMAAN",
          tingkat: TingkatPrestasi.KABUPATEN,
          peringkat: "Juara 1",
          tanggalPerolehan: new Date("2025-01-12"),
          penyelenggara: "Kemenag Kota Sawahlunto",
          dicatatOlehId: profilBambang.id,
          diverifikasiOlehId: adminTest.id,
          statusVerifikasi: StatusVerifikasi.DIVERIFIKASI,
          diverifikasiAt: new Date("2025-01-15"),
        },
      });
    }
  }

  console.log("Seeding data SIMPATIK selesai dengan sukses!");
}

main()
  .catch((e) => {
    console.error("Error during seeding:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

