# Зомби «с открытым мозгом»: красное вещество только ВЫШЕ линии глаз.
# Линия глаз определяется по кадру: тёмные пиксели, окружённые кожей.
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

function Is-Skin($c) { $c.A -ge 40 -and $c.G -gt 140 -and $c.R -gt 110 -and $c.R -lt 190 -and $c.B -gt 100 -and $c.B -lt 170 }
function Is-Dark($c) { $c.A -ge 40 -and $c.R -lt 95 -and $c.G -lt 95 -and $c.B -lt 95 }

$files = Get-ChildItem $SrcDir -Filter *.png | Where-Object { $Only -eq "" -or $_.BaseName -eq $Only }
foreach ($f in $files) {
  $img = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $w = $img.Width; $h = $img.Height

  $eyeTop = 9999
  for ($y = 1; $y -lt [math]::Min($h, 140); $y++) {
    for ($x = 1; $x -lt ($w - 1); $x++) {
      $c = $img.GetPixel($x, $y)
      if (-not (Is-Dark $c)) { continue }
      $skinN = 0
      for ($dy = -1; $dy -le 1; $dy++) {
        for ($dx = -1; $dx -le 1; $dx++) {
          if ($dx -eq 0 -and $dy -eq 0) { continue }
          if (Is-Skin ($img.GetPixel($x + $dx, $y + $dy))) { $skinN++ }
        }
      }
      if ($skinN -ge 4 -and $y -lt $eyeTop) { $eyeTop = $y }
    }
  }
  if ($eyeTop -eq 9999) { $eyeTop = [int]($h * 0.35) }

  $out = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $img.GetPixel($x, $y)
      if ($c.A -lt 40 -or $y -ge $eyeTop) { $out.SetPixel($x, $y, $c); continue }
      if (Is-Skin $c -or (Is-Dark $c)) {
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
  Write-Output ("ok " + $f.Name + " eyeTop=" + $eyeTop)
}
