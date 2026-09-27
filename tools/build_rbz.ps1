param(
    # ru — русская сборка, en — английская, all — обе
    [ValidateSet('ru', 'en', 'all')][string]$Lang = 'all',
    # Дополнительно упаковать релизные архивы: .rbz + PDF-инструкция (docs\)
    [switch]$Release
)

# Собирает dist\area-counter-<версия>-rus.rbz и dist\area-counter-<версия>-eng.rbz
# из src\ — как в RALNCS: языковой пакет — тот же исходник, в копии подменяется
# строка LANG в src\area_counter\lang.rb (Ruby) и src\area_counter\html\i18n.js (окна).
# С -Release рядом кладутся dist\area-counter-<версия>-rus.zip / -eng.zip:
# внутри плагин и инструкция docs\area-counter-<версия>-guide-rus.pdf / -eng.pdf.
# Имя архива на идентичность расширения не влияет: SketchUp читает
# area_counter.rb из КОРНЯ архива, а версию — из него же.
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_rbz.ps1 [-Lang en] [-Release]

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression            # ZipArchive / ZipArchiveMode
Add-Type -AssemblyName System.IO.Compression.FileSystem # ZipFile / ZipFileExtensions

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'src'
$dist = Join-Path $root 'dist'
$docs = Join-Path $root 'docs'
New-Item -ItemType Directory -Force $dist | Out-Null

# 1. Версия берётся из исходника, чтобы имя пакета не разъезжалось с кодом
$entry = Join-Path $src 'area_counter.rb'
$match = Select-String -Path $entry -Pattern "VERSION\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $match) { throw "Не нашёл VERSION в $entry" }
$version = $match.Matches[0].Groups[1].Value

$suffix = @{ ru = 'rus'; en = 'eng' }
$langs  = if ($Lang -eq 'all') { @('ru', 'en') } else { @($Lang) }
$utf8   = New-Object System.Text.UTF8Encoding $false

# Записи добавляем поштучно: CreateFromDirectory в .NET Framework пишет пути
# через обратный слэш, а ZIP требует прямой — SketchUp такой архив разложит
# в один файл с именем "area_counter\toolbar.rb" вместо папки.
function Add-Tree($zipPath, $dir) {
    $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $prefix = (Resolve-Path $dir).Path.TrimEnd('\') + '\'
        Get-ChildItem $dir -Recurse -File | Sort-Object FullName | ForEach-Object {
            $name = $_.FullName.Substring($prefix.Length).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $_.FullName, $name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
}

foreach ($l in $langs) {
    $base  = 'area-counter-{0}-{1}' -f $version, $suffix[$l]
    $stage = Join-Path $env:TEMP ('area_counter_build_' + $l)
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item $src $stage -Recurse

    # 2. Язык: одна строка LANG в двух словарях
    foreach ($f in @('area_counter\lang.rb', 'area_counter\html\i18n.js')) {
        $p = Join-Path $stage $f
        $text = [System.IO.File]::ReadAllText($p, $utf8)
        $patched = $text -replace "LANG = '[a-z]{2}'", "LANG = '$l'"
        if ($patched -notmatch "LANG = '$l'") { throw "Не нашёл строку LANG в $f" }
        [System.IO.File]::WriteAllText($p, $patched, $utf8)
    }

    # 3. Плагин
    $rbz = Join-Path $dist "$base.rbz"
    Remove-Item $rbz -ErrorAction SilentlyContinue
    Add-Tree $rbz $stage
    Remove-Item $stage -Recurse -Force
    Write-Host "Собрано: $rbz"

    # 4. Релизный архив: плагин + инструкция
    if ($Release) {
        $guide = Join-Path $docs ('area-counter-{0}-guide-{1}.pdf' -f $version, $suffix[$l])
        if (-not (Test-Path $guide)) { throw "Нет инструкции $guide — сначала tools\build_guides.ps1" }
        $pack = Join-Path $env:TEMP ('area_counter_pack_' + $l)
        Remove-Item $pack -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $pack | Out-Null
        Copy-Item $rbz $pack
        Copy-Item $guide $pack
        $zip = Join-Path $dist "$base.zip"
        Remove-Item $zip -ErrorAction SilentlyContinue
        Add-Tree $zip $pack
        Remove-Item $pack -Recurse -Force
        Write-Host "Собрано: $zip"
    }
}

Get-ChildItem $dist -File | ForEach-Object { Write-Host ("  {0,-40} {1,9} б" -f $_.Name, $_.Length) }
