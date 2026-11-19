# Вариант зомби «с открытым мозгом»: тёмные волосы в верхней части головы
# заменяются на розово-серое вещество с извилинами. Геометрия и альфа не меняются.
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$SrcDir = Join-Path $PSScriptRoot "..\assets\zombie"
$OutDir = Join-Path $PSScriptRoot "..\assets\zombie_brain"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# зона «крышки черепа» в кадре 260x227 — верх головы
$TOP_Y = 44; $BOT_Y = 76; $LEFT_X = 108; $RIGHT_X = 176

function C([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }
$BRAIN  = C 222 158 158
$BRAIN1 = C 198 126 132
$BRAIN2 = C 240 186 178
$INK    = C 96 52 58

$files = Get-ChildItem $SrcDir -Filter *.png | Where-Object { $Only -eq "" -or $_.BaseName -eq $Only }
foreach ($f in $files) {
  $img = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $out = [System.Drawing.Bitmap]::new($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y = 0; $y -lt $img.Height; $y++) {
    for ($x = 0; $x -lt $img.Width; $x++) {
      $c = $img.GetPixel($x, $y)
      $out.SetPixel($x, $y, $c)
    }
  }
  for ($y = $TOP_Y; $y -le $BOT_Y; $y++) {
    for ($x = $LEFT_X; $x -le $RIGHT_X; $x++) {
      if ($x -lt 0 -or $y -lt 0 -or $x -ge $img.Width -or $y -ge $img.Height) { continue }
      $c = $img.GetPixel($x, $y)
      if ($c.A -lt 40) { continue }
      # тёмные пиксели головы (волосы и обводка) -> мозг
      if ($c.R -lt 90 -and $c.G -lt 90 -and $c.B -lt 90) {
        $band = ($x + $y) % 7
        if ($band -lt 2) { $n = $BRAIN1 } elseif ($band -lt 5) { $n = $BRAIN } else { $n = $BRAIN2 }
        $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, $n.R, $n.G, $n.B))
      } elseif ($c.R -gt 120 -and $c.R -lt 200 -and $c.G -gt 160) {
        # зелёная кожа под «крышкой» тоже притемняется краем мозга
        if ($y -lt ($TOP_Y + 10)) { $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, 206, 148, 150)) }
      }
    }
  }
  $dst = Join-Path $OutDir $f.Name
  $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose(); $img.Dispose()
  Write-Output ("ok " + $f.Name)
}
