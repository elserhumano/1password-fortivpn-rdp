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
