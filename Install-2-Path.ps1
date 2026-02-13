# ==============================================================================
# DEVELOPER SETTINGS (Configure your application here)
# ==============================================================================
# [REQUIRED] The display name of your application. Used for UI and Window Title.
$AppName          = "APP_NAME"

# [REQUIRED] Current version string. Used for UI and Window Title.
$AppVersion       = "1.0.0"

# [REQUIRED] The name of the folder where the app will be installed (inside C:\ or UserProfile).
$DefaultDirName   = "MyTool"

# [REQUIRED] Direct download link for your software package (.zip, .rar, or .7z).
$AppDownloadUrl   = "http://to.your.package/here.xyz"

# [OPTIONAL] External tool for extraction. 
# - Leave empty "" to use Windows native 'Expand-Archive' (Only works for .zip).
# - Use "https://www.rarlab.com/rar/unrarw64.exe" for RAR
# - Use "https://www.7-zip.org/a/7zr.exe" for 7z
$ExternalToolUrl  = "" 

# [OPTIONAL] Relative path to the executable folder inside the installation directory.
$RelativeBinPath  = "" 
# ==============================================================================

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "$AppName Installer v$AppVersion"

function Exit-WithPause {
    $isExplorer = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).ProcessName -eq "explorer"
    if ($isExplorer) {
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey()
    }
    exit
}

$isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(0x220)

if ($isAdministrator) {
    $installPath = "C:\$DefaultDirName"
} else {
    $installPath = Join-Path $env:USERPROFILE "$DefaultDirName"
    Write-Host "`n* Run as administrator to be able to change the System Variable, or continue with a local user installation. *" -ForegroundColor Yellow
}

Write-Host "`n$AppName Installer v$AppVersion" -ForegroundColor Magenta
Write-Host "--------------------------------------------------"

Write-Host "Default path: $installPath" -ForegroundColor Gray
$userPath = Read-Host "Enter custom path (or press Enter for default)"

if ($userPath -and $userPath.Trim() -ne "") {
    $installPath = $userPath.Trim()
    Write-Host "Destination set to: $installPath" -ForegroundColor Cyan
}

$scriptPath = if ($MyInvocation.MyCommand.Definition -and (Test-Path $MyInvocation.MyCommand.Definition)) { $MyInvocation.MyCommand.Definition } else { $null }
$baseDir = if ($scriptPath) { Split-Path -Parent $scriptPath } else { $null }

$dataDir = if ($null -eq $baseDir) { Join-Path $installPath "installer-cache" } else { Join-Path $baseDir "$DefaultDirName Installer Data" }
$binTools = Join-Path $dataDir "bin-tools"
$latestBuildsDir = Join-Path $dataDir "latest-builds"
$backupDir = Join-Path $dataDir "env-backup"

foreach ($path in @($binTools, $latestBuildsDir, $backupDir)) {
    if (-not (Test-Path $path)) { New-Item $path -ItemType Directory -Force | Out-Null }
}

$toolExe = $null
if ($ExternalToolUrl -ne "") {
    $toolFileName = Split-Path $ExternalToolUrl -Leaf
    if ($toolFileName -eq "unrarw64.exe") { $toolFileName = "unrar.exe" }
    $toolExe = Join-Path $binTools $toolFileName

    if (-not (Test-Path $toolExe)) {
        Write-Host "External tool required. Downloading: $toolFileName..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri "$ExternalToolUrl" -OutFile $toolExe -ErrorAction Stop
        } catch {
            Write-Host "--------------------------------------------------"
            Write-Host "CRITICAL ERROR: Failed to download extraction tool.`n" -ForegroundColor Red
            Exit-WithPause
        }
    }
}

$fileName = Split-Path $AppDownloadUrl -Leaf
$zipPath = Join-Path $latestBuildsDir $fileName

if (-not (Test-Path $zipPath)) {
    Write-Host "Downloading package: $fileName..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $AppDownloadUrl -OutFile $zipPath -ErrorAction Stop
    } catch {
        Write-Host "--------------------------------------------------"
        Write-Host "CRITICAL ERROR: Failed to download package.`n" -ForegroundColor Red
        Exit-WithPause
    }
}

Write-Host "Preparing destination..." -ForegroundColor Cyan
if (Test-Path $installPath) {
    Get-ChildItem $installPath | Where-Object { $_.FullName -ne $dataDir } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
} else {
    New-Item $installPath -ItemType Directory -Force | Out-Null
}

Write-Host "Extracting files..." -ForegroundColor Cyan
try {
    if ($toolExe -and $toolExe -like "*unrar.exe") {
        & "$toolExe" x "$zipPath" *.* "$installPath\" -y
    }
    elseif ($toolExe -and $toolExe -like "*7zr.exe") {
        & "$toolExe" x "$zipPath" "-o$installPath" -y
    }
    else {
        Expand-Archive -Path "$zipPath" -DestinationPath "$installPath" -Force
    }
} catch {
    Write-Host "--------------------------------------------------"
    Write-Host "CRITICAL ERROR: Extraction failed.`n" -ForegroundColor Red
    Exit-WithPause
}

$finalBinPath = if ($RelativeBinPath) { Join-Path $installPath $RelativeBinPath } else { $installPath }
$scope = if ($isAdministrator) { "Machine" } else { "User" }

try {
    $oldPath = [Environment]::GetEnvironmentVariable("Path", $scope)
    $pathClean = ($oldPath -split ';').Trim() | Where-Object { $_ -ne "" }

    if ($pathClean -notcontains $finalBinPath) {
        Write-Host "Backing up and updating PATH ($scope)..." -ForegroundColor Cyan
        
        $timestamp = Get-Date -Format "yyMMdd_HHmmss"
        $backupFile = Join-Path $backupDir "$($timestamp)-backup_path.txt"
        $oldPath | Out-File $backupFile -NoEncoding
        
        $newPath = ($pathClean + $finalBinPath) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)
    }
} catch {
    Write-Host "WARNING: Could not update PATH. Check registry permissions." -ForegroundColor Yellow
}

Write-Host "--------------------------------------------------"
Write-Host "Installation finished successfully!`n" -ForegroundColor Green

Exit-WithPause
