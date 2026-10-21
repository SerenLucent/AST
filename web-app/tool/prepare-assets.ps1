param([string]$GameSourceRoot = '')
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Join-Path $project '..'))
$gameSource = if ($GameSourceRoot) { [IO.Path]::GetFullPath($GameSourceRoot) } else { $source }
$icons = Join-Path $project 'web/icons'
New-Item -ItemType Directory -Force -Path $icons | Out-Null
Add-Type -AssemblyName System.Drawing
$original = [Drawing.Image]::FromFile((Join-Path $project 'assets/images/app_icon.png'))
try {
  foreach ($size in @(180,192,512)) {
    $bitmap = New-Object Drawing.Bitmap($size,$size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.Clear([Drawing.Color]::White)
      $graphics.DrawImage($original,0,0,$size,$size)
      $name = if ($size -eq 180) {'apple-touch-icon.png'} else {"Icon-$size.png"}
      $bitmap.Save((Join-Path $icons $name),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
  }
} finally { $original.Dispose() }
foreach ($game in @('ast-home','timing-shooter')) {
  $target = Join-Path $project "web/games/$game"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  $html = [IO.File]::ReadAllText((Join-Path $gameSource "docs/games/$game/index.html"))
  # Only clone the HTML entry point; immutable game modules/images remain on
  # their existing public host. The injected bridge is local to THIS web app.
  $insert = '<head><base href="https://serenlucent.github.io/AST/games/' + $game + '/"><script>' +
    [IO.File]::ReadAllText((Join-Path $project 'web/game-bridge.js')) + '</script>'
  $html = $html.Replace('<head>', $insert)
  [IO.File]::WriteAllText((Join-Path $target 'index.html'),$html,[Text.UTF8Encoding]::new($false))
}
Write-Output 'Prepared brand icons and separate browser-game entry points.'
