#!/bin/bash
#
# Axios Supply Chain Attack Scanner (Linux/macOS)
# Checks if your computer was affected by the axios npm hack (March 31, 2026).
#
# Usage:  chmod +x axios-scanner.sh && ./axios-scanner.sh
#
# Flags:  --fix          Remove malicious files if found
#         --path /dir    Only scan a specific folder
#
# Author: Ahmed Taha (@SufficientDaikon)

# --- Config ---

MALICIOUS_VERSIONS=("1.14.1" "0.30.4")
DROPPER="plain-crypto-js"
C2_DOMAIN="sfrclak.com"
C2_IP="142.11.206.73"

FIX=false
SCAN_PATH="$HOME"
COMPROMISED=false

TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_FILE="$SCRIPT_DIR/axios-scan-log_$TIMESTAMP.txt"
REPORT_FILE="$SCRIPT_DIR/axios-scan-report_$TIMESTAMP.txt"

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
DC='\033[0;90m'
W='\033[1;37m'
NC='\033[0m'

# --- Args ---

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)  FIX=true; shift ;;
        --path) SCAN_PATH="$2"; shift 2 ;;
        --help)
            echo "Usage: ./axios-scanner.sh [--fix] [--path /some/dir]"
            echo "  --fix    Automatically remove malicious files"
            echo "  --path   Only scan a specific directory"
            exit 0
            ;;
        *) echo "Unknown option: $1 (use --help)"; exit 1 ;;
    esac
done

# --- Logging ---

log() {
    local msg="$1"
    local level="${2:-INFO}"
    local time
    time="$(date '+%H:%M:%S')"
    echo "[$time] [$level] $msg" >> "$LOG_FILE"

    case "$level" in
        PASS)
            TOTAL=$((TOTAL + 1)); PASSED=$((PASSED + 1))
            echo -e "  ${DC}[${G}PASS${DC}]${NC} $msg"
            ;;
        FAIL)
            TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1))
            COMPROMISED=true
            echo -e "  ${DC}[${R}FAIL${DC}]${NC} ${R}$msg${NC}"
            ;;
        WARN)
            TOTAL=$((TOTAL + 1)); WARNINGS=$((WARNINGS + 1))
            echo -e "  ${DC}[${Y}WARN${DC}]${NC} ${Y}$msg${NC}"
            ;;
        HEAD)
            echo ""
            echo -e "  ${C}$msg${NC}"
            local len=${#msg}
            echo -e "  ${DC}$(printf '%*s' "$len" '' | tr ' ' '-')${NC}"
            ;;
        STEP)
            echo -e "  ${DC}[ .. ]${NC} $msg"
            ;;
        *)
            echo -e "  ${DC}[INFO]${NC} ${DC}$msg${NC}"
            ;;
    esac
}

# --- Banner ---

echo ""
echo -e "  ${C}============================================================${NC}"
echo -e "  ${C}|                                                          |${NC}"
echo -e "  ${C}|         AXIOS SUPPLY CHAIN ATTACK SCANNER               |${NC}"
echo -e "  ${C}|                                                          |${NC}"
echo -e "  ${C}|  Checks if your computer was affected by the axios      |${NC}"
echo -e "  ${C}|  npm package hack that happened on March 31, 2026.      |${NC}"
echo -e "  ${C}|                                                          |${NC}"
echo -e "  ${C}|  This scanner is safe to run. It only READS your        |${NC}"
echo -e "  ${C}|  files and checks your system. Nothing is changed       |${NC}"
echo -e "  ${C}|  unless you use the --fix flag.                         |${NC}"
echo -e "  ${C}|                                                          |${NC}"
echo -e "  ${C}============================================================${NC}"
echo ""

log "Scanner started" INFO
log "Log file: $LOG_FILE" INFO
log "Scan target: $SCAN_PATH" INFO
echo ""

# --- Phase 1: Axios Versions ---

phase1_axios() {
    log "PHASE 1 of 5: Looking for axios installations on your computer..." HEAD
    log "This finds every copy of the axios library and checks its version number." STEP

    local count=0
    local bad=0

    log "Searching your files (this may take a moment)..." STEP

    while IFS= read -r -d '' pkgfile; do
        local name="" version=""

        if command -v jq &>/dev/null; then
            name="$(jq -r '.name // empty' "$pkgfile" 2>/dev/null)"
            version="$(jq -r '.version // empty' "$pkgfile" 2>/dev/null)"
        else
            name="$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$pkgfile" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
            version="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$pkgfile" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
        fi

        if [[ "$name" == "axios" ]]; then
            count=$((count + 1))
            local dir
            dir="$(dirname "$pkgfile")"

            local is_bad=false
            for mv in "${MALICIOUS_VERSIONS[@]}"; do
                if [[ "$version" == "$mv" ]]; then
                    is_bad=true
                    bad=$((bad + 1))
                    log "COMPROMISED: axios version $version found at $dir" FAIL
                    if $FIX; then
                        rm -rf "$dir"
                        log "REMOVED compromised axios at: $dir" WARN
                    fi
                fi
            done

            if ! $is_bad; then
                log "Safe: axios $version at $dir" PASS
            fi
        fi
    done < <(find "$SCAN_PATH" -path "*/axios/package.json" -not -path "*/.git/*" -print0 2>/dev/null || true)

    if [[ $count -eq 0 ]]; then
        log "No axios installations found. Normal if you don't use Node.js." INFO
    elif [[ $bad -gt 0 ]]; then
        log "RESULT: Found $bad COMPROMISED out of $count total axios installations" FAIL
    else
        log "RESULT: All $count axios installations are safe versions" PASS
    fi
}

# --- Phase 2: Dropper Package ---

phase2_dropper() {
    log "PHASE 2 of 5: Looking for the malicious dropper package..." HEAD
    log "The attacker used a fake package called 'plain-crypto-js' to deliver the virus." STEP

    log "Searching for '$DROPPER' in all your project folders..." STEP
    local found=""
    found="$(find "$SCAN_PATH" -type d -name "$DROPPER" -not -path "*/.git/*" 2>/dev/null || true)"

    if [[ -n "$found" ]]; then
        while IFS= read -r dir; do
            log "FOUND malicious package at: $dir" FAIL
            if $FIX; then
                rm -rf "$dir"
                log "REMOVED malicious package at: $dir" WARN
            fi
        done <<< "$found"
    else
        log "Malicious 'plain-crypto-js' package was NOT found anywhere" PASS
    fi

    log "Checking for suspicious postinstall scripts inside axios folders..." STEP
    local setup=""
    setup="$(find "$SCAN_PATH" -path "*/axios/setup.js" 2>/dev/null || true)"

    if [[ -n "$setup" ]]; then
        while IFS= read -r f; do
            log "SUSPICIOUS setup.js found inside axios folder: $f" FAIL
        done <<< "$setup"
    else
        log "No suspicious scripts found inside axios folders" PASS
    fi
}

# --- Phase 3: RAT Artifacts ---

phase3_rat() {
    log "PHASE 3 of 5: Checking for backdoor files on your system..." HEAD
    log "The attacker's virus drops specific files. We check if any exist." STEP

    local rat_paths=(
        "/tmp/6202033.sh:Shell script backdoor (6202033.sh in /tmp)"
        "/tmp/6202033.py:Python backdoor (6202033.py in /tmp)"
        "/var/tmp/6202033:Backdoor file in /var/tmp"
        "$HOME/.6202033:Hidden backdoor in home directory"
    )

    local found_any=false
    for entry in "${rat_paths[@]}"; do
        local path="${entry%%:*}"
        local desc="${entry#*:}"

        log "Checking: $desc..." STEP
        if [[ -e "$path" ]]; then
            found_any=true
            log "BACKDOOR FILE FOUND: $path" FAIL
            if $FIX; then
                rm -f "$path"
                log "REMOVED backdoor file: $path" WARN
            fi
        else
            log "Not found: $desc" PASS
        fi
    done
}

# --- Phase 4: Network ---

phase4_network() {
    log "PHASE 4 of 5: Checking if your computer contacted the attacker's server..." HEAD
    log "We check active connections and your hosts file." STEP

    # Active connections
    log "Checking for active connections to attacker's server ($C2_IP)..." STEP
    if command -v ss &>/dev/null; then
        if ss -tn 2>/dev/null | grep -q "$C2_IP"; then
            log "ACTIVE CONNECTION to attacker's server detected! IP: $C2_IP" FAIL
        else
            log "No active connections to attacker's server" PASS
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tn 2>/dev/null | grep -q "$C2_IP"; then
            log "ACTIVE CONNECTION to attacker's server detected! IP: $C2_IP" FAIL
        else
            log "No active connections to attacker's server" PASS
        fi
    else
        log "Could not check connections (ss and netstat not available)" INFO
    fi

    # /etc/hosts
    log "Checking hosts file..." STEP
    if [[ -f /etc/hosts ]]; then
        if grep -qi "$C2_DOMAIN" /etc/hosts 2>/dev/null; then
            log "Attacker's domain found in /etc/hosts (may be a block entry -- check manually)" WARN
        else
            log "Attacker's domain NOT in /etc/hosts" PASS
        fi
    fi

    # macOS: check LaunchAgents
    if [[ "$(uname)" == "Darwin" ]]; then
        log "Checking macOS LaunchAgents for persistence..." STEP
        local bad_agents=""
        bad_agents="$(grep -rl "6202033\|plain-crypto\|sfrclak" "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null || true)"
        if [[ -n "$bad_agents" ]]; then
            while IFS= read -r f; do
                log "SUSPICIOUS LaunchAgent: $f" FAIL
            done <<< "$bad_agents"
        else
            log "No suspicious LaunchAgents found" PASS
        fi
    fi

    # Linux: check crontab
    if [[ "$(uname)" == "Linux" ]]; then
        log "Checking crontab for persistence..." STEP
        local cron_check=""
        cron_check="$(crontab -l 2>/dev/null | grep -E "6202033|plain-crypto|sfrclak" || true)"
        if [[ -n "$cron_check" ]]; then
            log "SUSPICIOUS crontab entry found" FAIL
        else
            log "No suspicious crontab entries" PASS
        fi
    fi
}

# --- Phase 5: Lockfiles ---

phase5_lockfiles() {
    log "PHASE 5 of 5: Scanning project dependency files..." HEAD
    log "Lockfiles record exact versions of packages used in your projects." STEP

    local checked=0
    local bad_locks=0

    log "Searching for lockfiles (this may take a moment)..." STEP

    while IFS= read -r -d '' lockfile; do
        checked=$((checked + 1))

        for mv in "${MALICIOUS_VERSIONS[@]}"; do
            if grep -q "axios.*$mv" "$lockfile" 2>/dev/null; then
                bad_locks=$((bad_locks + 1))
                log "Compromised axios $mv referenced in: $lockfile" FAIL
            fi
        done

        if grep -q "$DROPPER" "$lockfile" 2>/dev/null; then
            bad_locks=$((bad_locks + 1))
            log "Dropper package referenced in: $lockfile" FAIL
        fi
    done < <(find "$SCAN_PATH" -maxdepth 8 \( -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" \) -not -path "*/node_modules/*" -print0 2>/dev/null || true)

    if [[ $checked -eq 0 ]]; then
        log "No project lockfiles found (normal if you don't have Node.js projects)" INFO
    elif [[ $bad_locks -eq 0 ]]; then
        log "Scanned $checked lockfiles -- all clean" PASS
    fi
}

# --- Report ---

write_report() {
    {
        echo "========================================================"
        echo "  AXIOS SUPPLY CHAIN ATTACK - SCAN REPORT"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Computer:  $(hostname)"
        echo "  User:      $(whoami)"
        echo "  OS:        $(uname -s) $(uname -r)"
        echo "  Scanner:   axios-scanner.sh"
        echo "========================================================"
        echo ""

        if $COMPROMISED; then
            echo "  VERDICT:  *** COMPROMISED ***"
            echo ""
            echo "  Your computer shows signs of the axios supply chain attack."
            echo "  Follow the steps below immediately."
        else
            echo "  VERDICT:  CLEAN"
            echo ""
            echo "  No signs of compromise were found on your computer."
        fi

        echo ""
        echo "  Summary: $TOTAL checks run, $PASSED passed, $FAILED failed, $WARNINGS warnings"
        echo ""
        echo "  (See the log file for full details: $LOG_FILE)"
        echo ""

        if $COMPROMISED; then
            echo "--------------------------------------------------------"
            echo "  WHAT TO DO NOW"
            echo "--------------------------------------------------------"
            echo ""
            echo "  1. DISCONNECT from the internet right now"
            echo "  2. Re-run this scanner with --fix:"
            echo "     ./axios-scanner.sh --fix"
            echo "  3. CHANGE ALL YOUR PASSWORDS:"
            echo "     - Email, GitHub, npm, cloud services"
            echo "  4. REGENERATE all API keys, SSH keys, and tokens"
            echo "  5. CHECK git history for unauthorized commits"
            echo "  6. TELL YOUR TEAM if this is a work computer"
        else
            echo "--------------------------------------------------------"
            echo "  HOW TO STAY SAFE"
            echo "--------------------------------------------------------"
            echo ""
            echo "  - Pin dependency versions (avoid ^ and ~ ranges)"
            echo "  - Always commit your lockfile"
            echo "  - Use 'npm ci' instead of 'npm install'"
            echo "  - Enable 2FA on your npm account"
        fi

        echo ""
        echo "--------------------------------------------------------"
        echo "  ATTACK INDICATORS (for reference)"
        echo "--------------------------------------------------------"
        echo ""
        echo "  Bad versions:  axios@1.14.1, axios@0.30.4"
        echo "  Bad package:   plain-crypto-js@4.2.1"
        echo "  Attacker IP:   142.11.206.73"
        echo "  Attacker URL:  sfrclak.com:8000/6202033"
        echo ""
        echo "========================================================"
        echo "  Log:    $LOG_FILE"
        echo "  Report: $REPORT_FILE"
        echo "========================================================"
    } > "$REPORT_FILE"
}

# --- Main ---

START_TIME=$(date +%s)

phase1_axios
phase2_dropper
phase3_rat
phase4_network
phase5_lockfiles

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

write_report

# --- Verdict ---

echo ""
echo -e "  ${DC}============================================================${NC}"
echo -e "  ${DC}|                                                          |${NC}"

if $COMPROMISED; then
    echo -e "  ${DC}|   ${NC}VERDICT: ${R}COMPROMISED${NC}                                  ${DC}|${NC}"
    echo -e "  ${DC}|                                                          |${NC}"
    echo -e "  ${DC}|   ${R}Your computer shows signs of the attack.${NC}              ${DC}|${NC}"
    echo -e "  ${DC}|   ${Y}Open the report file for what to do next.${NC}             ${DC}|${NC}"
else
    echo -e "  ${DC}|   ${NC}VERDICT: ${G}CLEAN${NC}                                        ${DC}|${NC}"
    echo -e "  ${DC}|                                                          |${NC}"
    echo -e "  ${DC}|   ${G}No signs of compromise. You are safe.${NC}                  ${DC}|${NC}"
fi

echo -e "  ${DC}|                                                          |${NC}"
echo -e "  ${DC}============================================================${NC}"
echo ""
echo -e "  ${DC}Checks: $TOTAL | Passed: $PASSED | Failed: $FAILED | Warnings: $WARNINGS${NC}"
echo -e "  ${DC}Time: ${ELAPSED}s${NC}"
echo ""
echo -e "  ${DC}Log file:    $LOG_FILE${NC}"
echo -e "  ${DC}Report file: $REPORT_FILE${NC}"
echo ""

if $COMPROMISED; then exit 1; else exit 0; fi
