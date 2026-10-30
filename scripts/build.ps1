# Build the static deploy bundle for Cloudflare Pages.
# Only public assets are copied; assets/brand/ is an internal reference set.

$ErrorActionPreference = "Stop"

$src  = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $src "dist"

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory $dist | Out-Null

foreach ($f in @("index.html", "404.html", "_headers", "_redirects")) {
    $p = Join-Path $src $f
    if (Test-Path $p) { Copy-Item $p -Destination $dist }
}

New-Item -ItemType Directory (Join-Path $dist "assets") | Out-Null
Get-ChildItem (Join-Path $src "assets") -File | Copy-Item -Destination (Join-Path $dist "assets")

Write-Host "Built $dist"
Get-ChildItem $dist -Recurse -File |
    Select-Object @{n = 'rel'; e = { $_.FullName.Replace("$dist\", "") } }, Length |
    Format-Table -AutoSize
