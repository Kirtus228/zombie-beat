
Add-Type -AssemblyName System.Drawing
$base = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie'
$rows = @(
  @{ name = 'WALK z_walk_0..5'; frames = @('z_walk_0','z_walk_1','z_walk_2','z_walk_3','z_walk_4','z_walk_5') },
  @{ name = 'ATTACK z_atk_0..4'; frames = @('z_atk_0','z_atk_1','z_atk_2','z_atk_3','z_atk_4') },
  @{ name = 'PACK: idle / walk_3 / punch2_1 (для сравнения)'; frames = @('idle','walk_3','punch2_1') }
)
$scale = 3
$cw = 170; $ch = 200
$cellW = $cw*$scale + 10; $cellH = $ch*$scale + 34
$maxF = 6
$bmp = [System.Drawing.Bitmap]::new([int]($cellW*$maxF), [int]($cellH*3))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,16,18,24))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$fontS = [System.Drawing.Font]::new('Arial', 11)
$fontT = [System.Drawing.Font]::new('Arial', 14, [System.Drawing.FontStyle]::Bold)
for ($r = 0; $r -lt $rows.Count; $r++) {
  $row = $rows[$r]
  $g.DrawString($row.name, $fontT, [System.Drawing.Brushes]::Yellow, [single]6, [single]($r*$cellH + 4))
  for ($i = 0; $i -lt $row.frames.Count; $i++) {
    $img = [System.Drawing.Bitmap]::FromFile((Join-Path $base ($row.frames[$i] + '.png')))
    $x = $i * $cellW; $y = $r * $cellH + 30
    $g.DrawString($row.frames[$i], $fontS, [System.Drawing.Brushes]::White, [single]($x+4), [single]($y-16))
    $src = [System.Drawing.Rectangle]::new(45, 20, $cw, $ch)
    $dst = [System.Drawing.Rectangle]::new([int]$x, [int]$y, [int]($cw*$scale), [int]($ch*$scale))
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
  }
}
$out = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\zombie-drawn-frames.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $out"
