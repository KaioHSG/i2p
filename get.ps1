param (
    [String]$Install = $null,
    [Switch]$UpdatePath = $false
)

$installDir = "$env:LOCALAPPDATA\b2p"
$baseUrl    = "https://raw.githubusercontent.com/KaioHSG/i2p/refs/heads/main/dist"
$apiUrl     = "https://api.github.com/repos/KaioHSG/i2p/contents/dist"

function Install-B2P {
    Write-Host "`nConfiguring global 'b2p' command..." -ForegroundColor Cyan
    if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
    
    $batContent = "@echo off`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& { `$s = irm 'https://kaiohsg.dev/i2p/get.ps1'; Invoke-Expression `$s }`" %*"
    $batContent | Out-File -FilePath "$binFile\b2p.bat" -Encoding ASCII
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$installDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", "User")
        $env:Path += ";$installDir"
        Write-Host "Success! You can now use the 'b2p' command in any terminal." -ForegroundColor Green
    } else {
        Write-Host "b2p is already in PATH and has been updated." -ForegroundColor Yellow
    }
}

if (-not [string]::IsNullOrWhiteSpace($Install)) {
    Write-Host "`nFetching installer for: $Install..." -ForegroundColor Cyan
    try {
        $appScript = Invoke-RestMethod -Uri "$baseUrl/$Install/get.ps1"
        Invoke-Expression $appScript
    } catch {
        Write-Host "Error: Script '$Install' not found or connection failed." -ForegroundColor Red
    }
} else {
    try {
        $folders = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent"="PowerShell-I2P"}
        $programs = $folders | Where-Object { $_.type -eq "dir" } | Select-Object -ExpandProperty name
        
        $commandExists = Get-Command b2p -ErrorAction SilentlyContinue

        Write-Host "`nBinary-2-Path" -ForegroundColor Magenta
        Write-Host "The command line installer script.`n"
        
        $showInstallOption = (-not $commandExists -or $UpdatePath)

        if ($showInstallOption) {
            Write-Host "[0] > INSTALL 'b2p' COMMAND (Global Access) <" -ForegroundColor Cyan
        }

        for ($i = 0; $i -lt $programs.Count; $i++) {
            "[{0}] {1}" -f ($i + 1), $programs[$i]
        }

        $rangeText = if ($showInstallOption) { "0-$($programs.Count)" } else { "1-$($programs.Count)" }
        $choice = Read-Host "`nChoice ($rangeText)"

        if ($choice -eq "0" -and $showInstallOption) {
            Install-B2P
        } elseif ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $programs.Count) {
            $selected = $programs[$index - 1]
            Write-Host "`nStarting $selected..."
            Invoke-Expression (Invoke-RestMethod -Uri "$baseUrl/$selected/get.ps1")
        } else {
            Write-Host "Exiting..."
        }
    } catch {
        Write-Host "CRITICAL ERROR: Could not list programs via GitHub API." -ForegroundColor Red
    }
}