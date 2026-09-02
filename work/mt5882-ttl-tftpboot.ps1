$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000

$commands = @(
    'setenv ipaddr 169.254.55.222',
    'setenv serverip 169.254.55.25',
    'setenv netmask 255.255.0.0',
    'tftpboot 0x02000000 uImage-mt5882-cbar'
)
$stage = 0
$buffer = ''
$deadline = [DateTime]::UtcNow.AddMinutes(8)
$bootSent = $false
$breakSent = $false

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] COM3 aperta; interrompo il ping e richiamo U-Boot...')
    $serial.Write([char]3)
    Start-Sleep -Milliseconds 300
    $serial.Write("`r")

    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $buffer += $text
            if ($buffer.Length -gt 16384) {
                $buffer = $buffer.Substring($buffer.Length - 16384)
            }
        }

        if (-not $breakSent -and $buffer -match 'U-Boot 2011\.12\.12') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Autoboot interrotto per il caricamento TFTP.")
            $buffer = ''
        }

        if (-not $breakSent -and $buffer -match 'Hit any key to stop autoboot') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Autoboot interrotto per il caricamento TFTP.")
            $buffer = ''
        }

        if ($buffer -match 'mt5882\s*#\s*$') {
            if ($stage -lt $commands.Count) {
                $command = $commands[$stage]
                if ($command -like 'tftpboot *') {
                    [Console]::WriteLine("`r`n[HOST] Attendo 10 secondi per la negoziazione Ethernet...")
                    Start-Sleep -Seconds 10
                }
                Start-Sleep -Milliseconds 250
                [Console]::WriteLine("`r`n[HOST] -> $command")
                $serial.Write($command + "`r")
                $stage++
                $buffer = ''
            }
            elseif (-not $bootSent) {
                if ($buffer -match 'Bytes transferred = 5429472') {
                    [Console]::WriteLine("`r`n[HOST] Immagine ricevuta; avvio in sola RAM.")
                    $serial.Write('setenv bootargs console=ttyMT0,115200n1 earlyprintk rdinit=/init loglevel=8 ignore_loglevel' + "`r")
                    Start-Sleep -Milliseconds 500
                    $serial.Write('bootm 0x02000000' + "`r")
                    $bootSent = $true
                    $buffer = ''
                }
                else {
                    [Console]::WriteLine("`r`n[HOST] TFTP non completato; nessun boot eseguito.")
                    break
                }
            }
        }

        Start-Sleep -Milliseconds 20
    }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    [Console]::WriteLine("`r`n[HOST] COM3 chiusa.")
}
