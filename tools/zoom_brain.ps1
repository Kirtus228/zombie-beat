
Add-Type -AssemblyName System.Drawing
$base = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie_brain'
# кадр, левый x, верхний y, ширина, высота (окно вокруг головы)
$items = @(
  @('idle',118,40,58,48), @('punch1_1',94,46,58,48), @('walk_3',120,45,58,48), @('punch2_1',96,46,58,48)
)
$scale = 10
$cw = 58*$scale+10; $chh = 48*$scale+30
$bmp = [System.Drawing.Bitmap]::new([int]($cw*2), [int]($chh*2))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,16,18,24))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$font = [System.Drawing.Font]::new('Arial', 14)
for ($i=0; $i -lt $items.Count; $i++) {
  $it = $items[$i]
  $p = Join-Path $base ($it[0] + '.png')
  $img = [System.Drawing.Bitmap]::FromFile($p)
  $col = $i % 2; $row = [int][math]::Floor($i/2)
  $x = $col*$cw; $y = $row*$chh
  $g.DrawString($it[0], $font, [System.Drawing.Brushes]::Yellow, [single]($x+6), [single]($y+4))
  $src = [System.Drawing.Rectangle]::new([int]$it[1], [int]$it[2], [int]$it[3], [int]$it[4])
  $dst = [System.Drawing.Rectangle]::new([int]$x, [int]($y+26), [int]($it[3]*$scale), [int]($it[4]*$scale))
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $img.Dispose()
}
$out = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\brain-v4.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $out"
