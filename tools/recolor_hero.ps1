# Кадры героя из кадров пака Jampa: майка -> чёрная футболка, жёлтые шорты ->
# тёмно-серые с белой полоской, кепка и борода -> короткие тёмные волосы и чистое лицо.
# Тело и позы — художника пака. Голова перерисовывается в том же стиле.
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$SrcDir = Join-Path $PSScriptRoot "..\assets\jampa\norm_guy1"
$OutDir = Join-Path $PSScriptRoot "..\assets\hero"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function C([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }
$HAIR    = C 58 44 36
$HAIRD   = C 40 30 25
$SHIRT   = C 40 38 46
$SHIRTR  = C 96 94 108
$SHORT   = C 84 80 90
$SKIN    = C 235 205 160
$SKIND   = C 205 168 124
$OUTLINE = C 44 30 22
$WHITE   = C 240 240 236
$CLEAR   = [System.Drawing.Color]::FromArgb(0,0,0,0)
$WIDEN = 1.10
$HXS = 1.02
$HYS = 1.2
$AXIS  = 146.0

function Is-Skin($c) { $c.A -ge 40 -and $c.R -gt 195 -and $c.G -gt 145 -and $c.B -gt 100 -and $c.B -lt 215 }
function Is-Green($c) { $c.A -ge 40 -and $c.G -gt 150 -and $c.R -lt 130 -and $c.B -lt 130 }
function Is-White($c) { $c.A -ge 40 -and $c.R -gt 225 -and $c.G -gt 225 -and $c.B -gt 225 }
function Is-Yellow($c) { $c.A -ge 40 -and $c.R -gt 215 -and $c.G -gt 165 -and $c.B -lt 125 }
function Same($c, $d) { $c.A -eq $d.A -and $c.R -eq $d.R -and $c.G -eq $d.G -and $c.B -eq $d.B }
function Pt($x, $y) { [System.Drawing.PointF]::new([float]$x, [float]$y) }

function Seg($g, $x1, $y1, $x2, $y2, $w, $col, $ink) {
  if ($ink -gt 0) {
    $po = [System.Drawing.Pen]::new($OUTLINE, [float]($w + $ink))
    $po.StartCap = 'Round'; $po.EndCap = 'Round'
    $g.DrawLine($po, [float]$x1, [float]$y1, [float]$x2, [float]$y2); $po.Dispose()
  }
  $pc = [System.Drawing.Pen]::new($col, [float]$w)
  $pc.StartCap = 'Round'; $pc.EndCap = 'Round'
  $g.DrawLine($pc, [float]$x1, [float]$y1, [float]$x2, [float]$y2); $pc.Dispose()
}

function Poly($g, $pts, $col, $ink) {
  $b = [System.Drawing.SolidBrush]::new($col)
  $g.FillPolygon($b, $pts); $b.Dispose()
  if ($ink -gt 0) {
    $p = [System.Drawing.Pen]::new($OUTLINE, [float]$ink); $p.LineJoin = 'Round'
    $g.DrawPolygon($p, $pts); $p.Dispose()
  }
}

function Ell($g, $cx, $cy, $rx, $ry, $col, $ink) {
  $b = [System.Drawing.SolidBrush]::new($col)
  $g.FillEllipse($b, [float]($cx-$rx), [float]($cy-$ry), [float]($rx*2), [float]($ry*2)); $b.Dispose()
  if ($ink -gt 0) {
    $p = [System.Drawing.Pen]::new($OUTLINE, [float]$ink)
    $g.DrawEllipse($p, [float]($cx-$rx), [float]($cy-$ry), [float]($rx*2), [float]($ry*2)); $p.Dispose()
  }
}

# Шея: заливка без рамки, боковые линии тонкие. Композит с маской:
# где под шеей уже есть кожа (рука при ударе), шея НЕ рисуется — рука остаётся впереди.
function Draw-Neck($rim, $cx, $cy, $neckBot, $sx, $sy) {
  $w = $rim.Width; $h = $rim.Height
  $tmp = [System.Drawing.Bitmap]::new($w, $h)
  $tg = [System.Drawing.Graphics]::FromImage($tmp)
  $tg.SmoothingMode = 'AntiAlias'
  $tg.Clear([System.Drawing.Color]::Transparent)
  $neck = [System.Drawing.PointF[]]@(
    (Pt ($cx-6.5*$sx) ($cy+8*$sy)), (Pt ($cx+7*$sx) ($cy+8*$sy)),
    (Pt ($cx+9*$sx) ($neckBot+1)), (Pt ($cx-9*$sx) ($neckBot+1)))
  $b = [System.Drawing.SolidBrush]::new($SKIN); $tg.FillPolygon($b, $neck); $b.Dispose()
  $pen = [System.Drawing.Pen]::new($OUTLINE, 1.3)
  $tg.DrawLine($pen, [float]($cx-6.5*$sx), [float]($cy+8*$sy), [float]($cx-9*$sx), [float]($neckBot+1))
  $tg.DrawLine($pen, [float]($cx+7*$sx), [float]($cy+8*$sy), [float]($cx+9*$sx), [float]($neckBot+1))
  $pen.Dispose(); $tg.Dispose()

  $x0 = [math]::Max(0, [int]($cx-12*$sx)); $x1 = [math]::Min($w-1, [int]($cx+12*$sx))
  $y0 = [math]::Max(0, [int]($cy+4*$sy)); $y1 = [math]::Min($h-1, [int]($neckBot+3))
  $skin = [bool[,]]::new(($x1-$x0+1), ($y1-$y0+1))
  for ($y = $y0; $y -le $y1; $y++) { for ($x = $x0; $x -le $x1; $x++) {
    if (Is-Skin ($rim.GetPixel($x, $y))) { $skin[($x-$x0), ($y-$y0)] = $true } } }

  for ($y = $y0; $y -le $y1; $y++) {
    for ($x = $x0; $x -le $x1; $x++) {
      $c = $tmp.GetPixel($x, $y)
      if ($c.A -lt 40) { continue }
      if ($skin[($x-$x0), ($y-$y0)]) { continue }
      $rim.SetPixel($x, $y, $c)
    }
  }
  $tmp.Dispose()
}

# Голова в стиле пака: плоские заливки, контур как у тела, вид 3/4 вправо.
# Пропорции и посадка — как у головы врага из того же пака: ~29 x 39 px, центр над плечом.
function Draw-Head($g, $cx, $cy, $neckBot) {
  $sx = 1.02
  $sy = 1.2
  # (шея рисуется отдельно, функцией Draw-Neck)
  Ell -g $g -cx ($cx-1*$sx) -cy ($cy-3*$sy) -rx (13.5*$sx) -ry (14.5*$sy) -col $HAIR -ink 2.2
  Ell -g $g -cx ($cx+2.5*$sx) -cy ($cy+2*$sy) -rx (10.6*$sx) -ry (14.2*$sy) -col $SKIN -ink 2.2
  Ell -g $g -cx ($cx-7*$sx) -cy ($cy+4*$sy) -rx (3*$sx) -ry (4*$sy) -col $SKIN -ink 1.6
  $hairPts = [System.Drawing.PointF[]]@(
    (Pt ($cx-13*$sx) ($cy+2*$sy)), (Pt ($cx-11.5*$sx) ($cy-9*$sy)), (Pt ($cx-5*$sx) ($cy-16*$sy)),
    (Pt ($cx+4*$sx) ($cy-16*$sy)), (Pt ($cx+10.5*$sx) ($cy-10*$sy)), (Pt ($cx+12*$sx) ($cy-5*$sy)),
    (Pt ($cx+7.5*$sx) ($cy-6*$sy)), (Pt ($cx+1*$sx) ($cy-3*$sy)), (Pt ($cx-6*$sx) ($cy-1*$sy)))
  Poly -g $g -pts $hairPts -col $HAIR -ink 2.0
  Seg -g $g -x1 ($cx+2.5*$sx) -y1 ($cy-4.5*$sy) -x2 ($cx+9*$sx) -y2 ($cy-4.5*$sy) -w (2.4*$sx) -col $HAIRD -ink 0
  Ell -g $g -cx ($cx+6.2*$sx) -cy ($cy-0.5*$sy) -rx (3.1*$sx) -ry (2.8*$sy) -col $WHITE -ink 1.4
  Ell -g $g -cx ($cx+7.0*$sx) -cy ($cy-0.3*$sy) -rx (1.4*$sx) -ry (1.6*$sy) -col $OUTLINE -ink 0
  $nose = [System.Drawing.PointF[]]@(
    (Pt ($cx+9.5*$sx) ($cy+2*$sy)), (Pt ($cx+14.5*$sx) ($cy+5.5*$sy)), (Pt ($cx+9.5*$sx) ($cy+6.5*$sy)))
  Poly -g $g -pts $nose -col $SKIND -ink 1.4
  Seg -g $g -x1 ($cx+3*$sx) -y1 ($cy+9.5*$sy) -x2 ($cx+8*$sx) -y2 ($cy+9.5*$sy) -w (1.8*$sx) -col $OUTLINE -ink 0
}

function Convert-Frame($path, $outPath) {
  $src = [System.Drawing.Bitmap]::FromFile($path)
  $w = $src.Width; $h = $src.Height

  $capMinX = 9999; $capMaxX = -1; $capMinY = 9999
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if (Is-Green ($src.GetPixel($x, $y))) {
        if ($x -lt $capMinX) { $capMinX = $x }; if ($x -gt $capMaxX) { $capMaxX = $x }
        if ($y -lt $capMinY) { $capMinY = $y }
      }
    }
  }
  if ($capMaxX -lt 0) { "no cap"; return }
  # центр головы = середина макушки (2 верхние строки кепки), козырёк её не сдвигает
  $crownL = 9999; $crownR = -1
  for ($y = $capMinY; $y -le ($capMinY + 2); $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if (Is-Green ($src.GetPixel($x, $y))) { if ($x -lt $crownL) { $crownL = $x }; if ($x -gt $crownR) { $crownR = $x } }
    }
  }
  if ($crownR -lt $crownL) { $crownL = $capMinX; $crownR = $capMinX + 12 }
  $capCx = ($crownL + $crownR) / 2.0

  $dst = [System.Drawing.Bitmap]::new($w, $h)
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $src.GetPixel($x, $y)
      if ($c.A -lt 40) { $dst.SetPixel($x, $y, $CLEAR); continue }
      if (Is-Green $c) { $dst.SetPixel($x, $y, $CLEAR); continue }
      if (Is-White $c) { $dst.SetPixel($x, $y, $SHIRT); continue }
      if (Is-Yellow $c) { $dst.SetPixel($x, $y, $SHORT); continue }
      $dst.SetPixel($x, $y, $c)
    }
  }

  # стереть старую голову целиком (кепка, борода, лицо)
  for ($y = [int]($capMinY - 10); $y -le [int]($capMinY + 46); $y++) {
    for ($x = [int]($capMinX - 18); $x -le [int]($capMaxX + 10); $x++) {
      if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h) { continue }
      $dst.SetPixel($x, $y, $CLEAR)
    }
  }

  # белая полоска по низу шорт
  for ($x = 0; $x -lt $w; $x++) {
    $botY = -1
    for ($y = 0; $y -lt $h; $y++) { if (Same ($dst.GetPixel($x, $y)) $SHORT) { $botY = $y } }
    if ($botY -gt 1) {
      for ($k = 0; $k -lt 2; $k++) {
        if ($dst.GetPixel($x, $botY-$k).A -ge 40) { $dst.SetPixel($x, $botY-$k, $WHITE) }
      }
    }
  }

  # корпус чуть шире в плечах
  $split = [int]($capMinY + 44)
  $out = [System.Drawing.Bitmap]::new($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($out)
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($dst, (New-Object System.Drawing.Rectangle 0,0,$w,$split), (New-Object System.Drawing.Rectangle 0,0,$w,$split), [System.Drawing.GraphicsUnit]::Pixel)
  $g.TranslateTransform([float]$AXIS, 0.0)
  $g.ScaleTransform([float]$WIDEN, 1.0)
  $g.TranslateTransform([float](-$AXIS), 0.0)
  $g.DrawImage($dst, (New-Object System.Drawing.Rectangle 0,$split,$w,($h-$split)), (New-Object System.Drawing.Rectangle 0,$split,$w,($h-$split)), [System.Drawing.GraphicsUnit]::Pixel)
  $g.ResetTransform()
  $g.Dispose()

  # светлая кромка по верху чёрной футболки
  $penRim = [System.Drawing.Pen]::new($SHIRTR, 1.2)
  $rim = [System.Drawing.Bitmap]::new($w, $h)
  $rg = [System.Drawing.Graphics]::FromImage($rim)
  $rg.DrawImageUnscaled($out, 0, 0)
  for ($y = 1; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $rim.GetPixel($x, $y)
      if ($c.A -lt 40) { continue }
      if (-not (Same $c $SHIRT)) { continue }
      if (($rim.GetPixel($x, $y-1)).A -lt 40) { $rg.DrawLine($penRim, [float]$x, [float]$y, [float]$x, [float]$y) }
    }
  }
  $penRim.Dispose()

  # новая голова
  # верх футболки — куда опускаем шею
  $shirtTop = $h
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) { if (Same ($rim.GetPixel($x, $y)) $SHIRT) { if ($y -lt $shirtTop) { $shirtTop = $y } } }
  }
  if ($shirtTop -ge $h) { $shirtTop = $capMinY + 50 }
  # дырка от старой головы: закрыть футболкой по ширине майки в этой строке
  for ($y = $shirtTop; $y -le [int]($capMinY + 46); $y++) {
    $rowL = 9999; $rowR = -1
    for ($x = 0; $x -lt $w; $x++) { if (Same ($rim.GetPixel($x, $y)) $SHIRT) { if ($x -lt $rowL) { $rowL = $x }; if ($x -gt $rowR) { $rowR = $x } } }
    if ($rowR -lt $rowL) { continue }
    for ($x = $rowL; $x -le $rowR; $x++) { if (($rim.GetPixel($x, $y)).A -lt 40) { $rim.SetPixel($x, $y, $SHIRT) } }
  }
  $rg.Dispose()
  # голова садится подбородком прямо на ворот: отдельной шеи нет — одно целое с туловищем
  $cy = $shirtTop - 17.5
  # голова рисуется в отдельный слой и накладывается с маской: где под ней рука (кожа),
  # голова НЕ рисуется — рука проходит перед головой
  $layer = [System.Drawing.Bitmap]::new($w, $h)
  $hg = [System.Drawing.Graphics]::FromImage($layer)
  $hg.SmoothingMode = 'AntiAlias'
  $hg.Clear([System.Drawing.Color]::Transparent)
  Draw-Head -g $hg -cx ($capCx - 8) -cy $cy
  $hg.Dispose()
  $ly0 = [math]::Max(0, [int]($cy - 22)); $ly1 = [math]::Min($h-1, [int]($cy + 24))
  $lx0 = [math]::Max(0, [int]($capCx - 30)); $lx1 = [math]::Min($w-1, [int]($capCx + 22))
  $under = [bool[,]]::new(($lx1-$lx0+1), ($ly1-$ly0+1))
  for ($y = $ly0; $y -le $ly1; $y++) { for ($x = $lx0; $x -le $lx1; $x++) {
    $u = $rim.GetPixel($x, $y)
    if ($u.A -ge 40 -and -not (Is-Skin $u) -and $u.R -gt 235 -and $u.G -gt 210) { $under[($x-$lx0), ($y-$ly0)] = $false }
    elseif (Is-Skin $u) { $under[($x-$lx0), ($y-$ly0)] = $true }
    else { $under[($x-$lx0), ($y-$ly0)] = $false }
  } }
  for ($y = $ly0; $y -le $ly1; $y++) {
    for ($x = $lx0; $x -le $lx1; $x++) {
      $c = $layer.GetPixel($x, $y)
      if ($c.A -lt 40) { continue }
      if ($under[($x-$lx0), ($y-$ly0)]) { continue }
      $rim.SetPixel($x, $y, $c)
    }
  }
  $layer.Dispose()

  $rim.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $rim.Dispose(); $out.Dispose(); $dst.Dispose(); $src.Dispose()
  "wrote $(Split-Path $outPath -Leaf)"
}

$want = @{}
if ($Only -ne "") { foreach ($n in $Only.Split(",")) { $want[$n.Trim()] = $true } }
$names = @("idle","falling","punch1_0","punch1_1","punch2_0","punch2_1","punch2_2","walk_0","walk_3","walk_4","walk_5","walk_6","walk_7","walk_8","jump","jumpkick")
foreach ($n in $names) {
  if ($want.Count -gt 0 -and -not $want.ContainsKey($n)) { continue }
  $src = Join-Path $SrcDir "$n.png"
  if (-not (Test-Path $src)) { "skip $n"; continue }
  Convert-Frame $src (Join-Path $OutDir "$n.png")
}
"done"