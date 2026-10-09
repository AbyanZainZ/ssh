#!/bin/bash

# ================================================================
#  MyInstaller - VPS OS Deployment Tool
#  Mirip TinyInstaller — support Windows & Linux
#  Author: github.com/AbyanZainZ
#  Run as: root di VPS Linux
# ================================================================

set -e

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
CYAN='\033[0;36m';   BLUE='\033[0;34m';   MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  BOLD='\033[1m';      NC='\033[0m'
BG_BLUE='\033[44m';  BG_GREEN='\033[42m'

# ── Helpers ──────────────────────────────────────────────────
log()     { echo -e "${GREEN}  [✔] $1${NC}"; }
warn()    { echo -e "${YELLOW}  [!] $1${NC}"; }
error()   { echo -e "${RED}  [✘] $1${NC}"; exit 1; }
info()    { echo -e "${CYAN}  [→] $1${NC}"; }
title()   { echo -e "\n${BOLD}${WHITE}  ══ $1 ══${NC}\n"; }
divider() { echo -e "${BLUE}  ─────────────────────────────────────────────${NC}"; }

# ── Root check ───────────────────────────────────────────────
[ "$EUID" -ne 0 ] && error "Jalankan sebagai root: sudo bash myinstaller.sh"

# ── Dependency check ─────────────────────────────────────────
check_deps() {
  for cmd in curl wget; do
    command -v "$cmd" &>/dev/null || apt-get install -y -qq "$cmd"
  done
}

# ================================================================
#  BANNER
# ================================================================
show_banner() {
  clear
  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "   ███╗   ███╗██╗   ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ "
  echo "   ████╗ ████║╚██╗ ██╔╝    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗"
  echo "   ██╔████╔██║ ╚████╔╝     ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝"
  echo "   ██║╚██╔╝██║  ╚██╔╝      ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗"
  echo "   ██║ ╚═╝ ██║   ██║       ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║"
  echo "   ╚═╝     ╚═╝   ╚═╝       ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝"
  echo -e "${NC}"
  echo -e "   ${WHITE}${BOLD}VPS OS Deployment Tool${NC}  ${YELLOW}v1.0${NC}  ${MAGENTA}by AbyanZainZ${NC}"
  divider
  echo -e "   ${CYAN}IP Server : ${WHITE}$(hostname -I | awk '{print $1}')${NC}  |  ${CYAN}OS Saat ini : ${WHITE}$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC}"
  echo -e "   ${CYAN}CPU       : ${WHITE}$(nproc) Core${NC}  |  ${CYAN}RAM : ${WHITE}$(free -h | awk '/^Mem/{print $2}')${NC}  |  ${CYAN}Disk : ${WHITE}$(df -h / | awk 'NR==2{print $2}')${NC}"
  divider
  echo ""
}

# ================================================================
#  MENU UTAMA
# ================================================================
main_menu() {
  show_banner
  echo -e "   ${BOLD}Pilih mode instalasi:${NC}\n"
  echo -e "   ${BG_BLUE}${WHITE}  WINDOWS  ${NC}"
  echo -e "   ${WHITE}  [1]${NC} Windows 10 Pro         ${YELLOW}(via DD Image — cepat)${NC}"
  echo -e "   ${WHITE}  [2]${NC} Windows 11 Pro         ${YELLOW}(via DD Image — cepat)${NC}"
  echo -e "   ${WHITE}  [3]${NC} Windows Server 2022    ${YELLOW}(recommended untuk VPS)${NC}"
  echo -e "   ${WHITE}  [4]${NC} Windows Server 2019    ${YELLOW}(stabil & ringan)${NC}"
  echo ""
  echo -e "   ${BG_GREEN}${WHITE}  LINUX + DESKTOP (RDP)  ${NC}"
  echo -e "   ${WHITE}  [5]${NC} Ubuntu 24.04 + XFCE + xRDP  ${GREEN}(script v2 optimized)${NC}"
  echo -e "   ${WHITE}  [6]${NC} Debian 12 + XFCE + xRDP"
  echo ""
  echo -e "   ${WHITE}  [7]${NC} ${RED}Reinstall Linux bersih${NC} (tanpa desktop)"
  echo -e "   ${WHITE}  [0]${NC} Keluar"
  echo ""
  divider
  read -rp "$(echo -e "   ${BOLD}Pilihan kamu [0-7]: ${NC}")" CHOICE
  echo ""

  case "$CHOICE" in
    1) install_windows "10"      ;;
    2) install_windows "11"      ;;
    3) install_windows "2022"    ;;
    4) install_windows "2019"    ;;
    5) install_ubuntu_rdp        ;;
    6) install_debian_rdp        ;;
    7) reinstall_linux_clean     ;;
    0) echo -e "\n   ${CYAN}Bye!${NC}\n"; exit 0 ;;
    *) warn "Pilihan tidak valid."; sleep 1; main_menu ;;
  esac
}

# ================================================================
#  KONFIRMASI BERBAHAYA
# ================================================================
danger_confirm() {
  local os_name="$1"
  echo ""
  echo -e "   ${RED}${BOLD}⚠  PERINGATAN PENTING ⚠${NC}"
  divider
  echo -e "   ${YELLOW}Kamu akan menginstall: ${WHITE}${BOLD}$os_name${NC}"
  echo -e "   ${RED}• SEMUA DATA DI DISK AKAN TERHAPUS PERMANEN${NC}"
  echo -e "   ${RED}• VPS akan tidak bisa diakses selama proses (10-40 menit)${NC}"
  echo -e "   ${RED}• Pastikan kamu punya akses console/VNC dari panel UpCloud${NC}"
  echo -e "   ${YELLOW}• Setelah selesai, konek via RDP ke IP: $(hostname -I | awk '{print $1}')${NC}"
  divider
  echo ""
  read -rp "$(echo -e "   ${BOLD}Ketik 'SETUJU' untuk melanjutkan: ${NC}")" CONFIRM
  [ "$CONFIRM" != "SETUJU" ] && { warn "Dibatalkan."; sleep 1; main_menu; }
}

# ================================================================
#  INSTALL WINDOWS (via reinstall.sh — metode paling reliable)
# ================================================================
install_windows() {
  local version="$1"
  local os_name=""
  local win_ver=""
  local win_lang="en-us"

  case "$version" in
    "10")   os_name="Windows 10 Pro";      win_ver="10" ;;
    "11")   os_name="Windows 11 Pro";      win_ver="11" ;;
    "2022") os_name="Windows Server 2022"; win_ver="2022" ;;
    "2019") os_name="Windows Server 2019"; win_ver="2019" ;;
  esac

  danger_confirm "$os_name"

  # ── Input password Windows ───────────────────────────────
  title "Konfigurasi Windows"
  echo -e "   ${CYAN}Username default: ${WHITE}Administrator${NC}"
  echo ""
  while true; do
    read -rsp "$(echo -e "   ${BOLD}Password untuk Administrator: ${NC}")" WIN_PASS
    echo ""
    read -rsp "$(echo -e "   ${BOLD}Konfirmasi password: ${NC}")" WIN_PASS2
    echo ""
    [ "$WIN_PASS" = "$WIN_PASS2" ] && break
    warn "Password tidak cocok, coba lagi."
  done
  [ ${#WIN_PASS} -lt 8 ] && error "Password minimal 8 karakter."

  echo ""
  info "Memulai instalasi $os_name..."
  info "Proses ini memakan waktu 15-40 menit. Jangan putus koneksi!"
  echo ""

  # ── Download reinstall engine ────────────────────────────
  info "Mengunduh MyInstaller Engine..."
  curl -sLo /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || \
    wget -qO /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh

  chmod +x /tmp/reinstall.sh

  # ── Jalankan instalasi ───────────────────────────────────
  log "Engine berhasil diunduh."
  info "Menjalankan instalasi Windows $version..."
  echo ""

  bash /tmp/reinstall.sh windows \
    --version "$win_ver" \
    --lang "$win_lang" \
    --password "$WIN_PASS"

  post_windows_info "$os_name" "$WIN_PASS"
}

# ================================================================
#  INFO SETELAH INSTALL WINDOWS
# ================================================================
post_windows_info() {
  local os_name="$1"
  local pass="$2"
  local ip
  ip=$(hostname -I | awk '{print $1}')

  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║        ✅  INSTALASI WINDOWS DIMULAI!                    ║${NC}"
  echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}${BOLD}║  OS         : ${CYAN}$os_name${GREEN}${BOLD}                     ║${NC}"
  echo -e "${GREEN}${BOLD}║  IP Server  : ${CYAN}$ip${GREEN}${BOLD}                              ║${NC}"
  echo -e "${GREEN}${BOLD}║  Port RDP   : ${CYAN}3389${GREEN}${BOLD}                                  ║${NC}"
  echo -e "${GREEN}${BOLD}║  Username   : ${CYAN}Administrator${GREEN}${BOLD}                         ║${NC}"
  echo -e "${GREEN}${BOLD}║  Password   : ${CYAN}$pass${GREEN}${BOLD}                        ║${NC}"
  echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}${BOLD}║  Server akan REBOOT dan install otomatis.                ║${NC}"
  echo -e "${GREEN}${BOLD}║  Tunggu 20-40 menit lalu konek RDP dari Windows:        ║${NC}"
  echo -e "${GREEN}${BOLD}║  Win+R → mstsc → masukkan IP di atas                   ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  warn "Buka port 3389 di firewall panel UpCloud jika belum dibuka!"
  echo ""
}

# ================================================================
#  INSTALL UBUNTU + XFCE + XRDP (script v2 optimized)
# ================================================================
install_ubuntu_rdp() {
  title "Ubuntu 24.04 LTS + XFCE + xRDP (Optimized v2)"

  read -rp "$(echo -e "   ${BOLD}Username baru untuk RDP: ${NC}")" RDP_USER
  [ -z "$RDP_USER" ] && error "Username tidak boleh kosong."

  while true; do
    read -rsp "$(echo -e "   ${BOLD}Password untuk $RDP_USER: ${NC}")" RDP_PASS
    echo ""
    read -rsp "$(echo -e "   ${BOLD}Konfirmasi password: ${NC}")" RDP_PASS2
    echo ""
    [ "$RDP_PASS" = "$RDP_PASS2" ] && break
    warn "Password tidak cocok, coba lagi."
  done

  echo ""
  info "Memulai setup Ubuntu RDP..."

  # Update
  info "Update sistem..."
  apt update -y -qq && apt upgrade -y -qq

  # Install paket
  info "Install XFCE4 + xRDP..."
  DEBIAN_FRONTEND=noninteractive apt install -y -qq \
    xfce4 xfce4-goodies xfce4-terminal thunar mousepad \
    xrdp cpufrequtils tuned htop curl wget git unzip \
    fonts-ubuntu papirus-icon-theme

  # Optimasi kernel
  info "Optimasi kernel & network..."
  cat > /etc/sysctl.d/99-rdp-optimize.conf << 'EOF'
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
  sysctl -p /etc/sysctl.d/99-rdp-optimize.conf -q 2>/dev/null || true

  # User
  if ! id "$RDP_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$RDP_USER"
  fi
  echo "$RDP_USER:$RDP_PASS" | chpasswd
  usermod -aG sudo "$RDP_USER"
  usermod -aG ssl-cert xrdp 2>/dev/null || true

  # Session
  USER_HOME="/home/$RDP_USER"
  echo "xfce4-session" > /root/.xsession
  echo "xfce4-session" > "$USER_HOME/.xsession"
  chown "$RDP_USER:$RDP_USER" "$USER_HOME/.xsession"
  chmod +x "$USER_HOME/.xsession" /root/.xsession

  # Patch xRDP
  STARTWM="/etc/xrdp/startwm.sh"
  grep -q "startxfce4" "$STARTWM" || {
    sed -i 's/^test -x/#test -x/' "$STARTWM"
    echo "exec startxfce4" >> "$STARTWM"
  }

  # xRDP turbo
  cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak 2>/dev/null || true
  sed -i 's/^max_bpp=.*/max_bpp=32/' /etc/xrdp/xrdp.ini 2>/dev/null || true
  sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini 2>/dev/null || true

  # XFCE optimasi (compositor off)
  mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
  cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="shadow_opacity" type="int" value="0"/>
  </property>
</channel>
EOF
  chown -R "$RDP_USER:$RDP_USER" "$USER_HOME/.config"

  # Chrome
  info "Install Google Chrome..."
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  DEBIAN_FRONTEND=noninteractive apt install -y -qq /tmp/chrome.deb || true
  rm -f /tmp/chrome.deb
  mkdir -p "$USER_HOME/Desktop"
  cat > "$USER_HOME/Desktop/chrome.desktop" << 'EOF'
[Desktop Entry]
Name=Google Chrome
Exec=/usr/bin/google-chrome-stable --no-sandbox %U
Terminal=false
Icon=google-chrome
Type=Application
EOF
  chmod +x "$USER_HOME/Desktop/chrome.desktop"
  chown "$RDP_USER:$RDP_USER" "$USER_HOME/Desktop/chrome.desktop"

  # Firewall
  ufw allow 22/tcp > /dev/null
  ufw allow 3389/tcp > /dev/null
  ufw --force enable > /dev/null

  # Start xRDP
  systemctl enable xrdp > /dev/null
  systemctl restart xrdp

  local ip
  ip=$(hostname -I | awk '{print $1}')

  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║       ✅  UBUNTU RDP SIAP DIGUNAKAN!                     ║${NC}"
  echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}${BOLD}║  IP Server  : ${CYAN}$ip${GREEN}${BOLD}                              ║${NC}"
  echo -e "${GREEN}${BOLD}║  Port RDP   : ${CYAN}3389${GREEN}${BOLD}                                  ║${NC}"
  echo -e "${GREEN}${BOLD}║  Username   : ${CYAN}$RDP_USER${GREEN}${BOLD}                              ║${NC}"
  echo -e "${GREEN}${BOLD}║  Password   : ${CYAN}(yang kamu input tadi)${GREEN}${BOLD}                ║${NC}"
  echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}${BOLD}║  ✔ XFCE4 Desktop   ✔ Google Chrome                     ║${NC}"
  echo -e "${GREEN}${BOLD}║  ✔ xRDP Turbo      ✔ Kernel Optimized                  ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  warn "Buka port 3389 di panel UpCloud jika belum!"
}

# ================================================================
#  INSTALL DEBIAN + XFCE + XRDP
# ================================================================
install_debian_rdp() {
  title "Debian 12 + XFCE + xRDP"
  info "Menggunakan engine reinstall untuk deploy Debian 12..."

  read -rp "$(echo -e "   ${BOLD}Username RDP: ${NC}")" RDP_USER
  while true; do
    read -rsp "$(echo -e "   ${BOLD}Password: ${NC}")" RDP_PASS; echo ""
    read -rsp "$(echo -e "   ${BOLD}Konfirmasi: ${NC}")" RDP_PASS2; echo ""
    [ "$RDP_PASS" = "$RDP_PASS2" ] && break
    warn "Tidak cocok, coba lagi."
  done

  curl -sLo /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
  chmod +x /tmp/reinstall.sh
  bash /tmp/reinstall.sh debian --version 12 --password "$RDP_PASS"

  log "Debian 12 akan diinstall. Setelah reboot, jalankan setup-rdp.sh untuk install desktop."
}

# ================================================================
#  REINSTALL LINUX BERSIH
# ================================================================
reinstall_linux_clean() {
  show_banner
  title "Reinstall Linux Bersih"
  echo -e "   Pilih distro:\n"
  echo -e "   ${WHITE}[1]${NC} Ubuntu 24.04 LTS"
  echo -e "   ${WHITE}[2]${NC} Ubuntu 22.04 LTS"
  echo -e "   ${WHITE}[3]${NC} Debian 12"
  echo -e "   ${WHITE}[4]${NC} Debian 11"
  echo -e "   ${WHITE}[5]${NC} CentOS Stream 9"
  echo -e "   ${WHITE}[0]${NC} Kembali"
  echo ""
  read -rp "$(echo -e "   ${BOLD}Pilihan: ${NC}")" DISTRO_CHOICE

  local distro="" ver=""
  case "$DISTRO_CHOICE" in
    1) distro="ubuntu"; ver="24.04" ;;
    2) distro="ubuntu"; ver="22.04" ;;
    3) distro="debian"; ver="12" ;;
    4) distro="debian"; ver="11" ;;
    5) distro="centos"; ver="9" ;;
    0) main_menu; return ;;
    *) warn "Tidak valid."; sleep 1; reinstall_linux_clean; return ;;
  esac

  danger_confirm "$distro $ver"

  read -rsp "$(echo -e "   ${BOLD}Password root baru: ${NC}")" ROOT_PASS; echo ""

  curl -sLo /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
  chmod +x /tmp/reinstall.sh
  bash /tmp/reinstall.sh "$distro" --version "$ver" --password "$ROOT_PASS"

  log "Proses reinstall dimulai. Server akan reboot otomatis."
}

# ── Main ─────────────────────────────────────────────────────
check_deps
main_menu
