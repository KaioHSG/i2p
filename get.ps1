# KaioHSG.Dev Script Registry

$BaseUrl = "https://raw.githubusercontent.com/KaioHSG/i2p/refs/heads/main/dist"
$ApiUrl  = "https://api.github.com/repos/KaioHSG/i2p/contents/dist"

Write-Host "`n--- KaioHSG.Dev Script Registry ---" -ForegroundColor Magenta

try {
    # Busca a lista de pastas dentro de /dist via API do GitHub
    $folders = Invoke-RestMethod -Uri $ApiUrl -Headers @{"User-Agent"="PowerShell-I2P"}
    $programs = $folders | Where-Object { $_.type -eq "dir" } | Select-Object -ExpandProperty name

    if ($null -eq $programs) { throw "No programs found in /dist" }

    Write-Host "Select a program to install:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $programs.Count; $i++) {
        "  [{0}] {1}" -f ($i + 1), $programs[$i]
    }

    $choice = Read-Host "`nChoice (1-$($programs.Count))"
    $index = 0
    if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $programs.Count) {
        $selectedApp = $programs[$index - 1]
        $appUrl = "$BaseUrl/$selectedApp/get.ps1"
        
        Write-Host "`nFetching installer for: $selectedApp..." -ForegroundColor Gray
        Write-Host "URL: $appUrl" -ForegroundColor Gray
        
        $appScript = Invoke-RestMethod -Uri $appUrl
        Invoke-Expression $appScript
    } else {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Yellow
    }

} catch {
    Write-Host "CRITICAL ERROR: Could not list programs from GitHub API." -ForegroundColor Red
    Write-Host "Check if /dist exists or GitHub API rate limits." -ForegroundColor Yellow
}