param([string]$TvIp = '192.168.1.50', [string]$PcIp = '192.168.1.48')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = Split-Path $PSScriptRoot -Parent
$package = Join-Path $repo 'outputs\wpa-original-hisense\h32-wpa-original.tar.gz'
$remote = '/tmp/h32-wpa-upload-' + [Guid]::NewGuid().ToString('N')
$destination = '/proc/1/root/mnt/usb2/h32-wpa-original.tar.gz'
$token = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
$config = @{
    destination = $destination
    client_ip = $PcIp
    bind_ip = $TvIp
    token = $token
    size = (Get-Item -LiteralPath $package).Length
    sha256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json -Compress

$serial = [IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.WriteTimeout = 5000

function Invoke-Line([string]$Line, [int]$TimeoutSeconds = 60) {
    $marker = '__H32_WPA_' + [Guid]::NewGuid().ToString('N') + '__'
    $serial.Write('(' + $Line + '); rc=$?; echo ' + $marker + ':$rc' + "`r")
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $buffer += $serial.ReadExisting()
        if ($buffer -match ([regex]::Escape($marker) + ':(\d+)')) {
            if ([int]$Matches[1] -ne 0) { throw "TV command failed: $Line" }
            return $buffer
        }
        Start-Sleep -Milliseconds 30
    }
    throw 'TTL shell response timeout'
}

function Send-SmallFile([byte[]]$Bytes, [string]$Path) {
    $encoded = [Convert]::ToBase64String($Bytes)
    [void](Invoke-Line ('rm -f ' + $Path + '.b64'))
    for ($offset = 0; $offset -lt $encoded.Length; $offset += 600) {
        $piece = $encoded.Substring($offset, [Math]::Min(600, $encoded.Length - $offset))
        [void](Invoke-Line ("printf '%s' '" + $piece + "' >> " + $Path + '.b64'))
    }
    $reply = Invoke-Line ('base64 -d ' + $Path + '.b64 > ' + $Path + ' && rm -f ' + $Path + '.b64 && sha256sum ' + $Path)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    if ($reply -notmatch $hash) { throw 'Uploaded helper hash mismatch' }
}

try {
    $serial.Open()
    $serial.DiscardInBuffer()
    $serial.Write("`r")
    Start-Sleep -Seconds 1
    $initial = $serial.ReadExisting()
    if ($initial -match 'login:\s*$') {
        $serial.Write("root`r")
        Start-Sleep -Seconds 1
        [void]$serial.ReadExisting()
    }
    [void](Invoke-Line 'umask 077')
    Send-SmallFile ([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'receive-usb-package-once.py'))) ($remote + '.py')
    Send-SmallFile ([Text.Encoding]::UTF8.GetBytes($config)) ($remote + '.json')
    [void](Invoke-Line ('chroot /mnt/usb2/archlinux/rootfs /usr/bin/python3 -B /proc/1/root' + $remote + '.py /proc/1/root' + $remote + '.json > ' + $remote + '.log 2>&1 < /dev/null &'))
    Start-Sleep -Seconds 2
    $reply = Invoke-Line ('cat ' + $remote + '.log')
    if ($reply -notmatch '(?m)^UPLOAD_READY\r?$') { throw 'USB receiver did not start' }

    $response = Invoke-WebRequest -Uri ('http://' + $TvIp + ':8099/package') -Method Put -InFile $package -Headers @{'X-Package-Key' = $token} -ContentType 'application/octet-stream' -TimeoutSec 180
    $body = if ($response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($response.Content) } else { [string]$response.Content }
    if ($body -notmatch 'USB_PACKAGE_VERIFIED') { throw 'Package upload not verified' }

    $install = 'stage=/mnt/usb2/.h32-wpa-original-new; test ! -e /mnt/usb2/h32-wpa-original; rm -rf "$stage"; mkdir "$stage"; zcat /mnt/usb2/h32-wpa-original.tar.gz | tar -xf - -C "$stage"; cd "$stage/h32-wpa-original"; sha256sum -c SHA256SUMS >/dev/null; cd /; mv "$stage/h32-wpa-original" /mnt/usb2/h32-wpa-original; rmdir "$stage"; rm -f /mnt/usb2/h32-wpa-original.tar.gz; sync'
    [void](Invoke-Line $install 180)
    Write-Output 'HISENSE_WPA_ORIGINAL_INSTALLED_ON_USB'
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
