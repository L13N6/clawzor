#!/bin/bash
# setup.sh — One liner OpenClaw + Bionic Bypass
# Usage (BENAR — agar wizard interaktif):
#   curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh -o setup.sh && bash setup.sh
#
# Atau jika openclaw sudah terinstall dan mau setup ulang config:
#   proot-distro login debian -- bash -c "openclaw setup && openclaw gateway --verbose"

set -e

# ─── Deteksi environment ───────────────────────────────────────────
IS_TERMUX=false
IS_PROOT=false

[ -n "$TERMUX_VERSION" ] && IS_TERMUX=true
[ -f "/etc/debian_version" ] && IS_PROOT=true

# ══════════════════════════════════════════════════════════════════
# BAGIAN A — Berjalan di Termux (luar proot)
# ══════════════════════════════════════════════════════════════════
if $IS_TERMUX; then
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  OpenClaw Setup — Termux Environment ║"
  echo "╚══════════════════════════════════════╝"
  echo ""

  echo ">>> [1/3] Update & install proot-distro..."
  pkg update -y && pkg upgrade -y
  pkg install -y proot-distro curl

  echo ">>> [2/3] Install Debian (skip jika sudah ada)..."
  proot-distro install debian 2>/dev/null || true

  echo ">>> [3/3] Download & jalankan setup di dalam Debian..."
  # ✅ FIX: download dulu ke file, jangan pipe langsung
  # Supaya stdin tetap interaktif untuk wizard openclaw
  proot-distro login debian -- bash -c "
    curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh -o /tmp/setup.sh
    bash /tmp/setup.sh
  "
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

  # Cek apakah openclaw sudah terinstall, skip install jika sudah ada
  OPENCLAW_INSTALLED=false
  command -v openclaw &>/dev/null && OPENCLAW_INSTALLED=true

  if ! $OPENCLAW_INSTALLED; then
    echo ">>> [1/6] Update Debian..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold"
    apt-get install -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      curl git build-essential python3 cmake

    echo ">>> [2/6] Install nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    echo ">>> [3/6] Install Node.js v22..."
    nvm install 22
    nvm use 22
    nvm alias default 22

    echo ">>> [4/6] Install OpenClaw..."
    npm install -g openclaw@latest

  else
    echo ">>> OpenClaw sudah terinstall, skip ke setup..."
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  fi

  echo ">>> [5/6] Setup Bionic Bypass..."
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

  echo ">>> [6/6] Verifikasi instalasi..."
  echo "    Node    : $(node --version)"
  echo "    npm     : $(npm --version)"
  echo "    OpenClaw: $(openclaw --version 2>/dev/null || echo 'OK')"

  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ✅ Setup selesai! Memulai konfigurasi OpenClaw...   ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
  sleep 1

  # ─── CEK APAKAH CONFIG SUDAH ADA ───
  CONFIG_EXISTS=false
  [ -f "$HOME/.openclawd/config.json" ] && CONFIG_EXISTS=true

  if ! $CONFIG_EXISTS; then
    echo ">>> Menjalankan wizard konfigurasi..."
    echo ""
    # ✅ FIX: redirect stdin dari terminal agar wizard bisa interaktif
    openclaw setup </dev/tty
  else
    echo ">>> Config sudah ada, skip wizard..."
  fi

  echo ""
  echo "╔════════════════════════════════════════════╗"
  echo "║  🚀 Menjalankan Gateway...                 ║"
  echo "║  Buka URL yang muncul di browser HP kamu! ║"
  echo "╚════════════════════════════════════════════╝"
  echo ""
  sleep 1

  # ─── JALANKAN GATEWAY ───
  NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js" openclaw gateway --verbose

  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# Fallback — Environment tidak dikenali
# ══════════════════════════════════════════════════════════════════
echo ""
echo "❌ Environment tidak dikenali."
echo "   Jalankan script ini di Termux atau di dalam proot-distro Debian."
echo ""
echo "   Cara benar:"
echo "   curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh -o setup.sh"
echo "   bash setup.sh"
exit 1
