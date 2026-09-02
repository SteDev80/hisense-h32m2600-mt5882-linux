$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000

function Invoke-UbootCommand([string]$command, [int]$timeoutSeconds = 30) {
    [Console]::WriteLine("`r`n[HOST] -> $command")
    $script:serial.Write($command + "`r")
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddSeconds($timeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $script:serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $buffer += $text
        }
        if ($buffer -match 'mt5882\s*#\s*$') { return $buffer }
        Start-Sleep -Milliseconds 20
    }
    throw "Timeout in attesa del prompt dopo: $command"
}

try {
    $serial.Open()
    $serial.Write("`r")
    Start-Sleep -Milliseconds 300
    [void]$serial.ReadExisting()

    [void](Invoke-UbootCommand 'fatls usb 0:1 /' 15)
    $loadOutput = Invoke-UbootCommand 'fatload usb 0:1 0x02000000 uImage-h32m2600-series5-upnowait' 90
    if ($loadOutput -notmatch '2616360 bytes read') {
        throw 'Dimensione del kernel non confermata: boot annullato.'
    }

    [Console]::WriteLine("`r`n[HOST] Immagine completa verificata da U-Boot.")
    [void](Invoke-UbootCommand 'setenv bootargs console=ttyMT0,115200n1 earlyprintk rdinit=/init loglevel=8 ignore_loglevel' 15)

    [Console]::WriteLine("`r`n[HOST] -> bootm 0x02000000")
    $serial.Write("bootm 0x02000000`r")
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) { [Console]::Write($text) }
        Start-Sleep -Milliseconds 20
    }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    [Console]::WriteLine("`r`n[HOST] COM3 chiusa.")
}
