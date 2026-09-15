param(
    # Суффикс в имени пакета. Уйдём в прод — запускать с -Suffix ''
    [string]$Suffix = '_test'
)

# Собирает src\ в area_counter<версия><суффикс>.rbz — например
# area_counter0.5_test.rbz. Имя архива на идентичность расширения не влияет:
# SketchUp читает area_counter.rb из КОРНЯ архива, а версию — из него же.
# Предыдущая сборка сохраняется в build\backup.
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_rbz.ps1

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root 'src'
$backup = Join-Path $root 'build\backup'

if (-not (Test-Path $src)) { throw "Нет папки с исходниками: $src" }

# 1. Версия берётся из исходника, чтобы имя пакета не разъезжалось с кодом
$entry = Join-Path $src 'area_counter.rb'
$match = Select-String -Path $entry -Pattern "VERSION\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $match) { throw "Не нашёл VERSION в $entry" }
$version = $match.Matches[0].Groups[1].Value

$name = "area_counter$version$Suffix.rbz"
$rbz  = Join-Path $root $name

# 2. Резервная копия предыдущей сборки
if (Test-Path $rbz) {
    New-Item -ItemType Directory -Force $backup | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $rbz (Join-Path $backup "$($name -replace '\.rbz$', '')_$stamp.rbz") -Force
}

# 3. Упаковка.
# Записи добавляем поштучно: CreateFromDirectory в .NET Framework пишет пути
# через обратный слэш, а ZIP требует прямой — SketchUp такой архив разложит
# в один файл с именем "area_counter\toolbar.rb" вместо папки.
$zip = Join-Path $root 'build\staging.zip'
New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null
if (Test-Path $zip) { Remove-Item $zip -Force }

Add-Type -AssemblyName System.IO.Compression            # ZipArchive / ZipArchiveMode
Add-Type -AssemblyName System.IO.Compression.FileSystem # ZipFile / ZipFileExtensions
$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
$prefix = (Resolve-Path $src).Path.TrimEnd('\') + '\'
Get-ChildItem $src -Recurse -File | Sort-Object FullName | ForEach-Object {
    $entryName = $_.FullName.Substring($prefix.Length).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $_.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
$archive.Dispose()

Move-Item $zip $rbz -Force

# 4. Прошлые пакеты с другим именем убираем из корня, чтобы не поставили старое
Get-ChildItem $root -Filter '*.rbz' -File | Where-Object { $_.Name -ne $name } | ForEach-Object {
    New-Item -ItemType Directory -Force $backup | Out-Null
    Move-Item $_.FullName (Join-Path $backup $_.Name) -Force
    Write-Host "Убрал в backup прежний пакет: $($_.Name)"
}

Write-Host "Собрано: $rbz"
$check = [System.IO.Compression.ZipFile]::OpenRead($rbz)
$check.Entries | ForEach-Object { Write-Host ("  {0,-45} {1,7} б" -f $_.FullName, $_.Length) }
$check.Dispose()
