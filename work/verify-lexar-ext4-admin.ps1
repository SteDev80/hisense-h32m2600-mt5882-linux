$ErrorActionPreference = 'Stop'
$expectedSerial = '2362577235'
$expectedSize = 16022241280
$result = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\verify-ext4.txt'

try {
    $disk = Get-Disk | Where-Object {
        $_.BusType -eq 'USB' -and $_.FriendlyName -eq 'Lexar JumpDrive' -and $_.SerialNumber.Trim() -eq $expectedSerial
    }
    if (@($disk).Count -ne 1 -or $disk.Size -ne $expectedSize -or $disk.IsBoot -or $disk.IsSystem) {
        throw 'La Lexar prevista non e stata identificata senza ambiguita.'
    }
    $partitions = @(Get-Partition -DiskNumber $disk.Number | Sort-Object PartitionNumber)
    if ($partitions.Count -ne 2 -or $partitions[0].Offset -ne 1048576 -or $partitions[1].Offset -ne 537919488) {
        throw 'La tabella partizioni della Lexar non corrisponde a quella preparata.'
    }

    $stream = [System.IO.File]::Open("\\.\PhysicalDrive$($disk.Number)", 'Open', 'Read', 'ReadWrite')
    try {
        [void]$stream.Seek($partitions[1].Offset + 1080, [System.IO.SeekOrigin]::Begin)
        $magic = New-Object byte[] 2
        if ($stream.Read($magic, 0, 2) -ne 2 -or $magic[0] -ne 0x53 -or $magic[1] -ne 0xEF) {
            throw 'Firma ext4 0xEF53 non trovata nella seconda partizione.'
        }
    }
    finally {
        $stream.Dispose()
    }

    "OK ext4: disk=$($disk.Number) serial=$expectedSerial offset=$($partitions[1].Offset) magic=53EF" |
        Set-Content -LiteralPath $result -Encoding ascii
}
catch {
    "ERROR: $($_.Exception.Message)`r`n$($_.ScriptStackTrace)" |
        Set-Content -LiteralPath $result -Encoding ascii
    exit 1
}
