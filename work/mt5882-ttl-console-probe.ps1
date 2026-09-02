$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000
try {
    $serial.Open()
    $serial.Write("`r")
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) { [Console]::Write($text) }
        Start-Sleep -Milliseconds 25
    }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
}
