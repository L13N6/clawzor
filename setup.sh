#!/bin/bash
#
# ClawZor Installer — OpenClaw untuk Termux
# One-liner: curl -fsSL https://raw.githubusercontent.com/L13N6/clawzor/main/setup.sh | bash
#

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
N='\033[0m'

echo -e "${B}"
echo "╔═══════════════════════════════════════════╗"
echo "║         ClawZor — OpenClaw Termux         ║"
echo "║         AI Gateway for Android            ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${N}"

# Cek Termux
if [ ! -d "/data/data/com.termux" ] && [ -z "$TERMUX_VERSION" ]; then
  echo -e "${Y}Warning:${N} Bukan Termux — beberapa fitur mungkin tidak jalan"
fi

# ─── [1/2] Install packages ───────────────────────────────────────
echo -e "\n${B}[1/2]${N} Install packages yang dibutuhkan..."
pkg update -y && pkg upgrade -y
pkg install -y nodejs-lts git

echo -e "  ${G}✓${N} Node.js $(node --version)"
echo -e "  ${G}✓${N} npm $(npm --version)"
echo -e "  ${G}✓${N} git installed"

# ─── [2/2] Install openclaw-termux ────────────────────────────────
echo -e "\n${B}[2/2]${N} Install openclaw-termux..."
npm install -g openclaw-termux

echo -e "\n${G}═══════════════════════════════════════════${N}"
echo -e "${G}  ✅ Instalasi selesai!${N}"
echo -e "${G}═══════════════════════════════════════════${N}"
echo ""
echo -e "${Y}Langkah selanjutnya:${N}"
echo ""
echo -e "  ${B}openclawx onboard${N}  — Setup & konfigurasi awal"
echo -e "  ${B}openclawx start${N}    — Jalankan OpenClaw Gateway"
echo ""
echo -e "  ⚠️  Saat ditanya binding, pilih: ${Y}Loopback (127.0.0.1)${N}"
echo ""
echo -e "Dashboard: ${B}http://127.0.0.1:18789${N}"
echo ""
echo -e "${Y}Tips:${N} Matikan battery optimization untuk Termux"
echo "       di Settings → Apps → Termux → Battery"
echo ""

# Langsung jalankan onboard
echo -e "${B}Memulai onboard...${N}"
echo ""
openclawx onboard
