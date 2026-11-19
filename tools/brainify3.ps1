# Зомби «с открытым мозгом»: только от макушки до линии глаз (~12 px), извилины волной.
# Позиция головы берётся от верхней точки силуэта в кадре.
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$SrcDir = Join-Path $PSScriptRoot "..\assets\zombie"
$OutDir = Join-Path $PSScriptRoot "..\assets\zombie_brain"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function C([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }
$BRAIN  = C 210 142 148   # тело извилины
$BRAIN1 = C 186 118 128   # полутень
$BRAIN2 = C 240 184 180   # гребень извилины
$GROOVE = C 156 90 104    # борозда
$EDGE   = C 118 60 76     # край среза и контур
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

  # рамка «крышки»: все непрозрачные пиксели выше линии глаз
  $minx = 99999; $maxx = -1; $miny = 99999
  for ($y = 0; $y -lt $brainBottom; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if ($img.GetPixel($x, $y).A -ge 40) {
        if ($x -lt $minx) { $minx = $x }
        if ($x -gt $maxx) { $maxx = $x }
        if ($y -lt $miny) { $miny = $y }
      }
    }
  }
  if ($maxx -lt 0) { $minx = 0; $maxx = $w - 1; $miny = $top }
  $midX = ($minx + $maxx) / 2.0
  $cy = $miny + ($brainBottom - 1 - $miny) / 2.0

  $out = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $img.GetPixel($x, $y)
      if ($c.A -lt 40 -or $y -ge $brainBottom) { $out.SetPixel($x, $y, $c); continue }
      # извилины: вложенные волнообразные контуры вокруг центра головы (вид в профиль)
      $dx = $x - $midX
      $dy = $y - $cy
      # поле из двух перекрещенных волн: изолинии получаются рваными завитками,
      # а не концентрическими кольцами
      $fld = [math]::Sin($x * 0.80 + 1.4 * [math]::Sin($y * 0.55)) * [math]::Cos($y * 1.15 + 1.2 * [math]::Sin($x * 0.42))
      if ((Is-Dark $c) -and $y -gt $miny + 1) { $n = $EDGE }                # тёмный контур головы
      elseif ($y -eq $brainBottom - 1) { $n = $EDGE }                        # тёмный край среза черепа
      elseif ($fld -lt -0.45) { $n = $GROOVE }                               # борозда
      elseif ($fld -gt 0.45) { $n = $BRAIN2 }                                # гребень извилины
      else { $n = $BRAIN }                                                   # тело извилины
      if ($n -eq $BRAIN2 -and $y -ge $brainBottom - 3) { $n = $BRAIN }        # низ ближе к срезу — в тени
      $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, $n.R, $n.G, $n.B))
    }
  }
  $dst = Join-Path $OutDir $f.Name
  $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose(); $img.Dispose()
  Write-Output ("ok " + $f.Name + " top=" + $top + " brainBottom=" + $brainBottom)
}
