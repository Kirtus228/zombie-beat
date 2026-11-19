
# Зомби-марионетка: берём МОДЕЛЬКУ пака (тот самый кадр), режем на части и анимируем
# эти части. Ничего не перерисовываем — двигаем существующие пиксели.
# Части: голова, торс, шорты, две руки, две ноги. Вращение вокруг сустава (1 степень
# свободы на часть) — так модель остаётся собой, а позы становятся зомбийными.
param([string]$Mode = "anim")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$srcDir = Join-Path $PSScriptRoot "..\assets\zombie"
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $srcDir "idle.png"))
$W = $src.Width; $H = $src.Height
$OUT = $srcDir

function Cls($c) {
  if ($c.A -lt 40) { return 'none' }
  $r=$c.R; $g=$c.G; $b=$c.B
  if ($r -lt 75 -and $g -lt 75 -and $b -lt 75) { return 'ink' }
  if ($g -gt 160 -and $b -lt 160 -and $b -gt 100 -and $r -lt 180) { return 'skin' }
  if ($r -gt 140 -and $g -gt 120 -and $b -lt 115) { return 'hair' }
  if ($r -gt 210 -and $g -gt 210 -and $b -gt 190) { return 'white' }
  if ([math]::Abs($r-104) -lt 20 -and [math]::Abs($g-100) -lt 20 -and [math]::Abs($b-96) -lt 20) { return 'tank' }
  if ([math]::Abs($r-96) -lt 22 -and [math]::Abs($g-104) -lt 22 -and [math]::Abs($b-74) -lt 22) { return 'short' }
  if ($r -gt 95 -and $b -gt 95 -and $b -ge $g) { return 'shoe' }
  return 'skin'
}

# --- нарезка на части: каждая часть = своя картинка + точка вращения
$parts = @{}
foreach ($name in @('head','torso','shorts','armN','armF','legN','legF')) {
  $parts[$name] = @{ pix = @{}; minx = 9999; maxx = -1; miny = 9999; maxy = -1 }
}
function AddPix($part, $x, $y, $c) {
  $p = $parts[$part]
  $p.pix["$x,$y"] = $c
  if ($x -lt $p.minx) { $p.minx = $x }; if ($x -gt $p.maxx) { $p.maxx = $x }
  if ($y -lt $p.miny) { $p.miny = $y }; if ($y -gt $p.maxy) { $p.maxy = $y }
}
for ($y = 40; $y -lt 226; $y++) {
  for ($x = 90; $x -lt 200; $x++) {
    $c = $src.GetPixel($x, $y)
    if ($c.A -lt 40) { continue }
    $cl = Cls $c
    if ($y -le 83) { AddPix 'head' $x $y $c; continue }
    if ($y -ge 144 -and $y -le 169 -and ($cl -eq 'short' -or $cl -eq 'ink')) { AddPix 'shorts' $x $y $c; continue }
    if ($y -le 147) {
      if ($x -ge 160 -and $y -le 122) { AddPix 'armF' $x $y $c; continue }
      if ($x -le 134 -and $y -ge 86) { AddPix 'armN' $x $y $c; continue }
      AddPix 'torso' $x $y $c
      continue
    }
    if ($y -ge 168) {
      if ($x -le 138) { AddPix 'legF' $x $y $c } else { AddPix 'legN' $x $y $c }
      continue
    }
    AddPix 'torso' $x $y $c
  }
}
# вырезаем каждую часть в отдельный битмап
function MakePart($name) {
  $p = $parts[$name]
  if ($p.maxx -lt 0) { return $null }
  $bw = $p.maxx - $p.minx + 1; $bh = $p.maxy - $p.miny + 1
  $b = [System.Drawing.Bitmap]::new($bw, $bh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  foreach ($k in $p.pix.Keys) {
    $xy = $k.Split(',')
    $b.SetPixel([int]$xy[0] - $p.minx, [int]$xy[1] - $p.miny, $p.pix[$k])
  }
  return @{ bmp = $b; minx = $p.minx; miny = $p.miny; w = $bw; h = $bh }
}
$cut = @{}
foreach ($n in @('head','torso','shorts','armN','armF','legN','legF')) { $cut[$n] = MakePart $n }
foreach ($n in @('head','torso','shorts','armN','armF','legN','legF')) {
  $c = $cut[$n]
  if ($c -eq $null) { "ЧАСТЬ НЕ НАЙДЕНА: $n" } else { "{0,-7} bbox {1},{2} {3}x{4}" -f $n, $c.minx, $c.miny, $c.w, $c.h }
}
# сохраним нарезку для визуальной проверки
if ($Mode -eq "parts") {
  $sheet = [System.Drawing.Bitmap]::new(900, 240)
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.Clear([System.Drawing.Color]::FromArgb(255,16,18,24))
  $x = 8
  foreach ($n in @('head','torso','shorts','armN','armF','legN','legF')) {
    $c = $cut[$n]; if ($c -eq $null) { continue }
    $g.DrawImageUnscaled($c.bmp, $x, 30)
    $g.DrawString($n, (New-Object System.Drawing.Font('Arial', 11)), [System.Drawing.Brushes]::Yellow, [single]$x, [single]6)
    $x += $c.w + 14
  }
  $g.Dispose()
  $p = Join-Path $PSScriptRoot "..\shots\zombie-parts.png"
  $sheet.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $sheet.Dispose()
  "saved $p"
}
"ok"
