$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$sourceDir = Join-Path $repo 'buildroot\rootfs-overlay\usr\local\sbin'
$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 5000

function Invoke-Line([string]$Line, [int]$TimeoutSeconds = 20) {
    $marker = '__H32_TTL_' + [Guid]::NewGuid().ToString('N') + '__'
    $serial.Write('(' + $Line + '); rc=$?; echo ' + $marker + ':$rc' + "`r")
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $buffer += $serial.ReadExisting()
        if ($buffer -match ([regex]::Escape($marker) + ':(\d+)')) {
            if ([int]$Matches[1] -ne 0) { throw "TV command failed: $Line" }
            return
        }
        Start-Sleep -Milliseconds 25
    }
    throw 'Timeout waiting for the TV shell'
}

function Send-File([string]$Source, [string]$Destination) {
    $temporary = '/tmp/' + [IO.Path]::GetFileName($Destination) + '.b64'
    Invoke-Line ('rm -f ' + $temporary)
    $encoded = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Source))
    for ($offset = 0; $offset -lt $encoded.Length; $offset += 600) {
        $piece = $encoded.Substring($offset, [Math]::Min(600, $encoded.Length - $offset))
        Invoke-Line ("printf '%s' '" + $piece + "' >> " + $temporary)
    }
    Invoke-Line ('base64 -d ' + $temporary + ' > ' + $Destination + ' && rm -f ' + $temporary)
}

try {
    $serial.Open()
    $serial.DiscardInBuffer()
    $serial.Write("`r")
    $initial = ''
    $loginDeadline = [DateTime]::UtcNow.AddSeconds(2)
    while ([DateTime]::UtcNow -lt $loginDeadline) {
        $initial += $serial.ReadExisting()
        if ($initial -match 'login:\s*$' -or $initial -match '(?m)^#\s*$') { break }
        Start-Sleep -Milliseconds 30
    }
    if ($initial -match 'login:\s*$') {
        $serial.Write("root`r")
        Start-Sleep -Seconds 1
        [void]$serial.ReadExisting()
    }

    # Refuse to install unless the live root is the USB ext4 partition.
    Invoke-Line 'awk ''$1=="/dev/sda2" && $2=="/" {ok=1} END {exit !ok}'' /proc/mounts'
    Invoke-Line 'mkdir -p /usr/local/sbin'
    foreach ($name in 'h32-wifi-connect', 'h32-wifi-setup', 'h32-wifi-status') {
        Send-File (Join-Path $sourceDir $name) ('/usr/local/sbin/' + $name)
    }
    Send-File (Join-Path $repo 'buildroot\rootfs-overlay\etc\init.d\S99zzwifi') '/etc/init.d/S99zzwifi'
    Invoke-Line 'chmod 755 /usr/local/sbin/h32-wifi-connect /usr/local/sbin/h32-wifi-setup /usr/local/sbin/h32-wifi-status'
    Invoke-Line 'chmod 755 /etc/init.d/S99zzwifi'
    Invoke-Line 'sync'
    Write-Output 'WIFI_TOOLS_INSTALLED_ON_USB'
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
