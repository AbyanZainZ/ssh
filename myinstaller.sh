#!/bin/bash

# ================================================================
#  MyInstaller — VPS OS Deployment Tool  v2.0
#  github.com/AbyanZainZ
# ================================================================
#
#  Palette (3 warna, tujuan jelas):
#    WHITE  = teks utama / label
#    CYAN   = nilai & data (IP, username, angka)
#    RED    = destruktif / error
#    DIM    = teks sekunder (hint, keterangan)
#    BOLD   = hierarki heading
#  Aksen satu-satunya = CYAN, hanya pada data yang perlu dibaca.
#
# ================================================================

set -e

# ── Palette ──────────────────────────────────────────────────
WHITE='\033[1;37m'
CYAN='\033[0;36m'
RED='\033[0;31m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ── Primitif output ──────────────────────────────────────────
# Setiap fungsi punya satu tujuan visual, tidak bertumpuk.
ok()      { printf "  ${CYAN}ok${NC}   %s\n" "$1"; }
fail()    { printf "  ${RED}err${NC}  %s\n" "$1" >&2; exit 1; }
warn()    { printf "  ${RED}!${NC}    %s\n" "$1"; }
step()    { printf "\n  ${BOLD}%s${NC}\n" "$1"; }
hint()    { printf "  ${DIM}%s${NC}\n" "$1"; }
label()   { printf "  %-14s${CYAN}%s${NC}\n" "$1" "$2"; }
rule()    { printf "  ${DIM}%s${NC}\n" "────────────────────────────────────────────"; }

# ── Root check ───────────────────────────────────────────────
[ "$EUID" -ne 0 ] && fail "Jalankan sebagai root: sudo bash myinstaller.sh"

# ── Dependency check ─────────────────────────────────────────
check_deps() {
  for cmd in curl wget; do
    command -v "$cmd" &>/dev/null || apt-get install -y -qq "$cmd"
  done
}

# ── Baca info server sekali saja ─────────────────────────────
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_OS=$(lsb_release -ds 2>/dev/null || \
            awk -F'"' '/PRETTY_NAME/{print $2}' /etc/os-release)
SERVER_CPU=$(nproc)
SERVER_RAM=$(free -h | awk '/^Mem/{print $2}')
SERVER_DISK=$(df -h / | awk 'NR==2{print $2}')

# ================================================================
#  BANNER  — nama + satu baris info server
# ================================================================
show_banner() {
  clear
  printf "\n"
  printf "  ${BOLD}MyInstaller${NC}  ${DIM}VPS OS Deployment Tool  v2.0  by AbyanZainZ${NC}\n"
  rule
  printf "  ${DIM}%-10s${NC}${CYAN}%-20s${NC}  ${DIM}%-6s${NC}${CYAN}%s${NC}\n" \
    "IP" "$SERVER_IP" "OS" "$SERVER_OS"
  printf "  ${DIM}%-10s${NC}${CYAN}%-20s${NC}  ${DIM}%-6s${NC}${CYAN}%s${NC}\n" \
    "CPU" "${SERVER_CPU} core" "RAM" "$SERVER_RAM / Disk $SERVER_DISK"
  rule
  printf "\n"
}

# ================================================================
#  MENU UTAMA
# ================================================================
main_menu() {
  show_banner

  printf "  ${BOLD}Windows${NC}\n"
  printf "  ${DIM}1${NC}  Windows 10 Pro\n"
  printf "  ${DIM}2${NC}  Windows 11 Pro\n"
  printf "  ${DIM}3${NC}  Windows Server 2022        ${DIM}direkomendasikan untuk VPS${NC}\n"
  printf "  ${DIM}4${NC}  Windows Server 2019        ${DIM}ringan, stabil${NC}\n"
  printf "\n"
  printf "  ${BOLD}Linux + Desktop (RDP)${NC}\n"
  printf "  ${DIM}5${NC}  Ubuntu 24.04 + XFCE + xRDP\n"
  printf "  ${DIM}6${NC}  Debian 12 + XFCE + xRDP\n"
  printf "\n"
  printf "  ${BOLD}Lainnya${NC}\n"
  printf "  ${DIM}7${NC}  Reinstall Linux bersih     ${DIM}tanpa desktop${NC}\n"
  printf "  ${DIM}0${NC}  Keluar\n"
  printf "\n"
  rule

  printf "\n  Pilihan [0-7]: "
  read -r CHOICE
  printf "\n"

  case "$CHOICE" in
    1) install_windows "10"   ;;
    2) install_windows "11"   ;;
    3) install_windows "2022" ;;
    4) install_windows "2019" ;;
    5) install_ubuntu_rdp     ;;
    6) install_debian_rdp     ;;
    7) reinstall_linux_clean  ;;
    0) printf "  Selesai.\n\n"; exit 0 ;;
    *) warn "Pilihan tidak dikenal."; sleep 1; main_menu ;;
  esac
}

# ================================================================
#  KONFIRMASI — hanya muncul sebelum tindakan destruktif
# ================================================================
danger_confirm() {
  local target="$1"
  printf "\n"
  rule
  printf "  ${RED}${BOLD}PERINGATAN — tindakan ini tidak dapat dibatalkan${NC}\n"
  rule
  printf "\n"
  printf "  Target instalasi  : ${BOLD}%s${NC}\n" "$target"
  printf "  Disk              : ${RED}seluruh isi akan dihapus${NC}\n"
  printf "  Downtime          : server tidak bisa diakses 10–40 menit\n"
  printf "  Console           : siapkan akses VNC dari panel UpCloud\n"
  printf "  RDP setelah selesai: ${CYAN}%s${NC}\n" "$SERVER_IP"
  printf "\n"
  hint "Pastikan kamu sudah backup semua data penting."
  printf "\n"
  printf "  Ketik SETUJU untuk melanjutkan: "
  read -r CONFIRM
  [ "$CONFIRM" != "SETUJU" ] && { warn "Dibatalkan."; sleep 1; main_menu; }
  printf "\n"
}

# ================================================================
#  INSTALL WINDOWS
# ================================================================
install_windows() {
  local version="$1"
  local os_name win_ver
  win_ver="$version"

  case "$version" in
    "10")   os_name="Windows 10 Pro"      ;;
    "11")   os_name="Windows 11 Pro"      ;;
    "2022") os_name="Windows Server 2022" ;;
    "2019") os_name="Windows Server 2019" ;;
  esac

  danger_confirm "$os_name"

  step "Konfigurasi akun Administrator"
  hint "Username: Administrator (tidak bisa diubah)"
  printf "\n"

  while true; do
    printf "  Password (min. 8 karakter): "
    read -rs WIN_PASS; printf "\n"
    printf "  Konfirmasi password       : "
    read -rs WIN_PASS2; printf "\n"
    [ "$WIN_PASS" = "$WIN_PASS2" ] && break
    warn "Password tidak cocok, coba lagi."
    printf "\n"
  done
  [ "${#WIN_PASS}" -lt 8 ] && fail "Password minimal 8 karakter."

  printf "\n"
  step "Mengunduh engine instalasi"
  curl -sLo /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh \
  || wget -qO /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
  chmod +x /tmp/reinstall.sh
  ok "Engine siap."

  step "Menjalankan instalasi $os_name"
  hint "Server akan reboot otomatis. SSH akan terputus — ini normal."
  printf "\n"

  bash /tmp/reinstall.sh windows \
    --version "$win_ver" \
    --lang "en-us" \
    --password "$WIN_PASS"

  _summary_windows "$os_name" "$WIN_PASS"
}

_summary_windows() {
  local os_name="$1" pass="$2"
  printf "\n"
  rule
  printf "  ${BOLD}Instalasi dimulai${NC}\n"
  rule
  printf "\n"
  label "OS"       "$os_name"
  label "IP"       "$SERVER_IP"
  label "Port RDP" "3389"
  label "Username" "Administrator"
  label "Password" "$pass"
  printf "\n"
  hint "Tunggu 20–40 menit, lalu buka mstsc dan masukkan IP di atas."
  hint "Buka port 3389 di firewall panel UpCloud jika belum."
  printf "\n"
}

# ================================================================
#  INSTALL UBUNTU + XFCE + XRDP
# ================================================================
install_ubuntu_rdp() {
  show_banner
  step "Ubuntu 24.04 LTS + XFCE + xRDP"

  printf "  Username RDP baru : "
  read -r RDP_USER
  [ -z "$RDP_USER" ] && fail "Username tidak boleh kosong."

  while true; do
    printf "  Password          : "
    read -rs RDP_PASS; printf "\n"
    printf "  Konfirmasi        : "
    read -rs RDP_PASS2; printf "\n"
    [ "$RDP_PASS" = "$RDP_PASS2" ] && break
    warn "Password tidak cocok."
    printf "\n"
  done

  printf "\n"
  step "1/7  Update sistem"
  apt update -y -qq && apt upgrade -y -qq
  ok "Sistem diperbarui."

  step "2/7  Install XFCE4 + xRDP"
  DEBIAN_FRONTEND=noninteractive apt install -y -qq \
    xfce4 xfce4-goodies xfce4-terminal thunar mousepad \
    xrdp cpufrequtils tuned htop curl wget git unzip \
    fonts-ubuntu papirus-icon-theme
  ok "Paket terinstall."

  step "3/7  Optimasi kernel & jaringan"
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
  ok "Kernel dioptimasi."

  step "4/7  Membuat user $RDP_USER"
  if ! id "$RDP_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$RDP_USER"
  fi
  echo "$RDP_USER:$RDP_PASS" | chpasswd
  usermod -aG sudo "$RDP_USER"
  usermod -aG ssl-cert xrdp 2>/dev/null || true
  ok "User $RDP_USER siap."

  step "5/7  Konfigurasi sesi XFCE"
  USER_HOME="/home/$RDP_USER"
  echo "xfce4-session" > /root/.xsession
  echo "xfce4-session" > "$USER_HOME/.xsession"
  chown "$RDP_USER:$RDP_USER" "$USER_HOME/.xsession"
  chmod +x "$USER_HOME/.xsession" /root/.xsession

  STARTWM="/etc/xrdp/startwm.sh"
  grep -q "startxfce4" "$STARTWM" || {
    sed -i 's/^test -x/#test -x/' "$STARTWM"
    echo "exec startxfce4" >> "$STARTWM"
  }

  cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak 2>/dev/null || true
  sed -i 's/^max_bpp=.*/max_bpp=32/' /etc/xrdp/xrdp.ini 2>/dev/null || true
  sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini 2>/dev/null || true

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
  ok "xRDP dikonfigurasi."

  step "6/7  Install Google Chrome"
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    -O /tmp/chrome.deb
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
  ok "Chrome terinstall."

  step "7/7  Firewall + xRDP service"
  ufw allow 22/tcp  > /dev/null
  ufw allow 3389/tcp > /dev/null
  ufw --force enable > /dev/null
  systemctl enable xrdp > /dev/null
  systemctl restart xrdp
  ok "xRDP berjalan."

  printf "\n"
  rule
  printf "  ${BOLD}Setup selesai${NC}\n"
  rule
  printf "\n"
  label "IP"       "$SERVER_IP"
  label "Port RDP" "3389"
  label "Username" "$RDP_USER"
  label "Password" "(yang kamu input tadi)"
  printf "\n"
  hint "Koneksi: Win+R  ->  mstsc  ->  masukkan IP"
  hint "Buka port 3389 di firewall panel UpCloud jika belum."
  printf "\n"
}

# ================================================================
#  INSTALL DEBIAN + XFCE + XRDP
# ================================================================
install_debian_rdp() {
  show_banner
  step "Debian 12 + XFCE + xRDP"

  printf "  Username RDP : "
  read -r RDP_USER

  while true; do
    printf "  Password     : "; read -rs RDP_PASS; printf "\n"
    printf "  Konfirmasi   : "; read -rs RDP_PASS2; printf "\n"
    [ "$RDP_PASS" = "$RDP_PASS2" ] && break
    warn "Tidak cocok."; printf "\n"
  done

  printf "\n"
  step "Mengunduh engine"
  curl -sLo /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
  chmod +x /tmp/reinstall.sh
  ok "Engine siap."

  step "Instalasi Debian 12"
  bash /tmp/reinstall.sh debian --version 12 --password "$RDP_PASS"
  ok "Selesai. Setelah reboot jalankan setup-rdp.sh untuk install desktop."
}

# ================================================================
#  REINSTALL LINUX BERSIH
# ================================================================
reinstall_linux_clean() {
  show_banner
  step "Reinstall Linux bersih"

  printf "  1  Ubuntu 24.04\n"
  printf "  2  Ubuntu 22.04\n"
  printf "  3  Debian 12\n"
  printf "  4  Debian 11\n"
  printf "  5  CentOS Stream 9\n"
  printf "  0  Kembali\n"
  printf "\n"
  printf "  Distro [0-5]: "
  read -r DISTRO_CHOICE
  printf "\n"

  local distro ver
  case "$DISTRO_CHOICE" in
    1) distro="ubuntu"; ver="24.04" ;;
    2) distro="ubuntu"; ver="22.04" ;;
    3) distro="debian"; ver="12"    ;;
    4) distro="debian"; ver="11"    ;;
    5) distro="centos"; ver="9"     ;;
    0) main_menu; return ;;
    *) warn "Tidak valid."; sleep 1; reinstall_linux_clean; return ;;
  esac

  danger_confirm "$distro $ver"

  printf "  Password root baru: "
  read -rs ROOT_PASS; printf "\n\n"

  step "Mengunduh engine"
  curl -sLo /tmp/reinstall.sh \
    https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
  chmod +x /tmp/reinstall.sh
  ok "Engine siap."

  step "Menjalankan reinstall $distro $ver"
  bash /tmp/reinstall.sh "$distro" --version "$ver" --password "$ROOT_PASS"
  ok "Reinstall dimulai. Server akan reboot otomatis."
}

# ── Entry point ──────────────────────────────────────────────
check_deps
main_menu
