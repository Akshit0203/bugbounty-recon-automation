# Bug Bounty Recon Automation

> A single Bash script that automates the initial reconnaissance phase of a bug bounty engagement — subdomain enumeration, filtering, live-host probing, JavaScript discovery, subdomain-takeover detection, and directory fuzzing — in one run.

<p align="center">
  <img src="https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnubash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/platform-Kali%20%7C%20Linux-557C94?logo=kalilinux&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  <img src="https://img.shields.io/badge/category-recon%20automation-red" alt="Category">
</p>

---

## ⚠️ Legal & Ethical Notice

This tool is for **authorized security testing only**. Run it exclusively against:

- Assets **you own**, or
- Targets **explicitly in scope** of a bug bounty program you are participating in.

Unauthorized scanning or enumeration of systems you do not own or have permission to test may be **illegal** in your jurisdiction. The author assumes no liability for misuse. **You are responsible for your own actions.**

---

## Why

Recon is the foundation of bug bounty hunting, but running six tools by hand for every target is slow and error-prone. `recon.sh` chains the standard passive/active recon tools into one reproducible pipeline that drops organized, per-target artifacts to disk.

## Pipeline

```
┌─────────────────┐   ┌──────────────┐   ┌───────────────┐   ┌──────────────┐
│ 1. Enumerate    │──▶│ 2. Sort &    │──▶│ 3. Probe live │──▶│ 4. JS file   │
│ Sublist3r +     │   │    dedupe    │   │    hosts      │   │   discovery  │
│ Assetfinder     │   │ sort -u      │   │ httprobe      │   │ subjs        │
└─────────────────┘   └──────────────┘   └───────────────┘   └──────┬───────┘
                                                                     │
                      ┌──────────────┐   ┌───────────────┐          │
                      │ 6. Directory │◀──│ 5. Takeover   │◀─────────┘
                      │    fuzzing   │   │    check      │
                      │ dirsearch    │   │ subjack       │
                      └──────────────┘   └───────────────┘
```

| Step | Tool | Purpose |
| ---- | ---- | ------- |
| 1 | [Sublist3r](https://github.com/aboul3la/Sublist3r) + [Assetfinder](https://github.com/tomnomnom/assetfinder) | Passive subdomain enumeration |
| 2 | `sort -u` | Merge and de-duplicate results |
| 3 | [httprobe](https://github.com/tomnomnom/httprobe) | Probe for live HTTP/HTTPS hosts |
| 4 | [subjs](https://github.com/lc/subjs) | Extract JavaScript file URLs |
| 5 | [subjack](https://github.com/haccer/subjack) | Detect subdomain takeovers |
| 6 | [dirsearch](https://github.com/maurosoria/dirsearch) | Directory / path brute-forcing |

## Requirements

- Bash 4+ (tested on Kali Linux)
- Go (for `assetfinder`, `httprobe`, `subjs`, `subjack`)
- Python 3 (for `sublist3r`, `dirsearch`)

## Installation

```bash
# Clone
git clone https://github.com/Akshit0203/bugbounty-recon-automation.git
cd bugbounty-recon-automation
chmod +x recon.sh

# --- Tool dependencies ---
# Debian/Kali packages
sudo apt update
sudo apt install -y sublist3r dirsearch httprobe

# Go-based tools
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/lc/subjs@latest
go install github.com/haccer/subjack@latest

# Make sure your Go bin is on PATH
export PATH="$PATH:$(go env GOPATH)/bin"
```

> **subjack fingerprints:** `subjack` needs its `fingerprints.json`. Find it with
> `find / -name fingerprints.json 2>/dev/null` and point the script at it via the
> `SUBJACK_FINGERPRINTS` environment variable (see below).

## Usage

```bash
./recon.sh example.com
```

Override defaults with environment variables:

```bash
# More threads and a custom wordlist
THREADS=50 WORDLIST=~/wordlists/big.txt ./recon.sh example.com

# Custom subjack fingerprints path
SUBJACK_FINGERPRINTS=~/go/.../fingerprints.json ./recon.sh example.com
```

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `THREADS` | `25` | Concurrency for enumeration tools |
| `WORDLIST` | `/usr/share/wordlists/dirb/common.txt` | Wordlist for `dirsearch` |
| `SUBJACK_FINGERPRINTS` | `$HOME/go/pkg/mod/github.com/haccer/subjack/fingerprints.json` | Path to subjack fingerprints |

## Output

All artifacts are written to a per-target directory, `./<target>/`:

```
example.com/
├── subdomains.txt         # raw enumeration output
├── subdomains             # sorted + de-duplicated
├── alive.txt              # live HTTP/HTTPS hosts
├── jsfiles                # discovered JavaScript URLs
├── takeovers.txt          # subdomain-takeover findings
└── directory_fuzzing.txt  # dirsearch results
```

See [`docs/WALKTHROUGH.md`](docs/WALKTHROUGH.md) for a full, annotated walkthrough with sample output.

## Hardening over a naive script

This implementation improves on a basic linear script with:

- `set -euo pipefail` for fail-fast, safe error handling
- Pre-flight dependency checks with actionable messages
- Domain-format validation on input
- No hardcoded user paths — everything configurable via environment
- Graceful degradation (skips a step with a warning instead of crashing when an optional input is missing)
- TTY-aware colored logging

## Roadmap

- [ ] Add `amass` and `subfinder` as enumeration sources
- [ ] Parallelize `dirsearch` across hosts
- [ ] Optional Slack/Discord notification on completion
- [ ] JSON summary report

## License

[MIT](LICENSE) © Akshit
