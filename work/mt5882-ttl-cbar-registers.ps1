$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000

$commands = @(
    'md.l f1000000 4',
    'md.l f1000100 4',
    'md.l f1001000 4',
    'md.l f1001fe0 8',
    'md.l f1002000 4',
    'md.l f1002fe0 8'
)
$stage = 0
$buffer = ''
$breakSent = $false
$deadline = [DateTime]::UtcNow.AddMinutes(12)

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] COM3 aperta. In attesa del riavvio per lettura CBAR/GIC...')
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $buffer += $text
            if ($buffer.Length -gt 8192) { $buffer = $buffer.Substring($buffer.Length - 8192) }
        }
        if (-not $breakSent -and $buffer -match 'U-Boot 2011\.12\.12') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Autoboot interrotto.")
            $buffer = ''
        }
        elseif (-not $breakSent -and $buffer -match 'Hit any key to stop autoboot') {
            $serial.Write(' ')
            $breakSent = $true
            $buffer = ''
        }
        if ($buffer -match 'mt5882\s*#\s*$') {
            if ($stage -ge $commands.Count) {
                [Console]::WriteLine("`r`n[HOST] Letture completate; TV lasciata al prompt U-Boot.")
                break
            }
            $command = $commands[$stage]
            Start-Sleep -Milliseconds 250
            [Console]::WriteLine("`r`n[HOST] -> $command")
            $serial.Write($command + "`r")
            $stage++
            $buffer = ''
        }
        Start-Sleep -Milliseconds 20
    }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    [Console]::WriteLine("`r`n[HOST] COM3 chiusa.")
}
