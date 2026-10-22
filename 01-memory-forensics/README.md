# Lab 1: Memory Forensics — Malware Artifact Hunt

**Status:** Complete (2 of 3 flags recovered; see Findings)

## Objective

Analyze a memory image (MemLabs Lab 1 — a simulated "crashed computer" scenario) using
Volatility to recover evidence of attacker activity: a malicious command, a hidden file,
and a password-protected artifact, without access to the live system.

## Scenario

A 1 GB Windows 7 memory dump (`MemoryDump_Lab1.raw`) representing a family member's crashed
computer. The challenge is built around 3 hidden flags that require process analysis, command
history recovery, file carving, credential recovery, and (attempted) memory-resident image
extraction.

## Tools

- [Volatility 3](https://github.com/volatilityfoundation/volatility3) — used for initial
  triage (`windows.info`, `pslist`, `cmdline`, `filescan`)
- [Volatility 2.6](https://github.com/volatilityfoundation/volatility/wiki) (standalone) —
  used for `consoles`, `hashdump`, and `memdump`, since Volatility 3 does not support
  `cmdscan`/`consoles` on this Windows 7 build
- [GIMP](https://www.gimp.org/) — used to attempt to render a process memory dump as a raw
  bitmap image
- Memory sample: [MemLabs Lab 1](https://github.com/stuxnet999/MemLabs)

## Process

1. **Identify the system and running processes**
   ```
   vol.exe -f MemoryDump_Lab1.raw windows.info
   vol.exe -f MemoryDump_Lab1.raw windows.pslist
   vol.exe -f MemoryDump_Lab1.raw windows.cmdline
   ```
   Confirmed the image as Windows 7 SP1 x64 and identified a Paint process (`mspaint.exe`,
   PID 2424) and other running processes worth investigating.

2. **Recover command history (Flag 1)**
   Volatility 3 does not support `cmdscan`/`consoles` against this profile, so switched to
   Volatility 2.6:
   ```
   volatility_2.6_win64_standalone.exe -f MemoryDump_Lab1.raw --profile=Win7SP1x64 consoles
   ```
   This surfaced a Base64-encoded string in the console history. Decoded it (CyberChef /
   PowerShell) to recover **Flag 1**.

3. **Locate and carve a hidden file**
   ```
   vol.exe -f MemoryDump_Lab1.raw windows.filescan | findstr /i important
   vol.exe -f MemoryDump_Lab1.raw windows.dumpfiles --physaddr <offset> --dump-dir out
   ```
   Used `filescan` to locate the physical offset of `Important.rar` in memory, then
   `dumpfiles --physaddr` to carve it out to disk. (Note: `--physaddr` is required, not
   `--virtaddr` — the latter does not resolve correctly for this plugin.)

4. **Recover account password hashes (Flag 3)**
   ```
   set PYTHONIOENCODING=utf-8
   volatility_2.6_win64_standalone.exe -f MemoryDump_Lab1.raw --profile=Win7SP1x64 hashdump
   ```
   Dumped the SAM hashes for all local accounts. The Administrator and Guest accounts had
   the hash for an empty password; the account relevant to the scenario (`Alissa Simpson`)
   had a distinct NT hash. Used that NT hash as the password to open `Important.rar`,
   which contained a password-protected `flag3.png`. Opening it recovered **Flag 3**.

5. **Attempt to carve a process's memory as an image (Flag 2 — unresolved)**
   Dumped the Paint process's private memory:
   ```
   volatility_2.6_win64_standalone.exe -f MemoryDump_Lab1.raw --profile=Win7SP1x64 memdump -p 2424 -D dumps
   ```
   Renamed the resulting `.dmp` to `.data` and attempted to load it in GIMP as raw RGBA
   image data, scanning the ~266 MB file in large offset increments (file size ÷ 4 to
   account for GIMP 3's pixel-based, not byte-based, offset field — a detail that cost
   significant time before being caught). Identified several distinct regions in the dump:
   a small (~32px) repeating icon/cursor bitmap, and a large flat white region consistent
   with a blank canvas, but was not able to align the width/offset precisely enough to
   render the drawn content before pausing the search.

## Findings

- **Flag 1:** Recovered from Base64-encoded data in Volatility 2 `consoles` output.
- **Flag 3:** Recovered by cracking a local account's NT hash via `hashdump` and using it
  as the decryption password for a RAR archive carved from memory, which contained the
  final flag image.
- **Flag 2:** Not recovered. The target data (the Paint canvas, drawn in `mspaint.exe`'s
  process memory) was not successfully isolated at the correct width/offset during manual
  raw-image reconstruction in GIMP. Next attempt should try a more systematic approach:
  scanning the raw dump for BMP file-header signatures (`42 4D` / `"BM"`) with a hex
  editor or `findstr`/`grep -a`, rather than manually guessing width/offset pairs.

## What this demonstrates

This mirrors memory and volatile forensics work from malware triage: pulling command
history, carving files, and cracking credentials out of a volatile memory image without
access to the live system or disk. It also reflects a real investigative constraint —
not every artifact is recoverable on the first pass, and documenting a partial result
(including the dead ends) is itself part of a forensic record.
