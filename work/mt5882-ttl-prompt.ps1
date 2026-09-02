$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000

$commands = @(
    'help tftpboot',
    'setenv ipaddr 192.168.1.222',
    'setenv serverip 192.168.1.18',
    'setenv netmask 255.255.255.0',
    'ping 192.168.1.18'
)
$stage = 0
$buffer = ''
$deadline = [DateTime]::UtcNow.AddMinutes(3)

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] COM3 aperta; richiamo il prompt U-Boot...')
    $serial.Write("`r")

    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $buffer += $text
            if ($buffer.Length -gt 8192) {
                $buffer = $buffer.Substring($buffer.Length - 8192)
            }
        }

        if ($buffer -match 'mt5882\s*#\s*$') {
            if ($stage -ge $commands.Count) {
                [Console]::WriteLine("`r`n[HOST] Diagnostica completata; prompt lasciato invariato.")
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
