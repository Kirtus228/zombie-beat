
Add-Type -AssemblyName System.Drawing
$base = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie'
$rows = @(
  @{ name = 'БЫЛО: falling -> jump -> punch2_1 (кадр jump = подскок в ударе)'; frames = @('falling','jump','punch2_1') },
  @{ name = 'СТАЛО: punch2_0 замах -> punch2_1 удар когтями -> falling отход';   frames = @('punch2_0','punch2_1','falling') }
)
$scale = 4
$cx = 130; $cy = 40; $cw = 110; $ch = 150
$cellW = $cw*$scale + 12; $cellH = $ch*$scale + 40
$bmp = [System.Drawing.Bitmap]::new([int]($cellW*3), [int]($cellH*2))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,16,18,24))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$fontS = [System.Drawing.Font]::new('Arial', 12)
$fontT = [System.Drawing.Font]::new('Arial', 15, [System.Drawing.FontStyle]::Bold)
for ($r = 0; $r -lt $rows.Count; $r++) {
  $row = $rows[$r]
  $g.DrawString($row.name, $fontT, [System.Drawing.Brushes]::Yellow, [single]6, [single]($r*$cellH + 4))
  for ($i = 0; $i -lt $row.frames.Count; $i++) {
    $p = Join-Path $base ($row.frames[$i] + '.png')
    $img = [System.Drawing.Bitmap]::FromFile($p)
    $x = $i * $cellW; $y = $r * $cellH + 34
    $g.DrawString($row.frames[$i], $fontS, [System.Drawing.Brushes]::White, [single]($x+4), [single]($y-18))
    $src = [System.Drawing.Rectangle]::new($cx, $cy, $cw, $ch)
    $dst = [System.Drawing.Rectangle]::new([int]$x, [int]$y, [int]($cw*$scale), [int]($ch*$scale))
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
  }
}
$out = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\zombie-attack-before-after.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $out"
