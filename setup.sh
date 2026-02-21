#!/bin/bash
# setup.sh — OpenClaw + Bionic Bypass + Termux Wrapper
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh -o setup.sh
#   bash setup.sh

set -e

REPO_RAW="https://raw.githubusercontent.com/L13N6/clawzor/main"

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

  echo ">>> [1/4] Update & install proot-distro..."
  pkg update -y && pkg upgrade -y
  pkg install -y proot-distro curl

  echo ">>> [2/4] Install Debian (skip jika sudah ada)..."
  proot-distro install debian 2>/dev/null || true

  echo ">>> [3/4] Jalankan setup di dalam Debian..."
  proot-distro login debian -- bash -c "
    curl -fsSL $REPO_RAW/setup.sh -o /tmp/setup.sh
    bash /tmp/setup.sh
  "

  echo ">>> [4/4] Install wrapper 'openclaw' di Termux..."

  # Buat wrapper command di Termux $PREFIX/bin
  cat > $PREFIX/bin/openclaw << 'WRAPPER'
#!/bin/bash
# Wrapper openclaw untuk Termux — redirect ke proot Debian

PROOT_CMD="proot-distro login debian --"
NVM_LOAD='export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
BYPASS='export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"'

case "$1" in
  onboard)
    echo ">>> Membuka wizard OpenClaw onboard di Debian..."
    proot-distro login debian -- bash -c "$NVM_LOAD && $BYPASS && openclaw onboard --no-install-daemon </dev/tty"
    ;;
  start)
    echo ">>> Menjalankan OpenClaw Gateway..."
    echo ">>> Buka URL yang muncul di browser HP kamu!"
    echo ""
    proot-distro login debian -- bash -c "$NVM_LOAD && $BYPASS && NODE_OPTIONS='--require \$HOME/.openclawd/bionic-bypass.js' openclaw gateway --verbose"
    ;;
  shell)
    echo ">>> Membuka shell Debian (proot)..."
    proot-distro login debian
    ;;
  update)
    echo ">>> Update OpenClaw di Debian..."
    proot-distro login debian -- bash -c "$NVM_LOAD && npm install -g openclaw@latest"
    ;;
  *)
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║         OpenClaw — Termux CLI        ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "  Perintah yang tersedia:"
    echo ""
    echo "  openclaw onboard   — Setup & konfigurasi awal"
    echo "  openclaw start     — Jalankan gateway OpenClaw"
    echo "  openclaw shell     — Buka shell Debian (proot)"
    echo "  openclaw update    — Update ke versi terbaru"
    echo ""
    ;;
esac
WRAPPER

  chmod +x $PREFIX/bin/openclaw

  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ✅ Semua selesai! Wrapper openclaw sudah terpasang  ║"
  echo "╠══════════════════════════════════════════════════════╣"
  echo "║                                                      ║"
  echo "║  Perintah yang bisa dipakai di Termux:               ║"
  echo "║                                                      ║"
  echo "║  openclaw onboard  — Setup & konfigurasi awal        ║"
  echo "║  openclaw start    — Jalankan OpenClaw               ║"
  echo "║  openclaw shell    — Buka shell Debian               ║"
  echo "║  openclaw update   — Update OpenClaw                 ║"
  echo "║                                                      ║"
  echo "╚══════════════════════════════════════════════════════╝"
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

  OPENCLAW_INSTALLED=false
  command -v openclaw &>/dev/null && OPENCLAW_INSTALLED=true

  if ! $OPENCLAW_INSTALLED; then
    echo ">>> [1/5] Update Debian..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold"
    apt-get install -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      curl git build-essential python3 cmake

    echo ">>> [2/5] Install nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    echo ">>> [3/5] Install Node.js v22..."
    nvm install 22
    nvm use 22
    nvm alias default 22

    echo ">>> [4/5] Install OpenClaw..."
    npm install -g openclaw@latest

  else
    echo ">>> OpenClaw sudah terinstall, skip instalasi..."
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  fi

  echo ">>> [5/5] Setup Bionic Bypass..."
  mkdir -p ~/.openclawd

  cat > ~/.openclawd/bionic-bypass.js << 'EOF'
const os = require('os');

const _net = os.networkInterfaces.bind(os);
os.networkInterfaces = function () {
  try { return _net(); } catch (e) {
    return { lo: [{ address: '127.0.0.1', netmask: '255.0.0.0',
      family: 'IPv4', mac: '00:00:00:00:00:00',
      internal: true, cidr: '127.0.0.1/8' }] };
  }
};

const _cpus = os.cpus.bind(os);
os.cpus = function () {
  try { return _cpus(); } catch (e) {
    return [{ model: 'Android ARM64', speed: 0,
      times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 } }];
  }
};
EOF

  # Set gateway.mode=local agar gateway tidak blocked
  mkdir -p ~/.openclaw
  if [ ! -f ~/.openclaw/openclaw.json ]; then
    echo '{"gateway":{"mode":"local"}}' > ~/.openclaw/openclaw.json
  else
    # Inject gateway.mode jika belum ada
    node -e "
      const fs = require('fs');
      const cfg = JSON.parse(fs.readFileSync(process.env.HOME+'/.openclaw/openclaw.json','utf8'));
      cfg.gateway = cfg.gateway || {};
      cfg.gateway.mode = 'local';
      fs.writeFileSync(process.env.HOME+'/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2));
      console.log('gateway.mode=local sudah diset');
    " 2>/dev/null || true
  fi

  grep -qxF 'export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"' ~/.bashrc || \
    echo 'export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"' >> ~/.bashrc
  grep -qxF 'export NVM_DIR="$HOME/.nvm"' ~/.bashrc || \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
  grep -qxF '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' ~/.bashrc || \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc

  export NODE_OPTIONS="--require $HOME/.openclawd/bionic-bypass.js"

  echo ""
  echo "    Node    : $(node --version)"
  echo "    npm     : $(npm --version)"
  echo "    OpenClaw: $(openclaw --version 2>/dev/null || echo 'OK')"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# Fallback
# ══════════════════════════════════════════════════════════════════
echo ""
echo "❌ Environment tidak dikenali."
echo ""
echo "Cara benar:"
echo "  curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh -o setup.sh"
echo "  bash setup.sh"
exit 1
