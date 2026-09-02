$ErrorActionPreference = 'Stop'

$expectedDiskNumber = 1
$expectedSerial = '2362577235'
$expectedSize = 16022241280
$root = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an'
$artifacts = Join-Path $root 'outputs\buildroot-h32m2600'
$image = Join-Path $artifacts 'rootfs.ext4'
$log = Join-Path $root 'outputs\buildroot-h32m2600\prepare-usb.log'

Start-Transcript -LiteralPath $log -Force
try {
    $disk = Get-Disk -Number $expectedDiskNumber
    if ($disk.BusType -ne 'USB' -or
        $disk.FriendlyName -ne 'Lexar JumpDrive' -or
        $disk.SerialNumber.Trim() -ne $expectedSerial -or
        $disk.Size -ne $expectedSize -or
        $disk.IsBoot -or $disk.IsSystem) {
        throw "Controllo di sicurezza fallito: il disco $expectedDiskNumber non e' la Lexar prevista."
    }
    if ((Get-Item -LiteralPath $image).Length -ne 268435456) {
        throw 'Immagine rootfs.ext4 assente o di dimensione inattesa.'
    }

    Write-Host 'Disco verificato: Lexar JumpDrive 2362577235, 16 GB.'
    Write-Host 'Ripartizionamento della sola chiavetta USB...'
    Clear-Disk -Number $expectedDiskNumber -RemoveData -RemoveOEM -Confirm:$false
    $disk = Get-Disk -Number $expectedDiskNumber
    if ($disk.PartitionStyle -eq 'RAW') {
        Initialize-Disk -Number $expectedDiskNumber -PartitionStyle MBR
    }
    elseif ($disk.PartitionStyle -ne 'MBR') {
        throw "Stile partizione inatteso dopo Clear-Disk: $($disk.PartitionStyle)"
    }

    $boot = New-Partition -DiskNumber $expectedDiskNumber -Size 536870912 -AssignDriveLetter
    Format-Volume -Partition $boot -FileSystem FAT32 -NewFileSystemLabel 'MT5882BOOT' -Confirm:$false -Force | Out-Null
    $rootPart = New-Partition -DiskNumber $expectedDiskNumber -UseMaximumSize
    Set-Partition -DiskNumber $expectedDiskNumber -PartitionNumber $rootPart.PartitionNumber -MbrType 131
    $rootPart = Get-Partition -DiskNumber $expectedDiskNumber -PartitionNumber $rootPart.PartitionNumber

    Write-Host "Scrittura rootfs ext4 alla partizione $($rootPart.PartitionNumber), offset $($rootPart.Offset)..."
    $source = [System.IO.File]::Open($image, 'Open', 'Read', 'Read')
    $target = [System.IO.File]::Open('\\.\PhysicalDrive1', 'Open', 'ReadWrite', 'ReadWrite')
    try {
        [void]$target.Seek($rootPart.Offset, [System.IO.SeekOrigin]::Begin)
        $source.CopyTo($target, 4MB)
        $target.Flush($true)
    }
    finally {
        $source.Dispose()
        $target.Dispose()
    }

    $boot = Get-Partition -DiskNumber $expectedDiskNumber -PartitionNumber $boot.PartitionNumber
    $drive = "$($boot.DriveLetter):\"
    Copy-Item -LiteralPath (Join-Path $artifacts 'uInitrd-h32m2600-buildroot') -Destination $drive -Force
    Copy-Item -LiteralPath (Join-Path $artifacts 'rootfs.cpio.gz') -Destination $drive -Force
    Copy-Item -LiteralPath (Join-Path $artifacts 'boot-original-usb.txt') -Destination $drive -Force
    Copy-Item -LiteralPath (Join-Path $artifacts 'README-H32M2600.txt') -Destination $drive -Force
    Copy-Item -LiteralPath (Join-Path $artifacts 'h32m2600_buildroot_defconfig') -Destination $drive -Force
    Copy-Item -LiteralPath (Join-Path $artifacts 'SHA256SUMS.txt') -Destination $drive -Force

    $verify = [System.IO.File]::Open('\\.\PhysicalDrive1', 'Open', 'Read', 'ReadWrite')
    try {
        [void]$verify.Seek($rootPart.Offset + 1080, [System.IO.SeekOrigin]::Begin)
        $magic = New-Object byte[] 2
        if ($verify.Read($magic, 0, 2) -ne 2 -or $magic[0] -ne 0x53 -or $magic[1] -ne 0xEF) {
            throw 'Verifica ext4 fallita: firma 0xEF53 non trovata.'
        }
    }
    finally {
        $verify.Dispose()
    }

    Write-Host 'OK: FAT32 + rootfs ext4 scritti e verificati.'
    Get-Partition -DiskNumber $expectedDiskNumber | Format-Table PartitionNumber,DriveLetter,Type,Size,Offset -AutoSize
    Get-ChildItem -LiteralPath $drive | Format-Table Name,Length -AutoSize
}
finally {
    Stop-Transcript
}
