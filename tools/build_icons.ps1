# Генерирует PNG-фолбэки иконок (24px и 16px) из тех же форм, что и SVG.
# SVG используется на Windows, PNG — запасной вариант (в т.ч. macOS).
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_icons.ps1

Add-Type -AssemblyName System.Drawing

$root    = Split-Path -Parent $PSScriptRoot
$iconDir = Join-Path $root 'src\area_counter\icons'
if (-not (Test-Path $iconDir)) { New-Item -ItemType Directory -Force $iconDir | Out-Null }

$S     = 8            # супер-сэмплинг: рисуем 24*8 = 192px
$LINE  = [System.Drawing.ColorTranslator]::FromHtml('#3C3C3C')
$ACC   = [System.Drawing.ColorTranslator]::FromHtml('#4A90D9')
$ACCED = [System.Drawing.ColorTranslator]::FromHtml('#2D6FB0')

function New-Pt([double]$x, [double]$y) {
    New-Object System.Drawing.PointF([float]($x * $S), [float]($y * $S))
}

function Add-Poly($g, [double[][]]$pts, $fillColor, $strokeColor, [double]$w) {
    $p = @($pts | ForEach-Object { New-Pt $_[0] $_[1] })
    if ($null -ne $fillColor) {
        $br = New-Object System.Drawing.SolidBrush($fillColor)
        $g.FillPolygon($br, $p); $br.Dispose()
    }
    if ($null -ne $strokeColor) {
        $pen = New-Object System.Drawing.Pen($strokeColor, [float]($w * $S))
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPolygon($pen, $p); $pen.Dispose()
    }
}

function Add-Rect($g, [double]$x, [double]$y, [double]$w, [double]$h, $fillColor, $strokeColor, [double]$sw) {
    # скобки обязательны: в PowerShell запятая связывает сильнее арифметики
    $x2 = $x + $w
    $y2 = $y + $h
    Add-Poly $g @(@($x,$y), @($x2,$y), @($x2,$y2), @($x,$y2)) $fillColor $strokeColor $sw
}

function Add-Line($g, [double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$w, [double[]]$dash) {
    $pen = New-Object System.Drawing.Pen($LINE, [float]($w * $S))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    if ($dash) { $pen.DashPattern = [float[]]$dash }
    $g.DrawLine($pen, (New-Pt $x1 $y1), (New-Pt $x2 $y2))
    $pen.Dispose()
}

function New-Canvas {
    $px  = 24 * $S
    $bmp = New-Object System.Drawing.Bitmap($px, $px, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    ,@($bmp, $g)
}

function Save-Icon($bmp, [string]$name) {
    foreach ($size in 24, 16) {
        $out = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $og = [System.Drawing.Graphics]::FromImage($out)
        $og.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $og.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $og.Clear([System.Drawing.Color]::Transparent)
        $og.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)))
        $og.Dispose()
        $path = Join-Path $iconDir ("{0}_{1}.png" -f $name, $size)
        $out.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $out.Dispose()
        Write-Host "  $path"
    }
    $bmp.Dispose()
}

# Вершины изометрического куба (в координатах 24x24)
$T = @(12, 2); $L = @(3, 7);  $R  = @(21, 7)
$C = @(12,12); $BL= @(3,17);  $BR = @(21,17); $B = @(12,22)

function Get-Gray([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

# --- 1. area_top: верхняя грань акцентом ------------------------------------
$canvas = New-Canvas; $bmp, $g = $canvas[0], $canvas[1]
Add-Poly $g @($L, $C, $B, $BL)  (Get-Gray '#F2F2F2') $LINE  1.3
Add-Poly $g @($C, $R, $BR, $B)  (Get-Gray '#E4E4E4') $LINE  1.3
Add-Poly $g @($T, $R, $C, $L)   $ACC                 $ACCED 1.3
Save-Icon $bmp 'area_top'; $g.Dispose()

# --- 2. volume: сплошной куб ------------------------------------------------
$canvas = New-Canvas; $bmp, $g = $canvas[0], $canvas[1]
Add-Poly $g @($L, $C, $B, $BL)  (Get-Gray '#EDEDED') $LINE 1.3
Add-Poly $g @($C, $R, $BR, $B)  (Get-Gray '#D8D8D8') $LINE 1.3
Add-Poly $g @($T, $R, $C, $L)   (Get-Gray '#FAFAFA') $LINE 1.3
Save-Icon $bmp 'volume'; $g.Dispose()

# --- 3. lengths: пунктирный силуэт + узлы -----------------------------------
$canvas = New-Canvas; $bmp, $g = $canvas[0], $canvas[1]
$hex = @($T, $R, $BR, $B, $BL, $L)
$pen = New-Object System.Drawing.Pen($LINE, [float](1.6 * $S))
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$pen.DashPattern = [float[]](2.0, 1.375)   # ~ "3.2 2.2" при ширине 1.6
$g.DrawPolygon($pen, @($hex | ForEach-Object { New-Pt $_[0] $_[1] }))
$pen.Dispose()
foreach ($n in @(@(10.6,0.6), @(10.6,20.6), @(1.6,5.6), @(19.6,15.6))) {
    Add-Rect $g $n[0] $n[1] 2.8 2.8 $LINE $null 0
}
Save-Icon $bmp 'lengths'; $g.Dispose()

# --- 4. schedule: лист с таблицей -------------------------------------------
$canvas = New-Canvas; $bmp, $g = $canvas[0], $canvas[1]
Add-Rect $g 4 2.5 16 19  (Get-Gray '#FAFAFA') $LINE 1.3
Add-Rect $g 4 2.5 16 4.5 (Get-Gray '#D8D8D8') $LINE 1.3
Add-Line $g 4 12    20 12    1.1 $null
Add-Line $g 4 16.75 20 16.75 1.1 $null
Add-Line $g 13.5 7  13.5 21.5 1.1 $null
Save-Icon $bmp 'schedule'; $g.Dispose()

# --- 5. export: лист + стрелка ----------------------------------------------
$canvas = New-Canvas; $bmp, $g = $canvas[0], $canvas[1]
Add-Rect $g 2.5 3 11 18 (Get-Gray '#FAFAFA') $LINE 1.3
Add-Line $g 5.5 7.5  10.5 7.5  1.1 $null
Add-Line $g 5.5 11   10.5 11   1.1 $null
Add-Line $g 5.5 14.5 8.5  14.5 1.1 $null
Add-Line $g 15 17.5 19 17.5 1.6 $null
Add-Poly $g @(@(22.5,17.5), @(18.4,19.8), @(18.4,15.2)) $LINE $null 0
Save-Icon $bmp 'export'; $g.Dispose()

Write-Host "Готово: иконки в $iconDir"
