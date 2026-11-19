# Зомби «с открытым мозгом»: красное только от макушки до линии глаз (~12 px).
# Позиция головы берётся от верхней точки силуэта в кадре.
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$SrcDir = Join-Path $PSScriptRoot "..\assets\zombie"
$OutDir = Join-Path $PSScriptRoot "..\assets\zombie_brain"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function C([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }
$BRAIN  = C 214 150 150
$BRAIN1 = C 188 118 124
$BRAIN2 = C 236 180 172
$BAND = 13   # высота «крышки черепа» до глаз, px

function Is-Skin($c) { $c.A -ge 40 -and $c.G -gt 140 -and $c.R -gt 110 -and $c.R -lt 190 -and $c.B -gt 100 -and $c.B -lt 170 }
function Is-Dark($c) { $c.A -ge 40 -and $c.R -lt 95 -and $c.G -lt 95 -and $c.B -lt 95 }

$files = Get-ChildItem $SrcDir -Filter *.png | Where-Object { $Only -eq "" -or $_.BaseName -eq $Only }
foreach ($f in $files) {
  $img = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $w = $img.Width; $h = $img.Height

  # центр головы по x: медиана непрозрачных пикселей в верхней половине
  $xs = @()
  for ($y = 0; $y -lt [int]($h * 0.5); $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if ($img.GetPixel($x, $y).A -ge 40) { $xs += $x }
    }
  }
  if ($xs.Count -eq 0) { $xs = @([int]($w / 2)) }
  $xs = $xs | Sort-Object
  $cx = $xs[[int]($xs.Count / 2)]
  # верх головы — только в столбцах вокруг центра (поднятая рука не считается)
  $top = 9999
  for ($y = 0; $y -lt [int]($h * 0.6); $y++) {
    for ($x = [math]::Max(0, $cx - 26); $x -le [math]::Min($w - 1, $cx + 26); $x++) {
      if ($img.GetPixel($x, $y).A -ge 40) { $top = $y; break }
    }
    if ($top -ne 9999) { break }
  }
  if ($top -eq 9999) { $top = 40 }
  $brainBottom = [int]$top + 12

  $out = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $img.GetPixel($x, $y)
      if ($c.A -lt 40 -or $y -ge $brainBottom) { $out.SetPixel($x, $y, $c); continue }
      if ($true) {
        $band = ($x + $y) % 7
        if ($band -lt 2) { $n = $BRAIN1 } elseif ($band -lt 5) { $n = $BRAIN } else { $n = $BRAIN2 }
        $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, $n.R, $n.G, $n.B))
      } else {
        $out.SetPixel($x, $y, $c)
      }
    }
  }
  $dst = Join-Path $OutDir $f.Name
  $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose(); $img.Dispose()
  Write-Output ("ok " + $f.Name + " top=" + $top + " brainBottom=" + $brainBottom)
}
