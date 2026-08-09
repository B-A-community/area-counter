# Собирает src\ в area_counter.rbz (это обычный ZIP, area_counter.rb должен
# лежать в КОРНЕ архива). Предыдущий .rbz сохраняется в build\backup.
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_rbz.ps1

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root 'src'
$rbz    = Join-Path $root 'area_counter.rbz'
$backup = Join-Path $root 'build\backup'

if (-not (Test-Path $src)) { throw "Нет папки с исходниками: $src" }

# 1. Резервная копия предыдущей сборки
if (Test-Path $rbz) {
    New-Item -ItemType Directory -Force $backup | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $rbz (Join-Path $backup "area_counter_$stamp.rbz") -Force
}

# 2. Упаковка.
# Записи добавляем поштучно: CreateFromDirectory в .NET Framework пишет пути
# через обратный слэш, а ZIP требует прямой — SketchUp такой архив разложит
# в один файл с именем "area_counter\toolbar.rb" вместо папки.
$zip = Join-Path $root 'build\area_counter.zip'
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

Write-Host "Собрано: $rbz"
$check = [System.IO.Compression.ZipFile]::OpenRead($rbz)
$check.Entries | ForEach-Object { Write-Host ("  {0,-45} {1,7} б" -f $_.FullName, $_.Length) }
$check.Dispose()
