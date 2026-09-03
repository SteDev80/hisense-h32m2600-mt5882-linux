param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [int]$TimeoutSeconds = 120,
    [string]$Port = 'COM3'
)

$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new($Port, 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 5000
$marker = '__H32_COMMAND_DONE_' + [Guid]::NewGuid().ToString('N') + '__'

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

    $serial.Write('(' + $Command + '); rc=$?; echo ' + $marker + ':$rc' + "`r")
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $all = ''
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text) {
            [Console]::Write($text)
            $all += $text
            if ($all -match ([regex]::Escape($marker) + ':(\d+)')) {
                exit [int]$Matches[1]
            }
        }
        Start-Sleep -Milliseconds 30
    }
    throw "Timeout waiting for Linux shell command on $Port"
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
