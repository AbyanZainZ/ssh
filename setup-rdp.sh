#!/bin/bash

# ============================================================
#  setup-rdp.sh — Ubuntu VPS to RDP Setup
#  Tested on: Ubuntu 22.04 / 24.04 LTS
#  Run as: root
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✔] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[✘] $1${NC}"; exit 1; }
info()  { echo -e "${CYAN}[→] $1${NC}"; }

# ── Root check ───────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "Jalankan script ini sebagai root: sudo bash setup-rdp.sh"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Ubuntu VPS → RDP Setup Script        ║${NC}"
echo -e "${CYAN}║     by Antigravity • UpCloud Ready        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Input username ───────────────────────────────────────────
read -rp "$(echo -e ${YELLOW}"Masukkan username baru (untuk login RDP): "${NC})" RDP_USER
if [ -z "$RDP_USER" ]; then
  error "Username tidak boleh kosong."
fi

read -rsp "$(echo -e ${YELLOW}"Masukkan password untuk $RDP_USER: "${NC})" RDP_PASS
echo ""
if [ -z "$RDP_PASS" ]; then
  error "Password tidak boleh kosong."
fi

echo ""
info "Memulai instalasi untuk user: $RDP_USER"
echo ""

# ── Step 1: Update sistem ─────────────────────────────────────
info "Step 1/7 — Update & upgrade sistem..."
apt update -y && apt upgrade -y
log "Sistem berhasil diupdate."

# ── Step 2: Install XFCE ─────────────────────────────────────
info "Step 2/7 — Install XFCE4 Desktop Environment..."
DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies
log "XFCE4 berhasil diinstall."

# ── Step 3: Install xRDP ─────────────────────────────────────
info "Step 3/7 — Install xRDP..."
apt install -y xrdp
log "xRDP berhasil diinstall."

# ── Step 4: Buat user ────────────────────────────────────────
info "Step 4/7 — Membuat user $RDP_USER..."
if id "$RDP_USER" &>/dev/null; then
  warn "User $RDP_USER sudah ada, skip pembuatan user."
else
  useradd -m -s /bin/bash "$RDP_USER"
  log "User $RDP_USER berhasil dibuat."
fi
echo "$RDP_USER:$RDP_PASS" | chpasswd
usermod -aG sudo "$RDP_USER"
log "Password & sudo privilege untuk $RDP_USER sudah diset."

# ── Step 5: Konfigurasi xRDP + XFCE ─────────────────────────
info "Step 5/7 — Konfigurasi xRDP untuk XFCE..."

# Set session untuk root
echo "xfce4-session" > /root/.xsession

# Set session untuk user baru
USER_HOME="/home/$RDP_USER"
echo "xfce4-session" > "$USER_HOME/.xsession"
chown "$RDP_USER:$RDP_USER" "$USER_HOME/.xsession"

# Patch startwm.sh supaya pakai XFCE
STARTWM="/etc/xrdp/startwm.sh"
if grep -q "startxfce4" "$STARTWM"; then
  warn "xRDP sudah dikonfigurasi ke XFCE, skip."
else
  sed -i 's/^test -x/#test -x/' "$STARTWM"
  echo "startxfce4" >> "$STARTWM"
  log "startwm.sh berhasil dipatch ke XFCE."
fi

# Tambah user xrdp ke group ssl-cert
usermod -aG ssl-cert xrdp 2>/dev/null || true

systemctl enable xrdp
systemctl restart xrdp
log "xRDP berhasil dikonfigurasi dan direstart."

# ── Step 6: Firewall ─────────────────────────────────────────
info "Step 6/7 — Setup UFW Firewall..."
ufw allow 22/tcp   comment 'SSH'   > /dev/null
ufw allow 3389/tcp comment 'RDP'   > /dev/null
ufw --force enable
log "UFW aktif. Port 22 (SSH) dan 3389 (RDP) dibuka."

# ── Step 7: Verifikasi ───────────────────────────────────────
info "Step 7/7 — Verifikasi status xRDP..."
sleep 2
if systemctl is-active --quiet xrdp; then
  log "xRDP berjalan normal ✔"
else
  error "xRDP gagal berjalan. Cek log: journalctl -u xrdp"
fi

# ── Selesai ──────────────────────────────────────────────────
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✅  SETUP SELESAI!                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  IP Server  : ${CYAN}$SERVER_IP${GREEN}                        ║${NC}"
echo -e "${GREEN}║  Port RDP   : ${CYAN}3389${GREEN}                              ║${NC}"
echo -e "${GREEN}║  Username   : ${CYAN}$RDP_USER${GREEN}                         ║${NC}"
echo -e "${GREEN}║  Password   : ${CYAN}(yang kamu input tadi)${GREEN}            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Cara konek dari Windows:                        ║${NC}"
echo -e "${GREEN}║  Win+R → ketik 'mstsc' → masukkan IP di atas    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
warn "Jangan lupa buka port 3389 di firewall panel UpCloud juga!"
echo ""
