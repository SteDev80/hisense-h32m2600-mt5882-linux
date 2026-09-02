$ErrorActionPreference = 'Stop'

$diskNumber = 1
$expectedName = 'Lexar JumpDrive'
$expectedSerial = '2362577235'
$source = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs'
$resultFile = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\work\usb-mbr-result.txt'

trap {
    "ERROR`r`n$($_ | Out-String)" | Set-Content -LiteralPath $resultFile -Encoding utf8
    exit 1
}

Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue

$target = Get-Disk -Number $diskNumber
if (
    $target.BusType -ne 'USB' -or
    $target.FriendlyName -ne $expectedName -or
    $target.SerialNumber.Trim() -ne $expectedSerial -or
    $target.IsBoot -or
    $target.IsSystem -or
    $target.Size -lt 15000000000 -or
    $target.Size -gt 17000000000
) {
    throw 'Verifica di sicurezza Lexar fallita. Nessun disco modificato.'
}

$diskpartScript = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\work\diskpart-lexar-mbr.txt'
& diskpart.exe /s $diskpartScript | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "DiskPart terminato con codice $LASTEXITCODE."
}
Update-Disk -Number $diskNumber

$preparedDisk = Get-Disk -Number $diskNumber
$preparedPartition = Get-Partition -DiskNumber $diskNumber -PartitionNumber 1
$preparedVolume = Get-Volume -DriveLetter D
if (
    $preparedDisk.PartitionStyle -ne 'MBR' -or
    -not $preparedPartition.IsActive -or
    $preparedVolume.FileSystem -ne 'FAT32'
) {
    throw 'La verifica MBR/FAT32/Active non è riuscita.'
}

$names = @(
    'uImage-mt5882-ramtest',
    'BOOT-MT5882.txt',
    'README-MT5882.txt',
    'SHA256SUMS.txt',
    'kernel-config-mt5882-ramtest.txt'
)

foreach ($name in $names) {
    Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path 'D:\' $name) -Force
}

$hash = (Get-FileHash -LiteralPath 'D:\uImage-mt5882-ramtest' -Algorithm SHA256).Hash
if ($hash -ne 'FFB5796708B38F798EEDBB35C9BED596FA4C5DCD20BD8DEE539FD5E64B8B7230') {
    throw 'Checksum non valido dopo la copia.'
}

$afterDisk = Get-Disk -Number $diskNumber
$afterPartition = Get-Partition -DiskNumber $diskNumber -PartitionNumber 1
$afterVolume = Get-Volume -DriveLetter D

@(
    "Disk=$($afterDisk.FriendlyName)",
    "Serial=$($afterDisk.SerialNumber.Trim())",
    "Style=$($afterDisk.PartitionStyle)",
    "Active=$($afterPartition.IsActive)",
    "FileSystem=$($afterVolume.FileSystem)",
    "Label=$($afterVolume.FileSystemLabel)",
    "SHA256=$hash"
) | Set-Content -LiteralPath $resultFile -Encoding ascii
