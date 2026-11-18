# Делает кадр «лежит на земле» из кадра падения: тело поворачивается вокруг ступней
# и садится на линию земли (низ кадра = 221), иначе лежащий «висит в воздухе».
param(
  [Parameter(Mandatory=$true)][string]$Source,
  [Parameter(Mandatory=$true)][string]$Target,
  [double]$Angle = -78.0
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$bmpIn = [System.Drawing.Bitmap]::FromFile($Source)
$w = $bmpIn.Width; $h = $bmpIn.Height
$GROUND = 221        # линия ступней в кадре пака
$PIVOT_X = 147.0     # ось тела
$PIVOT_Y = 215.0     # примерно ступни

$dst = [System.Drawing.Bitmap]::new($w, $h)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$g.TranslateTransform([float]$PIVOT_X, [float]$PIVOT_Y)
$g.RotateTransform([float]$Angle)
$g.TranslateTransform([float](-$PIVOT_X), [float](-$PIVOT_Y))
$g.DrawImage($bmpIn, 0, 0, $w, $h)
$g.ResetTransform()
$g.Dispose()
$bmpIn.Dispose()

# найти габарит тела: посадить на линию земли и не обрезать голову слева
$minX = 9999; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $h; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    if (($dst.GetPixel($x, $y)).A -ge 40) {
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }; if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
if ($maxX -lt 0) { throw "пустой кадр после поворота" }
$shiftY = $GROUND - $maxY
$shiftX = [int](130 - ($minX + $maxX) / 2)   # центр лежащего тела, чтобы голова не уходила за край
$out = [System.Drawing.Bitmap]::new($w, $h)
$og = [System.Drawing.Graphics]::FromImage($out)
$og.Clear([System.Drawing.Color]::Transparent)
$og.DrawImageUnscaled($dst, $shiftX, $shiftY)
$og.Dispose()
$out.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose(); $dst.Dispose()
"wrote " + $Target + " shiftX=" + $shiftX + " shiftY=" + $shiftY