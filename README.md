# 🦾 Clawzor

> Wrapper CLI untuk menjalankan **OpenClaw** di Android via Termux + proot-distro, tanpa perlu masuk ke shell Debian secara manual.

---

## Daftar Isi

- [Tentang](#tentang)
- [Prasyarat](#prasyarat)
- [Instalasi](#instalasi)
- [Perintah](#perintah)
- [Cara Kerja](#cara-kerja)
- [Troubleshooting](#troubleshooting)
- [Catatan Teknis](#catatan-teknis)

---

## Tentang

**Clawzor** adalah installer dan command-line wrapper yang memungkinkan kamu menjalankan [OpenClaw](https://github.com/openclaw) langsung dari Termux di Android — tanpa harus repot masuk ke environment proot-distro secara manual setiap saat.

Satu perintah install, lalu pakai `clawzor` dari mana saja di Termux.

### Apa yang diinstall?

| Komponen | Keterangan |
|---|---|
| `proot-distro` + Debian | Linux environment di dalam Termux |
| `nvm` | Node Version Manager |
| `Node.js v22` | Runtime untuk OpenClaw |
| `OpenClaw` | AI gateway utama |
| `Bionic Bypass` | Patch kompatibilitas Android/ARM |
| `clawzor` | Wrapper CLI (diinstall di Termux) |

---

## Prasyarat

- Android dengan **Termux** terinstall (dari F-Droid, bukan Play Store)
- Koneksi internet aktif
- Storage cukup (~1-2 GB untuk Debian + Node.js)

---

## Instalasi

Jalankan perintah berikut langsung di Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh | bash
```

Script akan otomatis:
1. Install `proot-distro` dan `curl` di Termux
2. Install distro Debian di dalam proot
3. Install `nvm`, `Node.js v22`, dan `OpenClaw` di dalam Debian
4. Setup `Bionic Bypass` untuk kompatibilitas Android
5. Install command `clawzor` yang bisa dipakai langsung di Termux

Setelah selesai, command `clawzor` langsung siap digunakan **tanpa perlu restart Termux**.

---

## Perintah

Semua perintah dijalankan dari **Termux** (tidak perlu masuk ke Debian dulu).

### `clawzor setup`

Cek kondisi semua komponen dan perbaiki otomatis jika ada yang bermasalah.

```bash
clawzor setup
```

Output diagnostic mencakup:
- ✓/✗ Status paket sistem Debian (`curl`, `git`, `build-essential`, dll)
- ✓/✗ Status `nvm`
- ✓/✗ Status `Node.js` (dengan cek versi minimum)
- ✓/✗ Status `npm`
- ✓/✗ Status `OpenClaw`
- ✓/✗ Status `Bionic Bypass`
- ✓/✗ Status `NODE_OPTIONS` di `.bashrc`
- ✓/✗ Status `proot-distro`, Debian, dan wrapper `clawzor` di sisi Termux

Jika ada komponen yang hilang atau gagal, `clawzor setup` akan langsung memperbaikinya tanpa perlu input manual.

---

### `clawzor onboard`

Jalankan wizard konfigurasi awal OpenClaw.

```bash
clawzor onboard
```

Gunakan perintah ini **setelah instalasi pertama** untuk mengkonfigurasi akun, workspace, dan sesi OpenClaw. Wizard berjalan di dalam proot Debian secara transparan.

---

### `clawzor start`

Jalankan OpenClaw Gateway.

```bash
clawzor start
```

Gateway akan berjalan dan menampilkan URL yang bisa dibuka di browser HP kamu. OpenClaw berjalan di dalam proot Debian dengan `Bionic Bypass` aktif secara otomatis.

---

### `clawzor shell`

Buka shell interaktif Debian (proot-distro).

```bash
clawzor shell
```

Gunakan ini jika kamu perlu akses langsung ke environment Debian, misalnya untuk debug, install paket tambahan, atau cek file secara manual.

---

## Cara Kerja

```
Termux
  │
  ├── clawzor (wrapper di $PREFIX/bin)
  │     │
  │     ├── clawzor setup   → diagnostic + repair di proot & Termux
  │     ├── clawzor onboard → proot-distro login debian -- openclaw onboard
  │     ├── clawzor start   → proot-distro login debian -- openclaw gateway
  │     └── clawzor shell   → proot-distro login debian (interactive)
  │
  └── proot-distro (Debian)
        │
        ├── nvm → Node.js v22 → npm
        ├── openclaw (global npm package)
        └── ~/.openclawd/bionic-bypass.js (patch Android compatibility)
```

### Bionic Bypass

Android menggunakan **Bionic libc** yang berbeda dari glibc standar Linux. Beberapa API Node.js seperti `os.networkInterfaces()` dan `os.cpus()` dapat crash di environment Android. Bionic Bypass adalah patch JavaScript yang di-require via `NODE_OPTIONS` sebelum OpenClaw berjalan, mengganti fungsi-fungsi tersebut dengan implementasi yang aman untuk Android.

---

## Troubleshooting

### OpenClaw tidak ditemukan setelah install

Jalankan diagnostic terlebih dahulu:
```bash
clawzor setup
```

### Gateway gagal start / crash saat buka

Pastikan `Bionic Bypass` aktif. Cek dengan:
```bash
clawzor setup
```
Lihat bagian `[ Bionic Bypass ]` dan `[ NODE_OPTIONS (.bashrc) ]`.

### Paket Debian gagal diinstall saat `clawzor setup`

Buka shell Debian dan update manual:
```bash
clawzor shell
# di dalam Debian:
apt-get update -y
exit
# lalu:
clawzor setup
```

### Error `openclaw: command not found` di dalam proot

nvm mungkin tidak ter-load. Masuk shell dan cek:
```bash
clawzor shell
# di dalam Debian:
source ~/.nvm/nvm.sh
nvm use 22
which openclaw
```

---

## Catatan Teknis

- **Distro**: Debian (via `proot-distro`) — dipilih karena stabilitas dan ketersediaan package
- **Node.js**: Diinstall via `nvm` agar versi bisa dikontrol dan tidak konflik dengan package system
- **`--ignore-scripts`**: Dipakai saat `npm install openclaw` untuk skip native build (`@discordjs/opus`) yang tidak kompatibel dengan environment proot Android
- **Deteksi environment**: Menggunakan flag `CLAWZOR_PROOT=1` eksplisit (bukan hanya `$TERMUX_VERSION`) untuk menghindari false-positive saat variabel Termux ter-inherit ke dalam proot
- **Tidak ada `pkg upgrade`**: Setup menggunakan `apt-get` langsung dengan `--force-confold` untuk menghindari prompt interaktif konfig file seperti `sources.list`

---
