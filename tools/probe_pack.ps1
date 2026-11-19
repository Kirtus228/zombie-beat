
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile('D:\OneDrive\Desktop\Mobidick\games\zombie-beat\assets\zombie\idle.png')
# подписи цветов
function Name($c) {
  if ($c.A -lt 40) { return '.' }
  $k = "$($c.R),$($c.G),$($c.B)"
  switch ($k) {
    '34,36,30'   { return 'K' }   # контур
    '152,182,138'{ return 'S' }   # кожа
    '168,150,62' { return 'H' }   # волосы
    '104,100,96' { return 'T' }   # майка
    '96,104,74'  { return 'P' }   # шорты
    '120,108,118'{ return 'B' }   # ботинки
    '226,226,214'{ return 'W' }   # зубы/белок
    '124,152,112'{ return 's' }   # тень кожи
    '122,150,110'{ return 's' }
    '92,84,92'   { return 'b' }
    '74,80,58'   { return 'p' }
    '78,76,74'   { return 't' }
    '42,34,36'   { return 'M' }   # пасть
    default { return '?' }
  }
}
"легенда: K контур, S кожа, s тень кожи, H волосы, T майка, P шорты, B ботинки, W зубы, M пасть"
for ($y = 44; $y -lt 224; $y += 2) {
  $line = ''
  for ($x = 100; $x -lt 195; $x++) { $line += (Name $img.GetPixel($x,$y)) }
  "{0,3} {1}" -f $y, $line
}
