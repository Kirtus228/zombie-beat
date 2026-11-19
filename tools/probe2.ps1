
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile('D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie\idle.png')
$w = $img.Width; $h = $img.Height
# какие цвета где — чтобы нарезать модель на части
function Cls($c) {
  if ($c.A -lt 40) { return 'none' }
  $r=$c.R; $g=$c.G; $b=$c.B
  if ($r -lt 70 -and $g -lt 70 -and $b -lt 70) { return 'ink' }
  if ($g -gt 165 -and $r -gt 120 -and $r -lt 175 -and $b -lt 155 -and $b -gt 105) { return 'skin' }
  if ($r -gt 140 -and $g -gt 120 -and $b -lt 110) { return 'hair' }
  if ($r -gt 215 -and $g -gt 215) { return 'white' }
  if ([math]::Abs($r-104) -lt 14 -and [math]::Abs($g-100) -lt 14 -and [math]::Abs($b-96) -lt 14) { return 'tank' }
  if ([math]::Abs($r-96) -lt 16 -and [math]::Abs($g-104) -lt 16 -and [math]::Abs($b-74) -lt 16) { return 'short' }
  if ($r -gt 100 -and $b -gt 100 -and [math]::Abs($r-$b) -lt 20) { return 'shoe' }
  return 'other'
}
# границы частей по строкам (найдены probe_pack.ps1)
$rows = @{}
for ($y=40; $y -lt 226; $y++) {
  $first = -1; $last = -1
  for ($x=90; $x -lt 200; $x++) { if ($img.GetPixel($x,$y).A -ge 40) { if ($first -lt 0) { $first = $x }; $last = $x } }
  if ($first -ge 0) { $rows[$y] = @($first, $last) }
}
"строки: " + (($rows.Keys | Sort-Object) | Select-Object -First 3) + " ... " + (($rows.Keys | Sort-Object) | Select-Object -Last 3)
foreach ($y in @(46,60,80,84,90,100,120,140,146,150,160,170,180,200,214,220)) {
  if ($rows.ContainsKey($y)) { "{0,3}: x {1}..{2}" -f $y, $rows[$y][0], $rows[$y][1] }
}
