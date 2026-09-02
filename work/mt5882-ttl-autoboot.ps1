$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000

$stage = 0
$breakSent = $false
$buffer = ''
$deadline = [DateTime]::UtcNow.AddMinutes(12)
$commands = @(
    'printenv ipaddr',
    'printenv serverip',
    'printenv netmask',
    'help tftpboot',
    'setenv ipaddr 192.168.1.222',
    'setenv serverip 192.168.1.18',
    'setenv netmask 255.255.255.0',
    'ping 192.168.1.18'
)

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] COM3 aperta a 115200 8N1. In attesa del boot...')

    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $buffer += $text
            if ($buffer.Length -gt 8192) {
                $buffer = $buffer.Substring($buffer.Length - 8192)
            }
        }

        if (-not $breakSent -and $buffer -match 'U-Boot 2011\.12\.12') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Spazio inviato prima del conto alla rovescia.")
            $buffer = ''
        }

        if (-not $breakSent -and $buffer -match 'Hit any key to stop autoboot') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Autoboot interrotto.")
            $buffer = ''
        }

        if ($buffer -match 'mt5882\s*#\s*$') {
            $command = if ($stage -lt $commands.Count) { $commands[$stage] } else { $null }

            if ($null -ne $command) {
                Start-Sleep -Milliseconds 250
                [Console]::WriteLine("`r`n[HOST] -> $command")
                $serial.Write($command + "`r")
                $stage++
                $buffer = ''
            }
        }

        Start-Sleep -Milliseconds 20
    }
}
finally {
    if ($serial.IsOpen) {
        $serial.Close()
    }
    [Console]::WriteLine("`r`n[HOST] Sessione TTL terminata.")
}
