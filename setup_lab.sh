#!/bin/bash

set -e

LOG_DIR="$HOME/CS26AdaptixClass/LOGS"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup.log"
touch "$LOG_FILE"

PING_TIMEOUT=120
KALI_REPO="https://github.com/orthrus1775/kali.git"

# --- Start timer ---
start_time=$(date +%s)

# --- Logging function ---
log() {
    echo "$(date '+%F %T') | $1" | tee -a "$LOG_FILE"
}

# --- Format runtime ---
format_time() {
    local runtime=$1
    printf '%02d:%02d:%02d' $((runtime/3600)) $((runtime%3600/60)) $((runtime%60))
}

# --- Trap for exit ---
finish() {
    rc=$?
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    formatted=$(format_time "$runtime")
    log "Runtime: $formatted | Exit Code: $rc"
}

trap finish EXIT

# --- Prompt for become password upfront ---
read -s -p "Enter sudo/become password: " BECOME_PASS
echo

# --- sudo wrapper ---
sudoit() {
    echo "$BECOME_PASS" | sudo -S "$@" 2>/dev/null
}

log "Starting lab setup script"

# --- Check eth1 exists ---
log "[*] Checking for eth1 interface..."
if ! ip link show eth1 &>/dev/null; then
    log "ERROR: eth1 not found. Ensure the second NIC is attached and try again."
    exit 1
fi
log "[*] eth1 found."

# --- Configure eth1 static IP ---
log "[*] Configuring eth1 static IP (192.168.57.40/24)..."
iface_tmpfile=$(mktemp)
cat > "$iface_tmpfile" <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address 192.168.57.40
    netmask 255.255.255.0
EOF
sudoit cp "$iface_tmpfile" /etc/network/interfaces
sudoit chown root:root /etc/network/interfaces
sudoit chmod 644 /etc/network/interfaces
rm -f "$iface_tmpfile"

sudoit systemctl restart networking

log "[*] Verifying eth1 IP address..."
sleep 3
if ip addr show eth1 | grep inet | grep -q "192.168.57.40"; then
    log "[*] eth1 is up with correct IP (192.168.57.40)."
else
    log "ERROR: eth1 did not come up with expected IP. Check /etc/network/interfaces."
    exit 1
fi

# --- Connectivity test ---
# Listens on eth1 for ICMP from DC (192.168.57.10) and Workstation (192.168.57.31).
# Passes only when a ping is received from BOTH hosts within PING_TIMEOUT seconds.
wait_for_pings() {
    local label="$1"
    local tmpfile
    tmpfile=$(mktemp)

    clear
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                  ║"
    echo "  ║          C O N N E C T I V I T Y   T E S T                      ║"
    echo "  ║                  A C T I O N   R E Q U I R E D                  ║"
    echo "  ║                                                                  ║"
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    echo "  ║                                                                  ║"
    echo "  ║  1.  Log in to DC           (192.168.57.10)                     ║"
    echo "  ║      Username: vagrant   |   Password: vagrant                  ║"
    echo "  ║                                                                  ║"
    echo "  ║  2.  Log in to Workstation  (192.168.57.31)                     ║"
    echo "  ║      Username: vagrant   |   Password: vagrant                  ║"
    echo "  ║                                                                  ║"
    echo "  ║  3.  From BOTH hosts, run:                                      ║"
    echo "  ║                                                                  ║"
    echo "  ║         ping 192.168.57.40                                      ║"
    echo "  ║                                                                  ║"
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    echo "  ║                                                                  ║"
    echo "  ║  Press Enter here when you are ready to start pinging.          ║"
    echo "  ║  tcpdump will listen for ${PING_TIMEOUT}s and confirm both hosts.         ║"
    echo "  ║                                                                  ║"
    echo "  ╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    read -rp "  >>> Press Enter when ready..." _
    echo ""
    log "[*] ${label}: Listening on eth1 for ICMP from 192.168.57.10 and 192.168.57.31 (${PING_TIMEOUT}s timeout)."

    echo "$BECOME_PASS" | sudo -S timeout "$PING_TIMEOUT" \
        tcpdump -i eth1 -nn -l "icmp and (host 192.168.57.10 or host 192.168.57.31)" \
        2>/dev/null | tee -a "$tmpfile" || true

    local dc_seen ws_seen
    dc_seen=$(grep -c "192.168.57.10" "$tmpfile" || echo 0)
    ws_seen=$(grep -c "192.168.57.31" "$tmpfile" || echo 0)
    rm -f "$tmpfile"

    if [ "$dc_seen" -gt 0 ] && [ "$ws_seen" -gt 0 ]; then
        log "[*] ${label}: Pings received from both hosts. Connectivity confirmed."
        return 0
    else
        log "ERROR: ${label}: Did not receive pings from both hosts. Check NIC config and Windows hosts."
        return 1
    fi
}

# --- Pre-setup connectivity test ---
read -rp "Conduct Connectivity Test? [Y/n] " _conn_reply
_conn_reply="${_conn_reply:-y}"
case "$_conn_reply" in
    [yY]|[yY][eE][sS]) wait_for_pings "Pre-setup connectivity test" ;;
    [nN]|[nN][oO])     log "[*] Connectivity test skipped." ;;
    *)                  log "ERROR: Invalid input '$_conn_reply'. Aborting."; exit 1 ;;
esac

# --- Update system ---
log "[*] Updating system..."
sudoit apt update && sudoit apt upgrade -y

# --- Install dependencies ---
log "[*] Installing OpenSSH, Ansible, and Git..."
sudoit apt install -y openssh-server ansible git > /dev/null 2>&1

log "[*] Detecting hypervisor..."
HYPERVISOR=$(systemd-detect-virt)
log "[*] Hypervisor detected: ${HYPERVISOR}"

if [ "$HYPERVISOR" = "oracle" ]; then
    log "[*] VirtualBox detected — reinstalling virtualbox-guest-x11..."
    sudoit apt install -y --reinstall virtualbox-guest-x11 > /dev/null 2>&1
elif [ "$HYPERVISOR" = "vmware" ]; then
    log "[*] VMware detected — installing open-vm-tools-desktop..."
    sudoit apt install -y open-vm-tools-desktop > /dev/null 2>&1
else
    log "[*] Hypervisor '${HYPERVISOR}' not recognised — skipping guest additions."
fi

# --- Clone or update kali repo ---
log "[*] Checking for existing ~/kali repo..."
if [ ! -d ~/kali ]; then
    log "[*] Cloning kali repo (CS2026 branch)..."
    cd ~
    git clone -b CS2026 "$KALI_REPO"
    cd ~/kali
else
    log "[*] ~/kali exists. Updating CS2026 branch..."
    cd ~/kali
    git checkout CS2026
    git pull
fi

# --- Run Kali Ansible playbook ---
log "[*] Running Ansible playbook to setup Kali..."
PYTHONWARNINGS=ignore ANSIBLE_LOG_PATH="$LOG_DIR/ansible_kali.log" \
    ansible-playbook main.yml -e "ansible_become_password=$BECOME_PASS"

# --- Post-kali connectivity test ---
# wait_for_pings "Post-setup connectivity test"

# --- Clone CS26AdaptixClass repo and run lab playbook ---
log "[*] Setting up lab environment..."
cd ~/CS26AdaptixClass/ansible

PLAYBOOKS=(
    "lab-servers.yml"
    "lab-settings.yml"
    "lab-domain.yml"
    "lab-data.yml"
    "lab-relations.yml"
    "lab-adcs.yml"
    "lab-acl.yml"
    "lab-security.yml"
    "lab-vulnerabilities.yml"
    "lab-workstation.yml"
)

run_playbook() {
    local playbook="$1"
    shift
    PYTHONWARNINGS=ignore ANSIBLE_LOG_PATH="$LOG_DIR/ansible_lab.log" \
        ansible-playbook "$playbook" "$@"
}

for playbook in "${PLAYBOOKS[@]}"; do
    extra_args=()
    [[ "$playbook" == "lab-workstation.yml" ]] && extra_args=(-e "autologon_user=seth.hawkins")

    success=false
    for attempt in 1 2 3; do
        log "[*] $playbook — attempt $attempt/3..."
        if run_playbook "$playbook" "${extra_args[@]}"; then
            log "[*] $playbook succeeded on attempt $attempt"
            success=true
            break
        else
            log "[!] $playbook failed on attempt $attempt"
        fi
    done

    if [ "$success" = false ]; then
        log "ERROR: $playbook failed after 3 attempts. Aborting."
        exit 1
    fi
done

log "[*] All playbooks completed successfully"

log "[*] Lab setup completed successfully"