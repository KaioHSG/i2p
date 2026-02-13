# LLVM-MinGW Installer v1.0.1

$ErrorActionPreference = "Stop"

$llvmMinGwApiUrl = "https://api.github.com/repos/mstorsjo/llvm-mingw"
$version = "1.0.1"
$Host.UI.RawUI.WindowTitle = "LLVM-MinGW Installer v$version"

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
    $installPath = "C:\LLVM-MinGW"
} else {
    $installPath = Join-Path $env:USERPROFILE "LLVM-MinGW"
    Write-Host "* Run as administrator to be able to change the System Variable, or continue with a local user installation. *`n" -ForegroundColor Yellow
}

Write-Host "LLVM-MinGW Installer v$version`n" -ForegroundColor Magenta
Write-Host "=================================================="

$builds = @(
    [PSCustomObject]@{ Name = "32 bits, MSVCRT";    Arch = "i686";      Build = "msvcrt" }
    [PSCustomObject]@{ Name = "32 bits, UCRT";      Arch = "i686";      Build = "ucrt" }
    [PSCustomObject]@{ Name = "64 bits, MSVCRT";    Arch = "x86_64";    Build = "msvcrt" }
    [PSCustomObject]@{ Name = "64 bits, UCRT";      Arch = "x86_64";    Build = "ucrt" }
)

for ($i = 0; $i -lt $builds.Count; $i++) {
    "[{0,2}] {1}" -f ($i + 1), $builds[$i].Name
}

Write-Host "=================================================="

while ($true) {
    $choice = Read-Host "Select a build (1-$($builds.Count))"
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

while ($true) {
    $confirmPath = Read-Host "Install in '$installPath'? (y/n)"
    if ($confirmPath -eq 'y') {
        break
    } elseif ($confirmPath -eq 'n') {
        $installPath = Read-Host "Set install path"
        break
    } else {
        Write-Host "Please enter 'y' or 'n'." -ForegroundColor Yellow
    }
}

Write-Host "--------------------------------------------------"

if ($isRemote) {
    $dataDir = Join-Path $installPath "installer-cache"
} else {
    $dataDir = Join-Path $baseDir "llvm-mingw Installer Data"
}
$latestBuildsDir = Join-Path $dataDir "latest-builds"

if (-not (Test-Path $dataDir)) { New-Item $dataDir -ItemType Directory -Force | Out-Null }

try {
    Write-Host "Checking for latest version on GitHub..."
    $apiRes = Invoke-RestMethod -Uri "$llvmMinGwApiUrl/releases/latest" -Headers @{"User-Agent"="PowerShell-LLVM-MinGW-Installer"} -ErrorAction Stop
    $asset = $apiRes.assets | Where-Object { $_.name -like "*-$buildName-$architecture.zip" } | Select-Object -First 1
    
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

Write-Host "Extracting files..."
if (Test-Path $installPath) {
    Get-ChildItem $installPath | Where-Object { $_.FullName -ne $dataDir } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
} else {
    New-Item $installPath -ItemType Directory -Force | Out-Null
}

Expand-Archive -Path $zipPath -DestinationPath $installPath -Force

$subFolder = Get-ChildItem $installPath -Directory | Where-Object { $_.Name -like "llvm-mingw*" } | Select-Object -First 1
if ($subFolder) {
    Get-ChildItem $subFolder.FullName | Move-Item -Destination $installPath -Force
    Remove-Item $subFolder.FullName -Recurse -Force
}

$binPath = Join-Path $installPath "bin"
$scope = if ($isAdministrator) { "Machine" } else { "User" }

$oldPath = [Environment]::GetEnvironmentVariable("Path", $scope)
$pathClean = ($oldPath -split ';').Trim() | Where-Object { $_ -ne "" }

if ($pathClean -notcontains $binPath) {
    Write-Host "Updating PATH ($scope)..."
    $backupDir = Join-Path $dataDir "env-backup"
    if (-not (Test-Path $backupDir)) { New-Item $backupDir -ItemType Directory -Force | Out-Null }
    $oldPath | Out-File (Join-Path $backupDir "backup_path.txt")
    $newPath = ($pathClean + $binPath) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)
}

Write-Host "--------------------------------------------------"
Write-Host "Install finished successfully." -ForegroundColor Green

$isExplorer = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).ProcessName -eq "explorer"   
if ($isExplorer) {
    Write-Host "Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey()
}

return