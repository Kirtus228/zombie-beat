# Зомби «с открытым мозгом», версия 5 (20.11.2026).
# Правка по замечанию Кирилла: «мозги выглядят как отдельная часть, налепленная
# на модельку, нужно чтобы это была цельная часть персонажа».
#
# Что делает мозг частью персонажа:
#  1. Контур раны — ТОТ ЖЕ цвет, что контур всей модельки (34,36,30).
#  2. Палитра мозга обесцвечена и равна по светлоте коже зомби (152,182,138),
#     поэтому мозг не «светится» поверх тела.
#  3. Извилины — волнистые полосы (4 px), как настоящая кора, а не пятна.
#  4. Край раны неровный (зазубрины), а не линия шапки.
#  5. Из раны на лоб идут потёки крови — мозг и лицо связаны.
#  6. По центру макушки мозг на 2 px ВЫСТУПАЕТ за силуэт головы: рана не
#     «нарисована поверх», а разрывает череп.
#  7. Остатки волос вокруг раны приглушены (стриженая кожа), а не жёлтая шапка.
param([string]$Only = "")

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$SrcDir = Join-Path $PSScriptRoot "..\assets\zombie"
$OutDir = Join-Path $PSScriptRoot "..\assets\zombie_brain"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function C([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }
function WithA($c, $n) { return [System.Drawing.Color]::FromArgb($c.A, $n.R, $n.G, $n.B) }

$BRAIN  = C 134  84  88   # тело извилины (темнее кожи — мозг в черепе, а не сверху)
$BRAIN2 = C 164 112 110   # гребень на свету (смотрит вверх-влево)
$BRAIN1 = C 112  68  76   # полутень
$GROOVE = C  84  48  58   # борозда между долями
$INK    = C  34  36  30   # контур модели
$BLOOD  = C 126  42  54   # кровь
$HAIRD  = C 116 104  56   # приглушённые остатки волос

function Is-Hair($c) { $c.A -ge 40 -and $c.R -gt 140 -and $c.G -gt 120 -and $c.B -lt 110 -and (($c.G - $c.B) -gt 40) }
function Is-Skin($c) { $c.A -ge 40 -and $c.G -gt 140 -and $c.R -gt 110 -and $c.R -lt 190 -and $c.B -gt 100 -and $c.B -lt 170 }

# Кора рисуется долями: несколько центров, у каждого — светлый гребень, вокруг
# полутень, между долями тёмная борозда. Так мозг читается как мозг, а не как
# полосатая шапка: у долей круглые края, а не параллельные полосы.
function LobeShade([double]$x, [double]$y, $centers) {
  $best = 9999.0; $bx = 0.0; $by = 0.0
  foreach ($c in $centers) {
    $dx = $x - $c[0]; $dy = ($y - $c[1]) * 1.15
    $d = [math]::Sqrt($dx * $dx + $dy * $dy)
    if ($d -lt $best) { $best = $d; $bx = $c[0]; $by = $c[1] }
  }
  # границы долей делаем волнистыми: без этого изо-линии расстояния дают
  # «кирпичную кладку» из прямоугольных заплаток
  $best = $best + 0.55 * [math]::Sin($x * 0.95) + 0.45 * [math]::Sin($y * 1.30 + 0.7)
  # свет сверху-слева: склон, обращённый к свету, светлее
  $lit = (($x - $bx) + ($y - $by)) -lt 0.0
  if ($best -lt 2.1) { if ($lit) { return 2 } else { return 1 } }   # гребень
  if ($best -lt 3.6) { if ($lit) { return 1 } else { return 0 } }   # тело
  if ($best -lt 5.2) { return 3 }                                    # полутень к борозде
  return 4                                                           # борозда
}

$files = Get-ChildItem $SrcDir -Filter *.png | Where-Object { $Only -eq "" -or $_.BaseName -eq $Only }
foreach ($f in $files) {
  $img = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $w = $img.Width; $h = $img.Height

  # макушка ищется по цвету волос: в позах с замахом сверху бывает поднятая рука
  $capTop = 9999; $hairMinY = 9999; $hairMaxY = -1; $hx0 = 9999; $hx1 = -1
  $rowL = [int[]]::new($h); $rowR = [int[]]::new($h)
  for ($y = 0; $y -lt $h; $y++) {
    $rowL[$y] = 99999; $rowR[$y] = -1
    for ($x = 0; $x -lt $w; $x++) {
      if (-not (Is-Hair ($img.GetPixel($x, $y)))) { continue }
      if ($y -lt $hairMinY) { $hairMinY = $y }
      if ($y -gt $hairMaxY) { $hairMaxY = $y }
      if ($x -lt $rowL[$y]) { $rowL[$y] = $x }
      if ($x -gt $rowR[$y]) { $rowR[$y] = $x }
      if ($x -lt $hx0) { $hx0 = $x }
      if ($x -gt $hx1) { $hx1 = $x }
    }
  }
  if ($hairMaxY -lt 0) { "skip $($f.Name) (no hair)"; $img.Dispose(); continue }
  $capTop = $hairMinY
  $cx = ($hx0 + $hx1) / 2.0
  $halfW = [math]::Max(4.0, ($hx1 - $hx0 + 1) / 2.0)
  # «лежит» = голова повёрнута (кадр down). Считаем непрерывную полосу волос от
  # макушки вниз: одиночные жёлтые пиксели в других местах кадра не должны сбивать.
  $runBot = $capTop
  $gap = 0
  for ($y = $capTop; $y -lt $h; $y++) {
    if ($rowR[$y] -ge $rowL[$y]) { $runBot = $y; $gap = 0 } else { $gap++; if ($gap -gt 2) { break } }
  }
  $lying = ($runBot - $capTop) -gt 18

  # ширина раны по строкам: волосы не в каждой строке, пустые наследуют предыдущую
  $spanL = $rowL[$capTop]; $spanR = $rowR[$capTop]
  for ($y = $capTop; $y -le [math]::Min($h - 1, $capTop + 12); $y++) {
    if ($rowR[$y] -ge $rowL[$y]) {
      $spanL = [math]::Min($spanL, $rowL[$y]); $spanR = [math]::Max($spanR, $rowR[$y])
    }
  }

  $isWound = [bool[,]]::new($w, $h)
  $cutY = [int[]]::new($w)
  for ($x = 0; $x -lt $w; $x++) { $cutY[$x] = -1 }
  for ($y = $capTop; $y -le [math]::Min($h - 1, $capTop + 13); $y++) {
    for ($x = $spanL - 2; $x -le $spanR + 2; $x++) {
      if ($x -lt 0 -or $x -ge $w) { continue }
      $c = $img.GetPixel($x, $y)
      if ($c.A -lt 40) { continue }
      $dx = ($x - $cx) / $halfW
      if ([math]::Abs($dx) -gt 0.95) { continue }
      $notch = 0
      $np = ($x + $capTop) % 7
      if ($np -eq 0) { $notch = -1 }   # редкая зазубрина, без «зубов» по всему краю
      $cut = $capTop + 12 - [int][math]::Round(2.2 * $dx * $dx) + $notch
      $cutY[$x] = $cut
      if ($y -le $cut) { $isWound[($x), ($y)] = $true }
    }
  }

  # контур модели не перекрываем: мозг остаётся внутри силуэта
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if (-not $isWound[($x), ($y)]) { continue }
      $touch = $false
      foreach ($s in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
        $nx = $x + $s[0]; $ny = $y + $s[1]
        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $w -or $ny -ge $h) { continue }
        if ($img.GetPixel($nx, $ny).A -lt 40) { $touch = $true; break }
      }
      if ($touch) { $isWound[($x), ($y)] = $false }
    }
  }

  # центры долей: раскладываем по площади раны, чтобы у каждой головы рисунок
  # сидел на своём месте (поза не влияет — считаем от макушки и центра головы)
  $centers = @(
    @(($cx - $halfW * 0.50), ($capTop + 4.0)),
    @(($cx + $halfW * 0.45), ($capTop + 3.2)),
    @(($cx + $halfW * 0.10), ($capTop + 8.6)),
    @(($cx - $halfW * 0.75), ($capTop + 9.2))
  )

  $out = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $img.GetPixel($x, $y)
      if (-not $isWound[($x), ($y)]) {
        # остатки волос у раны приглушаем: это стриженая кожа, а не жёлтая шапка
        if ($y -le ($capTop + 14) -and (Is-Hair $c)) { $out.SetPixel($x, $y, (WithA $c $HAIRD)); continue }
        # лоб под раной в тени черепа
        if ($cutY[$x] -gt 0 -and $y -eq ($cutY[$x] + 1) -and (Is-Skin $c)) {
          $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, [int]($c.R * 0.74), [int]($c.G * 0.74), [int]($c.B * 0.74)))
          continue
        }
        $out.SetPixel($x, $y, $c)
        continue
      }
      # край раны: пиксель на границе области раны
      $edge = $false
      foreach ($s in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
        $nx = $x + $s[0]; $ny = $y + $s[1]
        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $w -or $ny -ge $h) { continue }
        if (-not $isWound[($nx), ($ny)] -and $img.GetPixel($nx, $ny).A -ge 40) { $edge = $true; break }
      }
      if ($edge) { $out.SetPixel($x, $y, (WithA $c $INK)); continue }
      $k = LobeShade $x $y $centers
      if ($k -eq 2) { $n = $BRAIN2 }
      elseif ($k -eq 1) { $n = $BRAIN }
      elseif ($k -eq 0) { $n = $BRAIN1 }
      elseif ($k -eq 3) { $n = $BRAIN1 }
      else { $n = $GROOVE }
      # к нижнему краю раны мозг в тени от лба
      if ($y -ge ($cutY[$x] - 1)) {
        if ($n -eq $BRAIN2) { $n = $BRAIN } elseif ($n -eq $BRAIN) { $n = $BRAIN1 } elseif ($n -eq $BRAIN1) { $n = $GROOVE }
      }
      $out.SetPixel($x, $y, (WithA $c $n))
    }
  }

  # выступ мозга за силуэт по центру макушки: череп разорван, а не «наклеен»
  if (-not $lying) {
    $bulgeW = [int][math]::Max(2, [math]::Floor($halfW * 0.55))
    for ($k = 1; $k -le 2; $k++) {
      $yy = $capTop - $k
      if ($yy -lt 0) { continue }
      $bw = $bulgeW - ($k - 1) * 2
      if ($bw -lt 1) { continue }
      for ($x = [int]($cx - $bw); $x -le [int]($cx + $bw); $x++) {
        if ($x -lt 0 -or $x -ge $w) { continue }
        if ($img.GetPixel($x, $yy).A -ge 40) { continue }
        $k = LobeShade $x $yy $centers
        $n = if ($k -le 1) { $BRAIN2 } else { $BRAIN }
        $out.SetPixel($x, $yy, (WithA (C 255 255 255) $n))
      }
      # контур выступа
      $bl = [int]($cx - $bw)
      $br = [int]($cx + $bw)
      foreach ($x in @(($bl - 1), ($br + 1))) {
        if ($x -lt 0 -or $x -ge $w) { continue }
        if ($out.GetPixel($x, $yy).A -lt 40) { $out.SetPixel($x, $yy, (WithA (C 255 255 255) $INK)) }
      }
    }
    for ($x = [int]($cx - $bulgeW + 1); $x -le [int]($cx + $bulgeW - 1); $x++) {
      if ($x -lt 0 -or $x -ge $w) { continue }
      $yy = $capTop - 3
      if ($yy -lt 0) { continue }
      if ($out.GetPixel($x, $yy).A -lt 40 -and $out.GetPixel($x, $yy + 1).A -ge 40) { $out.SetPixel($x, $yy, (WithA (C 255 255 255) $INK)) }
    }
  }

  # потёки крови из раны на лоб: связывают мозг с лицом
  $drips = @(2, 6, 11)
  for ($i = 0; $i -lt $drips.Count; $i++) {
    $x = [int]($cx - $halfW + $drips[$i])
    if ($x -lt 0 -or $x -ge $w) { continue }
    $cy0 = $cutY[$x]
    if ($cy0 -lt 0) { continue }
    $len = 3 + (($x * 5 + $capTop) % 4)
    for ($k = 1; $k -le $len; $k++) {
      $yy = $cy0 + $k
      if ($yy -ge $h) { break }
      $c = $out.GetPixel($x, $yy)
      if ($c.A -lt 40) { break }
      if ($c.A -lt 40) { break }
      $out.SetPixel($x, $yy, [System.Drawing.Color]::FromArgb($c.A, $BLOOD.R, $BLOOD.G, $BLOOD.B))
    }
  }

  $dst = Join-Path $OutDir $f.Name
  $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose(); $img.Dispose()
  Write-Output ("ok " + $f.Name + " capTop=" + $capTop + " cx=" + $cx + " halfW=" + $halfW + " lying=" + $lying)
}