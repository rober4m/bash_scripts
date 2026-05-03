#!/usr/bin/env bash
# =============================================================================
#  sysinfo.sh — System Information Reporter
#  Works on Linux and macOS
#  Prints a formatted report to the terminal AND saves it as sysinfo.md
# =============================================================================

set -euo pipefail

OUTPUT_FILE="sysinfo.md"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# ── Detect OS ─────────────────────────────────────────────────────────────────
OS_TYPE="$(uname -s)"

# ── Helper: section header ────────────────────────────────────────────────────
section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

md_section() {
  echo "" >> "$OUTPUT_FILE"
  echo "---" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "## $1" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

row() {
  # row "Label" "value"  — prints to terminal and appends to md
  printf "  %-28s %s\n" "$1:" "$2"
  echo "- **$1:** $2" >> "$OUTPUT_FILE"
}

# ── Gather OS info ─────────────────────────────────────────────────────────────
get_os_info() {
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    OS_NAME="macOS $(sw_vers -productVersion)"
    OS_BUILD="$(sw_vers -buildVersion)"
    KERNEL="$(uname -r)"
    ARCH="$(uname -m)"
  else
    OS_NAME="$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -o)"
    OS_BUILD="$(uname -r)"
    KERNEL="$(uname -r)"
    ARCH="$(uname -m)"
  fi
}

# ── Gather CPU info ────────────────────────────────────────────────────────────
get_cpu_info() {
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    CPU_MODEL="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'N/A')"
    CPU_CORES="$(sysctl -n hw.physicalcpu 2>/dev/null || echo 'N/A')"
    CPU_THREADS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 'N/A')"
    CPU_FREQ="$(sysctl -n hw.cpufrequency_max 2>/dev/null | awk '{printf "%.0f MHz", $1/1000000}' 2>/dev/null || echo 'N/A')"
  else
    CPU_MODEL="$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs || echo 'N/A')"
    CPU_CORES="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 'N/A')"
    CPU_THREADS="$(nproc 2>/dev/null || echo 'N/A')"
    CPU_FREQ="$(grep 'cpu MHz' /proc/cpuinfo | head -1 | awk '{printf "%.0f MHz", $4}' 2>/dev/null || echo 'N/A')"
  fi
}

# ── Gather RAM info ────────────────────────────────────────────────────────────
get_ram_info() {
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    RAM_TOTAL="$(sysctl -n hw.memsize | awk '{printf "%.1f GB", $1/1073741824}')"
    RAM_FREE="$(vm_stat | awk '
      /Pages free/       { free=$3 }
      /Pages inactive/   { inact=$3 }
      END { printf "%.1f GB", (free+inact)*4096/1073741824 }' | tr -d '.')"
    # safer fallback
    RAM_FREE="$(vm_stat | grep 'Pages free' | awk '{printf "%.1f GB", $3*4096/1073741824}')"
  else
    RAM_TOTAL="$(free -h | awk '/^Mem:/ {print $2}')"
    RAM_USED="$(free -h  | awk '/^Mem:/ {print $3}')"
    RAM_FREE="$(free -h  | awk '/^Mem:/ {print $4}')"
  fi
}

# ── Gather Disk info ───────────────────────────────────────────────────────────
get_disk_info() {
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    DISK_INFO="$(df -h / | awk 'NR==2 {printf "Total: %s  Used: %s  Free: %s  (%s used)", $2, $3, $4, $5}')"
  else
    DISK_INFO="$(df -h / | awk 'NR==2 {printf "Total: %s  Used: %s  Free: %s  (%s used)", $2, $3, $4, $5}')"
  fi
}

# ── Gather Network info ────────────────────────────────────────────────────────
get_network_info() {
  HOSTNAME="$(hostname)"

  if [[ "$OS_TYPE" == "Darwin" ]]; then
    LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 'N/A')"
  else
    LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'N/A')"
  fi

  PUBLIC_IP="$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'N/A (no internet)')"
  DNS_SERVER="$(cat /etc/resolv.conf 2>/dev/null | grep '^nameserver' | head -1 | awk '{print $2}' || echo 'N/A')"
}

# ── Gather GPU info ────────────────────────────────────────────────────────────
get_gpu_info() {
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    GPU_INFO="$(system_profiler SPDisplaysDataType 2>/dev/null | grep 'Chipset Model' | head -1 | cut -d: -f2 | xargs || echo 'N/A')"
  else
    if command -v lspci &>/dev/null; then
      GPU_INFO="$(lspci | grep -i 'vga\|3d\|display' | head -1 | cut -d: -f3 | xargs || echo 'N/A')"
    elif command -v nvidia-smi &>/dev/null; then
      GPU_INFO="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
    else
      GPU_INFO="N/A (install lspci or nvidia-smi)"
    fi
  fi
}

# ── Gather uptime & load ───────────────────────────────────────────────────────
get_uptime_info() {
  UPTIME_STR="$(uptime | sed 's/.*up //' | cut -d',' -f1-2 | xargs)"
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    LOAD_AVG="$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')"
  else
    LOAD_AVG="$(cat /proc/loadavg | awk '{print $1, $2, $3}')"
  fi
}

# ── Gather shell & env info ────────────────────────────────────────────────────
get_env_info() {
  SHELL_NAME="$SHELL"
  BASH_VER="$BASH_VERSION"
  USER_NAME="$(whoami)"
  HOME_DIR="$HOME"
  TERM_TYPE="${TERM:-N/A}"
  LANG_ENV="${LANG:-N/A}"
  TIMEZONE="$(date +%Z)"
}

# ── Gather installed tools ─────────────────────────────────────────────────────
get_tools_info() {
  check_tool() {
    if command -v "$1" &>/dev/null; then
      echo "$("$1" --version 2>&1 | head -1)"
    else
      echo "not installed"
    fi
  }

  PYTHON_VER="$(check_tool python3)"
  NODE_VER="$(check_tool node)"
  GIT_VER="$(check_tool git)"
  DOCKER_VER="$(check_tool docker)"
  CURL_VER="$(check_tool curl)"
}

# =============================================================================
#  MAIN — collect everything
# =============================================================================
get_os_info
get_cpu_info
get_ram_info
get_disk_info
get_network_info
get_gpu_info
get_uptime_info
get_env_info
get_tools_info

# =============================================================================
#  INIT markdown file
# =============================================================================
cat > "$OUTPUT_FILE" <<HEADER
# System Information Report

> Generated on: **$TIMESTAMP**

HEADER

# =============================================================================
#  PRINT & WRITE — System Overview
# =============================================================================
clear
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          SYSTEM INFORMATION REPORT                  ║"
echo "║          $TIMESTAMP                 ║"
echo "╚══════════════════════════════════════════════════════╝"

# ── OS ─────────────────────────────────────────────────────────────────────────
section "OPERATING SYSTEM"
md_section "Operating System"
row "OS"           "$OS_NAME"
row "Build/Kernel" "$OS_BUILD"
row "Architecture" "$ARCH"

# ── CPU ────────────────────────────────────────────────────────────────────────
section "CPU"
md_section "CPU"
row "Model"        "$CPU_MODEL"
row "Cores"        "$CPU_CORES"
row "Threads"      "$CPU_THREADS"
row "Frequency"    "$CPU_FREQ"

# ── RAM ────────────────────────────────────────────────────────────────────────
section "MEMORY (RAM)"
md_section "Memory (RAM)"
row "Total RAM"    "$RAM_TOTAL"
if [[ "$OS_TYPE" == "Darwin" ]]; then
  row "Free (approx)" "$RAM_FREE"
else
  row "Used"        "$RAM_USED"
  row "Free"        "$RAM_FREE"
fi

# ── Disk ───────────────────────────────────────────────────────────────────────
section "DISK (root /)"
md_section "Disk (root /)"
row "Storage"      "$DISK_INFO"

# ── GPU ────────────────────────────────────────────────────────────────────────
section "GPU"
md_section "GPU"
row "Graphics"     "$GPU_INFO"

# ── Network ────────────────────────────────────────────────────────────────────
section "NETWORK"
md_section "Network"
row "Hostname"     "$HOSTNAME"
row "Local IP"     "$LOCAL_IP"
row "Public IP"    "$PUBLIC_IP"
row "DNS Server"   "$DNS_SERVER"

# ── Uptime & Load ──────────────────────────────────────────────────────────────
section "UPTIME & LOAD"
md_section "Uptime & Load"
row "Uptime"       "$UPTIME_STR"
row "Load Average" "$LOAD_AVG (1m 5m 15m)"

# ── Environment ────────────────────────────────────────────────────────────────
section "SHELL & ENVIRONMENT"
md_section "Shell & Environment"
row "User"         "$USER_NAME"
row "Home"         "$HOME_DIR"
row "Shell"        "$SHELL_NAME"
row "Bash Version" "$BASH_VER"
row "Terminal"     "$TERM_TYPE"
row "Language"     "$LANG_ENV"
row "Timezone"     "$TIMEZONE"

# ── Installed Tools ────────────────────────────────────────────────────────────
section "INSTALLED TOOLS"
md_section "Installed Tools"
row "Python 3"     "$PYTHON_VER"
row "Node.js"      "$NODE_VER"
row "Git"          "$GIT_VER"
row "Docker"       "$DOCKER_VER"
row "curl"         "$CURL_VER"

# ── Footer ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  Report saved to: \033[1;32m%s\033[0m\n" "$(pwd)/$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
  echo ""
  echo "---"
  echo ""
  echo "*Report generated by sysinfo.sh on \`$(hostname)\`*"
} >> "$OUTPUT_FILE"

echo "Done! Markdown report written to: $OUTPUT_FILE"
