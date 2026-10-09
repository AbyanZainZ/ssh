#!/bin/bash

# ============================================================
#  setup-rdp.sh — Ubuntu VPS to RDP Setup (Optimized v2)
#  Tested on: Ubuntu 22.04 / 24.04 LTS
#  Run as: root
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✔] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[✘] $1${NC}"; exit 1; }
info()  { echo -e "${CYAN}[→] $1${NC}"; }

# ── Root check ───────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "Jalankan script ini sebagai root: sudo bash setup-rdp.sh"
fi

clear
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║   Ubuntu VPS → RDP Setup (Optimized v2)      ║${NC}"
echo -e "${CYAN}${BOLD}║   XFCE4 + xRDP Turbo Config • UpCloud Ready  ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Input username & password ────────────────────────────────
read -rp "$(echo -e ${YELLOW}"Masukkan username baru (untuk login RDP): "${NC})" RDP_USER
[ -z "$RDP_USER" ] && error "Username tidak boleh kosong."

while true; do
  read -rsp "$(echo -e ${YELLOW}"Masukkan password untuk $RDP_USER: "${NC})" RDP_PASS
  echo ""
  read -rsp "$(echo -e ${YELLOW}"Konfirmasi password: "${NC})" RDP_PASS2
  echo ""
  [ "$RDP_PASS" = "$RDP_PASS2" ] && break
  warn "Password tidak cocok, coba lagi."
done
[ -z "$RDP_PASS" ] && error "Password tidak boleh kosong."

echo ""
info "Memulai instalasi untuk user: ${BOLD}$RDP_USER${NC}"
echo ""

# ── Step 1: Update sistem ─────────────────────────────────────
info "Step 1/9 — Update & upgrade sistem..."
apt update -y -qq
DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq
log "Sistem berhasil diupdate."

# ── Step 2: Install dependensi performa ──────────────────────
info "Step 2/9 — Install paket performa..."
DEBIAN_FRONTEND=noninteractive apt install -y -qq \
  cpufrequtils \
  tuned \
  htop \
  neofetch \
  ufw \
  curl \
  wget \
  git \
  unzip
log "Paket performa berhasil diinstall."

# ── Step 3: Optimasi CPU & Kernel ────────────────────────────
info "Step 3/9 — Optimasi CPU governor & kernel..."

# Set CPU ke performance mode
if command -v cpufreq-set &>/dev/null; then
  for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$cpu" 2>/dev/null || true
  done
  log "CPU governor diset ke performance."
fi

# Tuned profile
if command -v tuned-adm &>/dev/null; then
  systemctl enable tuned --now 2>/dev/null || true
  tuned-adm profile throughput-performance 2>/dev/null || true
  log "Tuned profile: throughput-performance."
fi

# Optimasi kernel sysctl untuk desktop remot
cat > /etc/sysctl.d/99-rdp-optimize.conf << 'EOF'
# Network performance
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3

# Memory
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
sysctl -p /etc/sysctl.d/99-rdp-optimize.conf -q 2>/dev/null || true
log "Kernel sysctl dioptimasi."

# ── Step 4: Install XFCE (ringan + cepat) ────────────────────
info "Step 4/9 — Install XFCE4 Desktop Environment..."
DEBIAN_FRONTEND=noninteractive apt install -y -qq \
  xfce4 \
  xfce4-goodies \
  xfce4-terminal \
  xfce4-taskmanager \
  thunar \
  mousepad \
  ristretto \
  xarchiver \
  fonts-ubuntu \
  papirus-icon-theme
log "XFCE4 berhasil diinstall."

# ── Step 5: Install xRDP + optimasi ──────────────────────────
info "Step 5/9 — Install & konfigurasi xRDP (Turbo Mode)..."
DEBIAN_FRONTEND=noninteractive apt install -y -qq xrdp

# Backup config asli
cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak

# Patch xrdp.ini untuk performa maksimal
sed -i 's/^#tcp_nodelay=.*/tcp_nodelay=true/' /etc/xrdp/xrdp.ini
sed -i 's/^#tcp_keepalive=.*/tcp_keepalive=true/' /etc/xrdp/xrdp.ini
sed -i 's/^max_bpp=.*/max_bpp=32/' /etc/xrdp/xrdp.ini
sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini
sed -i 's/^#bulk_compression=.*/bulk_compression=true/' /etc/xrdp/xrdp.ini

# Tambahkan optimasi di section [Globals] jika belum ada
grep -q "tcp_nodelay" /etc/xrdp/xrdp.ini || \
  sed -i '/^\[Globals\]/a tcp_nodelay=true\ntcp_keepalive=true\nbulk_compression=true' /etc/xrdp/xrdp.ini

log "xRDP Turbo Config selesai."

# ── Step 6: Buat user & konfigurasi sesi XFCE ────────────────
info "Step 6/9 — Membuat user $RDP_USER..."
if id "$RDP_USER" &>/dev/null; then
  warn "User $RDP_USER sudah ada, melanjutkan konfigurasi."
else
  useradd -m -s /bin/bash "$RDP_USER"
  log "User $RDP_USER berhasil dibuat."
fi
echo "$RDP_USER:$RDP_PASS" | chpasswd
usermod -aG sudo,ssl-cert "$RDP_USER" 2>/dev/null || usermod -aG sudo "$RDP_USER"
log "Password & privilege untuk $RDP_USER sudah diset."

# Setup sesi XFCE untuk semua user
USER_HOME="/home/$RDP_USER"
for HOMEDIR in /root "$USER_HOME"; do
  echo "xfce4-session" > "$HOMEDIR/.xsession"
  chmod +x "$HOMEDIR/.xsession"
done
chown "$RDP_USER:$RDP_USER" "$USER_HOME/.xsession"

# Patch startwm.sh
STARTWM="/etc/xrdp/startwm.sh"
if ! grep -q "startxfce4" "$STARTWM"; then
  sed -i 's/^test -x/#test -x/' "$STARTWM"
  echo "exec startxfce4" >> "$STARTWM"
fi

# Tambah xrdp user ke ssl-cert
usermod -aG ssl-cert xrdp 2>/dev/null || true

log "Sesi XFCE dikonfigurasi."

# ── Step 7: Optimasi XFCE untuk remote desktop ───────────────
info "Step 7/9 — Optimasi XFCE untuk remote desktop..."
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

# Matikan compositor (bikin RDP lebih mulus)
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="shadow_opacity" type="int" value="0"/>
    <property name="show_frame_shadow" type="bool" value="false"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
  </property>
</channel>
EOF

# Matikan animasi XFCE
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="SaveOnExit" type="bool" value="false"/>
  </property>
</channel>
EOF

chown -R "$RDP_USER:$RDP_USER" "$USER_HOME/.config"
log "XFCE dioptimasi untuk remote desktop (compositor OFF)."

# ── Step 8: Install Google Chrome ───────────────────────────
info "Step 8/10 — Install Google Chrome..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
DEBIAN_FRONTEND=noninteractive apt install -y -qq /tmp/chrome.deb || true
rm -f /tmp/chrome.deb

# Tambah shortcut Chrome di desktop user
mkdir -p "$USER_HOME/Desktop"
cat > "$USER_HOME/Desktop/chrome.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome
Exec=/usr/bin/google-chrome-stable --no-sandbox %U
StartupNotify=true
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
EOF
chmod +x "$USER_HOME/Desktop/chrome.desktop"
chown "$RDP_USER:$RDP_USER" "$USER_HOME/Desktop/chrome.desktop"
log "Google Chrome berhasil diinstall."

# ── Step 9: Firewall ─────────────────────────────────────────
info "Step 9/10 — Setup UFW Firewall..."
ufw allow 22/tcp   comment 'SSH'  > /dev/null
ufw allow 3389/tcp comment 'RDP'  > /dev/null
ufw --force enable > /dev/null
log "UFW aktif. Port 22 & 3389 dibuka."

# ── Step 9: Enable & restart xRDP ────────────────────────────
info "Step 10/10 — Enable & start xRDP service..."
systemctl enable xrdp > /dev/null 2>&1
systemctl restart xrdp
sleep 2

if systemctl is-active --quiet xrdp; then
  log "xRDP berjalan normal."
else
  error "xRDP gagal start. Cek: journalctl -u xrdp -n 50"
fi

# ── Selesai ──────────────────────────────────────────────────
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║           ✅  SETUP SELESAI! (v2 Optimized)          ║${NC}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}${BOLD}║  IP Server  : ${CYAN}$SERVER_IP${GREEN}${BOLD}                              ║${NC}"
echo -e "${GREEN}${BOLD}║  Port RDP   : ${CYAN}3389${GREEN}${BOLD}                                  ║${NC}"
echo -e "${GREEN}${BOLD}║  Username   : ${CYAN}$RDP_USER${GREEN}${BOLD}                              ║${NC}"
echo -e "${GREEN}${BOLD}║  Password   : ${CYAN}(yang kamu input tadi)${GREEN}${BOLD}                ║${NC}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}${BOLD}║  Cara konek dari Windows:                            ║${NC}"
echo -e "${GREEN}${BOLD}║  Win+R → ketik 'mstsc' → masukkan IP di atas        ║${NC}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}${BOLD}║  Optimasi aktif:                                     ║${NC}"
echo -e "${GREEN}${BOLD}║  ✔ CPU Performance Mode   ✔ TCP BBR               ║${NC}"
echo -e "${GREEN}${BOLD}║  ✔ xRDP Bulk Compression  ✔ XFCE Compositor OFF   ║${NC}"
echo -e "${GREEN}${BOLD}║  ✔ Kernel Network Tuning  ✔ Swappiness=10         ║${NC}"
echo -e "${GREEN}${BOLD}║  ✔ Google Chrome Installed (shortcut di Desktop)  ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
warn "Buka port 3389 di firewall panel UpCloud juga ya!"
echo ""
