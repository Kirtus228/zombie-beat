
Add-Type -AssemblyName System.Drawing
$base = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie'
$rows = @(
  @{ name = 'BYLO: falling -> jump -> punch2_1 (kadr jump = podskok v udare)'; frames = @('falling','jump','punch2_1') },
  @{ name = 'STALO: punch2_0 zamah -> punch2_1 udar kogtyami -> falling othod';   frames = @('punch2_0','punch2_1','falling') }
)
$scale = 4
$cw = 120; $ch = 150
$cellW = $cw*$scale + 14; $cellH = $ch*$scale + 44
$bmp = [System.Drawing.Bitmap]::new([int]($cellW*3), [int]($cellH*2))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,16,18,24))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$fontS = [System.Drawing.Font]::new('Arial', 13)
$fontT = [System.Drawing.Font]::new('Arial', 15, [System.Drawing.FontStyle]::Bold)
for ($r = 0; $r -lt $rows.Count; $r++) {
  $row = $rows[$r]
  $g.DrawString($row.name, $fontT, [System.Drawing.Brushes]::Yellow, [single]6, [single]($r*$cellH + 5))
  for ($i = 0; $i -lt $row.frames.Count; $i++) {
    $img = [System.Drawing.Bitmap]::FromFile((Join-Path $base ($row.frames[$i] + '.png')))
    $minx=9999;$maxx=-1;$maxy=-1
    for ($y=0; $y -lt $img.Height; $y++) { for ($x=0; $x -lt $img.Width; $x++) {
      if ($img.GetPixel($x,$y).A -ge 40) { if($x -lt $minx){$minx=$x}; if($x -gt $maxx){$maxx=$x}; if($y -gt $maxy){$maxy=$y} }
    } }
    $cxT = [int](($minx + $maxx) / 2) - [int]($cw/2)
    $cyT = $maxy - $ch + 8
    if ($cyT -lt 0) { $cyT = 0 }
    if ($cxT -lt 0) { $cxT = 0 }
    $x = $i * $cellW; $y = $r * $cellH + 36
    $g.DrawString($row.frames[$i], $fontS, [System.Drawing.Brushes]::White, [single]($x+4), [single]($y-19))
    $src = [System.Drawing.Rectangle]::new($cxT, $cyT, $cw, $ch)
    $dst = [System.Drawing.Rectangle]::new([int]$x, [int]$y, [int]($cw*$scale), [int]($ch*$scale))
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
  }
}
$out = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\zombie-attack-before-after.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $out"
