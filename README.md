# Ultimate Windows Maintenance Toolkit

![Version](https://img.shields.io/badge/Version-v1.0.0-blue.svg)
![Status](https://img.shields.io/badge/Status-Stable-success.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%2011-0078D6.svg)
![Requirements](https://img.shields.io/badge/Requirements-PowerShell%207-5391FE.svg)
![Downloads](https://img.shields.io/badge/Downloads-15K-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

An enterprise-grade, kernel-level refactored maintenance toolkit designed specifically for Windows 11 systems, tailored for modern hardware (like ASUS ROG laptops featuring AMD Ryzen CPUs and NVIDIA RTX GPUs).

[اقرأ باللغة العربية](README-ar.md)

---

## 📋 Table of Contents
- [Description](#description)
- [Features](#features)
- [Screenshots](#screenshots)
- [Version](#version)
- [Changelog](#changelog)
- [Documentation](#documentation)
- [Source Code (GitHub)](#source-code)
- [Download](#download)

---

## 📝 Description
The Ultimate Windows Maintenance Toolkit is a highly modular, safe, and professional utility designed to keep your Windows 11 system running at peak performance. It uses defensive programming, avoids dangerous registry tweaks, and enforces strict state management.

## ✨ Features
- **Health Diagnostics:** Checks OS version, disk health (SMART), memory status, and Event Viewer critical errors.
- **System Cleanup:** Safely cleans Windows/User Temp, DirectX caches, Windows Update caches, and the Recycle Bin. Handles locked files gracefully.
- **System Repair:** Automates `sfc /scannow`, `DISM RestoreHealth`, and Component Store optimization with robust process timeouts.
- **Updates:** Triggers Windows Update natively, upgrades packages via `winget`, and updates PowerShell modules.
- **Drivers:** Safely detects AMD/NVIDIA drivers without forcefully uninstalling them.
- **Security:** Updates Microsoft Defender signatures, runs background scans, and quarantines active threats.
- **G-Helper Integration:** Detects G-Helper status and safely backs up its configuration file.
- **Reporting:** Generates comprehensive run reports in JSON, TXT, and styled HTML formats.

## 📸 Screenshots
*(Coming soon)*

## 🏷️ Version
- **Current Release:** v1.0.0
- **Status:** Stable

## 🔄 Changelog
**v1.0.0 - Initial Release**
- Kernel-Level code refactoring
- Added rigorous `Invoke-SafeOperation` wrapper
- Implemented robust `Remove-LockedItem` for safe I/O operations
- Integrated System Restore Point checkpoints
- Modularized into Helpers, Health, Cleanup, Repair, Update, Security, Drivers, GHelper, and Report modules.

## 📚 Documentation
### Requirements
- **OS:** Windows 11
- **Terminal:** PowerShell 7+
- **Privileges:** Administrator Rights required.

### User Guide
1. Open PowerShell 7 as **Administrator**.
2. Clone or download the repository.
3. Navigate to the toolkit directory.
4. Execute the orchestrator script:
   ```powershell
   .\Start-Maintenance.ps1
   ```

> [!WARNING]
> **DO NOT** open the `.ps1` file and copy-paste its contents directly into the PowerShell window. The script must be executed as a file using the command above so it can locate its configuration and modules!

*(Note: To skip creating a System Restore Point, use the `-SkipRestorePoint` switch).*

## 💻 Source Code
Hosted securely on [GitHub](#). Contributions, pull requests, and forks are welcome!

## 📥 Download
You can download the latest stable release directly from the GitHub Releases page or clone the repository:
```powershell
git clone https://github.com/yourusername/Ultimate-Windows-Maintenance.git
```

---
**License:** MIT License
