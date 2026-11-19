# Зомби: своя рисовка походки и ударов (20.11.2026, v2).
# Заказчик: «походка как у людей», «удары непонятные». Рисуем параметрически:
# скелет (таз, колени, ступни, плечи, локти, кисти) + палитра пака + контур 34,36,30.
# Кадры 260x227, ступни на y=221 (как у кадров пака, иначе персонаж «висит»).
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$dir = Join-Path $PSScriptRoot "..\assets\zombie"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

function Col([int]$r,[int]$g,[int]$b){ return [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }
$P_SKIN  = Col 152 182 138
$P_SKIND = Col 122 150 110
$P_TANK  = Col 104 100  96
$P_SHORT = Col  96 104  74
$P_HAIR  = Col 168 150  62
$P_SHOE  = Col 120 108 118
$P_TEETH = Col 232 232 214
$P_MOUTH = Col  42  34  36
$P_EYE   = Col 226 226 214
$P_INK   = Col  34  36  30

function Pnt([double]$x,[double]$y) { return [System.Drawing.PointF]::new([float]$x,[float]$y) }

function Seg($gr, [double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$w, $col) {
  $pts = [System.Drawing.PointF[]]@((Pnt $x1 $y1), (Pnt $x2 $y2))
  $rr = [double[]]@(($w/2.0), ($w/2.0))
  Limb $gr $pts $rr $col
}

# Конечность целиком: одна полилиния с радиусами в суставах, ОДИН контур.
# Иначе на каждом сегменте свой контур и колени выглядят кольцами брони.
function Limb($gr, [System.Drawing.PointF[]]$pts, [double[]]$rr, $col) {
  $n = $pts.Count
  # 1) контур: каждая кость рисуется линией с круглыми концами, толщина = диаметр + 2*обводка
  for ($i = 0; $i -lt $n-1; $i++) {
    $d = ($rr[$i] + $rr[$i+1])
    $po = [System.Drawing.Pen]::new($P_INK, [float]($d + 5.2)); $po.StartCap='Round'; $po.EndCap='Round'
    $gr.DrawLine($po, $pts[$i].X, $pts[$i].Y, $pts[$i+1].X, $pts[$i+1].Y); $po.Dispose()
  }
  # 2) заливка: те же линии тоньше, поверх контура — стыки сливаются, колец нет
  for ($i = 0; $i -lt $n-1; $i++) {
    $d = ($rr[$i] + $rr[$i+1])
    $pc = [System.Drawing.Pen]::new($col, [float]$d); $pc.StartCap='Round'; $pc.EndCap='Round'
    $gr.DrawLine($pc, $pts[$i].X, $pts[$i].Y, $pts[$i+1].X, $pts[$i+1].Y); $pc.Dispose()
  }
  $sb = [System.Drawing.SolidBrush]::new($col)
  for ($i = 0; $i -lt $n; $i++) {
    $gr.FillEllipse($sb, [float]($pts[$i].X-$rr[$i]), [float]($pts[$i].Y-$rr[$i]), [float]($rr[$i]*2), [float]($rr[$i]*2))
  }
  $sb.Dispose()
}

function FillPoly($gr, [System.Drawing.PointF[]]$poly, $col, [double]$lw) {
  $b = [System.Drawing.SolidBrush]::new($col); $gr.FillPolygon($b, $poly); $b.Dispose()
  if ($lw -gt 0) {
    $p = [System.Drawing.Pen]::new($P_INK, [float]$lw); $p.LineJoin='Round'
    $gr.DrawPolygon($p, $poly); $p.Dispose()
  }
}

function FillEll($gr, [double]$cx, [double]$cy, [double]$rx, [double]$ry, $col, [double]$lw) {
  $b = [System.Drawing.SolidBrush]::new($col)
  $gr.FillEllipse($b, [float]($cx-$rx), [float]($cy-$ry), [float]($rx*2), [float]($ry*2)); $b.Dispose()
  if ($lw -gt 0) {
    $p = [System.Drawing.Pen]::new($P_INK, [float]$lw)
    $gr.DrawEllipse($p, [float]($cx-$rx), [float]($cy-$ry), [float]($rx*2), [float]($ry*2)); $p.Dispose()
  }
}

# Кисть-коготь: ладонь + 4 растопыренных пальца, угол в радианах
function Claw($gr, [double]$wx, [double]$wy, [double]$ang, [double]$spread, [double]$sc) {
  FillEll $gr $wx $wy (5.0*$sc) (4.4*$sc) $P_SKIN 2.0
  for ($i = 0; $i -lt 4; $i++) {
    $a = $ang + ($i - 1.5) * $spread
    $l = (8.0 + 2.0 * [math]::Abs($i - 1.5)) * $sc
    Seg $gr $wx $wy ($wx + [math]::Cos($a)*$l) ($wy + [math]::Sin($a)*$l) (1.9*$sc) $P_SKIN
  }
}

function Shoe($gr, [double]$ax, [double]$ay, [double]$dir) {
  $sp = [System.Drawing.PointF[]]@(
    (Pnt ($ax - 8*$dir) ($ay - 7)), (Pnt ($ax + 10*$dir) ($ay - 6)),
    (Pnt ($ax + 12*$dir) ($ay + 3)), (Pnt ($ax - 9*$dir) ($ay + 4)))
  FillPoly $gr $sp $P_SHOE 2.2
}

# Нога: бедро (в шортах) + голень + ступня
function DrawLeg($gr, [double]$hx, [double]$hy, [double]$kx, [double]$ky, [double]$ax, [double]$ay, [double]$shortsT, $skinCol) {
  $legPts = [System.Drawing.PointF[]]@((Pnt $hx $hy), (Pnt $kx $ky), (Pnt $ax $ay))
  $legRr = [double[]]@(8.0, 5.5, 4.0)
  Limb $gr $legPts $legRr $skinCol
  $mx = $hx + ($kx - $hx) * $shortsT
  $my = $hy + ($ky - $hy) * $shortsT
  $shPts = [System.Drawing.PointF[]]@((Pnt $hx $hy), (Pnt $mx $my))
  $shRr = [double[]]@(11.0, 9.0)
  Limb $gr $shPts $shRr $P_SHORT
  Shoe $gr $ax $ay 1.0
}

# Рука: плечо-локоть-кисть + коготь
function DrawArm($gr, [double]$sx, [double]$sy, [double]$ex, [double]$ey, [double]$wx, [double]$wy, [double]$ang, [double]$grip, $skinCol) {
  $armPts = [System.Drawing.PointF[]]@((Pnt $sx $sy), (Pnt $ex $ey), (Pnt $wx $wy))
  $armRr = [double[]]@(6.5, 5.0, 3.8)
  Limb $gr $armPts $armRr $skinCol
  Claw $gr $wx $wy $ang 0.46 $grip
}

# Голова: зелёное лицо, жёлтая «шапка» волос (по ней brainify4 находит макушку),
# раскрытая пасть с зубами. $tilt в градусах, $jaw 0..1 — насколько открыт рот.
function DrawHead($gr, [double]$hx, [double]$hy, [double]$tilt, [double]$jaw) {
  $gr.TranslateTransform([float]$hx, [float]$hy)
  $gr.RotateTransform([float]$tilt)
  # череп + челюсть
  FillEll $gr 0 1 14.0 15.0 $P_SKIN 2.6
  FillEll $gr 2.0 11.0 9.5 5.0 $P_SKIN 2.4
  # волосы куполом (по ним brainify4 находит макушку)
  FillEll $gr -1.0 -11.5 13.0 6.0 $P_HAIR 2.2
  # глазницы: тёмная впадина + белок
  FillEll $gr 5.0 -2.0 3.4 3.0 $P_SKIND 0
  FillEll $gr 5.0 -2.2 2.4 2.1 $P_EYE 1.2
  FillEll $gr 6.0 -2.0 1.1 1.2 $P_INK 0
  FillEll $gr -2.0 -2.6 3.0 2.8 $P_SKIND 0
  FillEll $gr -1.6 -2.8 2.1 1.9 $P_EYE 1.2
  FillEll $gr -0.8 -2.6 1.0 1.1 $P_INK 0
  # пасть: тёмный клин, сверху зубы
  $h = 3.0 + 5.0 * $jaw
  $mp = [System.Drawing.PointF[]]@(
    (Pnt 0.0 ($h*0.60)), (Pnt 9.5 ($h*0.45)), (Pnt 8.8 ($h*1.05)), (Pnt 0.5 ($h*1.15)))
  FillPoly $gr $mp $P_MOUTH 1.7
  $tb = [System.Drawing.SolidBrush]::new($P_TEETH)
  for ($i = 0; $i -lt 3; $i++) {
    $gr.FillRectangle($tb, [float](1.0 + $i*2.9), [float]($h*0.52), [float]2.0, [float]2.4)
  }
  $tb.Dispose()
  # нос
  $np = [System.Drawing.PointF[]]@((Pnt 11.0 -1.5),(Pnt 16.0 1.6),(Pnt 11.0 2.4))
  FillPoly $gr $np $P_SKIND 1.4
  $gr.ResetTransform()
}

# Тело: таз -> плечи (майка), шея
function DrawTorso($gr, [double]$hx, [double]$hy, [double]$nx, [double]$ny) {
  $tp = [System.Drawing.PointF[]]@(
    (Pnt ($nx - 18) ($ny + 2)), (Pnt ($nx + 18) ($ny + 2)),
    (Pnt ($hx + 14) ($hy + 2)), (Pnt ($hx - 14) ($hy + 2)))
  FillPoly $gr $tp $P_TANK 2.6
  # пояс шорт — один блок на тазу, штанины дорисовываются по бедру
  $sp = [System.Drawing.PointF[]]@(
    (Pnt ($hx - 16) ($hy - 4)), (Pnt ($hx + 16) ($hy - 4)),
    (Pnt ($hx + 17) ($hy + 12)), (Pnt ($hx - 17) ($hy + 12)))
  FillPoly $gr $sp $P_SHORT 2.4
  $neckPts = [System.Drawing.PointF[]]@((Pnt $nx ($ny + 3)), (Pnt $nx ($ny - 10)))
  $neckRr = [double[]]@(7.5, 6.5)
  Limb $gr $neckPts $neckRr $P_SKIN
}

# Сборка одного кадра по скелету
function Render($name, $sk) {
  $bmp = [System.Drawing.Bitmap]::new(260, 227, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gr = [System.Drawing.Graphics]::FromImage($bmp)
  $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $gr.Clear([System.Drawing.Color]::Transparent)

  # дальняя сторона — темнее, потом торс, потом ближняя
  DrawLeg $gr $sk.hipFx $sk.hipFy $sk.kneeFx $sk.kneeFy $sk.ankFx $sk.ankFy 0.55 $P_SKIND
  DrawArm $gr $sk.shFx $sk.shFy $sk.elbFx $sk.elbFy $sk.wrFx $sk.wrFy $sk.wrFAng 0.95 $P_SKIND
  DrawTorso $gr $sk.hipX $sk.hipY $sk.neckX $sk.neckY
  DrawLeg $gr $sk.hipNx $sk.hipNy $sk.kneeNx $sk.kneeNy $sk.ankNx $sk.ankNy 0.55 $P_SKIN
  DrawArm $gr $sk.shNx $sk.shNy $sk.elbNx $sk.elbNy $sk.wrNx $sk.wrNy $sk.wrNAng 1.05 $P_SKIN
  DrawHead $gr $sk.headX $sk.headY $sk.headTilt $sk.jaw

  $gr.Dispose()
  $path = Join-Path $dir ($name + ".png")
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "wrote $name"
}

# ---------------------------------------------------------------- ПОХОДКА (6 кадров)
# Шарканье: корпус наклонён, голова висит низко и качается, руки впереди почти не
# машут, одна нога волочится (ступня не отрывается), шаги неравные.
function WalkPose([int]$i) {
  $ph = 2.0 * [math]::PI * $i / 6.0
  $lead = [math]::Sin($ph)
  $drag = [math]::Sin($ph + 2.6)
  $bob = -1.0 * [math]::Abs([math]::Cos($ph)) * 3.5
  $lean = 17.0 + 5.0 * [math]::Sin($ph * 2.0)

  $hipX = 145.0; $hipY = 152.0 + $bob
  $nx = $hipX + 46.0 * [math]::Tan($lean * [math]::PI / 180.0)
  $ny = $hipY - 58.0
  $headX = $nx + 5.0 + [math]::Sin($ph) * 2.5; $headY = $ny - 26.0 + [math]::Abs([math]::Cos($ph)) * 3.0

  $leadStep = 24.0 * $lead
  $dragStep = 12.0 * $drag
  $leadLift = [math]::Max(0.0, $lead) * 12.0
  $dragLift = [math]::Max(0.0, $drag) * 2.0

  $sk = @{}
  $sk.hipX = $hipX; $sk.hipY = $hipY; $sk.neckX = $nx; $sk.neckY = $ny
  $sk.headX = $headX; $sk.headY = $headY; $sk.headTilt = $lean * 0.45; $sk.jaw = 0.55
  # ближняя нога (правая) — ведущая, дальняя волочится
  $sk.hipNx = $hipX + 6; $sk.hipNy = $hipY + 4
  $sk.kneeNx = $hipX + 6 + $leadStep * 0.6; $sk.kneeNy = 188 - $leadLift * 0.5
  $sk.ankNx = $hipX + 6 + $leadStep; $sk.ankNy = 212 - $leadLift
  $sk.hipFx = $hipX - 7; $sk.hipFy = $hipY + 4
  $sk.kneeFx = $hipX - 7 + $dragStep * 0.45; $sk.kneeFy = 190 - $dragLift * 0.4
  $sk.ankFx = $hipX - 7 + $dragStep; $sk.ankFy = 214 - $dragLift
  # руки висят впереди: локоть у корпуса, кисть ниже и чуть вперёд
  $sw = 4.0 * $lead
  $sk.shNx = $nx + 15; $sk.shNy = $ny + 8
  $sk.elbNx = $nx + 21 + $sw; $sk.elbNy = $ny + 28
  $sk.wrNx = $nx + 26 + $sw * 1.5; $sk.wrNy = $ny + 44
  $sk.wrNAng = [math]::PI * 0.44
  $sk.shFx = $nx - 13; $sk.shFy = $ny + 9
  $sk.elbFx = $nx - 15 + $sw * 0.5; $sk.elbFy = $ny + 29
  $sk.wrFx = $nx - 13 + $sw; $sk.wrFy = $ny + 45
  $sk.wrFAng = [math]::PI * 0.44
  return $sk
}

# ---------------------------------------------------------------- УДАР (5 кадров)
# 0-1 замах: корпус отведён назад, обе руки задраны назад-вверх, пасть раскрыта.
# 2 рывок: корпус вперёд, когти выбрасываются вперёд на уровне груди.
# 3 проводка: когти уходят вниз-вперёд, корпус ещё наклонён.
# 4 отход: руки падают вниз, корпус выпрямляется.
function AttackPose([int]$i) {
  # углы рук: -2.6 рад = когти заведены назад-вверх (замах), -0.1 = выброс вперёд,
  # +0.7 = проводка вниз-вперёд, +1.5 = руки падают вдоль тела
  # замах над головой ПЕРЕД собой (классический «удар сверху двумя лапами»),
  # затем свал вниз; z_atk_4 — отход. Углы: -1.9 = вверх-вперёд, +0.9 = вниз-вперёд.
  $tbl = @(
    @{ lean = -6.0; armN = -1.95; armF = -2.15; jaw = 0.9; step = -4.0 },
    @{ lean = -2.0; armN = -2.05; armF = -2.25; jaw = 1.0; step = -2.0 },
    @{ lean = 26.0; armN = -0.35; armF = -0.55; jaw = 1.0; step = 16.0 },
    @{ lean = 34.0; armN =  0.95; armF =  0.75; jaw = 0.7; step = 14.0 },
    @{ lean = 22.0; armN =  1.40; armF =  1.20; jaw = 0.4; step =  8.0 }
  )
  $p = $tbl[$i]
  $hipX = 142.0 - $p.step * 0.30
  $hipY = 152.0 + [math]::Abs($p.lean) * 0.12
  $nx = $hipX + 46.0 * [math]::Tan($p.lean * [math]::PI / 180.0)
  $ny = $hipY - 58.0
  $headX = $nx + 7.0; $headY = $ny - 26.0

  $sk = @{}
  $sk.hipX = $hipX; $sk.hipY = $hipY; $sk.neckX = $nx; $sk.neckY = $ny
  $sk.headX = $headX; $sk.headY = $headY; $sk.headTilt = $p.lean * 0.4; $sk.jaw = $p.jaw
  # широкая стойка, вес на передней ноге при рывке
  $sk.hipNx = $hipX + 7;  $sk.hipNy = $hipY + 4
  $sk.kneeNx = $hipX + 15 + $p.step * 0.5; $sk.kneeNy = 188
  $sk.ankNx = $hipX + 24 + $p.step; $sk.ankNy = 212
  $sk.hipFx = $hipX - 8; $sk.hipFy = $hipY + 4
  $sk.kneeFx = $hipX - 18 - $p.step * 0.2
  $sk.kneeFy = 190
  $sk.ankFx = $hipX - 30 - $p.step * 0.3; $sk.ankFy = 214
  # руки идут по дуге от «назад-вверх» к «вперёд-вниз»: локоть и кисть на одной линии
  $len1 = 24.0; $len2 = 26.0
  $sk.shNx = $nx + 14; $sk.shNy = $ny + 8
  $sk.elbNx = $sk.shNx + [math]::Cos($p.armN) * $len1
  $sk.elbNy = $sk.shNy + 6 + [math]::Sin($p.armN) * $len1
  $sk.wrNx = $sk.elbNx + [math]::Cos($p.armN + 0.30) * $len2
  $sk.wrNy = $sk.elbNy + [math]::Sin($p.armN + 0.30) * $len2
  $sk.wrNAng = $p.armN + 0.30
  $sk.shFx = $nx - 12; $sk.shFy = $ny + 9
  $sk.elbFx = $sk.shFx + [math]::Cos($p.armF) * ($len1 - 3)
  $sk.elbFy = $sk.shFy + 6 + [math]::Sin($p.armF) * ($len1 - 3)
  $sk.wrFx = $sk.elbFx + [math]::Cos($p.armF + 0.30) * ($len2 - 3)
  $sk.wrFy = $sk.elbFy + [math]::Sin($p.armF + 0.30) * ($len2 - 3)
  $sk.wrFAng = $p.armF + 0.30
  return $sk
}

function IdlePose {
  $hipX = 145.0; $hipY = 152.0
  $lean = 16.0
  $nx = $hipX + 46.0 * [math]::Tan($lean * [math]::PI / 180.0)
  $ny = $hipY - 58.0
  $sk = @{}
  $sk.hipX = $hipX; $sk.hipY = $hipY; $sk.neckX = $nx; $sk.neckY = $ny
  $sk.headX = $nx + 4.0; $sk.headY = $ny - 26.0 + 2.0; $sk.headTilt = $lean * 0.45; $sk.jaw = 0.25
  $sk.hipNx = $hipX + 6; $sk.hipNy = $hipY + 4
  $sk.kneeNx = $hipX + 9; $sk.kneeNy = 188
  $sk.ankNx = $hipX + 12; $sk.ankNy = 212
  $sk.hipFx = $hipX - 7; $sk.hipFy = $hipY + 4
  $sk.kneeFx = $hipX - 10; $sk.kneeFy = 190
  $sk.ankFx = $hipX - 13; $sk.ankFy = 214
  $sk.shNx = $nx + 15; $sk.shNy = $ny + 8
  $sk.elbNx = $nx + 21; $sk.elbNy = $ny + 28
  $sk.wrNx = $nx + 26; $sk.wrNy = $ny + 44
  $sk.wrNAng = [math]::PI * 0.44
  $sk.shFx = $nx - 13; $sk.shFy = $ny + 9
  $sk.elbFx = $nx - 15; $sk.elbFy = $ny + 29
  $sk.wrFx = $nx - 13; $sk.wrFy = $ny + 45
  $sk.wrFAng = [math]::PI * 0.44
  return $sk
}

if ($Only -eq "idle" -or $Only -eq "") { Render "z_idle" (IdlePose) }
if ($Only -eq "" -or $Only -eq "walk") {
  for ($i = 0; $i -lt 6; $i++) { Render ("z_walk_" + $i) (WalkPose $i) }
}
if ($Only -eq "" -or $Only -eq "attack") {
  for ($i = 0; $i -lt 5; $i++) { Render ("z_atk_" + $i) (AttackPose $i) }
}
"done"
