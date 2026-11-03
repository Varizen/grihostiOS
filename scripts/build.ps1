# Build the static deploy bundle for Cloudflare Pages.
# Only public assets are copied; assets/brand/ is an internal reference set.

$ErrorActionPreference = "Stop"

$src  = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $src "dist"

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory $dist | Out-Null

foreach ($f in @("_headers", "_redirects")) {
    $p = Join-Path $src $f
    if (Test-Path $p) { Copy-Item $p -Destination $dist }
}

# all root-level HTML pages
Get-ChildItem $src -File -Filter *.html | Copy-Item -Destination $dist

# subfolder page bundles (e.g. rfq/)
Get-ChildItem $src -Directory |
    Where-Object { $_.Name -notin @('assets', 'dist', 'brandcenter', 'scripts', '.git', '.github', '.wrangler') } |
    Where-Object { Get-ChildItem $_.FullName -File -Filter *.html -ErrorAction SilentlyContinue } |
    ForEach-Object {
        $target = Join-Path $dist $_.Name
        New-Item -ItemType Directory $target -Force | Out-Null
        Get-ChildItem $_.FullName -File | Copy-Item -Destination $target
    }

New-Item -ItemType Directory (Join-Path $dist "assets") | Out-Null
Get-ChildItem (Join-Path $src "assets") -File | Copy-Item -Destination (Join-Path $dist "assets")

Write-Host "Built $dist"
Get-ChildItem $dist -Recurse -File |
    Select-Object @{n = 'rel'; e = { $_.FullName.Replace("$dist\", "") } }, Length |
    Format-Table -AutoSize
