$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Join-Path $project '..'))
if (Test-Path (Join-Path $project 'lib')) { throw 'Web source already exists; never overwrite it with Android source.' }
$tracked = @('lib','android','assets','web','prototypes/nwc_player_lab/lib','prototypes/nwc_player_lab/assets','apps-script','config')
$baseline = @{}
foreach ($relative in $tracked) {
  Get-ChildItem -LiteralPath (Join-Path $source $relative) -Recurse -File | ForEach-Object {
    $baseline[$_.FullName.Substring($source.Length + 1)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }
}
foreach ($name in @('pubspec.yaml','pubspec.lock','analysis_options.yaml')) {
  $baseline[$name] = (Get-FileHash -LiteralPath (Join-Path $source $name) -Algorithm SHA256).Hash
}
New-Item -ItemType Directory -Force -Path (Join-Path $project 'verification') | Out-Null
$baseline | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $project 'verification/android-baseline.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $source 'lib') -Destination $project -Recurse
Copy-Item -LiteralPath (Join-Path $source 'assets') -Destination $project -Recurse
Copy-Item -LiteralPath (Join-Path $source 'pubspec.lock') -Destination $project
New-Item -ItemType Directory -Force -Path (Join-Path $project 'packages/nwc_player_lab') | Out-Null
$player = Join-Path $project 'packages/nwc_player_lab'
foreach ($name in @('lib','assets','third_party','pubspec.yaml','l10n.yaml')) {
  Copy-Item -LiteralPath (Join-Path $source "prototypes/nwc_player_lab/$name") -Destination $player -Recurse
}
Write-Output 'Copied isolated web source. No original app files were changed.'
