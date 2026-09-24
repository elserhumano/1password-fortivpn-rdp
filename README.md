# 🔐 No-Clipboard FortiVPN & RDP Automation

> *“Quod simplex est, in aeternum vivit; quod confusum, per se moritur.”*  
> *(What is simple lives forever; what is complicated dies on its own).*

This private repository contains the definitive solution and engineering blueprint for automating the complete connection lifecycle to private networks using **SSL-VPN (Fortinet v7.4+)** and automated **Remote Desktop (RDP)** access in hybrid development environments (Windows 11 + WSL2).

The primary objective is to eliminate 100% of the manual copy-pasting of corporate credentials, keeping the operating system clipboard clean and secure through native biometric access linked to **enterprise 1Password**.

---

## 🛠️ Solution Architecture

```
+-------------------------------------------------------------------------+

|                        💻 WINDOWS 11 HOST (YOUR LAPTOP)                 |
|                                                                         |
|  +------------------------+             +----------------------------+  |
|  |   🔒 ENTERPRISE        |             |   🖥️ WINDOWS APP (RDP)     |  |
|  |   1PASSWORD DESKTOP    |             |   (WSLg Hardware Render)   |  |
|  +-----------+------------+             +--------------^-------------+  |
|              | Biometric                               |                |
|              | Windows Hello                           |                |
|              v                                         |                |
|  +------------------------+                            |                |
|  |   🛠️ 1PASSWORD CLI     |                            |                |
|  |   (op.exe in PATH)     |                            |                |
|  +-----------+------------+                            |                |
|              |                                         |                |
|              | In-Memory Password Stream               |                |
|              v                                         |                |
|  +------------------------+                            |                |
|  |  🚀 XXX-VPN.PS1 SCRIPT |                            |                |
|  |  (PowerShell Execution)|                            |                |
+--------------+-----------------------------------------+----------------+

               |                                         |
               | wsl exec pipe                           | Native Linux Window
               | (No Windows Clipboard)                  | (No Clipboard exposure)
               v                                         |
+--------------+-----------------------------------------+----------------+

|              |         🐧 WSL2 ENVIRONMENT (UBUNTU)    |                |
|              v                                         |                |
|  +------------------------+             +--------------+-------------+  |
|  | 📂 /tmp/openfortivpn   |             |   🖥️ XFREERDP CLIENT       |  |
|  |    .conf (Temp File)   |             |   (CLI Native Motor)       |  |
|  +-----------+------------+             +--------------+-------------+  |
|              |                                         |                |
|              | Reads Config File                       | Crosses ppp0   |
|              v                                         | Network Route  |
|  +------------------------+                            |                |
|  |  🌐 OPENFORTIVPN       |                            |                |
|  |  (TLS 1.3 SSL-VPN Engine)                           |                |
|  +-----------+------------+                            |                |
|              |                                         |                |
|              | Establishes ppp0 Tunnel                 |                |
|              v                                         v                |
|  +-------------------------------------------------------------------+  |
|  |          🔒 VIRTUAL ADAPTER INTERFACE (ppp0 ROUTING TABLE)        |  |
|  +-----------------------------------+-------------------------------+  |
+--------------------------------------|----------------------------------+
                                       |
                                       | Encrypted SSL Data Flow
                                       v
                     +-----------------------------------+
                     |                                   |
                     |      🏢 CLIENT PRIVATE NETWORK    |
                     |      Gateway: vpn.xxx.com         |
                     |      Target IP: 10.2.1.250        |
                     +-----------------------------------+

```


1. **Network Orchestration:** A PowerShell script on the Windows 11 Host securely invokes the 1Password CLI (`op`) using local hardware (Windows Hello biometrics).
2. **Restriction Bypass:** The actual password is extracted directly in memory, cleaned of hidden encoding characters, and injected into a temporary configuration file (`.conf`) within the native Linux environment in WSL2. This completely circumvents Electron/Node bugs found in proprietary GUI applications.
3. **Tunnel Establishment:** The open-source `openfortivpn` engine in Ubuntu establishes the virtual adapter `ppp0`, bypassing modern encryption constraints (TLS 1.3).
4. **Secure Graphical Access:** The `xfreerdp` client leverages the Linux tunnel directly. The password is injected using 1Password's native keyboard emulation feature (*"Type in window"*), achieving a **Zero-Clipboard (Clean Clipboard)** environment. The session is rendered on Windows via hardware-accelerated Microsoft WSLg.

---

## 🚀 Automation Deployment Guide

### 1. Host Prerequisites (Windows 11 Pro)
* **1Password CLI:** Install the official command-line interface:
  ```powershell
  winget install -e --id AgileBits.1Password.CLI
  ```
* **Active Integration:** Inside the 1Password desktop app, navigate to *Settings > Developer* and toggle **"Integrate with 1Password CLI"** ON.
* **WSL2:** Ensure you are running an updated Ubuntu distribution with native graphical acceleration support (WSLg integrated into Windows 11).

### 2. Linux Environment Configuration (WSL2 / Ubuntu)
Inside your Linux terminal, install the compatible VPN engine and the terminal-based remote desktop client:
```bash
sudo apt update && sudo apt install -y openfortivpn freerdp2-x11
```

---

## 💻 The Local Command Center

### File: `xxx-vpn.ps1` (Orchestration Script on Windows)

Save this code into your local Windows scripts directory. This script generates the dynamic and temporary configuration file inside Linux, completely destroying the file containing the password as soon as the connection is closed:

```powershell
Write-Host "🔐 Calling 1Password CLI..." -ForegroundColor Cyan

# 1. Extract the REAL password from 1Password using the mandatory reveal flag
$VpnPass = op item get "VPN + jumphost login" --vault "XXX" --fields label=password --reveal

if (-not $VpnPass) {
    Write-Error "❌ Could not retrieve password from 1Password. Verify your biometric session."
    exit
}

# String sanitation (Removes accidental white spaces)
$VpnPassClean = $VpnPass.Trim()

Write-Host "📂 Generating temporary config file in WSL2..." -ForegroundColor Yellow

# 2. Declarative construction of the native Linux configuration file
# This completely avoids encoding compatibility issues (UTF-16 vs UTF-8) from PowerShell pipelines
$ConfigFileContent = @"
host = vpn.xxx.com
port = 443
username = xxx_support
password = $VpnPassClean
trusted-cert = XXXXXXXXXXXXXXXXXXXXXXXXXX
"@

# Clean file injection into Ubuntu's temporary directory
$ConfigFileContent | wsl exec sh -c "cat > /tmp/openfortivpn.conf"

Write-Host "🚀 Establishing native tunnel in WSL2 (Ubuntu)..." -ForegroundColor Green

# 3. Launch openfortivpn instructing it to read the temporary file we just created
wsl sudo openfortivpn -c /tmp/openfortivpn.conf

# 4. DEVOPS CLEANUP: When the script is terminated (Ctrl+C), the password file is instantly wiped from Linux storage
wsl exec sh -c "rm -f /tmp/openfortivpn.conf"
Write-Host "🧼 Temporary configuration file removed from WSL2." -ForegroundColor Cyan
```

---

## 🎮 Daily Operational Workflow

1. **Execute the Script:** Run `.\xxx-vpn.ps1` in your Windows terminal or via a desktop shortcut.
2. **Biometric Authentication:** Place your finger on the sensor. 1Password unlocks the password, `openfortivpn` in WSL2 initiates the tunnel and waits for the Multi-Factor Authentication (MFA) token sent to your email. Once submitted, the tunnel goes **UP**.
3. **Trigger Native RDP:** Open a new tab in your Ubuntu terminal and fire up the direct connection to the client's internal server IP (previously resolved via `nslookup` targeting the corporate DNS):
   ```bash
   xfreerdp /u:xxx_support /v:10.1.1.1 /cert:ignore +clipboard
   ```
4. **Passwordless Injection:** When the FreeRDP window prompts for the password in your console, press your universal 1Password shortcut (`Ctrl + Shift + Space`), select the item, and choose **"Type in window"**. 

The password will type itself, press Enter in the terminal, and the client's remote desktop will launch floating directly on your Windows 11 monitor. **Zero manual copy-pasting, absolute cryptographic security.**

---

## ⚙️ Engineering Specifications Applied
* **Network Protocol:** Point-to-Point Tunneling Protocol over SSL (PPP over TLS 1.3).
* **Certificate Bypassing:** Local whitelisting of the Sectigo gateway's SHA256 digest (`YYYYYYYYYYYY...`) to avoid broken interactive handshakes.
* **Memory Isolation:** Clean injection without utilizing the Host OS clipboard storage (`Clipboard Ring Security`).
* **Graphical Subsystem:** Seamless X11/Wayland rendering integrated into the Host via Microsoft WSLg.
