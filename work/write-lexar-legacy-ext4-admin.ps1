$ErrorActionPreference = 'Stop'
$expectedSerial = '2362577235'
$expectedSize = 16022241280
$expectedOffset = 537919488
$image = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\rootfs-legacy.ext4'
$result = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\write-legacy-result.txt'

try {
    $disk = Get-Disk | Where-Object {
        $_.BusType -eq 'USB' -and $_.FriendlyName -eq 'Lexar JumpDrive' -and $_.SerialNumber.Trim() -eq $expectedSerial
    }
    if (@($disk).Count -ne 1 -or $disk.Size -ne $expectedSize -or $disk.IsBoot -or $disk.IsSystem) {
        throw 'Controllo di sicurezza Lexar fallito.'
    }
    $parts = @(Get-Partition -DiskNumber $disk.Number | Sort-Object PartitionNumber)
    if ($parts.Count -ne 2 -or $parts[0].Offset -ne 1048576 -or $parts[1].Offset -ne $expectedOffset) {
        throw 'Tabella partizioni Lexar inattesa.'
    }
    if ((Get-Item -LiteralPath $image).Length -ne 268435456) {
        throw 'Dimensione immagine legacy inattesa.'
    }

    $source = [System.IO.File]::Open($image, 'Open', 'Read', 'Read')
    $target = [System.IO.File]::Open("\\.\PhysicalDrive$($disk.Number)", 'Open', 'ReadWrite', 'ReadWrite')
    try {
        [void]$target.Seek($expectedOffset, [System.IO.SeekOrigin]::Begin)
        $source.CopyTo($target, 4MB)
        $target.Flush($true)
    }
    finally {
        $source.Dispose()
        $target.Dispose()
    }
    "OK legacy ext4 written: disk=$($disk.Number) serial=$expectedSerial offset=$expectedOffset bytes=268435456" |
        Set-Content -LiteralPath $result -Encoding ascii
}
catch {
    "ERROR: $($_.Exception.Message)`r`n$($_.ScriptStackTrace)" |
        Set-Content -LiteralPath $result -Encoding ascii
    exit 1
}
