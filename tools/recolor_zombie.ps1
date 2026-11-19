# Перекраска кадров пака guy2 в зомби: цвет кожи -> бледно-зелёный,
# одежда -> грязная, волосы -> почти чёрные. Геометрия, размеры и альфа
# не меняются — анимации остаются прежними.
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$SrcDir = Join-Path $PSScriptRoot "..\assets\jampa\norm_guy2"
$OutDir = Join-Path $PSScriptRoot "..\assets\zombie"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function C([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }

# маппинг «было -> стало»
$MAP = @{}
$MAP["228,174,116"] = C 152 182 138   # кожа -> бледно-зелёная
$MAP["81,216,69"]   = C 96 104 74     # ярко-зелёная футболка -> грязно-оливковая
$MAP["223,212,205"] = C 104 100 96    # светлые штаны -> серые
$MAP["50,42,25"]    = C 34 36 30      # волосы/тёмное -> чёрно-зелёное
$MAP["255,221,78"]  = C 168 150 62    # жёлтый -> тусклый
$MAP["189,140,175"] = C 120 108 118   # розовый -> серо-фиолетовый
$MAP["255,255,255"] = C 226 226 214   # белое -> грязноватое

$files = Get-ChildItem $SrcDir -Filter *.png | Where-Object { $Only -eq "" -or $_.BaseName -eq $Only }
foreach ($f in $files) {
  $img = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $out = [System.Drawing.Bitmap]::new($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y = 0; $y -lt $img.Height; $y++) {
    for ($x = 0; $x -lt $img.Width; $x++) {
      $c = $img.GetPixel($x, $y)
      if ($c.A -lt 40) { $out.SetPixel($x, $y, $c); continue }
      $k = "$($c.R),$($c.G),$($c.B)"
      if ($MAP.ContainsKey($k)) {
        $n = $MAP[$k]
        $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, $n.R, $n.G, $n.B))
      } else {
        # прочие пиксели кожи (оттенки) тоже зеленеют: тёплые светлые тона
        if ($c.R -gt 210 -and $c.G -gt 160 -and $c.G -lt 195 -and $c.B -gt 100 -and $c.B -lt 135) {
          $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, 148, 176, 134))
        } else {
          $out.SetPixel($x, $y, $c)
        }
      }
    }
  }
  $dst = Join-Path $OutDir $f.Name
  $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose(); $img.Dispose()
  Write-Output ("ok " + $f.Name)
}
