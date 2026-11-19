
Add-Type -AssemblyName System.Drawing
$dir = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\caps'
$pick = @(18,22,26,30,34,38,42)
$scale = 1
$cw = 1920; $ch = 953
$cellW = [int]($cw/2); $cellH = [int]($ch/2)
$bmp = [System.Drawing.Bitmap]::new([int]($cellW*3), [int]($cellH*3))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,10,10,14))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for ($i = 0; $i -lt $pick.Count; $i++) {
  $n = $pick[$i]
  $p = Join-Path $dir ("cap_" + $n.ToString('00') + ".png")
  if (-not (Test-Path $p)) { continue }
  $img = [System.Drawing.Bitmap]::FromFile($p)
  $col = $i % 3; $row = [int][math]::Floor($i / 3)
  $src = [System.Drawing.Rectangle]::new(300, 400, 900, 330)
  $dst = [System.Drawing.Rectangle]::new([int]($col*$cellW), [int]($row*$cellH), [int]$cellW, [int]$cellH)
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $img.Dispose()
}
$out = 'D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\ingame-drawn-zombie.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $out"
