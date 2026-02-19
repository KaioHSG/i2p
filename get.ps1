param (
    [String]$Install = $null,
    [Switch]$UpdatePath = $false
)

$installDir = "$env:LOCALAPPDATA\b2p"
$binFile    = "$installDir\b2p.bat"
$baseUrl    = "https://raw.githubusercontent.com/KaioHSG/i2p/refs/heads/main/dist"
$apiUrl     = "https://api.github.com/repos/KaioHSG/i2p/contents/dist"
$ua         = "B2P-Installer/1.0 (KaioHSG; +https://kaiohsg.dev)"

function Install-B2P {
    Write-Host "`nConfiguring global 'b2p' command..." -ForegroundColor Cyan
    if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
    
    $batContent = "@echo off`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& { `$s = irm 'https://kaiohsg.dev/i2p/get.ps1'; Invoke-Expression `$s }`" %*"
    $batContent | Out-File -FilePath $binFile -Encoding ASCII
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$installDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", "User")
        $env:Path += ";$installDir"
        Write-Host "Success! Please RESTART your terminal to use 'b2p' command." -ForegroundColor Green
    }
}


if (-not [string]::IsNullOrWhiteSpace($Install)) {
    try {
        $appScript = Invoke-RestMethod -Uri "$baseUrl/$Install/get.ps1" -UserAgent $ua
        Write-Host "`n--- Loading External Installer: $Install ---`n" -ForegroundColor DarkGray
        Invoke-Expression $appScript
    } catch {
        Write-Host "Error: Script '$Install' not found." -ForegroundColor Red
    }
} else {
    try {
        $folders = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent"=$ua}
        $programs = $folders | Where-Object { $_.type -eq "dir" } | Select-Object -ExpandProperty name
        
        $commandExists = Get-Command b2p -ErrorAction SilentlyContinue
        $showInstallOption = (-not $commandExists -or $UpdatePath)

        Write-Host "`nBinary-2-Path" -ForegroundColor Magenta
        Write-Host "The b2p installer is a simple command line installer script.`n"
        
        if ($showInstallOption) {
            Write-Host "[0] > INSTALL 'b2p' COMMAND (Global Access) <" -ForegroundColor Cyan
        }

        for ($i = 0; $i -lt $programs.Count; $i++) {
            "[{0}] {1}" -f ($i + 1), $programs[$i]
        }

        $rangeText = if ($showInstallOption) { "0-$($programs.Count)" } else { "1-$($programs.Count)" }
        $choice = Read-Host "`nChoice ($rangeText)"

        $index = 0
        if ($choice -eq "0" -and $showInstallOption) {
            Install-B2P
            return 
        } elseif ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $programs.Count) {
            $selected = $programs[$index - 1]
            
            Write-Host "`nLoading External Installer: $selected" -ForegroundColor Cyan
            Write-Host ("." * 50) "`n" -ForegroundColor DarkGray
            
            Invoke-Expression (Invoke-RestMethod -Uri "$baseUrl/$selected/get.ps1" -UserAgent $ua)
        } else {
            Write-Host "Exiting..." -ForegroundColor Gray
        }
    } catch {
        Write-Host "`nCRITICAL ERROR: Operation failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}