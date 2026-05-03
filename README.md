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

**Usage:**

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

**Output:**

- Prints a formatted report to the terminal
- Saves a `sysinfo.md` file in the same directory where the script is run

**Compatibility:** Linux and macOS — the script auto-detects the OS and adjusts commands accordingly.
