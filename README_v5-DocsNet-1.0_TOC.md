# Options Oracle Portfolio Manager v5.0.1 (Stable)

Developer-oriented documentation for the Options Oracle Portfolio Manager project.

---

## Table of Contents
- [Overview](#overview)
  - [Highlights](#highlights)
  - [Versioning](#versioning)
- [Installation](#installation)
  - [Windows](#windows)
  - [PowerShell 7 Setup](#powershell-7-setup)
- [Usage](#usage)
  - [Running the Integration Check](#running-the-integration-check)
  - [Building and Verifying Bundles](#building-and-verifying-bundles)
- [Release Workflow](#release-workflow)
  - [Preparing a Bundle](#preparing-a-bundle)
  - [Verification and Freeze](#verification-and-freeze)
- [Documentation Standards](#documentation-standards)

---

## Overview
Options Oracle Portfolio Manager (OOPM) v5.0.1 provides a structured automation framework for managing options‑trade data, bundles, and documentation.  It is built around PowerShell and Python scripts that coordinate environment configuration, release bundling, and integrity verification.

### Highlights
- Environment‑aware automation scripts (paths auto‑detected)
- Portable PowerShell 7‑based execution
- Integrated checksum verification (`verify_bundle.ps1`)
- Configurable program/data separation for multi‑drive setups
- Developer‑friendly Makefile (`Makefile.win`) for Windows automation

### Versioning
The project follows **semantic versioning** (MAJOR.MINOR.PATCH).  Minor versions (e.g., 5.0.1 → 5.1.0) introduce backward‑compatible improvements; patch versions resolve specific issues.  All release bundles include version metadata and checksum logs.

---

## Installation

### Windows
1. Install **GNU Make**:
   ```powershell
   choco install make
   ```
2. Verify installation:
   ```powershell
   make --version
   ```
3. Install **Python 3.14+** from the Windows Store.
4. Clone or extract the project into:
   ```
   C:\Program Files\Options Oracle Portfolio Manager\
   ```
5. Place data directories under:
   ```
   D:\Documents\Oracle_Portfolio_Manager_v5\
   ```

### PowerShell 7 Setup
1. Install PowerShell 7 (`pwsh`) from Microsoft’s release page.
2. Set execution policy for your user:
   ```powershell
   pwsh -NoProfile -Command 'Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force'
   ```
3. Unblock project scripts:
   ```powershell
   pwsh -NoProfile -Command '
   Get-ChildItem "C:\Program Files\Options Oracle Portfolio Manager" -Recurse -File -Filter *.ps1 | Unblock-File;
   Get-ChildItem "D:\Documents\Oracle_Portfolio_Manager_v5" -Recurse -File -Filter *.ps1 | Unblock-File'
   ```
4. Verify `pwsh` is on PATH:
   ```powershell
   where pwsh
   ```

---

## Usage

### Running the Integration Check
Confirm environment alignment before any bundle build:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File D:\Documents\Oracle_Portfolio_Manager_v5\automation\integration_check.ps1
```
A **PASS** result indicates that all required components and paths are in place.

### Building and Verifying Bundles
To build and verify a full release bundle:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Options Oracle Portfolio Manager\automation\release_bundle.ps1" \
  -Version "v5.0.1" -Date (Get-Date -Format "yyyy-MM-dd")
```
This performs three steps:
1. Refresh documentation timestamps (`docs_refresh.py`)
2. Build the ZIP bundle (`make_v5_bundle.ps1`)
3. Verify integrity via SHA‑256 checksums (`verify_bundle.ps1`)

---

## Release Workflow

### Preparing a Bundle
1. Ensure `integration_check.ps1` passes.
2. Update README and CHANGELOG as needed.
3. Run `release_bundle.ps1` manually or via `make -f Makefile.win release-bundle-now`.

### Verification and Freeze
- Output bundle: `D:\Documents\Oracle_Portfolio_Manager_v5\Options_Oracle_Portfolio_Manager_v5.0.1_Stable_<date>.zip`
- Verify with:
  ```powershell
  pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Options Oracle Portfolio Manager\verify_bundle.ps1" \
    -BundleRoot "D:\Documents\Oracle_Portfolio_Manager_v5\Options_Oracle_Portfolio_Manager_v5.0.1_Stable"
  ```
- Once verified, move the bundle to `D:\Documents\Oracle_Portfolio_Manager_v5\bundles` and tag the release in Git if version control is used.

---

## Documentation Standards
- **Headers:** plain Markdown (`#`, `##`, `###`) only—no emoji.
- **Dates:** `YYYY-MM-DD` format throughout.
- **CLI flags:** shown exactly as typed (`--flag`, `-f`).
- **Cross‑references:** link to [`CHANGELOG.md`](./CHANGELOG.md) and [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md).
- **Encoding:** UTF‑8 without BOM.

---

> "Consistency is the silent ally of automation." — Project Oracle DocsNet Team (2025‑10‑26)

