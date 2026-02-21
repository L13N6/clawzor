#!/bin/bash
# setup.sh — OpenClaw + Bionic Bypass (One-Run Installer)
# Usage: curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh | bash

set -e

# ─── Deteksi environment ───────────────────────────────────────────
# CLAWZOR_PROOT=1 di-set secara eksplisit saat memanggil dari Termux ke proot
# Ini mencegah false-positive jika $TERMUX_VERSION ter-inherit ke dalam proot

IS_TERMUX=false
IS_PROOT=false

if [ "${CLAWZOR_PROOT}" = "1" ]; then
  IS_PROOT=true
elif [ -n "$TERMUX_VERSION" ]; then
  IS_TERMUX=true
elif [ -f "/etc/debian_version" ]; then
  IS_PROOT=true
else
  echo ""
  echo "❌ Environment tidak dikenali."
  echo "   Jalankan script ini di Termux atau di dalam proot-distro Debian."
  exit 1
fi

# ══════════════════════════════════════════════════════════════════
# BAGIAN A — Berjalan di Termux (luar proot)
# ══════════════════════════════════════════════════════════════════
if $IS_TERMUX; then
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  OpenClaw Setup — Termux Environment ║"
  echo "╚══════════════════════════════════════╝"
  echo ""

  echo ">>> [1/3] Update & install proot-distro + curl..."
  # Gunakan apt-get langsung agar bisa force-confold (mencegah prompt konfig file)
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    proot-distro curl

  echo ">>> [2/3] Install Debian (skip jika sudah ada)..."
  proot-distro install debian 2>/dev/null || true

  echo ">>> [3/3] Jalankan setup di dalam Debian (one-shot)..."
  # Re-download script di dalam proot lalu jalankan
  # (cat "$0" tidak bisa dipakai saat script di-pipe via curl | bash karena $0 = "bash")
  proot-distro login debian -- bash -c "
    export CLAWZOR_PROOT=1
    curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh | bash
  "

  # ─── Install wrapper clawzor di Termux ───────────────────────────
  echo ""
  echo ">>> Menginstall command 'clawzor' di Termux..."

  CLAWZOR_BIN="$PREFIX/bin/clawzor"
  cat > "$CLAWZOR_BIN" << 'WRAPPER_EOF'
#!/bin/bash
# clawzor — wrapper untuk OpenClaw di proot-distro Debian

DISTRO="debian"

# Warna output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

_ok()   { echo -e "  ${GREEN}[✓]${NC} $1"; }
_fail() { echo -e "  ${RED}[✗]${NC} $1"; }
_warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }

_proot_run() {
  proot-distro login "$DISTRO" -- bash -c "
    export NVM_DIR=\"\$HOME/.nvm\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && source \"\$NVM_DIR/nvm.sh\"
    export NODE_OPTIONS=\"--require \$HOME/.openclawd/bionic-bypass.js\"
    $1
  "
}

_do_setup() {
  # Jalankan diagnostic + repair di dalam proot
  proot-distro login "$DISTRO" -- bash << 'PROOT_SETUP'
set +e  # jangan exit saat ada error, kita handle manual

export NVM_DIR="$HOME/.nvm"
export DEBIAN_FRONTEND=noninteractive

# Warna
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
_ok()     { echo -e "  ${GREEN}[✓]${NC} $1"; }
_fail()   { echo -e "  ${RED}[✗]${NC} $1"; }
_warn()   { echo -e "  ${YELLOW}[~]${NC} $1"; }
_fixing() { echo -e "  ${YELLOW}[→]${NC} Memperbaiki: $1..."; }

NEED_FIX=false

echo ""
echo "══════════════════════════════════════════"
echo "  🔍 Diagnostic OpenClaw di Debian (proot)"
echo "══════════════════════════════════════════"
echo ""

# ─── Cek paket sistem ───
echo "[ Paket sistem ]"
# Update package list dulu sebelum cek/install apapun
apt-get update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" &>/dev/null
for pkg in curl git build-essential python3 cmake; do
  if dpkg -s "$pkg" &>/dev/null; then
    _ok "$pkg"
  else
    _fail "$pkg (belum terinstall)"
    NEED_FIX=true
    _fixing "$pkg"
    apt-get install -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      "$pkg" &>/dev/null && _ok "$pkg berhasil diinstall" || _fail "$pkg gagal diinstall"
  fi
done
echo ""

# ─── Cek nvm ───
echo "[ Node Version Manager (nvm) ]"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  \. "$NVM_DIR/nvm.sh"
  _ok "nvm $(nvm --version 2>/dev/null)"
else
  _fail "nvm tidak ditemukan"
  NEED_FIX=true
  _fixing "nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash &>/dev/null
  \. "$NVM_DIR/nvm.sh" 2>/dev/null && _ok "nvm berhasil diinstall" || _fail "nvm gagal diinstall"
fi
echo ""

# ─── Cek Node.js ───
echo "[ Node.js ]"
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
  if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
    _ok "Node.js $NODE_VER"
  else
    _warn "Node.js $NODE_VER (versi lama, direkomendasikan v22+)"
    NEED_FIX=true
    _fixing "upgrade Node.js ke v22"
    nvm install 22 &>/dev/null && nvm use 22 &>/dev/null && nvm alias default 22 &>/dev/null \
      && _ok "Node.js $(node --version) berhasil diinstall" || _fail "Node.js gagal diupgrade"
  fi
else
  _fail "Node.js tidak ditemukan"
  NEED_FIX=true
  _fixing "Node.js v22"
  nvm install 22 &>/dev/null && nvm use 22 &>/dev/null && nvm alias default 22 &>/dev/null \
    && _ok "Node.js $(node --version) berhasil diinstall" || _fail "Node.js gagal diinstall"
fi
echo ""

# ─── Cek npm ───
echo "[ npm ]"
if command -v npm &>/dev/null; then
  _ok "npm $(npm --version 2>/dev/null)"
else
  _fail "npm tidak ditemukan (harusnya ikut Node.js)"
  _warn "Coba jalankan: clawzor setup lagi setelah Node.js berhasil"
fi
echo ""

# ─── Cek OpenClaw ───
echo "[ OpenClaw ]"
if command -v openclaw &>/dev/null; then
  OC_VER=$(openclaw --version 2>/dev/null || echo "terinstall")
  _ok "OpenClaw $OC_VER"
else
  _fail "OpenClaw tidak ditemukan"
  NEED_FIX=true
  _fixing "OpenClaw"
  npm install -g openclaw@latest --ignore-scripts &>/dev/null \
    && _ok "OpenClaw berhasil diinstall" || _fail "OpenClaw gagal diinstall"
fi
echo ""

# ─── Cek Bionic Bypass ───
echo "[ Bionic Bypass ]"
BYPASS_FILE="$HOME/.openclawd/bionic-bypass.js"
if [ -f "$BYPASS_FILE" ]; then
  _ok "bionic-bypass.js ada"
else
  _fail "bionic-bypass.js tidak ditemukan"
  NEED_FIX=true
  _fixing "bionic-bypass.js"
  mkdir -p "$HOME/.openclawd"
  cat > "$BYPASS_FILE" << 'BYPASS_EOF'
const os = require('os');
const _net = os.networkInterfaces.bind(os);
os.networkInterfaces = function () {
  try { return _net(); } catch (e) {
    return { lo: [{ address: '127.0.0.1', netmask: '255.0.0.0', family: 'IPv4', mac: '00:00:00:00:00:00', internal: true, cidr: '127.0.0.1/8' }] };
  }
};
const _cpus = os.cpus.bind(os);
os.cpus = function () {
  try { return _cpus(); } catch (e) {
    return [{ model: 'Android ARM64', speed: 0, times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 } }];
  }
};
BYPASS_EOF
  _ok "bionic-bypass.js berhasil dibuat"
fi

# ─── Cek NODE_OPTIONS di .bashrc ───
echo "[ NODE_OPTIONS (.bashrc) ]"
BASHRC_LINE='export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"'
if grep -qF 'bionic-bypass.js' "$HOME/.bashrc" 2>/dev/null; then
  _ok "NODE_OPTIONS sudah ada di .bashrc"
else
  _warn "NODE_OPTIONS belum ada di .bashrc"
  NEED_FIX=true
  echo "$BASHRC_LINE" >> "$HOME/.bashrc"
  _ok "NODE_OPTIONS berhasil ditambahkan ke .bashrc"
fi
echo ""

# ─── Ringkasan ───
echo "══════════════════════════════════════════"
if $NEED_FIX; then
  echo -e "  ${YELLOW}⚠  Ada komponen yang diperbaiki. Cek log di atas.${NC}"
else
  echo -e "  ${GREEN}✅ Semua komponen OK! Tidak ada yang perlu diperbaiki.${NC}"
fi
echo "══════════════════════════════════════════"
echo ""
PROOT_SETUP
}

case "$1" in
  setup)
    echo ""
    echo ">>> Menjalankan diagnostic & repair OpenClaw..."
    _do_setup

    # ─── Cek sisi Termux juga ───
    echo ""
    echo "[ Termux ]"
    for pkg in proot-distro curl; do
      if command -v "$pkg" &>/dev/null; then
        _ok "$pkg"
      else
        _fail "$pkg belum terinstall"
        _warn "Menginstall $pkg..."
        pkg install -y "$pkg" && _ok "$pkg berhasil diinstall" || _fail "$pkg gagal diinstall"
      fi
    done

    # Cek distro Debian terdaftar (cek folder langsung, lebih reliable dari parse output)
    if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
      _ok "Distro Debian sudah terinstall"
    else
      _warn "Distro Debian belum terinstall, menginstall..."
      proot-distro install debian && _ok "Debian berhasil diinstall" || _fail "Debian gagal diinstall"
    fi

    # Cek clawzor wrapper sendiri
    if [ -x "$PREFIX/bin/clawzor" ]; then
      _ok "clawzor wrapper ($PREFIX/bin/clawzor)"
    else
      _fail "clawzor wrapper tidak ditemukan (aneh, kamu sedang menjalankannya...)"
    fi
    echo ""
    ;;
  onboard)
    echo ">>> Menjalankan OpenClaw onboard di Debian..."
    _proot_run "openclaw onboard"
    ;;
  start)
    echo ">>> Menjalankan OpenClaw Gateway di Debian..."
    _proot_run "openclaw gateway --verbose"
    ;;
  shell)
    echo ">>> Membuka shell Debian (proot)..."
    proot-distro login "$DISTRO"
    ;;
  *)
    echo ""
    echo "Penggunaan: clawzor <perintah>"
    echo ""
    echo "  setup     — Cek & perbaiki semua komponen yang belum/gagal terinstall"
    echo "  onboard   — Jalankan wizard konfigurasi OpenClaw"
    echo "  start     — Jalankan OpenClaw Gateway"
    echo "  shell     — Buka shell Debian (proot-distro)"
    echo ""
    ;;
esac
WRAPPER_EOF

  chmod +x "$CLAWZOR_BIN"

  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  ✅ Setup selesai!                                         ║"
  echo "║                                                            ║"
  echo "║  Perintah yang tersedia di Termux:                         ║"
  echo "║    clawzor setup    — Cek & repair semua komponen          ║"
  echo "║    clawzor onboard  — Konfigurasi awal OpenClaw            ║"
  echo "║    clawzor start    — Jalankan OpenClaw Gateway            ║"
  echo "║    clawzor shell    — Buka shell Debian                    ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# BAGIAN B — Berjalan di dalam proot Debian
# ══════════════════════════════════════════════════════════════════
if $IS_PROOT; then
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  OpenClaw Setup — Debian (proot)     ║"
  echo "╚══════════════════════════════════════╝"
  echo ""

  # ─── Cek apakah openclaw sudah terinstall ───
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  if command -v openclaw &>/dev/null; then
    echo ">>> OpenClaw sudah terinstall, skip ke verifikasi..."
  else
    echo ">>> [1/5] Update Debian..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold"
    apt-get install -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      curl git build-essential python3 cmake libopus-dev

    echo ">>> [2/5] Install nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    echo ">>> [3/5] Install Node.js v22..."
    nvm install 22
    nvm use 22
    nvm alias default 22

    echo ">>> [4/5] Install OpenClaw..."
    npm install -g openclaw@latest --ignore-scripts
  fi

  echo ">>> [5/5] Setup Bionic Bypass..."
  mkdir -p ~/.openclawd

  cat > ~/.openclawd/bionic-bypass.js << 'EOF'
// Bionic Bypass — fix Android/Termux compatibility untuk OpenClaw
const os = require('os');

// Fix os.networkInterfaces() crash di Android
const _net = os.networkInterfaces.bind(os);
os.networkInterfaces = function () {
  try {
    return _net();
  } catch (e) {
    return {
      lo: [{
        address: '127.0.0.1',
        netmask: '255.0.0.0',
        family: 'IPv4',
        mac: '00:00:00:00:00:00',
        internal: true,
        cidr: '127.0.0.1/8'
      }]
    };
  }
};

// Fix os.cpus() crash di beberapa device
const _cpus = os.cpus.bind(os);
os.cpus = function () {
  try {
    return _cpus();
  } catch (e) {
    return [{
      model: 'Android ARM64',
      speed: 0,
      times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 }
    }];
  }
};
EOF

  # Set NODE_OPTIONS di .bashrc agar persisten
  grep -qxF 'export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"' ~/.bashrc || \
    echo 'export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"' >> ~/.bashrc

  # Aktifkan langsung di sesi ini
  export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"

  echo ""
  echo ">>> Verifikasi instalasi:"
  echo "    Node    : $(node --version 2>/dev/null || echo 'tidak ditemukan')"
  echo "    npm     : $(npm --version 2>/dev/null || echo 'tidak ditemukan')"
  echo "    OpenClaw: $(openclaw --version 2>/dev/null || echo 'terinstall')"
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  ✅ Setup selesai!                                         ║"
  echo "║  Kembali ke Termux, lalu jalankan:                        ║"
  echo "║                                                            ║"
  echo "║    clawzor setup    — Cek & repair semua komponen          ║"
  echo "║    clawzor onboard  — untuk konfigurasi awal              ║"
  echo "║    clawzor start    — untuk menjalankan Gateway           ║"
  echo "║    clawzor shell    — untuk membuka shell Debian           ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
fi
