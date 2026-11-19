
Add-Type -AssemblyName System.Drawing
$base = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie'
$imgs = @(
  @('idle', (Join-Path $base 'idle.png')),
  @('z_idle', (Join-Path $base 'z_idle.png')),
  @('z_walk_0', (Join-Path $base 'z_walk_0.png'))
)
$scale = 6
$bmp = [System.Drawing.Bitmap]::new([int]($imgs.Count * (100*$scale + 12)), [int](120*$scale + 30))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,24,26,32))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$font = [System.Drawing.Font]::new('Arial', 13)
for ($i = 0; $i -lt $imgs.Count; $i++) {
  $img = [System.Drawing.Bitmap]::FromFile($imgs[$i][1])
  $x = $i * (100*$scale + 12)
  $g.DrawString($imgs[$i][0], $font, [System.Drawing.Brushes]::Yellow, [single]($x+4), [single]4)
  $src = [System.Drawing.Rectangle]::new(110, 40, 100, 120)
  $dst = [System.Drawing.Rectangle]::new([int]$x, [int]26, [int](100*$scale), [int](120*$scale))
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $img.Dispose()
}
$out = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\puppet-vs-pack.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $out"
