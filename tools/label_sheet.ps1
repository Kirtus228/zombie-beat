
Add-Type -AssemblyName System.Drawing
$src = "D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\rig-variants.png"
$out = "D:\OneDrive\Desktop\Mobidick\games\zombie-beat\shots\rig-variants-labelled.png"
$img = [System.Drawing.Image]::FromFile($src)
$left = 330
$top = 54
$bmp = New-Object System.Drawing.Bitmap(($img.Width + $left), ($img.Height + $top))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(26,26,34))
$g.DrawImage($img, $left, $top)
$f = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$f2 = New-Object System.Drawing.Font("Segoe UI", 17)
$br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,230,235))
$brDim = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150,150,160))
$rowH = [int]($img.Height / 3)
$l1 = @("A", "B", "C")
$l2 = @("tonkaya, kontur 1 px", "srednyaya, kontur 2 px", "tolstaya, kontur 2 px")
$nr = [string][char]0x0410
for ($i = 0; $i -lt 3; $i++) {
  $g.DrawString($l1[$i], $f, $br, 16, $top + $i * $rowH + 80)
  $g.DrawString($l2[$i], $f2, $brDim, 16, $top + $i * $rowH + 118)
}
$cols = @("stoyka paka", "zamah", "udar", "kasanie")
$tileW = ($img.Width) / 4
for ($c = 0; $c -lt 4; $c++) { $g.DrawString($cols[$c], $f2, $brDim, $left + $c * $tileW + 30, 14) }
$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); $img.Dispose()
"ok"
