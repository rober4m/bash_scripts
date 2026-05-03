# Linux Scripts & Algorithms

A collection of Bash scripts and algorithms for Linux (and macOS) system administration, automation, and diagnostics.

---

## Getting started

All scripts require execute permissions before running. Grant them with:

```bash
chmod +x <script-name>.sh
```

Then run with:

```bash
./<script-name>.sh
```

---

## Scripts

### `sysinfo.sh` — System Information Reporter

Collects and displays a full snapshot of your machine's hardware and environment, directly in the terminal and as a saved Markdown report.

**What it reports:**

| Category | Details |
|---|---|
| **OS** | Name, kernel version, architecture |
| **CPU** | Model, cores, threads, frequency |
| **RAM** | Total, used, free |
| **Disk** | Total capacity, used space, availability |
| **GPU** | Graphics card model |
| **Network** | Hostname, local IP, public IP, DNS |
| **Uptime** | System uptime and load averages |
| **Environment** | User, shell, timezone, language |
| **Tools** | Installed versions of Python, Node, Git, Docker, curl |

**Usage:**

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

**Output:**

- Prints a formatted report to the terminal
- Saves a `sysinfo.md` file in the same directory where the script is run

**Compatibility:** Linux and macOS — the script auto-detects the OS and adjusts commands accordingly.
