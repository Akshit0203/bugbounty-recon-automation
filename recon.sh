#!/usr/bin/env bash
#
# recon.sh — Bug Bounty Reconnaissance Automation
#
# Automates the initial recon phase of a bug bounty engagement:
#   subdomain enumeration -> dedup/filter -> live-host probing ->
#   JS file discovery -> subdomain takeover check -> directory fuzzing.
#
# Author : Akshit (https://github.com/Akshit0203)
# License: MIT
#
# USAGE:
#   ./recon.sh <target-domain>
#   ./recon.sh example.com
#
# All output is written to ./<target-domain>/ as timestamped artifacts.
#
# -----------------------------------------------------------------------------
# NOTE: Only run this against assets you are explicitly authorized to test
#       (your own, or a target within a bug bounty program's defined scope).
#       Unauthorized scanning may be illegal. You are responsible for your use.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# ---------- Colors -----------------------------------------------------------
if [[ -t 1 ]]; then
    RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

log()   { echo -e "${BLUE}[*]${RESET} $*"; }
step()  { echo -e "${RED}[+]${RESET} $*"; }
ok()    { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $*"; }
die()   { echo -e "${RED}[x]${RESET} $*" >&2; exit 1; }

# ---------- Config (override via environment) --------------------------------
THREADS="${THREADS:-25}"
WORDLIST="${WORDLIST:-/usr/share/wordlists/dirb/common.txt}"
SUBJACK_FINGERPRINTS="${SUBJACK_FINGERPRINTS:-$HOME/go/pkg/mod/github.com/haccer/subjack/fingerprints.json}"

# ---------- Usage ------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") <target-domain>

Automates recon: subdomain enumeration, live-host probing, JS discovery,
subdomain-takeover detection, and directory fuzzing.

Arguments:
  <target-domain>   Root domain to enumerate (e.g. example.com)

Environment overrides:
  THREADS               Concurrency for enumeration tools   (default: 25)
  WORDLIST              Wordlist for dirsearch               (default: $WORDLIST)
  SUBJACK_FINGERPRINTS  Path to subjack fingerprints.json

Example:
  ./$(basename "$0") example.com
  THREADS=50 WORDLIST=~/lists/big.txt ./$(basename "$0") example.com
EOF
}

# ---------- Dependency check -------------------------------------------------
require() {
    command -v "$1" >/dev/null 2>&1 || die "Missing dependency: '$1'. See README.md for install instructions."
}

check_deps() {
    log "Checking dependencies..."
    local missing=0
    for tool in sublist3r assetfinder httprobe subjs subjack dirsearch; do
        if command -v "$tool" >/dev/null 2>&1; then
            ok "found: $tool"
        else
            warn "missing: $tool"
            missing=1
        fi
    done
    [[ "$missing" -eq 0 ]] || die "Install missing tools before running (see README.md)."
}

# ---------- Main -------------------------------------------------------------
main() {
    case "${1:-}" in
        -h|--help|"") usage; exit 0 ;;
    esac

    local target="$1"

    # Basic sanity check on the domain format
    if ! [[ "$target" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        die "'$target' does not look like a valid domain (expected e.g. example.com)."
    fi

    check_deps

    local outdir="$target"
    mkdir -p "$outdir"
    cd "$outdir"

    # -- 1. Subdomain enumeration --------------------------------------------
    step "Finding subdomains with Sublist3r..."
    sublist3r -d "$target" -t "$THREADS" -o subdomains.txt || warn "sublist3r returned non-zero"

    step "Finding subdomains with Assetfinder..."
    assetfinder --subs-only "$target" >> subdomains.txt || warn "assetfinder returned non-zero"

    # -- 2. Sort & filter -----------------------------------------------------
    step "Sorting and de-duplicating..."
    sort -u subdomains.txt > subdomains
    ok "$(wc -l < subdomains) unique subdomains"

    # -- 3. Resolve live hosts ------------------------------------------------
    step "Probing for live hosts with httprobe..."
    httprobe < subdomains > alive.txt
    ok "$(wc -l < alive.txt) live hosts"

    # -- 4. JS file discovery -------------------------------------------------
    step "Extracting JavaScript files with subjs..."
    subjs < alive.txt > jsfiles || warn "subjs returned non-zero"
    ok "$(wc -l < jsfiles 2>/dev/null || echo 0) JS endpoints"

    # -- 5. Subdomain takeover check -----------------------------------------
    step "Checking for subdomain takeovers with subjack..."
    if [[ -f "$SUBJACK_FINGERPRINTS" ]]; then
        subjack -w subdomains -c "$SUBJACK_FINGERPRINTS" -t "$THREADS" -ssl -o takeovers.txt || warn "subjack returned non-zero"
    else
        warn "fingerprints.json not found at '$SUBJACK_FINGERPRINTS' — skipping takeover check."
        warn "Set SUBJACK_FINGERPRINTS to the correct path (see README.md)."
    fi

    # -- 6. Directory fuzzing -------------------------------------------------
    step "Fuzzing directories with dirsearch..."
    if [[ -f "$WORDLIST" ]]; then
        while read -r host; do
            [[ -z "$host" ]] && continue
            log "fuzzing $host"
            dirsearch -u "$host" -w "$WORDLIST" -o "directory_fuzzing.txt" || warn "dirsearch failed for $host"
        done < alive.txt
    else
        warn "wordlist not found at '$WORDLIST' — skipping directory fuzzing."
    fi

    ok "Recon complete. Artifacts written to ./$outdir/"
}

main "$@"
