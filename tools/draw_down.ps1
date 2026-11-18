# Рисует кадр «лежит на земле» в стиле пака: тело горизонтально на линии земли y=221.
# Цвета передаются строками RRGGBB и конвертируются внутри примитивов.
param(
  [Parameter(Mandatory=$true)][string]$Target,
  [string]$Shirt  = "28262E",
  [string]$Shorts = "545058",
  [string]$Skin   = "F0D8A8",
  [string]$Hair   = "3A2C24",
  [string]$Hair2  = "2A1F19"
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
function Col([string]$h){ [System.Drawing.ColorTranslator]::FromHtml("#" + $h) }

$OUT = "2C1E16"
$WHITE = "F0F0EC"
$W = 260; $H = 227
$bmp = [System.Drawing.Bitmap]::new($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)

function Pt($x, $y) { [System.Drawing.PointF]::new([float]$x, [float]$y) }
function Poly {
  param($pts, [string]$hex, [double]$ink)
  $b = [System.Drawing.SolidBrush]::new((Col $hex)); $g.FillPolygon($b, $pts); $b.Dispose()
  if ($ink -gt 0) {
    $p = [System.Drawing.Pen]::new((Col $OUT), [float]$ink); $p.LineJoin = 'Round'
    $g.DrawPolygon($p, $pts); $p.Dispose()
  }
}
function Seg {
  param([double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$w, [string]$hex)
  $po = [System.Drawing.Pen]::new((Col $OUT), [float]($w + 4)); $po.StartCap = 'Round'; $po.EndCap = 'Round'
  $g.DrawLine($po, [float]$x1, [float]$y1, [float]$x2, [float]$y2); $po.Dispose()
  $pc = [System.Drawing.Pen]::new((Col $hex), [float]$w); $pc.StartCap = 'Round'; $pc.EndCap = 'Round'
  $g.DrawLine($pc, [float]$x1, [float]$y1, [float]$x2, [float]$y2); $pc.Dispose()
}
function Ell {
  param([double]$cx, [double]$cy, [double]$rx, [double]$ry, [string]$hex, [double]$ink)
  $b = [System.Drawing.SolidBrush]::new((Col $hex))
  $g.FillEllipse($b, [float]($cx-$rx), [float]($cy-$ry), [float]($rx*2), [float]($ry*2)); $b.Dispose()
  if ($ink -gt 0) {
    $p = [System.Drawing.Pen]::new((Col $OUT), [float]$ink)
    $g.DrawEllipse($p, [float]($cx-$rx), [float]($cy-$ry), [float]($rx*2), [float]($ry*2)); $p.Dispose()
  }
}

# ноги: горизонтально, ступни вправо
Seg -x1 180 -y1 200 -x2 216 -y2 197 -w 14 -hex $Skin
Seg -x1 180 -y1 212 -x2 214 -y2 209 -w 13 -hex $Skin
Ell -cx 220 -cy 197 -rx 7 -ry 4.5 -hex $Skin -ink 2.4
Ell -cx 218 -cy 209 -rx 7 -ry 4.5 -hex $Skin -ink 2.4
# шорты
$sh = [System.Drawing.PointF[]]@((Pt 146 190), (Pt 188 188), (Pt 186 218), (Pt 142 216))
Poly -pts $sh -hex $Shorts -ink 2.6
$stripe = [System.Drawing.PointF[]]@((Pt 178 189), (Pt 186 189), (Pt 184 217), (Pt 176 217))
Poly -pts $stripe -hex $WHITE -ink 0
# торс
$tr = [System.Drawing.PointF[]]@((Pt 96 188), (Pt 150 185), (Pt 152 218), (Pt 92 219))
Poly -pts $tr -hex $Shirt -ink 2.6
# руки поперёк груди
Seg -x1 104 -y1 204 -x2 146 -y2 213 -w 10 -hex $Skin
Ell -cx 150 -cy 214 -rx 6.5 -ry 5.5 -hex $Skin -ink 2.2
Seg -x1 106 -y1 194 -x2 138 -y2 191 -w 9 -hex $Skin
# шея и голова влево
Seg -x1 96 -y1 202 -x2 84 -y2 200 -w 10 -hex $Skin
Ell -cx 70 -cy 199 -rx 13 -ry 12.5 -hex $Skin -ink 2.4
Ell -cx 66 -cy 191 -rx 14 -ry 11 -hex $Hair -ink 2.2
Ell -cx 57 -cy 201 -rx 5 -ry 7 -hex $Hair2 -ink 1.8
Ell -cx 77 -cy 198 -rx 2 -ry 2 -hex $OUT -ink 0
Seg -x1 62 -y1 209 -x2 70 -y2 209 -w 1.8 -hex $OUT

$g.Dispose()
$bmp.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"wrote " + $Target
