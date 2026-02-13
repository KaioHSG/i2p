# MinGW-w64 Installer v1.0.5

$ErrorActionPreference = "Stop"

$minGwW64BuildsApiUrl = "https://api.github.com/repos/niXman/mingw-builds-binaries"
$7zrDownloadExeUrl = "https://www.7-zip.org/a/7zr.exe"

$version = "1.0.5"
$Host.UI.RawUI.WindowTitle = "MinGW-w64 Installer v$version"

$scriptPath = $MyInvocation.MyCommand.Definition
if ($scriptPath -and (Test-Path $scriptPath)) {
    $baseDir = Split-Path -Parent $scriptPath
    $isRemote = $false
} else {
    $baseDir = $null
    $isRemote = $true
}

$isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(0x220)

if ($isAdministrator) {
    $installPath = "C:\MinGW-w64"
} else {
    $installPath = Join-Path $env:USERPROFILE "MinGW-w64"
    Write-Host "* Run as administrator to be able to change the System Variable, or continue with a local user installation. *`n" -ForegroundColor Yellow
}

# User Selection
Write-Host "MinGW-w64 Installer v$version`n" -ForegroundColor Magenta
Write-Host "=================================================="

$builds = @(
    [PSCustomObject]@{ Name = "32 bits, Minimal C Runtime, DWARF, UCRT";    Arch = "i686";      Build = "mcf-dwarf-ucrt" }
    [PSCustomObject]@{ Name = "32 bits, POSIX, DWARF, MSVCRT";              Arch = "i686";      Build = "posix-dwarf-msvcrt" }
    [PSCustomObject]@{ Name = "32 bits, POSIX, DWARF, UCRT";                Arch = "i686";      Build = "posix-dwarf-ucrt" }
    [PSCustomObject]@{ Name = "32 bits, Win32, DWARF, MSVCRT";              Arch = "i686";      Build = "win32-dwarf-msvcrt" }
    [PSCustomObject]@{ Name = "32 bits, Win32, DWARF, UCRT";                Arch = "i686";      Build = "win32-dwarf-ucrt" }
    [PSCustomObject]@{ Name = "64 bits, Minimal C Runtime, SEH, UCRT";      Arch = "x86_64";    Build = "mcf-seh-ucrt" }
    [PSCustomObject]@{ Name = "64 bits, POSIX, SEH, MSVCRT";                Arch = "x86_64";    Build = "posix-seh-msvcrt" }
    [PSCustomObject]@{ Name = "64 bits, POSIX, SEH, UCRT";                  Arch = "x86_64";    Build = "posix-seh-ucrt" }
    [PSCustomObject]@{ Name = "64 bits, Win32, SEH, MSVCRT";                Arch = "x86_64";    Build = "win32-seh-msvcrt" }
    [PSCustomObject]@{ Name = "64 bits, Win32, SEH, UCRT";                  Arch = "x86_64";    Build = "win32-seh-ucrt" }
)

for ($i = 0; $i -lt $builds.Count; $i++) {
    "[{0,2}] {1}" -f ($i + 1), $builds[$i].Name
}

Write-Host "=================================================="

while ($true) {
    $choice = Read-Host "Select a LLVM-MinGW build (1-$($builds.Count))"
    $index = 0
    if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $builds.Count) {
        $selected = $builds[$index - 1]
        $architecture = $selected.Arch
        $buildName = $selected.Build
        break
    } else {
        Write-Host "Invalid selection. '$choice' is not a valid option." -ForegroundColor Yellow
    }
}

# Path Setup
while ($true) {
    $confirmPath = Read-Host "Install MinGW-w64 in '$installPath'? (y/n)"
    
    if ($confirmPath -eq 'y') {
        break
    } 
    elseif ($confirmPath -eq 'n') {
        $installPath = Read-Host "Set install path"
        break
    } 
    else {
        Write-Host "Please enter 'y' for Yes or 'n' for No." -ForegroundColor Yellow
    }
}

# Define pastas de dados baseado no modo de execução
if ($isRemote) {
    $dataDir = Join-Path $installPath "installer-cache"
} else {
    $dataDir = Join-Path $baseDir "mingw-w64 Installer Data"
}
$binTools = Join-Path $dataDir "bin-tools"
$latestBuildsDir = Join-Path $dataDir "latest-builds"

Write-Host "--------------------------------------------------"

# Tool Check (7zr.exe)
$7zr = Join-Path $binTools "7zr.exe"
if (-not (Test-Path $7zr)) {
    Write-Host "7zr.exe not found. Downloading..."
    if (-not (Test-Path $binTools)) { New-Item $binTools -ItemType Directory -Force | Out-Null }
    
    try {
        Invoke-WebRequest -Uri "$7zrDownloadExeUrl" -OutFile $7zr -ErrorAction Stop
    } catch {
        Write-Host "--------------------------------------------------"
        Write-Host "Failed to download 7zr.exe. Check your internet connection." -ForegroundColor Red
        
        $isExplorer = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).ProcessName -eq "explorer"   
        if ($isExplorer) {
            Write-Host "Press any key to exit."
            $null = $Host.UI.RawUI.ReadKey()
        }

        return
    }
}

# Metadata Discovery
if (-not (Test-Path $dataDir)) { New-Item $dataDir -ItemType Directory | Out-Null }

try {
    Write-Host "Checking for latest version on GitHub..."
    $apiRes = Invoke-RestMethod -Uri "$minGwW64BuildsApiUrl/releases/latest" -Headers @{"User-Agent"="PowerShell-MinGW-W64-Installer"} -ErrorAction Stop
    $asset = $apiRes.assets | Where-Object { $_.name -like "$architecture-*$buildName*.7z" } | Select-Object -First 1
    
    if (-not $asset) {
        Write-Host "--------------------------------------------------"
        Write-Host "Build variant not found on GitHub." -ForegroundColor Red
        
        $isExplorer = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).ProcessName -eq "explorer"   
        if ($isExplorer) {
            Write-Host "Press any key to exit."
            $null = $Host.UI.RawUI.ReadKey()
        }
        
        return
    }
    
    $fileName = $asset.name
    $downloadUrl = $asset.browser_download_url

} catch {
    Write-Host "Connection failed or Build not found. Checking local cache..."
    $localFile = Get-ChildItem "$latestBuildsDir" -Filter "$architecture-*-release-$buildName-*.7z" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($localFile) { 
        $fileName = $localFile.Name 
        Write-Host "Using cached file: $fileName"
    } else {
        Write-Host "--------------------------------------------------"
        Write-Host "Could not find build online or locally." -ForegroundColor Red
        
        $isExplorer = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).ProcessName -eq "explorer"   
        if ($isExplorer) {
            Write-Host "Press any key to exit."
            $null = $Host.UI.RawUI.ReadKey()
        }
        
        return
    }
}

$zipPath = Join-Path $latestBuildsDir $fileName
if (-not (Test-Path $zipPath)) {
    Write-Host "Downloading $fileName..."
    if (-not (Test-Path $latestBuildsDir)) { New-Item $latestBuildsDir -ItemType Directory -Force | Out-Null }
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
}

# Extraction
Write-Host "Extracting files...`n"
if (Test-Path $installPath) {
    Get-ChildItem $installPath | Where-Object { $_.FullName -ne $dataDir } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
} else {
    New-Item $installPath -ItemType Directory -Force | Out-Null
}

& "$7zr" x "$latestBuildsDir\$fileName" "-o$installPath" -y

# Path Configuration
$archFolder = if ($architecture -eq "i686") { "mingw32" } else { "mingw64" }
$finalDestination = Join-Path $installPath $archFolder
$binPath = Join-Path $finalDestination "bin"
$scope = if ($isAdministrator) { "Machine" } else { "User" }

$oldPath = [Environment]::GetEnvironmentVariable("Path", $scope)
$pathClean = ($oldPath -split ';').Trim() | Where-Object { $_ -ne "" }

if ($pathClean -notcontains $binPath) {
    Write-Host "Updating PATH ($scope)..."
    $backupDir = Join-Path $dataDir "env-backup"
    if (-not (Test-Path $backupDir)) { New-Item $backupDir -ItemType Directory -Force | Out-Null }
    
    $oldPath | Out-File (Join-Path $backupDir "backup_path.txt") -NoEncoding
    
    $newPath = ($pathClean + $binPath) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)
}

# Save Metadata
$upgradeData = @($finalDestination, $architecture, $release, $buildName, $runtime, $revision)
$upgradeData | Out-File (Join-Path $installPath "mingw-w64-upgrade-data") -Encoding ASCII

Write-Host "--------------------------------------------------"
Write-Host "Install finished successfully." -ForegroundColor Green

$isExplorer = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).ProcessName -eq "explorer"   
if ($isExplorer) {
    Write-Host "Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey()
}

return